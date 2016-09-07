This is a mirror from [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) - Almost every text
is copied only commands/config files are changed to work with AWS. Thank you Kelsey Hightower for your awesome Documentation!

# Cloud Infrastructure Provisioning

Kubernetes can be installed just about anywhere physical or virtual machines can be run. In this lab
we are going to focus on AWS.

This lab will walk you through provisioning the compute instances required for running a H/A
Kubernetes cluster. A total of 9 virtual machines will be created.

After completing this guide you should have the following instances:
```
NAME         INTERNAL_IP  EXTERNAL_IP      STATUS
controller0  172.20.0.20  XXX.XXX.XXX.XXX  RUNNING
controller1  172.20.0.21  XXX.XXX.XXX.XXX  RUNNING
controller2  172.20.0.22  XXX.XXX.XXX.XXX  RUNNING
etcd0        172.20.0.10  XXX.XXX.XXX.XXX  RUNNING
etcd1        172.20.0.11  XXX.XXX.XXX.XXX  RUNNING
etcd2        172.20.0.12  XXX.XXX.XXX.XXX  RUNNING
worker0      172.20.0.30  XXX.XXX.XXX.XXX  RUNNING
worker1      172.20.0.31  XXX.XXX.XXX.XXX  RUNNING
worker2      172.20.0.32  XXX.XXX.XXX.XXX  RUNNING
```

> All machines will be provisioned with fixed private IP addresses to simplify the bootstrap process.

To make our Kubernetes control plane remotely accessible, a Load Balancer will be created that will sit in front of the 3 Kubernetes controllers.

Create vpc
```
vpcId=`aws ec2 create-vpc --cidr-block 172.20.0.0/16 --query 'Vpc.VpcId' --output text`
aws ec2 create-tags --resources $vpcId --tag Key=Name,Value=Kubernetes
subnetId=`aws ec2 create-subnet --vpc-id $vpcId --cidr-block 172.20.0.0/16 --query 'Subnet.SubnetId' --output text`
aws ec2 create-tags --resources $subnetId --tag Key=Name,Value=Kubernetes-Subnetwork
```

Create internet gateway that allows communication between instances in vpc and the internet
```
gatewayId=`aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text`
aws ec2 create-tags --resources $gatewayId --tag Key=Name,Value=Kubernetes-Gateway
```

Attach internet gateway to vpc
```
aws ec2 attach-internet-gateway --internet-gateway-id $gatewayId --vpc-id $vpcId
```

Find main routing table
```
tableId=`aws ec2 describe-route-tables --filters Name=vpc-id,Values=$vpcId --query RouteTables[0].RouteTableId --output text`
```

Ensure that your subnet's route table points to the Internet gateway
```
aws ec2 create-route --route-table-id $tableId --destination-cidr-block 0.0.0.0/0 --gateway-id $gatewayId
```

Retrieve vpc id
```
vpcId=`aws ec2 describe-vpcs --filters Name=tag:Name,Values=Kubernetes --query Vpcs[0].VpcId --output text`
```

Retrieve subnet id
```
subnetId=`aws ec2 describe-subnets --filters Name=tag:Name,Values=Kubernetes-Subnetwork --query Subnets[0].SubnetId --output text`
```

Create Security Groups (Firewall)
```
# Create one security group for every type of instance
worker_sg_id=`aws ec2 create-security-group --group-name kubernetes-worker --description kubernetes-worker --vpc-id $vpcId --query 'GroupId' --output text`
etcd_sg_id=`aws ec2 create-security-group --group-name kubernetes-etcd --description kubernetes-etcd --vpc-id $vpcId --query 'GroupId' --output text`
controller_sg_id=`aws ec2 create-security-group --group-name kubernetes-controller --description kubernetes-controller --vpc-id $vpcId --query 'GroupId' --output text`

# Add elb security group
elb_sg_id=`aws ec2 create-security-group --group-name kubernetes-elb --description kubernetes-elb --vpc-id $vpcId --query 'GroupId' --output text`
```

Retrieve all security group ids
```
aws ec2 describe-security-groups --filter Name=vpc-id,Values=$vpcId --query SecurityGroups[].[Description,GroupId] --output table
```

