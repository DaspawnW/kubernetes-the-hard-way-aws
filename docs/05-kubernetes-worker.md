This is a mirror from [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) - Almost every text
is copied only commands/config files are changed to work with AWS. Thank you Kelsey Hightower for your awesome Documentation!

# Bootstrapping Kubernetes Workers

In this lab you will bootstrap 3 Kubernetes worker nodes. The following virtual machines will be used:

````
NAME         INTERNAL_IP  EXTERNAL_IP      STATUS
worker0      172.20.0.30  XXX.XXX.XXX.XXX  RUNNING
worker1      172.20.0.31  XXX.XXX.XXX.XXX  RUNNING
worker2      172.20.0.32  XXX.XXX.XXX.XXX  RUNNING
````

## Why

Kubernetes worker nodes are responsible for running your containers. All Kubernetes clusters need one or more worker nodes. We are running the worker nodes on dedicated machines for the following reasons:

* Ease of deployment and configuration
* Avoid mixing arbitrary workloads with critical cluster components. We are building machine with just enough resources so we don't have to worry about wasting resources.

Some people would like to run workers and cluster services anywhere in the cluster. This is totally possible, and you'll have to decide what's best for your environment.


## Provision the Kubernetes Worker Nodes

Run the following commands on `worker0`, `worker1`, `worker2`:

> SSH into each machine

#### Move the TLS certificates in place

```
sudo mkdir -p /var/lib/kubernetes
```

```
sudo mv ca.pem kubernetes-key.pem kubernetes.pem /var/lib/kubernetes/
```

#### Docker

Kubernetes should be compatible with the Docker 1.9.x - 1.11.x:

```
wget https://get.docker.com/builds/Linux/x86_64/docker-1.11.2.tgz
```

```
tar -xvf docker-1.11.2.tgz
```

```
sudo cp docker/docker* /usr/bin/
```

Create the Docker systemd unit file:


```
sudo sh -c 'echo "[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io

[Service]
ExecStart=/usr/bin/docker daemon \
  --iptables=false \
  --ip-masq=false \
  --host=unix:///var/run/docker.sock \
  --log-level=error \
  --storage-driver=overlay
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/docker.service'
```

```
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl start docker
```

```
sudo docker version
```


#### kubelet

The Kubernetes kubelet no longer relies on docker networking for pods! The Kubelet can now use [CNI - the Container Network Interface](https://github.com/containernetworking/cni) to manage machine level networking requirements.

Download and install CNI plugins

```
sudo mkdir -p /opt/cni
```

```
wget https://storage.googleapis.com/kubernetes-release/network-plugins/cni-c864f0e1ea73719b8f4582402b0847064f9883b0.tar.gz
```

```
sudo tar -xvf cni-c864f0e1ea73719b8f4582402b0847064f9883b0.tar.gz -C /opt/cni
```


Download and install the Kubernetes worker binaries:

```
wget https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kubectl
wget https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-proxy
wget https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kubelet
```

```
chmod +x kubectl kube-proxy kubelet
```

```
sudo mv kubectl kube-proxy kubelet /usr/bin/
```

```
sudo mkdir -p /var/lib/kubelet/
```

```
sudo sh -c 'echo "apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /var/lib/kubernetes/ca.pem
    server: https://172.20.0.20:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubelet
  name: kubelet
current-context: kubelet
users:
- name: kubelet
  user:
    token: chAng3m3" > /var/lib/kubelet/kubeconfig'
```

Create the kubelet systemd unit file:

```
sudo sh -c 'echo "[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/kubelet \
  --allow-privileged=true \
  --api-servers=https://172.20.0.20:6443,https://172.20.0.21:6443,https://172.20.0.22:6443 \
  --cloud-provider= \
  --cluster-dns=172.16.0.10 \
  --cluster-domain=cluster.local \
  --configure-cbr0=true \
  --container-runtime=docker \
  --docker=unix:///var/run/docker.sock \
  --network-plugin=kubenet \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --reconcile-cidr=true \
  --serialize-image-pulls=false \
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \
  --v=2 \
  --non-masquerade-cidr="172.16.0.0/14"

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/kubelet.service'
```

```
sudo systemctl daemon-reload
sudo systemctl enable kubelet
sudo systemctl start kubelet
```

```
sudo systemctl status kubelet --no-pager
```


#### kube-proxy


```
sudo sh -c 'echo "[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-proxy \
  --master=https://172.20.0.20:6443 \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --proxy-mode=iptables \
  --v=2

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/kube-proxy.service'
```

```
sudo systemctl daemon-reload
sudo systemctl enable kube-proxy
sudo systemctl start kube-proxy
```

```
sudo systemctl status kube-proxy --no-pager
```

> Remember to run these steps on `worker0`, `worker1`, and `worker2`
