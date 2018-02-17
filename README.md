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

	docker build permission-reports -t permissions-report
	docker run -e GITHUB_API_TOKEN=1234567890abcdef1234567890abcdef permissions-report
