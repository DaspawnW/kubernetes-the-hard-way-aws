This is a mirror from [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) - Almost every text
is copied only commands/config files are changed to work with AWS. Thank you Kelsey Hightower for your awesome Documentation!

# Smoke Test

This lab walks you through a quick smoke test to make sure things are working.

## Test

```
kubectl run nginx --image=nginx --port=80 --replicas=3
```

```
deployment "nginx" created
```

```
kubectl get pods -o wide
```
```
NAME                                    READY     STATUS             RESTARTS   AGE       NODE
nginx-2032906785-314zi                  1/1       Running            0          1d        worker0
nginx-2032906785-i46bq                  1/1       Running            0          1d        worker1
nginx-2032906785-vznwh                  1/1       Running            0          1d        worker2
```

```
kubectl expose deployment nginx --type NodePort
```

```
service "nginx" exposed
```

> Note that --type=LoadBalancer will not work because we did not configure a cloud provider when bootstrapping this cluster.

Grab the `NodePort` that was setup for the nginx service:

```
export NODE_PORT=$(kubectl get svc nginx --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
```

```
vpcId=`aws ec2 describe-vpcs --filters Name=tag:Name,Values=Kubernetes --query Vpcs[0].VpcId --output text`
worker_sg_id=`aws ec2 describe-security-groups --filter Name=vpc-id,Values=$vpcId --filter Name=description,Values=kubernetes-worker --query SecurityGroups[0].GroupId --output text`
aws ec2 authorize-security-group-ingress --group-id $worker_sg_id  --protocol tcp --port $NODE_PORT --cidr 0.0.0.0/0
```

Grab the `EXTERNAL_IP` for one of the worker nodes

```
vpcId=`aws ec2 describe-vpcs --filters Name=tag:Name,Values=Kubernetes --query Vpcs[0].VpcId --output text`
export NODE_PUBLIC_IP=$(aws ec2 describe-instances --filter Name=vpc-id,Values=$vpcId --filter Name=tag:Name,Values=worker0 --query 'Reservations[].Instances[].PublicIpAddress' --output text)
```

Test the nginx service using cURL:

```
curl http://${NODE_PUBLIC_IP}:${NODE_PORT}
```

```
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```
