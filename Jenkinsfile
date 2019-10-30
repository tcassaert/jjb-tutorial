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
        println('Pushing package...')
      }
    }
    stage ('Create promotion job') {
      steps {
        script {
          def project_cfg = readYaml file: 'jjb/demo_project/promotions/jobs.yaml'
          def project_name = 'demo_project'
          project_cfg.project[0].name = project_name + '-' + "${BUILD_NUMBER}"
          project_cfg.project[0].folder = 'promotions/demo_project'
          project_cfg.project[0].custom_parameters[0].default = 'upstream_build_number'
          sh "rm jjb/demo_project/promotions/jobs.yaml"
          writeYaml file: 'jjb/demo_project/promotions/jobs.yaml', data: project_cfg
          sh "sed -i 's/^      default/        default/' jjb/demo_project/promotions/jobs.yaml"
          sh "jenkins-jobs --conf jjb/config.ini update jjb/demo_project/promotions:jjb/template.yaml"
        }
      }
    }
  }
}
