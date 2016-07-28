This is a mirror from [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) - Almost every text
is copied only commands/config files are changed to work with AWS. Thank you Kelsey Hightower for your awesome Documentation!

# Cleaning Up
Find old instances and terminate them
```
# Verify vpcid var is set
vpcId=`aws ec2 describe-vpcs --filters Name=tag:Name,Values=Kubernetes --query Vpcs[0].VpcId --output text`;echo $vpcId
# Stop instances first
aws ec2 stop-instances --instance-ids `aws ec2 describe-instances --filter Name=vpc-id,Values=$vpcId --query Reservations[*].Instances[0].InstanceId --output text`
# Take of your Headphones and check if any dev/ceo is shouting at you - If not:
aws ec2 terminate-instances --instance-ids `aws ec2 describe-instances --filter Name=vpc-id,Values=$vpcId --query Reservations[*].Instances[0].InstanceId --output text`
```

Remove Load Balancer
```
aws elb delete-load-balancer --load-balancer-name kubernetes
```

Remove old Security Groups
```
vpcId=`aws ec2 describe-vpcs --filters Name=tag:Name,Values=Kubernetes --query Vpcs[0].VpcId --output text`;echo $vpcId
aws ec2 describe-security-groups --filter Name=vpc-id,Values=$vpcId --query SecurityGroups[].[Description,GroupId] --output table
# Show all Security Groups and delete every except default!
# Elastic LB Security group can only deleted after a few minutes
aws ec2 delete-security-group --group-id manually-insert-id
```

Remove Subnets
```
subnetId=`aws ec2 describe-subnets --filters Name=tag:Name,Values=Kubernetes-Subnetwork --query Subnets[0].SubnetId --output text`
aws ec2 delete-subnet --subnet-id $subnetId
```

Remove Internet Gateway
```
gatewayId=`aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$vpcId --query InternetGateways[0].InternetGatewayId --output text`
aws ec2 detach-internet-gateway --internet-gateway-id $gatewayId --vpc-id $vpcId
aws ec2 delete-internet-gateway --internet-gateway-id $gatewayId
```

Remove VPC
```
vpcId=`aws ec2 describe-vpcs --filters Name=tag:Name,Values=Kubernetes --query Vpcs[0].VpcId --output text`;echo $vpcId
aws ec2 delete-vpc --vpc-id=$vpcId
```
