/* eslint-env node */
const axios = require('./axios');
const {getPullRequests} = require('./graphql.js');
const moment = require('moment');

const docsUrl = 'http://updates.jenkins.io/plugin-documentation-urls.json';

/**
 * Strips out all the extra github url type stuff and returns the plugin name from github
 * @param {string} url
 * @param {object} repoToPlugins maps repo URLs to lists of plugin IDs
 * @return {string} plugin name
 */
function getAllPluginNamesForRepo(url, repoToPlugins) {
  const match = url.match(/https?:\/\/github.com\/([^/]*)\/([^/.]*)/);
  const byUrl = repoToPlugins[match[0]];
  return byUrl ? byUrl : [match[2].replace(/-plugin$/, '')];
}

/**
 * Get the content of the progress report
 * @return {array} of objects representing table rows
 */
async function pluginsReport() {
  const updateCenterUrl = 'https://updates.jenkins.io/current/update-center.actual.json';


  const documentation = await getContent(docsUrl, 'json');
  const uc = await getContent(updateCenterUrl, 'json');
  const pulls = await getPulls(uc.plugins);
  const report = [];
  const recent = [];
  Object.keys(uc.plugins).forEach(function (key) {
    const plugin = uc.plugins[key];
    const url = documentation[key].url || '';
    plugin.name = key;
    plugin.installs = plugin.popularity || 0;
    plugin.releaseDate = moment(plugin.releaseTimestamp).format('YYYY-MM-DD');
    if (url.match('https?://github.com/jenkinsci/')) {
      plugin.status = 'OK';
      plugin.className = 'success';
      if (pulls['merged'][key]) {
        recent.push(key);
      }
    } else if (plugin.labels.includes('deprecated') ||
      Object.keys(uc.deprecations).includes(plugin.name)) {
      plugin.status = 'deprecated';
      plugin.className = 'success';
    } else if (pulls['merged'][key]) {
      plugin.status = 'PR merged';
      plugin.className = 'info';
      plugin.action = pulls['merged'][key];
    } else if (pulls['open'][key]) {
      plugin.status = 'PR open';
      plugin.className = 'info';
      plugin.action = pulls['open'][key];
    } else {
      plugin.status = 'TODO';
      plugin.action = '/?pluginName=' + plugin.name;
    }
    report.push(plugin);
  });
  report.sort((a, b) => b.installs - a.installs);

  const statuses = report.reduce((statuses, report) => {
    statuses[report.status.toLowerCase()] = (statuses[report.status.toLowerCase()] || 0) + 1;
    return statuses;
  }, {});
  statuses.total = report.length;
  return {
    plugins: report,
    statuses,
    recent,
  };
}

/**
 * Gets documentation URL for a plugin from Update Center
 * @param {string} pluginId plugin ID
 * @return {string} documentation URL
 */
async function getPluginWikiUrl(pluginId) {
  const documentation = await getContent(docsUrl, 'json');
  if (documentation[pluginId]) {
    return documentation[pluginId].url.replace('//wiki.jenkins-ci.org', '//wiki.jenkins.io');
  }
  return '';
}

/**
 * Gets list of all unreleased pull requests from GitHub project
 * @param {plugins} plugins map (plugin name) => plugin properties (see update-center.actual.json)
 * @return {object} nested map (state) => (plugin name) => url
 */
async function getPulls(plugins) {
  const repoToPlugins = {};
  Object.keys(plugins).forEach(function (key) {
    const scm = plugins[key].scm;
    repoToPlugins[scm] = repoToPlugins[scm] || [];
    repoToPlugins[scm].push(key);
  });
  const data = await getPullRequests();
  const columns = data.organization.project.columns.edges;
  return {'open': await getPullMap(columns[1], repoToPlugins), 'merged': await getPullMap(columns[2], repoToPlugins)};
}

/**
 * Gets PRs for one column
 * @param {object} column from GraphQL
 * @param {object} repoToPlugins map (repo URL) => list of plugin IDs
 * @return {object} map (plugin name) => url
 */
async function getPullMap(column, repoToPlugins) {
  const projectToPull = {};
  for (const edge of column.node.cards.edges) {
    if (!edge.node.content) {
      continue;
    }
    if (!edge.node.content.url) {
      continue;
    }
    const {url} = edge.node.content;
    const pluginNames = getAllPluginNamesForRepo(url, repoToPlugins);
    pluginNames.forEach(function (pluginName) {
      projectToPull[pluginName] = url;
    });
  }
  return projectToPull;
}

/**
 * Load content from URL, using cache.
 * @param {string} url
 * @param {string} type 'json' or 'blob'
 * @return {object} JSON object or string
 */
async function getContent(url, type) {
  return axios.get(url, {'type': type}).then((response) => response.data)
}

module.exports = {
  pluginsReport,
  getPluginWikiUrl,
};
