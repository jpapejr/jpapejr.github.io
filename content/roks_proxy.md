OpenShift clusters on IBM Cloud (ROKS) cluster are different that UPI/IPI installed OCP installs in that they do not support
the modification of some cluster global settings. Specifically, there are settings that the MachineConfig Operator deployment would
read and translate into host-level configuration on the workers. One example of this is configuring an HTTP(s) proxy for the cluster. 

Consider this, you have a VPC on IBM Cloud with no public gateways connected to your on-premises network via DirectLink. Thus your private-only ROKS cluster has no path out to the internet to pull container images from except that which you provide via your corporate proxy server. Additionally, cluster operators like the marketplace and samples operator (which populate the OperatorHub and Developer Catalog contents)
need to be able to reach the internet to obtain content as well. Using the steps below, we can configure the proxy for use on all the
worker hosts and for the cluster operators that require it. 

### Step 1 - Configure the cluster-wide proxy settings

To accomplish this, follow [this document](https://docs.openshift.com/container-platform/4.5/networking/enable-cluster-wide-proxy.html#nw-proxy-configure-object_config-cluster-wide-proxy) to configure the `proxy.config.openshift.io/cluster` resource in the cluster. 

After this, you can restart the operators in the `openshift-marketplace` and `openshift-cluster-samples-operator` projects and those 
workloads should be able to access their respective content from operatorhub.io and quay.io. 

### Step 2 - Create a ServiceAccount

In the default namespace, create a new ServiceAccount:

``` yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: crio-updater-ds
```

### Step 3 - Provide this new ServiceAccount with `privileged` access

Use the following command to grant the new ServiceAccount the `privileged` SecurityContextConstraint (SCC)

``` shell
oc project default
oc adm policy add-scc-to-user privileged -z crio-updater-ds
```

### Step 4 - Update the DaemonSet YAML

Taking the following example, update the following: 

- Replace the last three CIDR ranges (I.e. `10.241.128.0/24`, `10.241.64.0/24`, `10.241.0.0/24`) in the `NO_PROXY` field with the CIDR ranges for your VPC subnets. 
- Replace the `host:port` values in the `HTTP_PROXY` and `HTTPS_PROXY` fields with your proxy's host and port values.

> Note: The container image for this DaemonSet is taken from the `icr.io` registry. This was done because even a private-only ROKS cluster
will be able to access the IBM Cloud Container Registry (icr.io) via private service endpoints. If this is not the case in your environment, you'll need to use a container image that **can** be reached from the cluster **without** requiring access via the proxy.

``` yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: add-proxy-to-crio
  namespace: default
spec:
  selector:
    matchLabels:
      name: add-proxy-to-crio
  template:
    metadata:
      name: add-proxy-to-crio
      labels:
        name: add-proxy-to-crio
    spec:
      serviceAccountName: crio-updater-ds
      hostIPC: true
      containers:
        - name: add-proxy-to-crio
          image: icr.io/ibm/ibmcloud-backup-restore:latest
          imagePullPolicy: Always
          command: [ "/bin/sh", "-c", "+m" ]
          args:
          - >
              set -m;

              chroot /host echo
              NO_PROXY="localhost,127.0.0.1,172.20.0.1,172.21.0.0/16,172.17.0.0/18,161.26.0.0/16,166.8.0.0/14,172.20.0.0/16,10.241.128.0/24,10.241.64.0/24,10.241.0.0/24" 
              > /host/etc/sysconfig/crio-network;

              chroot /host echo HTTP_PROXY="http://10.241.0.11:3128/" >> /host/etc/sysconfig/crio-network;

              chroot /host echo HTTPS_PROXY="http://10.241.0.11:3128/" >> /host/etc/sysconfig/crio-network;

              chroot /host systemctl restart crio; 

              sleep 365d;

          volumeMounts:
          - name: host
            mountPath: /host
          securityContext:
            privileged: true
            runAsUser: 0
            capabilities:
              add:
              - SYS_ADMIN
              - SYS_CHROOT
      volumes:
      - name: host
        hostPath:
          path: /
          type: Directory
```

### Step 5 - Apply the DaemonSet YAML

Either run 

``` shell
oc apply -f <filename>
```

with the content from step 4 or simply access the `default` project from the OpenShift console and click the `Import YAML` button (I.e. plus icon in the top masthead of the console) and paste in the content from step 4. 


After a few moments, the daemonset pods should start and report as `Running`. A few moments longer (after the CRI-O systemd unit restarts), you should be able to pull images requiring access via the proxy. 
