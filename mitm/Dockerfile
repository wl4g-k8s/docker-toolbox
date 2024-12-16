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
FROM registry.cn-shenzhen.aliyuncs.com/wl4g/mitmproxy_mitmproxy:11.0.2
LABEL maintainer="James Wong<jameswong1376@gmail.com>"

RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources \
    && sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources \
    && echo 'APT::Get::Allow-Unauthenticated "true";' > /etc/apt/apt.conf.d/99allow-unauthenticated \
    && apt update \
    && apt install -y \
    procps \
    net-tools \
    curl \
    zlib1g \
    openssl \
    build-essential \
    libpcre3 \
    libpcre3-dev \
    zlib1g-dev \
    libssl-dev \
    && curl -vOL https://nginx.org/download/nginx-1.25.3.tar.gz \
    && tar -zxvf nginx-1.25.3.tar.gz \
    && cd nginx-1.25.3 \
    && ./configure \
        --prefix=/usr/share/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-http_ssl_module \
        --with-http_v2_module \
    && make modules -j7 \
    && make install \
    && mv /usr/share/nginx/sbin/nginx /usr/sbin/nginx \
    && cd .. \
    && rm -rf nginx-1.25.3 nginx-1.25.3.tar.gz \
    && apt remove -y \
    perl \
    build-essential \
    musl-dev \
    && apt autoremove -y gcc \
    && rm -rf /var/lib/apt/lists/*

COPY <<"EOF" /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;
#load_module /usr/lib/nginx/modules/ngx_stream_module.so;
events {
        worker_connections 1024;
        # multi_accept on;
}
stream {
    upstream mitmproxy_backend {
        server 127.0.0.1:8080;
    }
    server {
        listen 443;
        ssl_preread on;
        #ssl_protocols TLSv1.2 TLSv1.3;
        #ssl_prefer_server_ciphers on;
        #proxy_connect_timeout 10s;
        #proxy_protocol on;
        proxy_pass mitmproxy_backend;
    }
}
EOF

COPY <<"EOF" /opt/rewrite_proxy_host.py
import re
import os
from mitmproxy import http, ctx

def tls_setup(client_hello):
  # This the example custom process for SNI.
  ctx.log.info(f"Client hello SNI: {client_hello.sni}")

def request(flow: http.HTTPFlow) -> None:
    mitm_flow_rewrite_subdomain_add_suffix = os.environ.get('MITM_FLOW_REWRITE_SUBDOMAIN_ADD_SUFFIX', '')
    if mitm_flow_rewrite_subdomain_add_suffix:
        original_host = flow.request.pretty_host
        parts = original_host.split('.')
        if len(parts) > 1:
            # Add suffix to subdomain.
            # e.g: curl https://subdomain.example.com => proxy forward to: https://subdomain-<suffix>.example.com
            parts[0] = f"{parts[0]}{mitm_flow_rewrite_subdomain_add_suffix}"
            new_host = '.'.join(parts)
            ctx.log.info(f"Rewriting host from {original_host} to {new_host}")
            flow.request.scheme = "https"
            flow.request.host = new_host
            if flow.request.port != 443:
                flow.request.port = 443
    ctx.log.info(f"Forwarding request to: {flow.request.host}")
EOF

COPY <<"EOF" /entrypoint.sh
#!/bin/bash

export MITM_ADDR=${MITM_ADDR:-127.0.0.1}
export MITM_PORT=${MITM_PORT:-8080}

# Prepare CA certificate and key
if [ -n "$MITM_CA_CERT" ] && [ -n "$MITM_CA_KEY" ]; then
    # Create mitmproxy configuration directory
    mkdir -p ~/.mitmproxy

    # Write custom CA cert and key
    echo "$MITM_CA_CERT" > ~/.mitmproxy/mitmproxy-ca.pem
    echo "$MITM_CA_KEY" > ~/.mitmproxy/mitmproxy-ca.key

    # Set correct permissions
    chmod 600 ~/.mitmproxy/mitmproxy-ca.key
    chmod 644 ~/.mitmproxy/mitmproxy-ca.pem

    # Add custom CA flag
    CUSTOM_CA_OPTS="--set confdir=~/.mitmproxy"
fi

# Start the Frontend nginx.
nohup nginx -g "daemon off;" >/var/log/nginx/stdout.log 2>&1 &

# Split MITM_FLOW_DOMAINS by comma and convert to mitmproxy intercept format.
mkdir -p /var/log/audit/mitmproxy
if [ -n "$MITM_FLOW_DOMAINS" ]; then
    DOMAINS=($(echo "$MITM_FLOW_DOMAINS" | tr ',' ' '))
    # Make intercept domains parameter.
    INTERCEPT_DOMAINS=$(printf "~d %s|" "${DOMAINS[@]}" | sed 's/|$//')
    # Make MITM logs parameter. (Unfortunately, only one -w parameter is supported, and the last one takes effect.)
    #STREAM_LOG_OPTS=$(printf " -w /var/log/mitmproxy/%s.mitm" "${DOMAINS[@]}")
else
    DOMAINS=("example.com")
    INTERCEPT_DOMAINS="~d example.com"
    #STREAM_LOG_OPTS=" -w /var/log/audit/mitmproxy/example.com.mitm"
fi

STREAM_LOG_OPTS=" -w /var/log/audit/mitmproxy/capture.mitm"

# Start the Backend mitmproxy.
mitmdump -v \
-s /opt/rewrite_proxy_host.py \
--listen-host ${MITM_ADDR} \
--listen-port ${MITM_PORT} \
--showhost \
--set block_global=false \
--set view_body_layout=auto \
--set intercept="\"${INTERCEPT_DOMAINS}\"" \
$STREAM_LOG_OPTS \
$CUSTOM_CA_OPTS
EOF

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]