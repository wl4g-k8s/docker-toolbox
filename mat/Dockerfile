## Copyright 2017 ~ 2025 the original authors James Wong<jamewong1376@gmail.com>. 
## 
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
## 
##      http://www.apache.org/licenses/LICENSE-2.0
## 
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##

#FROM registry.cn-shenzhen.aliyuncs.com/wl4g-k8s/bitnami_minideb:buster AS builder
#WORKDIR /opt
#RUN apt update && apt-get install -y wget unzip
#RUN wget -O mat.zip https://mirror.umd.edu/eclipse/mat/1.14.0/rcp/MemoryAnalyzer-1.14.0.20230315-linux.gtk.x86_64.zip
#RUN unzip mat.zip && rm -rf mat.zip

FROM registry.cn-shenzhen.aliyuncs.com/wl4g-k8s/openjdk:17-ea-33-jdk-slim-buster

LABEL maintainer="James Wong<jameswong1376@gmail.com>" \
  description="Toolbox for Mat is a JVM heap troubleshooting image." \
  repoName=https://github.com/wl4g-k8s/docker-toolbox \
  branch=master \
  pr= \
  tag= \
  commit= \
  buildTime= \
  buildURL=

WORKDIR /opt
#COPY --from=builder /opt/mat /opt/mat
COPY ./mat /opt/mat
COPY ./run.sh ./mat
WORKDIR /data
ENTRYPOINT ["/opt/mat/run.sh"]
