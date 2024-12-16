# Toolbox image for MITM(proxy)

## Installation on Docker

- Startup MITM proxy for Monitoring Https Traffic
  - Note: When set the `MITM_FLOW_REWRITE_SUBDOMAIN_ADD_SUFFIX`, the MitmProxy will rewrite the subdomain to `${subdomain}-proxy`, such as `curl https://api.example.com` will proxy forward to `https://api-proxy.example.com`, but TLS handshake client hello SNI keep it the same.

```bash
docker kill mitmproxy_nginx; docker rm mitmproxy_nginx
docker run -d \
--platform linux/amd64 \
--name mitmproxy_nginx \
--restart unless-stopped \
-e MITM_FLOW_DOMAINS='example.com,github.com,cn.bing.com' \
-e MITM_FLOW_REWRITE_SUBDOMAIN_ADD_SUFFIX='-proxy' \
-p 8443:443 \
-v /tmp/mitmproxy:/var/log/audit/mitmproxy \
registry.cn-shenzhen.aliyuncs.com/wl4g-k8s/toolbox-mitm:main
#wl4g/toolbox-mitm:main
```

## Verify the MITMProxy Interception

### Case 1: Due to https proxy is used, must need to use `-k` and `--proxy-insecure` to ignore CA trust

- **Note:** This is the **correct** client request host for `api.github.com` which response is `200`.

```bash
unset https_proxy
curl -I https://api.github.com
#HTTP/2 200 
#date: Thu, 19 Dec 2024 15:07:55 GMT
#content-type: application/json; charset=utf-8
#cache-control: public, max-age=60, s-maxage=60
#vary: Accept,Accept-Encoding, Accept, X-Requested-With
#etag: W/"4f825cc84e1c733059d46e76e6df9db557ae5254f9625dfe8e1b09499c449438"
#x-github-media-type: github.v3; format=json
#x-github-api-version-selected: 2022-11-28
#access-control-expose-headers: ETag, Link, Location, Retry-After, X-GitHub-OTP, X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Used, X-RateLimit-Resource, #X-RateLimit-Reset, X-OAuth-Scopes, X-Accepted-OAuth-Scopes, X-Poll-Interval, X-GitHub-Media-Type, X-GitHub-SSO, X-GitHub-Request-Id, Deprecation, Sunset
#access-control-allow-origin: *
#strict-transport-security: max-age=31536000; includeSubdomains; preload
#x-frame-options: deny
#x-content-type-options: nosniff
#x-xss-protection: 0
#referrer-policy: origin-when-cross-origin, strict-origin-when-cross-origin
#content-security-policy: default-src 'none'
#server: github.com
#accept-ranges: bytes
#x-ratelimit-limit: 60
#x-ratelimit-remaining: 56
#x-ratelimit-reset: 1734623839
#x-ratelimit-resource: core
#x-ratelimit-used: 4
#content-length: 2396
#x-github-request-id: 1DE6:834A2:199EB50:1CF1931:676436CB
```

- **Note:** This is a **non-existent** client request host of `api-proxy.github.com` and response is `404`.

```bash
curl -I https://api-proxy.github.com
#HTTP/2 404 
#server: GitHub.com
#content-type: text/html; charset=utf-8
#x-pages-interstitial: 1
#content-security-policy: default-src 'none'; style-src 'unsafe-inline'; img-src data:; connect-src 'self'
#x-github-request-id: 8C00:F1961:94462F:99DCE1:67643454
#accept-ranges: bytes
#age: 598
#date: Thu, 19 Dec 2024 15:07:23 GMT
#via: 1.1 varnish
#x-served-by: cache-nrt-rjtf7700098-NRT
#x-cache: HIT
#x-cache-hits: 0
#x-timer: S1734620843.272283,VS0,VE2
#vary: Accept-Encoding
#x-fastly-request-id: 431e034d4919542816f20ff0531832ab9c566c54
#content-length: 9593
```

- **Note:** This is a **correct** client request host of `api.github.com`, but response is `404`, because the `mitmproxy/mitmdump` forwarded to the wrong host `api-proxy.github.com`.

```bash
export https_proxy=https://127.0.0.1:8443

curl -I -k --proxy-insecure https://api.github.com
#HTTP/1.1 200 Connection established
#HTTP/2 404
#server: GitHub.com
#content-type: text/html; charset=utf-8
#x-pages-interstitial: 1
#content-security-policy: default-src 'none'; style-src 'unsafe-inline'; img-src data:; connect-src 'self'
#x-github-request-id: 8C00:F1961:94462F:99DCE1:67643454
#accept-ranges: bytes
#date: Thu, 19 Dec 2024 14:58:39 GMT
#via: 1.1 varnish
#age: 74
#x-served-by: cache-nrt-rjtf7700045-NRT
#x-cache: HIT
#x-cache-hits: 1
#x-timer: S1734620319.464200,VS0,VE1
#vary: Accept-Encoding
#x-fastly-request-id: 1d89fa34bc92191fe4b5d3c45b7f840179065fb9
#content-length: 9593
```

### Case 2: Enterprise-Level standard solution, let the whole staff computer prepared client pre-trust the CA of MITMProxy

```bash
docker cp mitmproxy_nginx:~/.mitmproxy/mitmproxy-ca-cert.pem /tmp/mitmproxy-ca-cert.pem
export https_proxy=https://127.0.0.1:8443
curl -I --cacert /tmp/mitmproxy-ca-cert.pem --proxy-cacert /tmp/mitmproxy-ca-cert.pem https://api.github.com
#HTTP/2 200
#date: Thu, 19 Dec 2024 15:28:18 GMT
#content-type: application/json; charset=utf-8
#cache-control: public, max-age=60, s-maxage=60
#vary: Accept,Accept-Encoding, Accept, X-Requested-With
#etag: W/"4f825cc84e1c733059d46e76e6df9db557ae5254f9625dfe8e1b09499c449438"
#x-github-media-type: github.v3; format=json
#x-github-api-version-selected: 2022-11-28
#access-control-expose-headers: ETag, Link, Location, Retry-After, X-GitHub-OTP, X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Used, X-RateLimit-Resource, #X-RateLimit-Reset, X-OAuth-Scopes, X-Accepted-OAuth-Scopes, X-Poll-Interval, X-GitHub-Media-Type, X-GitHub-SSO, X-GitHub-Request-Id, Deprecation, Sunset
#access-control-allow-origin: *
#strict-transport-security: max-age=31536000; includeSubdomains; preload
#x-frame-options: deny
#x-content-type-options: nosniff
#x-xss-protection: 0
#referrer-policy: origin-when-cross-origin, strict-origin-when-cross-origin
#content-security-policy: default-src 'none'
#server: github.com
#accept-ranges: bytes
#x-ratelimit-limit: 60
#x-ratelimit-remaining: 51
#x-ratelimit-reset: 1734623839
#x-ratelimit-resource: core
#x-ratelimit-used: 9
#content-length: 2396
#x-github-request-id: 1055:120541:1A975A5:1DEFC00:67643B9A
```

- View of MITMProxy Capture logs & Replay Traffic

```bash
cat /tmp/mitmproxy/capture.mitm

# Replay traffic. (custom mock httpserver port as 9090)
mitmdump --mode regular@9090 -r /tmp/mitmproxy/capture.mitm
#[17:32:36.082] HTTP(S) proxy listening at *:9090.
#127.0.0.1:55814: GET https://api.github.com/ HTTP/2.0
#     << HTTP/2.0 200 OK 1.2k
```

## Next Steps

- Collecting MITMProxy Capture Log files and Replaying Traffic.
