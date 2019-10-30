#!/bin/bash

set -ex

container=$(buildah from jenkins/jenkins)
username=tcassaert
version=3.0.2

buildah run --user root "${container}" apt update
buildah run --user root "${container}" apt install -y python-pip
buildah run --user root "${container}" pip install jenkins-job-builder=="$version"

buildah config --created-by $username "${container}"
buildah config --author $username --label name=jenkins-master-job-builder:"$version" "${container}"

buildah commit "${container}" "$username"/jenkins-master-job-builder:"$version"

buildah rm "$container"
