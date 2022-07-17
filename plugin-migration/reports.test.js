/* eslint-env node, jest */
const MockDate = require('mockdate');
const crypto = require('crypto');
const path = require('path');

const talkback = require('talkback');

const {pluginsReport} = require('./reports.js');

jest.setTimeout(30000); // 30 seconds

let server;
beforeEach(function() {
  MockDate.set(new Date('2020-05-25 00:00:00Z'));
});

beforeAll(async function() {
  const port = 8888;
  process.env.GITHUB_SERVER = `http://localhost:${port}/graphql`;
  server = await talkback({
    host: 'https://api.github.com',
    port: port,
    path: path.join(__dirname, '__testData', 'vcr'),
    silent: true,
    ignoreHeaders: ['authorization'],
    ignoreQueryParams: ['adminuser', 'admintoken'],
    tapeNameGenerator: (tapeNumber, tape) => {
      const content = tape.req.body.toString();
      const hash = crypto.createHash('md5').update(content).digest('hex');
      const matches = content.match(/query (\w+)/);
      if (matches && matches[1]) {
        const variables = Object.entries(
            JSON.parse(content).variables,
        ).map(
            ([key, value]) => `${key}_${value}`,
        ).join('_');
        return `${tape.req.method.toLowerCase()}_${matches[1]}_${variables}_${hash}.json5`;
      }

      return `${tape.req.method.toLowerCase()}_${hash}.json5`;
    },
  }).start();
});
afterAll(function(done) {
  server.close(done);
});


describe('reports', function() {
  describe('happy path', function() {
    beforeAll( async () => {
      this.reportData = await pluginsReport();
    });
    it('should mark multiple-scms as deprecated', () => {
      expect(this.reportData.plugins.find(
          (plugin) => plugin.name == 'multiple-scms',
      )['labels']).toEqual([
        'deprecated', 'scm',
      ]);
    });
    it('have all the statuses ', () => {
      expect(this.reportData.statuses).toHaveProperty('ok');
      expect(this.reportData.statuses).toHaveProperty('pr merged');
      expect(this.reportData.statuses).toHaveProperty('pr open');
      expect(this.reportData.statuses).toHaveProperty('deprecated');
      expect(this.reportData.statuses).toHaveProperty('todo');
      expect(this.reportData.statuses).toHaveProperty('total');
    });
  });
});
