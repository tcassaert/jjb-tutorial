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
        script {
          println('Packaging project...')
          def date = new Date().format('yyyyMMdd')
          sh "tar -cf demo_project-${date}-${BUILD_NUMBER}.tar.gz src/"
          println('Pushing package to the registry...')
        }
      }
    }
    stage ('Create promotion job') {
      steps {
        script {
          def project_cfg = readYaml file: 'jjb/demo_project/promotions/jobs.yaml'
          def project_name = 'demo_project'
          project_cfg.project[0].name = project_name + '-' + "${BUILD_NUMBER}"
          project_cfg.project[0].folder = 'promotions/demo_project'
          def date = new Date().format('yyyyMMdd')
          project_cfg.project[0].custom_parameters[0].default = "demo_project-${date}-${BUILD_NUMBER}.tar.gz"
          sh "rm jjb/demo_project/promotions/jobs.yaml"
          writeYaml file: 'jjb/demo_project/promotions/jobs.yaml', data: project_cfg
          sh "sed -i 's/^      default/        default/' jjb/demo_project/promotions/jobs.yaml"
          sh "jenkins-jobs --conf jjb/config.ini update jjb/demo_project/promotions:jjb/template.yaml"
        }
      }
    }
  }
}
