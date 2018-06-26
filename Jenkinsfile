#!/usr/bin/env groovy

pipeline {

	triggers {
		cron('H H/2 * * *')
	}

	agent { label 'docker' }

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
			steps {
				withCredentials([usernameColonPassword(credentialsId: 'artifactoryAdmin', variable: 'ARTIFACTORY_AUTH')]) {
					sh 'docker run -e ARTIFACTORY_AUTH=$ARTIFACTORY_AUTH artifactory-users-report > artifactory-ldap-users-report.json'
				}
				withCredentials([usernamePassword(credentialsId: 'github-token', passwordVariable: 'GITHUB_API_TOKEN', usernameVariable: '_')]) {
					sh 'docker run -e GITHUB_API_TOKEN=$GITHUB_API_TOKEN permissions-report > github-jenkinsci-permissions-report.json'
				}
				archiveArtifacts '*.json'
				publishReports ([ /*'github-jenkinsci-permissions-report.json',*/ 'artifactory-ldap-users-report.json' ])
			}
		}
	}
}
