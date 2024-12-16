# Toolbox image for MITM(proxy)

## 1. Installation on Docker

- Startup MITM proxy for Monitoring Https Traffic
  - Note: When set the `MITM_FLOW_REWRITE_SUBDOMAIN_ADD_SUFFIX`, the MitmProxy will rewrite the subdomain to `${subdomain}-proxy`, such as `curl https://api.example.com` will proxy forward to `https://api-proxy.example.com`, but TLS handshake client hello SNI keep it the same.

```bash
docker kill mitmproxy_nginx; docker rm mitmproxy_nginx
docker run -d \
--platform linux/amd64 \
--name mitmproxy_nginx \
--restart unless-stopped \
-e MITM_FLOW_DOMAINS='github.com,cn.bing.com' \
-e MITM_FLOW_REWRITE_SUBDOMAIN_ADD_SUFFIX='-proxy' \
-p 8443:443 \
-v /tmp/mitmproxy:/var/log/audit/mitmproxy \
registry.cn-shenzhen.aliyuncs.com/wl4g-k8s/toolbox-mitm:main
#wl4g/toolbox-mitm:main
```

## 2. Installtion on Kubernetes

- TODO

## 3. Verify the MITMProxy Interception

### 3.1 No https proxy request behavior example

```bash
unset https_proxy
curl -vI https://api.github.com 2>&1 | grep -i issuer -B5
#* Server certificate:
#*  subject: CN=*.github.com
#*  start date: Mar  7 00:00:00 2024 GMT
#*  expire date: Mar  7 23:59:59 2025 GMT
#*  subjectAltName: host "api.github.com" matched cert's "*.github.com"
#*  issuer: C=GB; ST=Greater Manchester; L=Salford; O=Sectigo Limited; CN=Sectigo ECC Domain Validation Secure Server CA
```

### 3.2 Use https proxy request behavior example

- **Tips** Enterprise solution, let the whole staff computer prepared client pre-trust the custom Root CA of MITMProxy.
- **Note:** Due to https proxy is used, must need to use `k` and `-proxy-insecure` to ignore CA trust
- **Note:** The response server certificate issuer is `mitmproxy`, because the `mitmproxy/mitmdump` forwarded to upstream server.

```bash
docker cp mitmproxy_nginx:/root/.mitmproxy/mitmproxy-ca-cert.pem /tmp/mitmproxy-ca-cert.pem
export https_proxy=https://127.0.0.1:8443
#curl -vI -k --proxy-insecure https://api.github.com 2>&1 | grep -i issuer -B5
curl -vI --cacert /tmp/mitmproxy-ca-cert.pem --proxy-cacert /tmp/mitmproxy-ca-cert.pem https://api.github.com 2>&1 | grep -i issuer -B5
#* Proxy certificate:
#*  subject: CN=127.0.0.1
#*  start date: Dec 30 16:07:53 2024 GMT
#*  expire date: Jan  1 16:07:53 2026 GMT
#*  subjectAltName: host "127.0.0.1" matched cert's IP address!
#*  issuer: CN=mitmproxy; O=mitmproxy
#--
#* Server certificate:
#*  subject: CN=*.github.com
#*  start date: Dec 30 16:07:53 2024 GMT
#*  expire date: Jan  1 16:07:53 2026 GMT
#*  subjectAltName: host "api.github.com" matched cert's "*.github.com"
#*  issuer: CN=mitmproxy; O=mitmproxy
```

- **Note:** This is a **correct** client request host of `api.github.com`, but response HTTP/2 status is `404`, because the `mitmproxy/mitmdump` forwarded to `https://api-proxy.github.com` by mitmproxy rules see environment `MITM_FLOW_REWRITE_SUBDOMAIN_ADD_SUFFIX`.

```bash
curl -I --cacert /tmp/mitmproxy-ca-cert.pem --proxy-cacert /tmp/mitmproxy-ca-cert.pem https://api.github.com 2>&1 | grep -i -E 'HTTP/1.1|HTTP/2'
#HTTP/1.1 200 Connection established
#HTTP/2 404
```

### 3.3 View of MITMProxy Capture logs & Replay Traffic

```bash
cat /tmp/mitmproxy/capture.mitm

# Replay traffic. (custom mock httpserver port as 9090)
mitmdump --mode regular@9090 -r /tmp/mitmproxy/capture.mitm
#127.0.0.1:48014: HEAD https://api.github.com/ HTTP/2.0
#     << HTTP/2.0 200 OK 0b
```

## 4. Next Steps

- Collecting MITMProxy Capture Log files and Replaying Traffic.

