This is a mirror from [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) - Almost every text
is copied only commands/config files are changed to work with AWS. Thank you Kelsey Hightower for your awesome Documentation!

# Bootstrapping an H/A Kubernetes Control Plane

In this lab you will bootstrap a 3 node Kubernetes controller cluster. The following virtual machines will be used:

```
NAME         INTERNAL_IP  EXTERNAL_IP      STATUS
controller0  172.20.0.20  XXX.XXX.XXX.XXX  RUNNING
controller1  172.20.0.21  XXX.XXX.XXX.XXX  RUNNING
controller2  172.20.0.22  XXX.XXX.XXX.XXX  RUNNING
```

In this lab you will also create a frontend load balancer with a public IP address for remote access to the API servers and H/A.

## Why

The Kubernetes components that make up the control plane include the following components:

* Kubernetes API Server
* Kubernetes Scheduler
* Kubernetes Controller Manager

Each component is being run on the same machines for the following reasons:

* The Scheduler and Controller Manager are tightly coupled with the API Server
* Only one Scheduler and Controller Manager can be active at a given time, but it's ok to run multiple at the same time. Each component will elect a leader via the API Server.
* Running multiple copies of each component is required for H/A
* Running each component next to the API Server eases configuration.

## Provision the Kubernetes Controller Cluster

Run the following commands on `controller0`, `controller1`, `controller2`:

> SSH into each machine


Move the TLS certificates in place:

```
sudo mkdir -p /var/lib/kubernetes
```

```
sudo mv ca.pem kubernetes-key.pem kubernetes.pem /var/lib/kubernetes/
```

Download and install the Kubernetes controller binaries:

```
wget https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-apiserver
wget https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-controller-manager
wget https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-scheduler
wget https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kubectl
```

```
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
```

```
sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/bin/
```

### Kubernetes API Server

#### Setup Authentication and Authorization

##### Authentication

[Token based authentication](http://kubernetes.io/docs/admin/authentication) will be used to limit access to Kubernetes API.

```
wget https://raw.githubusercontent.com/ivx/kubernetes-the-hard-way-aws/master/token.csv
```

```
cat token.csv
```

```
sudo mv token.csv /var/lib/kubernetes/
```

##### Authorization

Attribute-Based Access Control (ABAC) will be used to authorize access to the Kubernetes API. In this lab ABAC will be setup using the Kuberentes policy file backend as documented in the [Kubernetes authorization guide](http://kubernetes.io/docs/admin/authorization).

```
wget https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/authorization-policy.jsonl
```

```
cat authorization-policy.jsonl
```

```
sudo mv authorization-policy.jsonl /var/lib/kubernetes/
```

### Create the systemd unit file

Capture the internal IP address:

```
export INTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
```

Create the systemd unit file:

```
cat > kube-apiserver.service <<"EOF"
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-apiserver \
  --admission-control=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota \
  --advertise-address=INTERNAL_IP \
  --allow-privileged=true \
  --apiserver-count=3 \
  --authorization-mode=ABAC \
  --authorization-policy-file=/var/lib/kubernetes/authorization-policy.jsonl \
  --bind-address=0.0.0.0 \
  --enable-swagger-ui=true \
  --etcd-cafile=/var/lib/kubernetes/ca.pem \
  --insecure-bind-address=0.0.0.0 \
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \
  --etcd-servers=https://172.20.0.10:2379,https://172.20.0.11:2379,https://172.20.0.12:2379 \
  --service-account-key-file=/var/lib/kubernetes/kubernetes-key.pem \
  --service-cluster-ip-range=172.16.0.0/16 \
  --service-node-port-range=30000-32767 \
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \
  --token-auth-file=/var/lib/kubernetes/token.csv \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

```
sed -i s/INTERNAL_IP/$INTERNAL_IP/g kube-apiserver.service
```

```
sudo mv kube-apiserver.service /etc/systemd/system/
```


```
sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver
sudo systemctl start kube-apiserver
```

```
sudo systemctl status kube-apiserver --no-pager
```

### Kubernetes Controller Manager

```
cat > kube-controller-manager.service <<"EOF"
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-controller-manager \
  --allocate-node-cidrs=true \
  --cluster-cidr=172.18.0.0/16 \
  --cluster-name=kubernetes \
  --leader-elect=true \
  --master=http://INTERNAL_IP:8080 \
  --root-ca-file=/var/lib/kubernetes/ca.pem \
  --service-account-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \
  --service-cluster-ip-range=172.16.0.0/16 \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

```
sed -i s/INTERNAL_IP/$INTERNAL_IP/g kube-controller-manager.service
```

```
sudo mv kube-controller-manager.service /etc/systemd/system/
```


```
sudo systemctl daemon-reload
sudo systemctl enable kube-controller-manager
sudo systemctl start kube-controller-manager
```

```
sudo systemctl status kube-controller-manager --no-pager
```

### Kubernetes Scheduler

```
cat > kube-scheduler.service <<"EOF"
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-scheduler \
  --leader-elect=true \
  --master=http://INTERNAL_IP:8080 \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

```
sed -i s/INTERNAL_IP/$INTERNAL_IP/g kube-scheduler.service
```

```
sudo mv kube-scheduler.service /etc/systemd/system/
```

```
sudo systemctl daemon-reload
sudo systemctl enable kube-scheduler
sudo systemctl start kube-scheduler
```

```
sudo systemctl status kube-scheduler --no-pager
```


### Verification

```
kubectl get componentstatuses
```
```
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-1               Healthy   {"health": "true"}
etcd-0               Healthy   {"health": "true"}
etcd-2               Healthy   {"health": "true"}
```

> Remember to run these steps on `controller0`, `controller1`, and `controller2`

## Setup Kubernetes API Server Frontend Load Balancer

The virtual machines created in this tutorial will not have permission to complete this section. Run the following commands from the same place used to create the virtual machines for this tutorial.

Configure health check
```
aws elb configure-health-check --load-balancer-name kubernetes --health-check Target=HTTP:8080/healthz,Interval=5,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3
```

Add instances to load balancer
```
vpcId=`aws ec2 describe-vpcs --filters Name=tag:Name,Values=Kubernetes --query Vpcs[0].VpcId --output text`
controller0_id=`aws ec2 describe-instances --filter Name=vpc-id,Values=$vpcId --filter Name=tag:Name,Values=controller0 --query 'Reservations[].Instances[].InstanceId' --output text`
controller1_id=`aws ec2 describe-instances --filter Name=vpc-id,Values=$vpcId --filter Name=tag:Name,Values=controller1 --query 'Reservations[].Instances[].InstanceId' --output text`
controller2_id=`aws ec2 describe-instances --filter Name=vpc-id,Values=$vpcId --filter Name=tag:Name,Values=controller2 --query 'Reservations[].Instances[].InstanceId' --output text`
aws elb register-instances-with-load-balancer --load-balancer-name kubernetes --instances $controller0_id $controller1_id $controller2_id
```
