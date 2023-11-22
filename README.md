# Docker toolbox images

## 1. Quick start

### 1.1 Attach the ephemeral tools container to the target Pod

- Scenario: James now finds that the coredns pod network is not connected,
he needs to use network tools to troubleshooting, he can do that.

- Note: This attach ephemeral container can share the `pid/utc/network/ipc namespace` with the
target pod, but not the `mnt namespace`, because the kubernetes design does not allow sharing of rootfs,
because the authors are concerned that rootfs file writes will pollute each other.

```bash
# export imageUrl="docker.io/wl4g/toolbox-base"
export imageUrl="registry.cn-shenzhen.aliyuncs.com/wl4g-k8s/toolbox-arthas"

alias k="kubectl" # alias k="sudo k3s kubectl"

export podName=$(k -n kube-system get pods | grep coredns | awk -F ' ' '{print $1}')
k -n kube-system debug -it ${podName} --image=${imageUrl} --target=coredns
```

### 1.2 Copy debug-run toobox Pod

- The advantage of this method is that it is safer than directly attaching temporary containers, because direct attaching
may cause pod resources to exceed the limit and be evicted, but the disadvantage is also obvious, because some failures
may need to preserve the running memory state, the way to create pod replicas will lose this states information.

```bash
k -n kube-system debug -it ${podName} --image=${imageUrl} --copy-to debug-pod --share-processes
```

### 1.3 Troubleshooting JVM problem with arthas

- 1.3.1 Preconditions1: If it is an environment less than kubernetes 1.23, the target Pod must run with root privileges, such as: `spec.containers[].securityContext.runAsNonRoot=false,runAsUser=0`. because pods follow immutability, i.e. they cannot be modified once created (but openshift supports `kubectl debug --as-root`, see to: [#3.6](#3.6))

- 1.3.2 Attach a ephemeral container and enter the terminal

```bash
# export imageUrl="docker.io/wl4g/toolbox-arthas"
export imageUrl="registry.cn-shenzhen.aliyuncs.com/wl4g-k8s/toolbox-arthas"

alias k="kubectl" # alias k="sudo k3s kubectl"

export podName=$(k -n biz-app get pods | grep myapp | awk -F ' ' '{print $1}')
k -n biz-app debug -it ${podName} --image=${imageUrl} --target=myapp
```

- 1.3.3 Manual copy arthas jars to target pod rootfs

```bash
# Get myapp JVM pid
export jvmPid=$(ps -ef | grep java | grep -v grep | cut -c 9-16 | sed 's/ //g')

cp -r /tmp/.arthas/ /proc/${jvmPid}/root/root/
```

- 1.3.4 Manual copy jps to target pod rootfs

```bash
# The following is the actual path of jre in the image openjdk:8u212-jre-alpine3.9
# Notice: Please modify the jre path in the target rootfs according to the actual path.
cp $(which jps) /proc/${jvmPid}/root/usr/lib/jvm/java-1.8-openjdk/jre/../lib/
```

- 1.3.5 Run arthas.

```bash
# Although it is usually more elegant to start arthas in the terminal of the debug ephemeral container,
# for the success rate of attach, it is better to directly enter the target pod to start arthas.
k -n biz-app exec -it pods/${podName} -- /bin/sh

cd /root/.arthas/lib/*/arthas/
java -jar arthas-boot.jar
```

- 1.3.6 Failed to attach to target troubleshooting

  - The following error may be caused by the application istio proxy or the application jvm cannot be loaded into
arthas jars and the sock is not monitored successfully, resulting in the attach failure. More to see: [#3.7](#3.7)

```log
[INFO] arthas-boot version: 3.6.2
[INFO] Found existing java process, please choose one and input the serial number of the process, eg : 1. Then hit ENTER.
* [1]: 7 com.xxx.MyApp

[INFO] arthas home: /root/.arthas/lib/3.6.2/arthas
[INFO] Try to attach process 7
[ERROR] Start arthas failed, exception stack trace: 
com.sun.tools.attach.AttachNotSupportedException: Unable to open socket file: target process not responding or HotSpot VM not loaded
        at sun.tools.attach.LinuxVirtualMachine.<init>(LinuxVirtualMachine.java:106)
        at sun.tools.attach.LinuxAttachProvider.attachVirtualMachine(LinuxAttachProvider.java:78)
        at com.sun.tools.attach.VirtualMachine.attach(VirtualMachine.java:250)
        at com.taobao.arthas.core.Arthas.attachAgent(Arthas.java:102)
        at com.taobao.arthas.core.Arthas.<init>(Arthas.java:27)
        at com.taobao.arthas.core.Arthas.main(Arthas.java:151)
[ERROR] attach fail, targetPid: 7
```

- Watch the process commands executed by arthas-boot.jar in real time at the target pod terminal (regardless of whether arthas is
started in the temporary container or the target container)

```bash
while true; do ps -ef | grep arthas; sleep 0.2; done

/usr/lib/jvm/java-1.8-openjdk/jre/../bin/java -Xbootclasspath/a:/usr/lib/jvm/java-1.8-openjdk/jre/../lib/tools.jar -jar /root/.arthas/lib/3.6.2/arthas/arthas-core.jar -pid 7 -core /root/.arthas/lib/3.6.2/arthas/arthas-core.jar -agent /root/.arthas/lib/3.6.2/arthas/arthas-agent.jar
```

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