## 5. FAQ

### 5.1. How does MITMProxy intercept TLS handshake?

```txt
+------------------+         +-------------------+        +------------------+     +------------------+
|  Client Browser  |         |   Nginx Stream    |        |   Mitmproxy      |     | Target HTTPS     |
|                  |         |  with preread on  |        |                  |     | Server           |
+---------+--------+         +----------+--------+        +---------+--------+     +---------+--------+
          |                           |                             |                        |
          | 1. Connect to proxy       |                             |                        |
          | (HTTP CONNECT method)     |                             |                        |
          |-------------------------->|                             |                        |
          |                           | 2. Preread client's TLS     |                        |
          |                           | ClientHello, determine if   |                        |
          |                           | it's HTTPS traffic          |                        |
          |                           |---------------------------> |                        |
          |                           |                             |                        |
          |                           | 3. If HTTPS, forward to     |                        |
          |                           | mitmproxy                   |                        |
          |                           |<----------------------------|                        |
          |                           |                             | 4. Establish connection|
          |                           |                             | with target server     |
          |                           |                             |----------------------->|
          |                           |                             |                        |
          |                           |                             | 5. Proxy acts as client|
          |                           |                             | to server, sends TLS   |
          |                           |                             | handshake              |
          |                           |                             |<-----------------------|
          |                           |                             |                        |
          | 6. Nginx forwards proxy's |                             | 7. Proxy presents its  |
          | certificate to client     |                             | site server certificate|
          |<--------------------------|                             | to the proxy           |
          |                           |                             |<-----------------------|
          |                           |                             |                        |
          | 8. Client verifies proxy's|                             |                        |
          | certificate with Proxy CA |                             |                        |
          | if trusted                |                             |                        |
          |<--------------------------|                             |                        |
          |                           |                             |                        |
          | 9. Client and proxy       |                             |                        |
          | establish encrypted       |                             |                        |
          | session                   |                             |                        |
          |<--------------------------|                             |                        |
          |                           |                             |                        |
          | 10. Proxy decrypts traffic,|                            |                        |
          | re-encrypts with server's |                             |                        |
          | public key, forwards      |                             |                        |
          |<--------------------------|---------------------------> |                        |
          |                           |                             |                        |
          | 11. Encrypted response    |                             |                        |
          | from server to proxy,     |                             |                        |
          | proxy decrypts and        |                             |                        |
          | re-encrypts for client    |                             |                        |
          |<--------------------------|<----------------------------|                        |
          |                           |                             |                        |
          | 12. Process repeats for   |                             |                        |
          | each request/response     |                             |                        |
          | pair                      |                             |                        |
          |<--------------------------|<----------------------------|                        |
```

### 5.2. 由如上 #FAQ.1 原理可知, 既然如此轻松地实现中间人 `TLS handshake` 拦截, 那么是否任何已获得权威机构颁发的证书, 都可以被黑客利用部署到 `MITMProxy` 中, 用于动态生成 `Fake server certificate`, 从而轻松实现中间人攻击呢?

- 5.2.1 确实 Mimtproxy 实现原理非常简单, 不过要完整实施 `TLS handshake` 拦截的必要条件是, 必须要让 Client Browser/curl 默认信任其 MITMProxy 签发证书的 CA 证书, 否则会直接拒绝 Not Trust 连接.
- 5.2.2 同时根据 x509 证书标准, 能作为二级颁发机构 CA 证书, 要求其属性必须为 `Basic Constraints CA: true` 及 `Key Usage/Extended Key Usage`, 如果恶意开发者篡改其属性, 这样会破坏证书签名, 导致浏览器也会验证失败而拒绝或提示非安全连接.

