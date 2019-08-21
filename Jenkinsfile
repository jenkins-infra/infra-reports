#!/usr/bin/env groovy

pipeline {

	triggers {
		cron('H/15 * * * *')
	}

	options {
		// 6 hours timeout combined with lock and inverse precedence to will properly gate the GitHub permissions report
		timeout(time: 10, unit: 'HOURS')
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
				sh 'docker build permissions-report -t permissions-report'
				sh 'docker build artifactory-users-report -t artifactory-users-report'
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
				stage('Artifactory Permissions') {
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
				stage('GitHub Permissions') {
					agent {
						label 'docker&&linux'
					}
					environment {
						GITHUB_API = credentials('github-token')
					}
					options {
						lock(resource: 'github-permissions', inversePrecedence: true)
					}
					steps {
						sh 'docker build permissions-report -t permissions-report'
						sh 'docker run -e GITHUB_API_TOKEN=$GITHUB_API_PSW permissions-report > github-jenkinsci-permissions-report.json'
						archiveArtifacts 'github-jenkinsci-permissions-report.json'
						publishReports ([ 'github-jenkinsci-permissions-report.json' ])
					}
				}
			}
		}
	}
}