Attach Rules to Security Groups
```
aws ec2 authorize-security-group-ingress --group-id $worker_sg_id     --protocol icmp --port -1 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $etcd_sg_id       --protocol icmp --port -1 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $controller_sg_id --protocol icmp --port -1 --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress --group-id $worker_sg_id     --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $etcd_sg_id       --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $controller_sg_id --protocol tcp --port 22 --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress --group-id $worker_sg_id     --protocol tcp  --port 0-65535 --cidr 172.20.0.0/16
aws ec2 authorize-security-group-ingress --group-id $etcd_sg_id       --protocol tcp  --port 0-65535 --cidr 172.20.0.0/16
aws ec2 authorize-security-group-ingress --group-id $controller_sg_id --protocol tcp  --port 0-65535 --cidr 172.20.0.0/16

aws ec2 authorize-security-group-ingress --group-id $worker_sg_id     --protocol udp  --port 0-65535 --cidr 172.20.0.0/16
aws ec2 authorize-security-group-ingress --group-id $etcd_sg_id       --protocol udp  --port 0-65535 --cidr 172.20.0.0/16
aws ec2 authorize-security-group-ingress --group-id $controller_sg_id --protocol udp  --port 0-65535 --cidr 172.20.0.0/16

aws ec2 authorize-security-group-ingress --group-id $worker_sg_id     --protocol tcp  --port 0-65535 --cidr 172.18.0.0/16
aws ec2 authorize-security-group-ingress --group-id $worker_sg_id     --protocol udp  --port 0-65535 --cidr 172.18.0.0/16

aws ec2 authorize-security-group-ingress --group-id $worker_sg_id     --protocol icmp --port -1 --cidr 172.20.0.0/16
aws ec2 authorize-security-group-ingress --group-id $etcd_sg_id       --protocol icmp --port -1 --cidr 172.20.0.0/16
aws ec2 authorize-security-group-ingress --group-id $controller_sg_id --protocol icmp --port -1 --cidr 172.20.0.0/16

aws ec2 authorize-security-group-ingress --group-id $worker_sg_id     --protocol tcp --port 8080 --cidr 130.211.0.0/22
aws ec2 authorize-security-group-ingress --group-id $etcd_sg_id       --protocol tcp --port 8080 --cidr 130.211.0.0/22
aws ec2 authorize-security-group-ingress --group-id $controller_sg_id --protocol tcp --port 8080 --cidr 130.211.0.0/22

# Allow connection internet => load balancer
aws ec2 authorize-security-group-ingress --group-id $elb_sg_id --protocol tcp --port 6443 --cidr 0.0.0.0/0

# Allow connection load balancer => controller0,controller1,controller2
aws ec2 authorize-security-group-ingress --group-id $controller_sg_id --protocol tcp --port 6443 --source-group $elb_sg_id
aws ec2 authorize-security-group-ingress --group-id $controller_sg_id --protocol tcp --port 8080 --source-group $elb_sg_id
```

Describe Firewall-Rules
```
aws ec2 describe-security-groups --filter Name=vpc-id,Values=$vpcId --output table
```

Create Public-IP - Not needed because this documentation uses an elastic load-balancer.

## Create instances

All the VMs in this lab will be provisioned using Ubuntu 16.04 mainly because it runs a newish Linux
Kernel that has good support for Docker.

