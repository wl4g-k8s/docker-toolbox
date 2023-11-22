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

FROM registry.cn-shenzhen.aliyuncs.com/wl4g-k8s/bitnami_minideb:buster AS base

LABEL maintainer="James Wong<jameswong1376@gmail.com>" \
  description="Toolbox is a cloud native troubleshooting image." \
  repoName=https://github.com/wl4g-k8s/docker-toolbox \
  branch=master \
  pr= \
  tag= \
  commit= \
  buildTime= \
  buildURL=

ENV LANG=C.UTF-8
ENV LANGUAGE=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV TZ=Asia/Shanghai

RUN apt update && apt install -y autoconf make libtool m4 patch g++

FROM base AS builder

ADD ./gperftools /tmp/gperftools

# If m4 has been generated and executed repeatedly, an error may be reported, but it can be ignored.
RUN cd /tmp/gperftools && ./autogen.sh; ./configure && make && make install

FROM registry.cn-shenzhen.aliyuncs.com/wl4g-k8s/bitnami_minideb:buster

# For pprof output format utils(text:objdump and pdf|svg).
RUN apt update && apt install -y binutils graphviz ghostscript
#&& curl iputils-ping net-tools telnet procps vim wget jq

COPY --from=builder /usr/local/bin/pprof /usr/local/bin/
COPY --from=builder /usr/local/bin/pprof-symbolize /usr/local/bin/
COPY --from=builder /usr/local/lib/ /usr/local/lib/
