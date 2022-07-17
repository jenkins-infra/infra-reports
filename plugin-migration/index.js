/* eslint-env node */
const {pluginsReport} = require('./reports');
const axios = require('./axios')
const jwt = require('jsonwebtoken');

async function main() {
  if (!process.env.GITHUB_API_TOKEN) {
    const PRIVATE_KEY = Buffer.from(process.env.GITHUB_APP_PRIVATE_KEY_B64, 'base64').toString('ascii');

    // Generate a JWT to authenticate the Github App
    const payload = {
      // The time that this JWT was issued, _i.e._ now.
      iat: Math.floor(new Date().getTime() / 1000),

      // JWT expiration time (10 minute maximum)
      exp: Math.floor(new Date().getTime() / 1000) + (10 * 60),

      // Your GitHub App's identifier number
      iss: process.env.GITHUB_APP_ID
    }

    // Cryptographically sign the JWT.
    const authorizationHeader = `Bearer ${jwt.sign(payload, PRIVATE_KEY, {algorithm: 'RS256'})}`

    // List installation for the Github App(ref: https://docs.github.com/en/rest/reference/apps#list-installations-for-the-authenticated-app)
    const installationId = await axios({
      url: 'https://api.github.com/app/installations',
      headers: {
        'Authorization': authorizationHeader,
      }
    })
      .then((response) => response.data)
      .then((data) => data[0].id)
      .catch(axios.catchAxiosError)
    if (!installationId) {
      throw new Error(`Error: no Github App installation for the organization ${process.env.GITHUB_ORG_NAME}`)
    }

    // Retrieve the Installation Access Token of the Github App(ref: https://docs.github.com/en/rest/reference/apps#create-an-installation-access-token-for-an-app)
    process.env.GITHUB_API_TOKEN = await axios({
      url: `https://api.github.com/app/installations/${installationId}/access_tokens`,
      method: 'POST',
      headers: {
        'Authorization': authorizationHeader,
      }
    })
      .then((response) => response.data.token)
      .catch(axios.catchAxiosError)
  }
  const report = await pluginsReport();
  console.log(`
  <!DOCTYPE html>
  <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <title>Plugin Migration Progress</title>
    <meta content="width=device-width, initial-scale=1" name="viewport">
    <meta content="ie=edge" http-equiv="x-ua-compatible">
  </head>
  <body>
    <div class="container">
      <h1>Plugin Migration Progress</h1>
      <p>Todo: ${report.statuses.todo}, PR open: ${report.statuses['pr open']}, PR merged: ${report.statuses['pr merged']}, Done: ${report.statuses.ok + report.statuses.deprecated}, Total: ${report.statuses.total}</p>

      <table class="table table-bordered table-hover" data-sortable="true" data-sort-name="installs" data-sort-order="desc"  data-toggle="table">
        <thead class="thead-dark">
          <th data-field="name" data-sortable="true">Plugin Name</th>
          <th data-field="status" data-sortable="true">Status</th>
          <th data-field="releaseDate" data-sortable="true">Last release</th>
          <th data-field="installs" data-sortable="true">Installs</th>
        </thead>
        <tbody>
      ${report.plugins.map(plugin => {
    return `
        <tr class="table-${plugin.className}">
          <td>
            <a href="https://plugins.jenkins.io/${plugin.name}" target="_blank">
              ${plugin.name}
            </a>
          </td>
          <td>
            <a href="${plugin.action}">
              ${plugin.status}
            </a>
          </td>

          <td>
            ${plugin.releaseDate}
          </td>
          <td>
            ${plugin.installs}
          </td>
        </tr>
        `;
  }).join("")}
        </tbody>
      </table>
      ${report.recent.length ? '<h3 class="mt-3">Recently merged</h3>' + report.recent.join(", ") : ''}
    </div>

    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@4.0.0/dist/css/bootstrap.min.css" integrity="sha384-Gn5384xqQ1aoWXA+058RXPxPg6fy4IWvTNh0E263XmFcJlSAwiGgFAW/dAiS6JXm" crossorigin="anonymous">
    <link rel="stylesheet" href="https://unpkg.com/bootstrap-table@1.20.2/dist/bootstrap-table.min.css">

    <script src="https://code.jquery.com/jquery-3.2.1.slim.min.js" integrity="sha384-KJ3o2DKtIkvYIK3UENzmM7KCkRr/rE9/Qpg6aAZGJwFDMVNA/GpGFF93hXpG5KkN" crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/popper.js@1.12.9/dist/umd/popper.min.js" integrity="sha384-ApNbgh9B+Y1QKtv3Rn7W3mgPxhU9K/ScQsAP7hUibX39j7fakFPskvXusvfa0b4Q" crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.0.0/dist/js/bootstrap.min.js" integrity="sha384-JZR6Spejh4U02d8jOt6vLEHfe/JQGiRRSQQxSfFWpi1MquVdAyjUar5+76PVCmYl" crossorigin="anonymous"></script>
    <script src="https://unpkg.com/bootstrap-table@1.20.2/dist/bootstrap-table.min.js"></script>
  </body>
</html>
  `);
}

main()