[Find AMI](https://cloud-images.ubuntu.com/locator/ec2/) - This documentation uses hvm:ebs-ssd eu-west-1 ubuntu 16.04 LTS

Create etcd
```
etcd0_id=`aws ec2 run-instances --key-name $AWS_SSH_KEY --security-group-ids $etcd_sg_id --associate-public-ip-address --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeType":"gp2", "VolumeSize": 200}}]' --image-id ami-a4d44ed7 --private-ip-address 172.20.0.10 --subnet-id $subnetId --instance-type m3.medium --query 'Instances[0].InstanceId' --output text`
aws ec2 create-tags --resources $etcd0_id --tag Key=Name,Value=etcd0
etcd1_id=`aws ec2 run-instances --key-name $AWS_SSH_KEY --security-group-ids $etcd_sg_id --associate-public-ip-address --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeType":"gp2", "VolumeSize": 200}}]' --image-id ami-a4d44ed7 --private-ip-address 172.20.0.11 --subnet-id $subnetId --instance-type m3.medium --query 'Instances[0].InstanceId' --output text`
aws ec2 create-tags --resources $etcd1_id --tag Key=Name,Value=etcd1
etcd2_id=`aws ec2 run-instances --key-name $AWS_SSH_KEY --security-group-ids $etcd_sg_id --associate-public-ip-address --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeType":"gp2", "VolumeSize": 200}}]' --image-id ami-a4d44ed7 --private-ip-address 172.20.0.12 --subnet-id $subnetId --instance-type m3.medium --query 'Instances[0].InstanceId' --output text`
aws ec2 create-tags --resources $etcd2_id --tag Key=Name,Value=etcd2
```

Create Kubernetes Controllers
```
controller0_id=`aws ec2 run-instances --key-name $AWS_SSH_KEY --security-group-ids $controller_sg_id --associate-public-ip-address --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeType":"gp2", "VolumeSize": 200}}]' --image-id ami-a4d44ed7 --private-ip-address 172.20.0.20 --subnet-id $subnetId --instance-type m3.medium --query 'Instances[0].InstanceId' --output text`
aws ec2 create-tags --resources $controller0_id --tag Key=Name,Value=controller0
controller1_id=`aws ec2 run-instances --key-name $AWS_SSH_KEY --security-group-ids $controller_sg_id --associate-public-ip-address --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeType":"gp2", "VolumeSize": 200}}]' --image-id ami-a4d44ed7 --private-ip-address 172.20.0.21 --subnet-id $subnetId --instance-type m3.medium --query 'Instances[0].InstanceId' --output text`
aws ec2 create-tags --resources $controller1_id --tag Key=Name,Value=controller1
controller2_id=`aws ec2 run-instances --key-name $AWS_SSH_KEY --security-group-ids $controller_sg_id --associate-public-ip-address --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeType":"gp2", "VolumeSize": 200}}]' --image-id ami-a4d44ed7 --private-ip-address 172.20.0.22 --subnet-id $subnetId --instance-type m3.medium --query 'Instances[0].InstanceId' --output text`
aws ec2 create-tags --resources $controller2_id --tag Key=Name,Value=controller2
```

Create Kubernetes Worker
```
worker0_id=`aws ec2 run-instances --key-name $AWS_SSH_KEY --security-group-ids $worker_sg_id --associate-public-ip-address --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeType":"gp2", "VolumeSize": 200}}]' --image-id ami-a4d44ed7 --private-ip-address 172.20.0.30 --subnet-id $subnetId --instance-type m3.medium --query 'Instances[0].InstanceId' --output text`
aws ec2 create-tags --resources $worker0_id --tag Key=Name,Value=worker0
worker1_id=`aws ec2 run-instances --key-name $AWS_SSH_KEY --security-group-ids $worker_sg_id --associate-public-ip-address --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeType":"gp2", "VolumeSize": 200}}]' --image-id ami-a4d44ed7 --private-ip-address 172.20.0.31 --subnet-id $subnetId --instance-type m3.medium --query 'Instances[0].InstanceId' --output text`
aws ec2 create-tags --resources $worker1_id --tag Key=Name,Value=worker1
worker2_id=`aws ec2 run-instances --key-name $AWS_SSH_KEY --security-group-ids $worker_sg_id --associate-public-ip-address --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeType":"gp2", "VolumeSize": 200}}]' --image-id ami-a4d44ed7 --private-ip-address 172.20.0.32 --subnet-id $subnetId --instance-type m3.medium --query 'Instances[0].InstanceId' --output text`
aws ec2 create-tags --resources $worker2_id --tag Key=Name,Value=worker2
```

"Each EC2 instance performs source/destination checks by default. This means that the instance must be the source or destination of any traffic it sends or receives. However, a NAT instance must be able to send and receive traffic when the source or destination is not itself. Therefore, you must disable source/destination checks on the NAT instance." (source: [AWS Docs](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_NAT_Instance.html#EIP_Disable_SrcDestCheck))
```
aws ec2 modify-instance-attribute --instance-id $worker0_id --no-source-dest-check
aws ec2 modify-instance-attribute --instance-id $worker1_id --no-source-dest-check
aws ec2 modify-instance-attribute --instance-id $worker2_id --no-source-dest-check
```

## Connect instances /  Transfer Files
Get table of instances
```
aws ec2 describe-instances --filter Name=vpc-id,Values=$vpcId --query 'Reservations[].Instances[].[PublicIpAddress,PrivateIpAddress,InstanceId,Tags[?Key==`Name`].Value[]]' --output text
```

Get ips
```
controller0_ip=`aws ec2 describe-instances --filter "Name=vpc-id,Values=$vpcId" "Name=tag:Name,Values=controller0" --query 'Reservations[].Instances[].PublicIpAddress' --output text`
```

Connect
```
ssh -l ubuntu $controller0_ip
```

Transfer File
```
scp file ubuntu@$controller0_ip:
```

Function to retrieve ip via shell alias
```
echo 'aws_ip () { aws ec2 describe-instances --filter "Name=vpc-id,Values=$vpcId" "Name=tag:Name,Values=$1" --query "Reservations[].Instances[].PublicIpAddress" --output text; }' >> ~/.aliases
source ~/.aliases
```

Now easily ssh into instance
```
ssh -l ubuntu `aws_ip controller0`
```

Or Copy Files:
```
scp file ubuntu@`aws_ip controller0`:
```

On every server ensure right name resolution (set etc hosts entries, set hostname through hostname file and command) - ssh to every instance and execute the following commands:
```
sudo /bin/bash -c "echo -e \"\n172.20.0.10 etcd0\n172.20.0.11 etcd1\n172.20.0.12 etcd2\n172.20.0.20 controller0\n172.20.0.21 controller1\n172.20.0.22 controller2\n172.20.0.30 worker0\n172.20.0.31 worker1\n172.20.0.32 worker2\" >> /etc/hosts"
sudo /bin/bash -c "grep `curl -s http://169.254.169.254/latest/meta-data/local-ipv4` /etc/hosts |cut -d ' ' -f 2 > /etc/hostname"
sudo /bin/bash -c "hostname `grep $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) /etc/hosts |cut -d ' ' -f 2`"
```

Or even easier:
```
for a in 0 1 2;do for b in etcd controller worker;do ssh -l ubuntu  ubuntu@`aws_ip $b$a` -C 'curl https://raw.githubusercontent.com/ivx/kubernetes-the-hard-way-aws/master/prepare-dns.sh |sudo bash';done;done
```
