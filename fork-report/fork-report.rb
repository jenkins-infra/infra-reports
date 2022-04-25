# Usage: GITHUB_API_TOKEN=abcdefabcdef ruby fork-report.rb > report.json

require 'graphql/client'
require 'graphql/client/http'
require 'httparty'
require 'pp'
require 'json'

$auth = "bearer #{ENV['GITHUB_AUTH_PSW']}"

module GitHubGraphQL
  HTTP = GraphQL::Client::HTTP.new('https://api.github.com/graphql') do
    def headers(context)
      {
        'Authorization' => $auth
      }
    end
  end
  Schema = GraphQL::Client.load_schema(HTTP)
  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)
end


CollaboratorsQuery = GitHubGraphQL::Client.parse <<-'GRAPHQL'

query($repository_cursor: String) {
  organization(login: "jenkinsci") {
    repositories(first: 100, after: $repository_cursor) {
      pageInfo {
        startCursor
        hasNextPage
        endCursor
      }
      edges {
        node {
          nameWithOwner
          isFork
          parent {
            nameWithOwner
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

def record_repository(repo_name, source_repo)
  $table_data << [ repo_name, source_repo ]
end

def ratelimit_info(rate_limit)
  STDERR.puts "Rate limit: Cost: #{rate_limit.cost}, limit #{rate_limit.limit}, remaining: #{rate_limit.remaining}, reset at: #{rate_limit.reset_at}"
end

repository_cursor = nil
collaborator_cursor = nil
error_count = 0

loop do
  STDERR.puts "Calling with cursors: repository #{repository_cursor}"
  result = GitHubGraphQL::Client.query(CollaboratorsQuery, variables: {repository_cursor: repository_cursor  })

  if !result.errors[:data].empty? then
    STDERR.puts result.errors[:data]
    sleep 5
    if error_count > 50 then
      # fatal
      STDERR.puts 'Consecutive error count limit reached, aborting'
      abort('Too many errors')
    else
      error_count += 1
    end
  else
    error_count = 0

    result.data.organization.repositories.edges.each { |repo|
      repo_name = repo.node.name_with_owner
      STDERR.puts "Processing #{repo_name}"
      if repo.node.is_fork then
        record_repository(repo_name, repo.node.parent&.name_with_owner )
      end
    }

    ratelimit_info(result.data.rate_limit)

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

puts JSON.generate($table_data)
