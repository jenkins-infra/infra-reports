# Jenkins GitHub Reports

If you want to execute these scripts locally, use the Docker image `jenkinsciinfra/helmfile` (source code at <https://github.com/jenkins-infra/docker-helmfile>).
It includes all the required dependencies:

- Ruby
- Ruby Gems for [octokit.rb](http://octokit.github.io/octokit.rb/) to generate reports about the `jenkinsci` GitHub organization and graphql
- Bash
- JQ, Azure and other command lines used by bash scripts

You can check the exact image version by checking the Jenkins agent pod template specified in `./JenkinsAgentPodTemplate.yaml`.

## Permissions Report

Prints a two-dimensional JSON array optimized for use in [DataTables](https://www.datatables.net/) hosted at [Source Code Hosting](https://www.jenkins.io/doc/developer/publishing/source-code-hosting/).

Format example:

```json
[
  [
    "ldap-plugin",
    "olamy",
    "push"
  ],
  [
    "ldap-plugin",
    "jglick",
    "push"
  ]
]
```

### Usage

We use a Github App for that, you'll need to define the following environment variables to run the script:

- GITHUB_APP_PRIVATE_KEY_B64: The Github App private key in PEM format, encoded in base64
- GITHUB_APP_ID: The GitHub App's identifier (type integer) set when registering an app
- GITHUB_ORG_NAME: The Github organization name (ex: "jenkinsci")

```shell
cd permisions-report/
ruby ./permisions-report.rb
```

## Artifactory Users Report

Creates a report listing all user accounts in Artifactory.

Consumed by <https://github.com/jenkins-infra/repository-permissions-updater/blob/master/src/main/groovy/io/jenkins/infra/repository_permissions_updater/KnownUsers.groovy>

### Usage

This requires Artifactory admin user credentials.

```bash
cd artifactory-users-report/
export ARTIFACTORY_AUTH=admin-username:admin-token
bash ./user-report.sh
```

## Jira Users Report

Creates a report listing all user accounts in a Jira group containing plugin maintainers.
Currently, we use `jira-users` for that, but may in the future use a more limited group.

Consumed by <https://github.com/jenkins-infra/repository-permissions-updater/blob/master/src/main/groovy/io/jenkins/infra/repository_permissions_updater/KnownUsers.groovy>

### Usage

This requires Jira admin user credentials.

```bash
cd jira-users-report/
export JIRA_AUTH=admin-username:admin-token
bash ./user-report
```

## Plugin Documentation Migration Report

Creates an html file with the current state of the documentation migration project

Consumed by docs-sig

### Usage

We use a Github App for that, you'll need to define the following environment variables to run the script:

- GITHUB_APP_PRIVATE_KEY_B64: The Github App private key in PEM format, encoded in base64
- GITHUB_APP_ID: The GitHub App's identifier (type integer) set when registering an app
- GITHUB_ORG_NAME: The Github organization name (ex: "jenkinsci")

```bash
cd plugin-migration
npm install
node index.js > index.html
```

## Mirrorbits Mirrors List Report

Creates a report listing all the mirrors within Jenkins Download Mirrorbits

Consumed by nothing yet

### Usage

WARNING need the docker image `allinone` (jenkinsciinfra/jenkins-agent-ubuntu-22.04) to have the correct tools (xq)

```bash
cd mirrorbits-mirrors-list/
bash ./mirrorbits-mirrors-list.sh
```
