echo -e "\n172.20.0.10 etcd0\n172.20.0.11 etcd1\n172.20.0.12 etcd2\n172.20.0.20 controller0\n172.20.0.21 controller1\n172.20.0.22 controller2\n172.20.0.30 worker0\n172.20.0.31 worker1\n172.20.0.32 worker2" >> /etc/hosts
grep `curl -s http://169.254.169.254/latest/meta-data/local-ipv4` /etc/hosts |cut -d ' ' -f 2 > /etc/hostname
hostname `grep $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) /etc/hosts |cut -d ' ' -f 2`
