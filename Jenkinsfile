#!groovy
pipeline {
  agent { label 'public' }
  options {
    timeout(time: 30, unit: 'MINUTES')
  }
  stages {
    stage('Test first time config') {
      steps {
        sh '''
          set -euo pipefail
          make test-up
        '''
      }
    }
    stage('Test second time provisioning') {
      steps {
        sh '''
          set -euo pipefail
          make test-provision
        '''
      }
    }
    stage('Test cleanup') {
      steps {
        sh '''
          set -euo pipefail
          make test-cleanup
        '''
      }
    }
  }
  post {
    always {
      sh '''
        set -euo pipefail
        vagrant destroy -f
      '''
    }
  }
}
