# Toolbox image for Base

## 1. Quick start

### 1.1 With Docker

```bash
docker run --rm \
--platform linux/amd64 \
--network container:<TARGET_ID> \
registry.cn-shenzhen.aliyuncs.com/wl4g-k8s/toolbox-base netstat -nlpt

docker run --rm \
--platform linux/amd64 \
--volumes-from "<TARGET_ID>" \
registry.cn-shenzhen.aliyuncs.com/wl4g-k8s/toolbox-base sh -c "ls -al /opt/"
```
