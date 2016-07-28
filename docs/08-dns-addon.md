This is a mirror from [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) - Almost every text
is copied only commands/config files are changed to work with AWS. Thank you Kelsey Hightower for your awesome Documentation!

# Deploying the Cluster DNS Add-on

In this lab you will deploy the DNS add-on which is required for every Kubernetes cluster. Without the DNS add-on the following things will not work:

* DNS based service discovery 
* DNS lookups from containers running in pods

## Cluster DNS Add-on

### Create the `skydns` service:

```
kubectl create -f https://raw.githubusercontent.com/ivx/kubernetes-the-hard-way-aws/master/skydns-svc.yaml
```

#### Verification

```
kubectl --namespace=kube-system get svc
```
```
NAME       CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
kube-dns   172.16.0.10   <none>        53/UDP,53/TCP   1m
```

### Create the `skydns` replication controller:

```
kubectl create -f https://raw.githubusercontent.com/ivx/kubernetes-the-hard-way-aws/master/skydns-rc.yaml
```

#### Verification

```
kubectl --namespace=kube-system get pods
```
```
NAME                 READY     STATUS    RESTARTS   AGE
kube-dns-v18-79maa   3/3       Running   0          41s
kube-dns-v18-bcs1f   3/3       Running   0          41s
```
