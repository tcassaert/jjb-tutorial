# Manage Jenkins with Jenkinsfiles and Jenkins Job Builder

## Introduction

When getting started with Jenkins, everyone begins with clicking together some Jenkins jobs. But when more and more jobs are added, it gets more difficult to keep an overview. You know it's time to also use the principles of Infrastructure As Code for your Jenkins jobs.

## Jenkins setup

To setup a sample Jenkins test instance, we're going to use a Jenkins container, running with [Podman][1]. Normally we would simply use the official Jenkins container image, but for this demo, we need to modify this one a little. We need to install the [Jenkins Job Builder(jjb)][2]. In the [git repository][3] dedicated to this blog post, you can find the build script. The new container image is built using [Buildah][4].

You can get the prebuilt image:
```
podman pull docker.io/tcassaert/jenkins-master-job-builder:3.0.2
```

But you can of course build it yourself as well.

To run the container, execute the following:

```
podman run -d -p 8080:8080 -v jenkins_volume_jjb:/var/jenkins_home:z --name jenkins-jjb tcassaert/jenkins-master-job-builder:3.0.2
```

When you're not using Podman yet, you can easily replace `podman` with `docker`, but it's really worth it to give it a try.

After a little minute, you should be able to access the web interface, at http://localhost:8080, where we are prompted for a password.

This password can be retrieved with

```
podman logs jenkins-jjb
```

Where you should see something like

```
*************************************************************
*************************************************************
*************************************************************

Jenkins initial setup is required. An admin user has been created and a password generated.
Please use the following password to proceed to installation:

ecca02fd3168417788d05546240ada4e

This may also be found at: /var/jenkins_home/secrets/initialAdminPassword

*************************************************************
*************************************************************
*************************************************************
```

On the next page, choose to install the suggested plugins and wait for it to be finished installing. After that you can choose to continue as admin and finish the installation.

## Prepare for using the Jenkins Job Builder

To use the Jenkins Job Builder, we need an API token, to be able to talk to the Jenkins API. This token can be created for any user. For this tutorial, we'll just create one for the admin user, this is of course not recommended for a production installation.

You can create an API token like this:

  * Upper-right corner -> admin -> configure
  * API Token -> Give name -> Generate token
  * Write down the token as this cannot be retrieved anymore

The last thing we will need to be able to run the sample project is the `Pipeline Utility Steps` plugin. Install it the normal way, with the `Plugin Manager`:

  * Manage Jenkins -> Manage Plugins -> Available
  * Search for `Pipeline Utility Steps`
  * Install plugin
  * Execute a `podman restart jenkins-jjb`

## Creating the first job

It is now time to create our first job. Of course, we now have to deal with the chicken-egg problem. There is one job that needs to be created manually, the `seed_job`. This job will be used to create all other jobs:

  * New Item -> `seed_job`, Pipeline project -> OK
  * Under the `Pipeline` tab, select `Pipeline script from SCM`
  * Select `Git` -> Repo url: https://github.com/tcassaert/jjb-tutorial, Script Path: `Jenkinsfile.seedjob`
  * Save

We can now run the newly created seed_job. This job will create a folder, named demo_project, with in that folder a job, also called demo_project.

So how did this all work behind the scenes?

The jjb is a tools that lets us create Jenkins jobs based on some Yaml configuration files. The jjb has some ways to prevent us repeating ourselves. One of them is the use of job-templates. These job-templates are a general template for how a job should look like. A template of course also has a way to define variables to be overridden by the projects that use the template.

A small template example:

```
$ cat jjb/template.yaml
---
- defaults:
    name: global
    custom_parameters: []

- job-template:
    name: '{name}'
    id: 'pipeline_template'
    folder: '{folder}'
    project-type: 'pipeline'
    parameters: '{obj:custom_parameters}'
    pipeline-scm:
      scm:
        - git:
            url: '{url}'
            branches:
              - '*/master'
      script-path: '{jenkinsfile_location|Jenkinsfile}'
      lightweigth-checkout: true
```

This file outlines how a generated job should look like. It has some variables, that can be filled in, like `url`, `name` or `jenkinsfile_location`. The `jenkinsfile_location` has a default defined, so this is not a required variable.

The template is used by a job:

```
$ cat jjb/demo_project/jobs.yaml
---
- job:
    name: 'demo_project'
    project-type: folder

- project:
    name: 'Demo project'
    folder: 'demo_project'
    jobs:
      - 'pipeline_template':
          name: 'demo_project'
          url: 'https://github.com/tcassaert/jjb-tutorial'
```

The variables for name and url are filled in and the top key of the jobs-hash defines the template that should be used. This corresponds with the template-id from the template definition. As you can see, folders are created the same way.

## The problem with promotion jobs

When using Jenkinsfiles, dealing with promotions is not an easy thing to do. You mostly don't want your projects to be promoted without manual intervention, so the first thing you think of, is asking for user input to give permission to promote the project. This, however, comes with its own problems.

One of them is that a job is never finished, until someone says "Yes, promote this!". With the defaults, you end up with a long running job, that even takes an executor. There are workarounds available around the fact that an executor is used up, but hopefully you won't need it anymore after this guide.

## A possible solution

In the previous parts, we have been using the jjb. It's this jjb that could help us to use promotion jobs that aren't as bad as the regular ones.

When your project is built, tested and packaged, we include one last stage. In this stage we call the jjb to create a job. This job has some parameters from the current job, like the artifact name and maybe the production hosts on which to deploy the project.

### Simple Jenkinsfile

In the git repository you can find a `Jenkinsfile` that shows how a simple project could look like. Let's dive a little deeper in the most important stage, the `Create promotion job` stage.

```
$ cat Jenkinsfile
pipeline {
    ...
    stage ('Create promotion job') {
      steps {
       script {
          def project_cfg = readYaml file: 'jjb/demo_project/promotions/jobs.yaml'
          def project_name = 'demo_project'
          project_cfg.project[0].name = project_name + '-' + "${BUILD_NUMBER}"
          project_cfg.project[0].folder = 'promotion_jobs'
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
```

The first thing you see, is the job definition of the promotion job that gets loaded. We have to make some modifications to the Yaml file, to inject build-specific parameters. The name is set to `demo_project-BUILD_NUMBER`, where `BUILD_NUMBER` is the build number of the current job. The folder is set to `promotion_jobs` and the first (and for this demo the only) parameter is set to the package name, which is built with the project name, the date and the build number. There also happens some ugly sed magic, to make the Yaml indentation work.

The last step is using the jjb to create a promotion job.

If we run this demo_project job, it should succeed and a folder `promotion_jobs` should be created, with a job called `demo_project-1` inside it.

If we now try to build this promotion job, the parameter is already filled in with the value we defined in the previous job.

This promotion job just shows how you can download the exact package you want to promote from your registry and do the necessary steps with that package in your promotion process.

At my customer, this is all included in a Jenkins shared library, but this is overkill for this simple demo project. The jjb configuration files are also in their own repository to have an overview of all job configurations.

## Conclusion

This demo project shows how you can use Infrastructure As Code for your pipelines. Nothing, except for the seed_job should be created manually. Putting everything in code makes it perfectly reproducible and prevents undocumented and unwanted changes.

[1]: https://podman.io/
[2]: https://docs.openstack.org/infra/jenkins-job-builder/index.html
[3]: https://github.com/tcassaert/jjb-tutorial
[3]: https://buildah.io/
