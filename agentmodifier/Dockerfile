# Copyright 2017 ~ 2025 the original authors James Wong. 
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

#FROM openjdk:8-jdk-alpine3.8 or alpine:3.15.5
FROM registry.cn-shenzhen.aliyuncs.com/wl4g/openjdk:8-jdk-alpine3.8
#FROM registry.cn-shenzhen.aliyuncs.com/wl4g/alpine:3.15.5
LABEL maintainer="James Wong<jameswong1376@gmail.com>"

ENV MODIFIER_VERSION='1.0.0'
ENV MODIFIER_HOME="/opt/agentmodifier/lib/${MODIFIER_VERSION}"

COPY ./book-playground/java-playground/playground-agent-modifier/build/libs/playground-agent-modifier-*.jar ${MODIFIER_HOME}/agentmodifier.jar

# 其中:bind-tools(dig), busybox-extras(telnet)
RUN echo "http://mirrors.aliyun.com/alpine/v3.8/main" > /etc/apk/repositories \
&& echo "http://mirrors.aliyun.com/alpine/v3.8/community" >> /etc/apk/repositories \
&& apk update upgrade \
&& apk add --no-cache bash \
&& mkdir -p ${MODIFIER_HOME}/