```bash
echo | openssl s_client -connect api.github.com:443 -servername api.github.com 2>/dev/null </dev/null | openssl x509 -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            8b:dc:0f:ff:54:77:2f:aa:d1:73:27:3f:23:36:2a:af
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: C = GB, ST = Greater Manchester, L = Salford, O = Sectigo Limited, CN = Sectigo ECC Domain Validation Secure Server CA
        Validity
            Not Before: Mar  7 00:00:00 2024 GMT
            Not After : Mar  7 23:59:59 2025 GMT
        Subject: CN = *.github.com
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:70:03:18:49:44:9b:01:0a:41:33:a3:09:37:99:
                    11:0f:98:15:a7:1b:ca:42:0a:43:e2:34:38:8d:8d:
                    42:a8:d3:9e:58:fe:df:3a:49:fe:3f:17:62:26:ae:
                    fa:42:fe:5b:3e:6b:f7:b5:3c:43:ea:99:61:a0:d0:
                    d8:0e:88:6f:32
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Authority Key Identifier: 
                F6:85:0A:3B:11:86:E1:04:7D:0E:AA:0B:2C:D2:EE:CC:64:7B:7B:AE
            X509v3 Subject Key Identifier: 
                2C:D5:9F:32:48:98:6A:F9:B9:5B:BD:65:51:E9:E9:75:D7:20:B1:96
            X509v3 Key Usage: critical
                Digital Signature
            X509v3 Basic Constraints: critical
                ***CA:FALSE***
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Certificate Policies: 
                Policy: 1.3.6.1.4.1.6449.1.2.2.7
                  CPS: https://sectigo.com/CPS
                Policy: 2.23.140.1.2.1
            Authority Information Access: 
                CA Issuers - URI:http://crt.sectigo.com/SectigoECCDomainValidationSecureServerCA.crt
                OCSP - URI:http://ocsp.sectigo.com
            CT Precertificate SCTs: 
                Signed Certificate Timestamp:
                    Version   : v1 (0x0)
                    Log ID    : CF:11:56:EE:D5:2E:7C:AF:F3:87:5B:D9:69:2E:9B:E9:
                                1A:71:67:4A:B0:17:EC:AC:01:D2:5B:77:CE:CC:3B:08
                    Timestamp : Mar  7 00:16:53.313 2024 GMT
                    Extensions: none
                    Signature : ecdsa-with-SHA256
                                30:44:02:20:49:FD:44:F4:E3:FE:65:9A:0C:D2:58:58:
                                B7:79:69:DC:0C:87:B9:50:2D:DD:07:E1:4E:BC:ED:2D:
                                15:83:0F:88:02:20:16:19:94:E1:D4:8E:8A:52:58:0A:
                                E9:12:36:98:5D:50:FB:1C:59:BC:E2:20:F0:56:1F:8F:
                                26:58:8A:8B:28:7B
                Signed Certificate Timestamp:
                    Version   : v1 (0x0)
                    Log ID    : A2:E3:0A:E4:45:EF:BD:AD:9B:7E:38:ED:47:67:77:53:
                                D7:82:5B:84:94:D7:2B:5E:1B:2C:C4:B9:50:A4:47:E7
                    Timestamp : Mar  7 00:16:53.177 2024 GMT
                    Extensions: none
                    Signature : ecdsa-with-SHA256
                                30:46:02:21:00:B7:30:9C:1C:99:38:C4:B2:93:D3:CF:
                                8D:AD:9C:5D:A0:39:FF:1C:07:1B:79:FD:CD:35:1E:56:
                                71:2B:5B:07:12:02:21:00:E7:E7:32:6C:DF:94:E2:31:
                                47:3F:FB:96:48:B8:6D:AF:2B:2A:99:6F:92:50:99:C5:
                                C5:2D:87:36:08:EB:DB:94
                Signed Certificate Timestamp:
                    Version   : v1 (0x0)
                    Log ID    : 4E:75:A3:27:5C:9A:10:C3:38:5B:6C:D4:DF:3F:52:EB:
                                1D:F0:E0:8E:1B:8D:69:C0:B1:FA:64:B1:62:9A:39:DF
                    Timestamp : Mar  7 00:16:53.176 2024 GMT
                    Extensions: none
                    Signature : ecdsa-with-SHA256
                                30:45:02:21:00:FA:DF:40:FF:39:46:39:23:4C:03:45:
                                88:7A:AE:F6:21:21:A1:58:48:70:2B:A9:D3:E4:3F:BB:
                                ED:45:96:B8:12:02:20:39:56:3E:7D:F7:1B:A0:D0:3F:
                                DC:C5:63:57:81:DB:3C:97:05:3E:7B:4F:BA:1D:B0:BD:
                                D0:F8:9A:57:05:16:41
            X509v3 Subject Alternative Name: 
                DNS:*.github.com, DNS:github.com
    Signature Algorithm: ecdsa-with-SHA256
    Signature Value:
        30:45:02:21:00:b8:9e:d5:0b:78:0d:9f:8f:78:5b:3f:2d:87:
        a3:56:94:88:92:d4:fe:a6:5e:e7:af:1a:f3:ff:d7:e4:f3:40:
        38:02:20:6c:ae:9e:87:cc:f2:2a:be:ee:61:cd:7f:d6:a4:4c:
        78:3a:ef:7a:47:29:38:63:85:9c:e1:dd:dd:a3:97:56:a7
```
