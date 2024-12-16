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
    build                                    Build toolbox images.
          all                                Build all toolbox images.
          base                               Build for toolbox-base images.
          arthas                             Build for toolbox-arthas images.
          pprof                              Build for toolbox-pprof images.
          mat                                Build for toolbox-mat image
          agentmodifier                      Build for toolbox-agentmodifier image
          mitm                               Build for toolbox-mitm image
    push                                     Push toolbox images to remote repoistory.
          all                                Push all toolbox images.
          base                               Push for toolbox-base images.
          arthas                             Push for toolbox-arthas images.
          pprof                              Push for toolbox-pprof images.
          mat                                Push for toolbox-mat image
          agentmodifier                      Push for toolbox-agentmodifier image
          mitm                               Push for toolbox-mitm image
                <repo_uri>                   Push to repoistory uri. format: <registryUri>/<namespace>, default: docker.io/wl4g
                                                for example: registry.cn-shenzhen.aliyuncs.com/wl4g-k8s)
"
}

function build_images() {
  local build_modules=$1
  local build_version=$(git branch | grep '*' | sed -E 's/\* \(HEAD detached at |\)|\* //g')

  if [[ $build_modules == *"base"* || $build_modules == *"all"* ]]; then
    echo "Building for toolbox-base ..."
    cd $BASE_DIR/base && docker build ${DOCKER_BUILD_OPTS} --platform linux/amd64 -t wl4g/toolbox-base:${build_version} . &
  fi

  if [[ $build_modules == *"arthas"* || $build_modules == *"all"* ]]; then
    echo "Building for toolbox-arthas ..." 
    cd $BASE_DIR/arthas && docker build ${DOCKER_BUILD_OPTS} --platform linux/amd64 -t wl4g/toolbox-arthas:${build_version} . &
  fi

  if [[ $build_modules == *"pprof"* || $build_modules == *"all"* ]]; then
    echo "Building for toolbox-pprof ..."
    if [ ! -d $BASE_DIR/pprof/gperftools ]; then
      echo "No found precondidtions depends and cloning from: https://github.com/gperftools/gperftools"
      cd $BASE_DIR/pprof && git clone https://github.com/gperftools/gperftools
    fi
    cd $BASE_DIR/pprof && docker build ${DOCKER_BUILD_OPTS} --platform linux/amd64 -t wl4g/toolbox-pprof:minideb-buster-${build_version} . &
  fi

  if [[ $build_modules == *"mat"* || $build_modules == *"all"* ]]; then
    echo "Building for toolbox-mat ..."
    # see:https://eclipse.dev/mat/downloads.php
    if [ ! -d $BASE_DIR/mat/mat ]; then
      echo "No found precondidtions depends and downloading from: https://eclipse.dev/mat/downloads.php"
      sudo apt install -y unzip
      # china network to see: https://mirrors.neusoft.edu.cn/eclipse/mat/1.14.0/rcp/MemoryAnalyzer-1.14.0.20230315-linux.gtk.x86_64.zip
      local dl_mat_url='https://mirror.umd.edu/eclipse/mat/1.14.0/rcp/MemoryAnalyzer-1.14.0.20230315-linux.gtk.x86_64.zip'
      cd $BASE_DIR/mat && curl -kL -o mat.zip $dl_mat_url && unzip mat.zip && rm -rf mat.zip # unzip -d ./mat mat.zip
    fi
    cd $BASE_DIR/mat && docker build ${DOCKER_BUILD_OPTS} --platform linux/amd64 -t wl4g/toolbox-mat:${build_version} . &
  fi

  if [[ $build_modules == *"agentmodifier"* || $build_modules == *"all"* ]]; then
    echo "Building for toolbox-agentmodifier ..."
    if [ ! -d $BASE_DIR/agentmodifier/book-playground/ ]; then
      cd $BASE_DIR/agentmodifier/
      git clone --single-branch --depth=1 git@github.com:wl4g-private/book-playground.git
    fi
    cd $BASE_DIR/agentmodifier/book-playground/ && git config pull.rebase true && git reset --hard && git pull
    cd $BASE_DIR/agentmodifier/book-playground/java-playground/ && ./gradlew :playground-agent-modifier:clean shadowJar -x test
    cd $BASE_DIR/agentmodifier && docker build ${DOCKER_BUILD_OPTS} --platform linux/amd64 -t wl4g/toolbox-agentmodifier:${build_version} . &
  fi

  if [[ $build_modules == *"mitm"* || $build_modules == *"all"* ]]; then
    echo "Building for toolbox-mitm ..."
    cd $BASE_DIR/mitm && docker build ${DOCKER_BUILD_OPTS} --platform linux/amd64 -t wl4g/toolbox-mitm:${build_version} . &
  fi

  wait
}

