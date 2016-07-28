This is a mirror from [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) - Almost every text
is copied only commands/config files are changed to work with AWS. Thank you Kelsey Hightower for your awesome Documentation!

# Configuring the Kubernetes Client - Remote Access

## Download and Install kubectl

### OS X

```
wget https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/darwin/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin
```

### Linux

```
wget https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin
```

## Configure Kubectl

In this section you will configure the kubectl client to point to the [Kubernetes API Server Frontend Load Balancer](04-kubernetes-controller.md#setup-kubernetes-api-server-frontend-load-balancer).

```
elbDnsname=`aws elb describe-load-balancers --load-balancer-names kubernetes --query LoadBalancerDescriptions[0].DNSName --output text`
```

Recall the token we setup for the admin user:

```
# /var/run/kubernetes/token.csv on the controller nodes
chAng3m3,admin,admin
```

Also be sure to locate the CA certificate [created earlier](02-certificate-authority.md). Since we are using self-signed TLS certs we need to trust the CA certificate so we can verify the remote API Servers.

### Build up the kubeconfig entry

The following commands will build up the default kubeconfig file used by kubectl.

```
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${elbDnsname}:6443
```

```
kubectl config set-credentials admin --token chAng3m3
```

```
kubectl config set-context default-context \
  --cluster=kubernetes-the-hard-way \
  --user=admin
```

```
kubectl config use-context default-context
```

At this point you should be able to connect securly to the remote API server:

```
kubectl get componentstatuses
```
```
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok                   
scheduler            Healthy   ok                   
etcd-2               Healthy   {"health": "true"}   
etcd-0               Healthy   {"health": "true"}   
etcd-1               Healthy   {"health": "true"}  
```


```
kubectl get nodes
```
```
NAME      STATUS    AGE
worker0   Ready     7m
worker1   Ready     5m
worker2   Ready     2m
```
