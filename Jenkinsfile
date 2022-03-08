#!/usr/bin/env groovy

pipeline {

	triggers {
		cron('H * * * *')
	}

	options {
		// 6 hours timeout combined with lock and inverse precedence to will properly gate the GitHub permissions report
		timeout(time: 25, unit: 'HOURS')
	}

	agent none

	stages {

		/* Run only on ci.jenkins.io for PR builds */
		stage ('CI Build') {
			when {
				expression {
					!infra.isTrusted()
				}
			}
			agent {
				label 'docker&&linux'
			}
			steps {
				sh 'docker build permissions-report -t fork-report'
				sh 'docker build permissions-report -t permissions-report'
				sh 'docker build artifactory-users-report -t artifactory-users-report'
				sh 'docker build jira-users-report -t jira-users-report'
				sh 'docker build maintainers-info-report -t maintainers-info-report'
			}
		}

		/* When running on trusted.ci.jenkins.io, build images and publish reports */
		stage ('Publishing') {
			when {
				expression {
					infra.isTrusted()
				}
			}
			parallel {
				stage('GitHub Forks') {
					agent {
						label 'docker'
					}
					steps {
						withCredentials(
							[usernamePassword(credentialsId: 'jenkins-infra-reports', usernameVariable: 'GITHUB_APP', passwordVariable: 'GITHUB_ACCESS_TOKEN')]
						) {
							sh 'docker build fork-report -t fork-report'
							sh 'docker run -e GITHUB_API_TOKEN=$GITHUB_ACCESS_TOKEN fork-report > github-jenkinsci-fork-report.json'
							archiveArtifacts 'github-jenkinsci-fork-report.json'
							publishReports ([ 'github-jenkinsci-fork-report.json' ])
						}
					}
				}
				stage('Artifactory Users') {
					agent {
						label 'docker&&linux'
					}
					environment {
						ARTIFACTORY_AUTH = credentials('artifactoryAdmin')
					}
					steps {
						sh 'docker build artifactory-users-report -t artifactory-users-report'
						sh 'docker run -e ARTIFACTORY_AUTH=$ARTIFACTORY_AUTH artifactory-users-report > artifactory-ldap-users-report.json'
						archiveArtifacts 'artifactory-ldap-users-report.json'
						publishReports ([ 'artifactory-ldap-users-report.json' ])
					}
				}
				stage('Jira Users') {
					agent {
						label 'docker'
					}
					environment {
						JIRA_AUTH = credentials('jiraAuth')
					}
					steps {
						sh 'docker build jira-users-report -t jira-users-report'
						sh 'docker run -e JIRA_AUTH="${JIRA_AUTH_USR}:${JIRA_AUTH_PSW}" jira-users-report > jira-users-report.json'
						archiveArtifacts 'jira-users-report.json'
						publishReports ([ 'jira-users-report.json' ])
					}
				}
				stage('Maintainers Jira Info') {
					agent {
						label 'docker'
					}
					environment {
						JIRA_AUTH = credentials('jiraAuth')
					}
					steps {
						sh 'docker build maintainers-info-report -t maintainers-info-report'
						sh 'docker run -e JIRA_AUTH="${JIRA_AUTH_USR}:${JIRA_AUTH_PSW}" maintainers-info-report > maintainers-info-report.json'
						archiveArtifacts 'maintainers-info-report.json'
						publishReports ([ 'maintainers-info-report.json' ])
					}
				}
				stage('GitHub Permissions') {
					agent {
						label 'docker&&linux'
					}
					environment {
						GITHUB_APP_PRIVATE_KEY_B64 = credentials('githubapp-jenkins-infra-reports-private-key-b64')
						GITHUB_APP_ID = credentials('githubapp-jenkins-infra-reports-app-identifier')
						GITHUB_ORG_NAME = "jenkinsci"
					}
					options {
						lock(resource: 'github-permissions', inversePrecedence: true)
					}
					steps {
						sh 'docker build permissions-report -t permissions-report'
						sh 'docker run -e GITHUB_APP_PRIVATE_KEY_B64 -e GITHUB_APP_ID -e GITHUB_ORG_NAME permissions-report > github-jenkinsci-permissions-report.json'
						archiveArtifacts 'github-jenkinsci-permissions-report.json'
						publishReports ([ 'github-jenkinsci-permissions-report.json' ])
					}
				}
			}
		}
	}
}
