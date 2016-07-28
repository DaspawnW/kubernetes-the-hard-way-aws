This is a mirror from [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) - Almost every text
is copied only commands/config files are changed to work with AWS. Thank you Kelsey Hightower for your awesome Documentation!

# Setting up a Certificate Authority and TLS Cert Generation

In this lab you will setup the necessary PKI infrastructure to secure the Kubernetes components.
This lab will leverage CloudFlare's PKI toolkit, [cfssl](https://github.com/cloudflare/cfssl), to
bootstrap a Certificate Authority and generate TLS certificates.

In this lab you will generate a single set of TLS certificates that can be used to secure the
following Kubernetes components:

* etcd
* Kubernetes API Server
* Kubernetes Kubelet

> In production you should strongly consider generating individual TLS certificates for each
> component.

After completing this lab you should have the following TLS keys and certificates:

```
ca-key.pem
ca.pem
kubernetes-key.pem
kubernetes.pem
```

## Install CFSSL

This lab requires the `cfssl` and `cfssljson` binaries. Download them from the [cfssl repository](https://pkg.cfssl.org).

### OS X

```
wget https://pkg.cfssl.org/R1.2/cfssl_darwin-amd64
chmod +x cfssl_darwin-amd64
sudo mv cfssl_darwin-amd64 /usr/local/bin/cfssl
```

```
wget https://pkg.cfssl.org/R1.2/cfssljson_darwin-amd64
chmod +x cfssljson_darwin-amd64
sudo mv cfssljson_darwin-amd64 /usr/local/bin/cfssljson
```


### Linux

```
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
chmod +x cfssl_linux-amd64
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
```

```
wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssljson_linux-amd64
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
```

## Setting up a Certificate Authority

### Create the CA configuration file

```
echo '{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}' > ca-config.json
```

### Generate the CA certificate and private key

Create the CA CSR:

```
echo '{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}' > ca-csr.json
```

Generate the CA certificate and private key:

```
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

Results:

```
ca-key.pem
ca.csr
ca.pem
```

### Verification

```
openssl x509 -in ca.pem -text -noout
```

## Generate the single Kubernetes TLS Cert

In this section we will generate a TLS certificate that will be valid for all Kubernetes components. This is being done for ease of use. In production you should strongly consider generating individual TLS certificates for each component.

The elastic load balancer will be created at this point to ensure the certificate is valid for its dns-name.
```
KUBERNETES_ELB_DNS=`aws elb create-load-balancer --load-balancer-name kubernetes --listeners Protocol=tcp,LoadBalancerPort=6443,InstanceProtocol=tcp,InstancePort=6443 --subnets $subnetId --security-groups $elb_sg_id --query DNSName --output text`
```

Create the `kubernetes-csr.json` file:
```
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "hosts": [
    "worker0",
    "worker1",
    "worker2",
    "172.16.0.1",
    "172.20.0.10",
    "172.20.0.11",
    "172.20.0.12",
    "172.20.0.20",
    "172.20.0.21",
    "172.20.0.22",
    "172.20.0.30",
    "172.20.0.31",
    "172.20.0.32",
    "${KUBERNETES_ELB_DNS}",
    "127.0.0.1"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Cluster",
      "ST": "Oregon"
    }
  ]
}
EOF
```

Generate the Kubernetes certificate and private key:

```
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
```

Results:

```
kubernetes-key.pem
kubernetes.csr
kubernetes.pem
```

### Verification

```
openssl x509 -in kubernetes.pem -text -noout
```

Copy CRT Files to Instances - Please be sure you already configured the shell alias:
```
for a in 0 1 2;do for b in etcd controller worker;do scp ca.pem kubernetes-key.pem kubernetes.pem ubuntu@`aws_ip $b$a`:;done;done
```
