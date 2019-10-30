pipeline {
  agent any
  environment {
    WORKSPACE    = "${env.WORKSPACE}"
    BUILD_NUMBER = "${env.BUILD_NUMBER}"
  }
  stages {
    stage ('Checkout') {
      steps {
        println('Checking out...')
      }
    }
    stage ('Build') {
      steps {
        println('Building project...')
      }
    }
    stage ('Package') {
      steps {
        println('Packaging project...')
        println('Pushing package')
      }
    }
    stage ('Create promotion job') {
      steps {
        sh "jenkins-jobs --conf jjb/config.ini update jjb/demo_project/promotions:jjb/templates.yaml"
      }
    }
  }
}
