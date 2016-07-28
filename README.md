# Kubernetes The Hard Way - AWS

This is a mirror from [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) - Almost every text
is copied only commands/config files are changed to work with AWS. Thank you Kelsey Hightower for your awesome Documentation!

This documentation was meant to help resolving google cloud specific commands in [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) to aws commands.
After i realized aws documentation needs a different ip address range ([Why?](https://github.com/kubernetes/kubernetes/blob/master/cluster/aws/options.md)) almost every config file changed and i decided to mirror the whole documentation.
This should remove error-prune comparison of both documentations.

# Kubernetes The Hard Way

This tutorial will walk you through setting up Kubernetes the hard way. This guide is not for people
looking for a fully automated command to bring up a Kubernetes cluster. If that's you then check out
[Google Container Engine](https://cloud.google.com/container-engine), or the [Getting Started
Guides](http://kubernetes.io/docs/getting-started-guides/).

This tutorial is optimized for learning, which means taking the long route to help people understand
each task required to bootstrap a Kubernetes cluster.

## Target Audience

The target audience for this tutorial is someone planning to support a production Kubernetes cluster
and wants to understand how everything fits together. After completing this tutorial I encourage you
to automate away the manual steps presented in this guide.

## Cluster Details

* Kubernetes 1.3.0
* Docker 1.11.2
* [CNI Based Networking](https://github.com/containernetworking/cni)
* Secure communication between all components (etcd, control plane, workers)
* Default Service Account and Secrets 


### What's Missing

The resulting cluster will be missing the following items:

* [Cluster add-ons](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons)
* [Logging](http://kubernetes.io/docs/user-guide/logging)
* [No Cloud Provider Integration](http://kubernetes.io/docs/getting-started-guides/)

## Labs

The following labs assume you have a working [AWS](https://aws.amazon.com/)
account and a recent version of the [AWS cli](https://aws.amazon.com/cli/) (1.10.36+)
installed. While AWS will be used for basic infrastructure needs, the things learned in this
tutorial apply to every platform.

* [Cloud Infrastructure Provisioning](docs/01-infrastructure.md)
* [Setting up a CA and TLS Cert Generation](docs/02-certificate-authority.md)
* [Bootstrapping an H/A etcd cluster](docs/03-etcd.md)
* [Bootstrapping an H/A Kubernetes Control Plane](docs/04-kubernetes-controller.md)
* [Bootstrapping Kubernetes Workers](docs/05-kubernetes-worker.md)
* [Configuring the Kubernetes Client - Remote Access](docs/06-kubectl.md)
* [Managing the Container Network Routes](docs/07-network.md)
* [Deploying the Cluster DNS Add-on](docs/08-dns-addon.md)
* [Smoke Test](docs/09-smoke-test.md)
* [Cleaning Up](docs/10-cleanup.md)
