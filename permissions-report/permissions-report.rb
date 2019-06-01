# Usage: GITHUB_API_TOKEN=abcdefabcdef ruby permission-report.rb > report.json

require "graphql/client"
require "graphql/client/http"
require 'httparty'
require 'pp'
require 'json'

$auth = "bearer #{ENV['GITHUB_API_TOKEN']}"

module GitHubGraphQL
  HTTP = GraphQL::Client::HTTP.new("https://api.github.com/graphql") do
    def headers(context)
      {
        "Authorization" => $auth
      }
    end
  end
  Schema = GraphQL::Client.load_schema(HTTP)
  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)
end


CollaboratorsQuery = GitHubGraphQL::Client.parse <<-'GRAPHQL'

query($repository_cursor: String, $collaborator_cursor: String) {
  organization(login: "jenkinsci") {
    repositories(first: 20, after: $repository_cursor) {
      pageInfo {
        startCursor
        hasNextPage
        endCursor
      }
      edges {
        node {
          name
          collaborators(first: 100, after: $collaborator_cursor) {
            totalCount
            pageInfo {
              startCursor
              hasNextPage
              endCursor
            }
            edges {
              permission
              node {
                login
              }
            }
          }
        }
      }
    }
  }
  rateLimit {
    limit
    cost
    remaining
    resetAt
  }
}
GRAPHQL


$table_data = []

response = HTTParty.get('https://api.github.com/orgs/jenkinsci/members?role=admin', :headers => {
  'Authorization' => $auth,
  "User-Agent" => "JenkinsCI report"
})

$org_admins = response.parsed_response.map{|user| user['login']&.downcase}

def record_collaborator(repo_name, collaborator, permission)
  unless permission == "READ" or $org_admins.include?(collaborator.downcase) then
    $table_data << [ repo_name, collaborator, permission ]
  end
end

def ratelimit_info(rate_limit)
  STDERR.puts "Rate limit: Cost: #{rate_limit.cost}, limit #{rate_limit.limit}, remaining: #{rate_limit.remaining}, reset at: #{rate_limit.reset_at}"
end

repository_cursor = nil
collaborator_cursor = nil
error_count = 0

loop do
  STDERR.puts "Calling with cursors: repository #{repository_cursor}, collaborator #{collaborator_cursor}"
  result = GitHubGraphQL::Client.query(CollaboratorsQuery, variables: {repository_cursor: repository_cursor, collaborator_cursor: collaborator_cursor})

  if !result.errors[:data].empty? then
    STDERR.puts result.errors[:data]
    sleep 5
    if error_count > 5 then
      # fatal
      STDERR.puts "Consecutive error count limit reached, aborting"
      abort("Too many errors")
    else
      error_count += 1
    end
  else
    error_count = 0

    collaborator_paging = nil
    result.data.organization.repositories.edges.each { |repo|
      repo_name = repo.node.name
      STDERR.puts "Processing #{repo_name}"
      if repo.node.collaborators then
        collaborator_paging = repo.node.collaborators.page_info
        repo.node.collaborators.edges.each { |collaborator|
          record_collaborator(repo_name, collaborator.node.login, collaborator.permission)
        }
      else
        STDERR.puts "Nil collaborators, archived repo #{repo_name}?"
      end
    }

    ratelimit_info(result.data.rate_limit)

    if collaborator_paging&.has_next_page then
      collaborator_cursor = collaborator_paging.end_cursor
      STDERR.puts "Next page of collaborators, from #{collaborator_cursor}"
    else
      repository_paging = result.data.organization.repositories.page_info
      if repository_paging.has_next_page
        collaborator_cursor = nil
        repository_cursor = repository_paging.end_cursor
        STDERR.puts "Next page of repositories, from #{repository_cursor}"
      else
        break
      end
    end
  end
end

puts JSON.generate($table_data)