function push_images() {
  local push_modules=$1
  local repo_uri="$2"
  local build_version=$(git branch | grep '*' | sed -E 's/\* \(HEAD detached at |\)|\* //g')

  [ -z "$repo_uri" ] && repo_uri="docker.io/wl4g"
  ## FIX: Clean up suffix delimiters for normalization '/'
  repo_uri="$(echo $repo_uri | sed -E 's|/$||g')"

  if [[ $push_modules == *"base"* || $push_modules == *"all"* ]]; then
    docker tag wl4g/toolbox-base:${build_version} $repo_uri/toolbox-base:${build_version}
    docker tag wl4g/toolbox-base:${build_version} $repo_uri/toolbox-base:latest
    echo "Pushing images of ${build_version}@$repo_uri ..."
    docker push $repo_uri/toolbox-base:${build_version} &
    docker push $repo_uri/toolbox-base &
  fi
  if [[ $push_modules == *"arthas"* || $push_modules == *"all"* ]]; then
    docker tag wl4g/toolbox-arthas:${build_version} $repo_uri/toolbox-arthas:${build_version}
    docker tag wl4g/toolbox-arthas:${build_version} $repo_uri/toolbox-arthas:latest
    docker push $repo_uri/toolbox-arthas:${build_version} &
    docker push $repo_uri/toolbox-arthas &
  fi
  if [[ $push_modules == *"pprof"* || $push_modules == *"all"* ]]; then
    docker tag wl4g/toolbox-pprof:minideb-buster-${build_version} $repo_uri/toolbox-pprof:minideb-buster-${build_version}
    docker tag wl4g/toolbox-pprof:minideb-buster-${build_version} $repo_uri/toolbox-pprof:minideb-buster
    docker push $repo_uri/toolbox-pprof:minideb-buster-${build_version} &
    docker push $repo_uri/toolbox-pprof:minideb-buster &
  fi
  if [[ $push_modules == *"mat"* || $push_modules == *"all"* ]]; then
    docker tag wl4g/toolbox-mat:${build_version} $repo_uri/toolbox-mat:${build_version}
    docker tag wl4g/toolbox-mat:${build_version} $repo_uri/toolbox-mat:latest
    docker push $repo_uri/toolbox-mat:${build_version} &
    docker push $repo_uri/toolbox-mat &
  fi
  if [[ $push_modules == *"agentmodifier"* || $push_modules == *"all"* ]]; then
    docker tag wl4g/toolbox-agentmodifier:${build_version} $repo_uri/toolbox-agentmodifier:${build_version}
    docker tag wl4g/toolbox-agentmodifier:${build_version} $repo_uri/toolbox-agentmodifier:latest
    docker push $repo_uri/toolbox-agentmodifier:${build_version} &
    docker push $repo_uri/toolbox-agentmodifier &
  fi
  if [[ $push_modules == *"mitm"* || $push_modules == *"all"* ]]; then
    docker tag wl4g/toolbox-mitm:${build_version} $repo_uri/toolbox-mitm:${build_version}
    docker tag wl4g/toolbox-mitm:${build_version} $repo_uri/toolbox-mitm:latest
    docker push $repo_uri/toolbox-mitm:${build_version} &
    docker push $repo_uri/toolbox-mitm &
  fi

  wait
}

# --- Main. ---
case $1 in
  build)
    case $2 in
        all)
            build_images "all"
            ;;
        base)
            build_images "base"
            ;;
        arthas)
            build_images "arthas"
            ;;
        pprof)
            build_images "pprof"
            ;;
        mat)
            build_images "mat"
            ;;
        agentmodifier)
            build_images "agentmodifier"
            ;;
        mitm)
            build_images "mitm"
            ;;
        *)
            print_help
            ;;
    esac
    ;;
  push)
    case $2 in
        all)
            push_images "all" "$3"
            ;;
        base)
            push_images "base" "$3"
            ;;
        arthas)
            push_images "arthas" "$3"
            ;;
        pprof)
            push_images "pprof" "$3"
            ;;
        mat)
            push_images "mat" "$3"
            ;;
        agentmodifier)
            push_images "agentmodifier" "$3"
            ;;
        mitm)
            push_images "mitm" "$3"
            ;;
        *)
            print_help
            ;;
    esac
    ;;
  *)
    print_help
    ;;
esac
