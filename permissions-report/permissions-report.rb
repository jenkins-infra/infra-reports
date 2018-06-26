# GitHub permissions report
#
# * List repositories in jenkinsci organization
#   https://developer.github.com/v3/repos/#list-organization-repositories
# * List org owners
#   https://developer.github.com/v3/orgs/members/#members-list
# * For each repository in organization
#   - List collaborators and access level, ignoring org owners
#     https://developer.github.com/v3/repos/collaborators/#list-collaborators

# Personal access token with `read:org`
# Created via https://github.com/settings/tokens/new
access_token = ENV['GITHUB_API_TOKEN']

org_name = "jenkinsci"

#############
# OPTIONS END
#############

require 'octokit'
require 'faraday-http-cache'
require 'json'

Octokit.per_page = 100
Octokit.auto_paginate = true

$client = Octokit::Client.new :access_token => access_token

stack = Faraday::RackBuilder.new do |builder|
  builder.use Faraday::HttpCache, serializer: Marshal, shared_cache: false
  builder.response :logger
  builder.use Octokit::Response::RaiseError
  builder.adapter Faraday.default_adapter
end
Octokit.middleware = stack

ratelimit = $client.ratelimit
STDERR.puts "Rate limit remaining: #{ratelimit.remaining}"

# local development/test: if there are args, they're assumed to be repo names
if ARGV.length > 0 then
  repositories = ARGV
else
  repositories = []
  $client.org_repos(org_name).each do |repo|
    repositories << repo[:name]
  end
end

STDERR.puts "Will scan #{repositories.length} repositories"

# determine org owners to filter them out
org_owners = $client.org_members(org_name, :role => "admin").map { |u| u.login }

ratelimit = $client.ratelimit
STDERR.puts "Rate limit remaining: #{ratelimit.remaining}"

table_data = []
i = 0

repositories.each do |repo|
  repo_name = org_name + "/" + repo
  i += 1

  STDERR.puts "#{i}: #{repo_name}"

  collaborators = $client.collaborators(repo_name, :affiliation => 'all')
  collaborators.each do |c|
    if org_owners.include? c[:login] then
      next
    end
    permission = c.permissions.admin ? 'admin' : (c.permissions.push ? 'push' : 'pull' )
    if permission != 'pull' then
      table_data << [ repo, c[:login], permission ]
    end
  end

  ratelimit = $client.ratelimit
  if ratelimit.remaining < 50 then
    STDERR.puts "Rate limit remaining: #{ratelimit.remaining} is below limit of 50, waiting #{ratelimit.resets_in} seconds until reset"
    sleep(ratelimit.resets_in + 5)
    ratelimit = $client.ratelimit
    STDERR.puts "Resuming with #{ratelimit.remaining} until #{ratelimit.resets_at}"
  end
end

puts JSON.generate(table_data)
