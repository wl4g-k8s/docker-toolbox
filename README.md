# Toolbox Images

## 1. Quick start

- [Toolbox for arthas](arthas/README.md)
- [Toolbox for pprof](pprof/README.md)
- [Toolbox for mat](mat/README.md)

## 2. Development Guide

```bash
./build.sh build
./build.sh push
```

## 3. References

- 3.1 [kubernetes.io security context docs](https://kubernetes.io/zh-cn/docs/tasks/configure-pod-container/security-context/)

- 3.2 [kubernetes.io ephemeral-volumes docs](https://kubernetes.io/zh-cn/docs/concepts/storage/ephemeral-volumes/)

- 3.3 [kubectl debug 之最佳实践. #411724](https://www.modb.pro/db/411724)

- 3.4 [kubectl debug 之无法访问 non-root 启动的容器. #105846](https://github.com/kubernetes/kubernetes/issues/105846)

- 3.5 [kubectl debug 临时容器一旦附加无法删除， 且多次 attach 会导致临时容器过多，当超过 1.5M 时 etcd 会报错](https://github.com/kubernetes/kubernetes/issues/84764#issuecomment-1124885813)

- 3.6 [openshift 支持启动具有 root 权限的 debug pod](https://access.redhat.com/documentation/zh-cn/openshift_container_platform/4.6/html/support/starting-debug-pods-with-root-access_investigating-pod-issues)

- 3.7 [arthas 在 ephemeral container attach 到目标 pod 失败. #1874](https://github.com/alibaba/arthas/issues/1874)

- 3.8 [开发一个 arthas native agent 和远程管理平台，统一实时管理 JVM 集群. #2163](https://github.com/alibaba/arthas/issues/2163)

- 3.9 [gperftools 追踪 JVM native 内存泄露](https://www.notion.so/gperftools-JVM-native-4aecf52bf9ed4e56a2519396119ec404)
