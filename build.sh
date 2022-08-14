#!/bin/bash
# Copyright 2017 ~ 2025 the original authors <jameswong1376@gmail.com>. 
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -e

export BASE_DIR=$(cd "`dirname $0`"/; pwd)

function print_help() {
  echo $"
Usage: ./$(basename $0) [OPTIONS] [arg1] [arg2] ...
    build                                    Build of toolbox modules image.
    push                                     Push the toolbox modules image to repoistory.
          <repo_uri>                           Push to repoistory uri. format: <registryUri>/<namespace>, default: docker.io/wl4g
                                             for example: registry.cn-shenzhen.aliyuncs.com/wl4g-k8s)
"
}

function build_images() {
  local build_version=$(git branch | grep '*' | sed -E 's/\* \(HEAD detached at |\)|\* //g')

  echo "Building images ..."
  cd $BASE_DIR/base && docker build -t wl4g/toolbox-base:${build_version} . &
  cd $BASE_DIR/arthas && docker build -t wl4g/toolbox-arthas:${build_version} . &

  wait
}

function push_images() {
  local build_version=$(git branch | grep '*' | sed -E 's/\* \(HEAD detached at |\)|\* //g')
  local repo_uri="$1"
  [ -z "$repo_uri" ] && repo_uri="docker.io/wl4g"
  ## FIX: Clean up suffix delimiters for normalization '/'
  repo_uri="$(echo $repo_uri | sed -E 's|/$||g')"

  echo "Tagging images to $repo_uri ..."
  docker tag wl4g/toolbox-base:${build_version} $repo_uri/toolbox-base:${build_version}
  docker tag wl4g/toolbox-arthas:${build_version} $repo_uri/toolbox-arthas:${build_version}
  docker tag wl4g/toolbox-base:${build_version} $repo_uri/toolbox-base:latest
  docker tag wl4g/toolbox-arthas:${build_version} $repo_uri/toolbox-arthas:latest

  echo "Pushing images of ${build_version}@$repo_uri ..."
  docker push $repo_uri/toolbox-base:${build_version} &
  docker push $repo_uri/toolbox-arthas:${build_version} &

  echo "Pushing images of latest@$repo_uri ..."
  docker push $repo_uri/toolbox-base &
  docker push $repo_uri/toolbox-arthas &

  wait
}

# --- Main. ---
case $1 in
  build)
    build_images
    ;;
  push)
    push_images "$2"
    ;;
  *)
    print_help
    ;;
esac
