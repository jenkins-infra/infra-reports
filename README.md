# Jenkins GitHub Reports

Use [octokit.rb](http://octokit.github.io/octokit.rb/) to generate reports about the `jenkinsci` GitHub organization.

## Permissions Report

Prints a two-dimensional JSON array optimized for use in [DataTables](https://www.datatables.net/).

Format example:

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

### Usage

We use a Github App for that, you'll need to define the following environment variables to run the script:

- GITHUB_APP_PRIVATE_KEY_B64: The Github App private key in PEM format, encoded in base64
- GITHUB_APP_ID: The GitHub App's identifier (type integer) set when registering an app
- GITHUB_ORG_NAME: The Github organization name (ex: "jenkinsci")

	docker build permissions-report -t permissions-report
	docker run -e GITHUB_APP_PRIVATE_KEY_B64 -e GITHUB_APP_ID -e GITHUB_ORG_NAME permissions-report

## Artifactory Users Report

Creates a report listing all user accounts in Artifactory.

Consumed by https://github.com/jenkins-infra/repository-permissions-updater/blob/master/src/main/groovy/io/jenkins/infra/repository_permissions_updater/KnownUsers.groovy

### Usage

This requires Artifactory admin user credentials.

	docker build artifactory-users-report -t artifactory-users-report
	docker run -e ARTIFACTORY_AUTH=admin-username:admin-token artifactory-users-report

## Jira Users Report

Creates a report listing all user accounts in a Jira group containing plugin maintainers.
Currently, we use `jira-users` for that, but may in the future use a more limited group.

Consumed by https://github.com/jenkins-infra/repository-permissions-updater/blob/master/src/main/groovy/io/jenkins/infra/repository_permissions_updater/KnownUsers.groovy

### Usage

This requires Jira admin user credentials.

	docker build jira-users-report -t jira-users-report
	docker run -e JIRA_AUTH=theUser:thePassword jira-users-report
