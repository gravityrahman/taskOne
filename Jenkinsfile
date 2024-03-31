pipeline {
    agent any
    environment {
        VERSION = "${env.BUILD_ID}"
        AWS_ACCOUNT_ID = '540420926773'
        AWS_DEFAULT_REGION = 'us-east-1'
        IMAGE_REPO_NAME = 'my-image-repo'
        IMAGE_TAG = "${env.BUILD_ID}"
        REPOSITORY_URI = '540420926773.dkr.ecr.us-east-1.amazonaws.com/my-image-repo'
    }

  stages {
        stage('Build with maven') {
      steps {
        sh 'cd SampleWeApp && mvn clean install'
      }
        }

    stage('Test') {
      steps {
        sh 'cd SampleWeApp && mvn test'
      }
    }

    stage('Logging into AWS ECR') {
      environment {
        AWS_ACCESS_KEY_ID = credentials('aws_access_key_id')
        AWS_SECRET_ACCESS_KEY = credentials('aws_secret_key_id')
      }
      steps {
        script {
          sh 'aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 540420926773.dkr.ecr.us-east-1.amazonaws.com'
        }
      }
    }
    stage('Building image') {
      steps {
        script {
          dockerImage = docker.build "${IMAGE_REPO_NAME}:${IMAGE_TAG}"
        }
      }
    }
    stage('Pushing to ECR') {
          steps {
            script {
          sh """docker tag ${IMAGE_REPO_NAME}:${IMAGE_TAG} ${REPOSITORY_URI}:$IMAGE_TAG"""
          sh """docker push ${REPOSITORY_URI}:$IMAGE_TAG"""
            }
          }
    }
  }
}
