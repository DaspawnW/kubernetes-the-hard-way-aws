This is a mirror from [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) - Almost every text
is copied only commands/config files are changed to work with AWS. Thank you Kelsey Hightower for your awesome Documentation!

# Managing the Container Network Routes

Now that each worker node is online we need to add routes to make sure that Pods running on different machines can talk to each other. In this lab we are not going to provision any overlay networks and instead rely on Layer 3 networking. That means we need to add routes to our vpc routing table. If this was an on-prem datacenter then ideally you would need to add the routes to your local router.

After completing this lab you will have the following router entries:

```
vpcId=`aws ec2 describe-vpcs --filters Name=tag:Name,Values=Kubernetes --query Vpcs[0].VpcId --output text`
tableId=`aws ec2 describe-route-tables --filters Name=vpc-id,Values=$vpcId --query RouteTables[0].RouteTableId --output text`
aws ec2 describe-route-tables --route-table-ids $tableId --output table
```
```
||+------------------+------------------------------------------------------------------+---------------------------------------+||
|||                                                           Routes                                                            |||
||+----------------------+---------------+-------------+------------------+---------------------+--------------------+----------+||
||| DestinationCidrBlock |   GatewayId   | InstanceId  | InstanceOwnerId  | NetworkInterfaceId  |      Origin        |  State   |||
||+----------------------+---------------+-------------+------------------+---------------------+--------------------+----------+||
|||  172.18.2.0/24       |               | id worker2  |  xxxxxxxxxxxx    |  eni-xxxxxxxx       |  CreateRoute       |  active  |||
|||  172.18.1.0/24       |               | id worker1  |  xxxxxxxxxxxx    |  eni-xxxxxxxx       |  CreateRoute       |  active  |||
|||  172.18.0.0/24       |               | id worker0  |  xxxxxxxxxxxx    |  eni-xxxxxxxx       |  CreateRoute       |  active  |||
|||  172.20.0.0/16       |  local        |             |                  |                     |  CreateRouteTable  |  active  |||
|||  0.0.0.0/0           |  igw-xxxxxxxx |             |                  |                     |  CreateRoute       |  active  |||
||+----------------------+---------------+-------------+------------------+---------------------+--------------------+----------+||
```

## Get the Routing Table

The first thing we need to do is gather the information required to populate the router table. We need the Internal IP address and Pod Subnet for each of the worker nodes.

Use `kubectl` to print the `InternalIP` and `podCIDR` for each worker node:

```
kubectl get nodes \
  --output=jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address} {.spec.podCIDR} {"\n"}{end}'
```

Output:

```
172.20.0.30 172.18.0.0/24
172.20.0.31 172.18.1.0/24
172.20.0.32 172.18.2.0/24
```

Use `awscli` to add the routes to VPC:

```
vpcId=`aws ec2 describe-vpcs --filters Name=tag:Name,Values=Kubernetes --query Vpcs[0].VpcId --output text`
tableId=`aws ec2 describe-route-tables --filters Name=vpc-id,Values=$vpcId --query RouteTables[0].RouteTableId --output text`

worker0_id=`aws ec2 describe-instances --filter Name=vpc-id,Values=$vpcId --filter Name=tag:Name,Values=worker2 --query 'Reservations[].Instances[].InstanceId' --output text`
aws ec2 create-route --route-table-id $tableId  --destination-cidr-block 172.18.0.0/24 --instance-id $worker0_id

worker1_id=`aws ec2 describe-instances --filter Name=vpc-id,Values=$vpcId --filter Name=tag:Name,Values=worker2 --query 'Reservations[].Instances[].InstanceId' --output text`
aws ec2 create-route --route-table-id $tableId  --destination-cidr-block 172.18.1.0/24 --instance-id $worker1_id

worker2_id=`aws ec2 describe-instances --filter Name=vpc-id,Values=$vpcId --filter Name=tag:Name,Values=worker2 --query 'Reservations[].Instances[].InstanceId' --output text`
aws ec2 create-route --route-table-id $tableId  --destination-cidr-block 172.18.2.0/24 --instance-id $worker2_id
```
