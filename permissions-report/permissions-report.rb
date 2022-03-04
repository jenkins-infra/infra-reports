# Usage: ruby permission-report.rb > report.json

require 'graphql/client'
require 'graphql/client/http'
require 'httparty'
require 'pp'
require 'json'
require 'openssl'
require 'jwt'
require 'time'
require 'base64'

# Expects that the private key in PEM format. Converts the newlines
PRIVATE_KEY = OpenSSL::PKey::RSA.new(Base64.decode64(ENV['GITHUB_APP_PRIVATE_KEY_B64']).gsub('\n', "\n"))
# The GitHub App's identifier (type integer) set when registering an app.
APP_IDENTIFIER = ENV['GITHUB_APP_ID']
# The organization to scan
GITHUB_ORG_NAME = ENV['GITHUB_ORG_NAME']

# Saves the raw payload and converts the payload to JSON format
def get_payload_request(request)
  # request.body is an IO or StringIO object
  # Rewind in case someone already read it
  request.body.rewind
  # The raw text of the body is required for webhook signature verification
  @payload_raw = request.body.read
  begin
    @payload = JSON.parse @payload_raw
  rescue => e
    fail  "Invalid JSON (#{e}): #{@payload_raw}"
  end
end

$userAgent = "Jenkins Infra Github App permissions-report (id: #{APP_IDENTIFIER})"

def get_auth_token
  # Generate a JWT to authenticate the Github App
  payload = {
      # The time that this JWT was issued, _i.e._ now.
      iat: Time.now.to_i,

      # JWT expiration time (10 minute maximum)
      exp: Time.now.to_i + (10 * 60),

      # Your GitHub App's identifier number
      iss: APP_IDENTIFIER
  }
  
  # Cryptographically sign the JWT.
  jwt = "Bearer #{JWT.encode(payload, PRIVATE_KEY, 'RS256')}"

  # List installation for the Github App (ref: https://docs.github.com/en/rest/reference/apps#list-installations-for-the-authenticated-app)
  response = HTTParty.get('https://api.github.com/app/installations', :headers => {
    'Authorization' => jwt,
    'User-Agent' => $userAgent
  })
  installationsResponse = response.parsed_response
  installationId = 0
  installationsResponse.each { |installation|
    if installation['account']['login'] == GITHUB_ORG_NAME then
      installationId = installation['id']
    end
  }
  if installationId > 0 then
    STDERR.puts "Running permissions-report on the organization #{GITHUB_ORG_NAME}"
  else
    abort "Error: no Github App installation for the organization #{GITHUB_ORG_NAME}"
  end

  # Retrieve the Installation Access Token of the Github App (ref: https://docs.github.com/en/rest/reference/apps#create-an-installation-access-token-for-an-app)
  response = HTTParty.post("https://api.github.com/app/installations/#{$installationId}/access_tokens", :headers => {
    'Authorization' => jwt,
    'User-Agent' => $userAgent
  })
  auth = "Bearer #{response.parsed_response['token']}"
end

$auth = get_auth_token

module GitHubGraphQL
  HTTP = GraphQL::Client::HTTP.new('https://api.github.com/graphql') do
    def headers(context)
      {
        'Authorization' => context[:authorization] != '' ? context[:authorization] : $auth,
        'User-Agent' => $userAgent
      }
    end
  end
  Schema = GraphQL::Client.load_schema(HTTP)
  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)
end

CollaboratorsQuery = GitHubGraphQL::Client.parse <<-'GRAPHQL'

query($github_org_name: String!, $repository_cursor: String, $collaborator_cursor: String) {
  organization(login: $github_org_name) {
    repositories(first: 10, after: $repository_cursor, privacy: PUBLIC) {
      pageInfo {
        startCursor
        hasNextPage
        endCursor
      }
      edges {
        node {
          name
          collaborators(first: 80, after: $collaborator_cursor) {
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

response = HTTParty.get("https://api.github.com/orgs/#{GITHUB_ORG_NAME}/members?role=admin", :headers => {
  'Authorization' => $auth,
  'User-Agent' => $userAgent
})

$org_admins = response.parsed_response.map{|user| user['login']}

def record_collaborator(repo_name, collaborator, permission)
  unless permission == 'READ' or $org_admins.include? collaborator then
    $table_data << [ repo_name, collaborator, permission ]
  end
end

def ratelimit_info(rate_limit)
  STDERR.puts "Rate limit: Cost: #{rate_limit.cost}, limit #{rate_limit.limit}, remaining: #{rate_limit.remaining}, reset at: #{rate_limit.reset_at}"
end

repository_cursor = nil
collaborator_cursor = nil
error_count = 0
counter = 0

loop do
  STDERR.puts "Calling with cursors: repository #{repository_cursor}, collaborator #{collaborator_cursor}"
  # Query with a new token every once in a while passed as context
  counter += 1
  if counter % 50 == 0 then
    $auth = get_auth_token
  end
  result = GitHubGraphQL::Client.query(CollaboratorsQuery, variables: {
    github_org_name: GITHUB_ORG_NAME,
    repository_cursor: repository_cursor,
    collaborator_cursor: collaborator_cursor
  }, context: {authorization: $auth})

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
