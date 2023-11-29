# Toolbox image for arthas

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

