#!/usr/bin/env groovy

pipeline {

	triggers {
		cron('H/15 * * * *')
	}

	options {
		// 6 hours timeout combined with lock and inverse precedence to will properly gate the GitHub permissions report
		timeout(time: 6, unit: 'HOURS')
	}

	agent none

	stages {
		stage ('Build') {
			steps {
				sh 'docker build permissions-report -t permissions-report'
				sh 'docker build artifactory-users-report -t artifactory-users-report'
			}
		}
		stage ('Run') {
			when {
				expression {
					infra.isTrusted()
				}
			}
			parallel {
				stage('Artifactory Permissions') {
					agent { label 'docker' }
					steps {
						withCredentials([usernameColonPassword(credentialsId: 'artifactoryAdmin', variable: 'ARTIFACTORY_AUTH')]) {
							sh 'docker run -e ARTIFACTORY_AUTH=$ARTIFACTORY_AUTH artifactory-users-report > artifactory-ldap-users-report.json'
						}
						archiveArtifacts 'artifactory-ldap-users-report.json'
						publishReports ([ 'artifactory-ldap-users-report.json' ])
					}
				}
				stage('GitHub Permissions') {
					agent { label 'docker' }
					options {
						lock(resource: 'github-permissions', inversePrecedence: true)
					}
					steps {
						withCredentials([usernamePassword(credentialsId: 'github-token', passwordVariable: 'GITHUB_API_TOKEN', usernameVariable: '_')]) {
							sh 'docker run -e GITHUB_API_TOKEN=$GITHUB_API_TOKEN permissions-report > github-jenkinsci-permissions-report.json'
						}
						archiveArtifacts 'github-jenkinsci-permissions-report.json'
						publishReports ([ 'github-jenkinsci-permissions-report.json' ])
					}
				}
			}
		}
	}
}
