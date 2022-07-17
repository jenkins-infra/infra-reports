/* eslint-env node */
const {GraphQLClient} = require('graphql-request');
require('cross-fetch/polyfill');

const getPullRequestsQuery = `
query getPullRequests($login: String!) {
  organization(login: $login) {
    project(number:3) {
      columns (first:100) {
        edges {
          node {
            id
            cards {
              edges {
                node {
                  content {
                    ... on PullRequest {
                      url
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}`;

/**
 * Creates a graphql github client
 * @private
 * @return {GraphQLClient}
 */
function getGithubClient() {
  return new GraphQLClient(
    process.env.GITHUB_SERVER || 'https://api.github.com/graphql',
    {
      headers: {
        Authorization: `bearer ${process.env.GITHUB_API_TOKEN}`,
      },
    },
  );
}

/**
 * Get all the pull requests from the jenkins project
 * @return {object}
 */
async function getPullRequests() {
  return getGithubClient().request(
    getPullRequestsQuery,
    {
      login: 'jenkinsci',
    },
  );
}

module.exports = {
  getPullRequests,
};
