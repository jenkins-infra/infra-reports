#!/usr/bin/env groovy

pipeline {

	agent { label 'docker' }

	stages {
		stage ('Build') {
			steps {
				sh 'docker build permissions-report -t permissions-report'
			}
		}
		stage ('Run') {
			when {
				expression {
					infra.isTrusted()
				}
			}
			steps {
				sh 'docker run -e GITHUB_API_TOKEN=$GITHUB_API_TOKEN permissions-report > github-jenkinsci-permissions-report.json'
				archiveArtifacts '*.json'
				publishReports ([ 'github-jenkinsci-permissions-report.json' ])
			}
		}
	}
}
