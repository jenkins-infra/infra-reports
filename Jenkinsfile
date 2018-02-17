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
				sh 'docker run -e GITHUB_API_TOKEN=$GITHUB_API_TOKEN permissions-report > permissions-report.json'
				archiveArtifacts '*.json'
			}
		}
	}
}
