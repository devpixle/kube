#!bin/bash
sudo swapoff -a
#sudo vi /etc/fstab
sudo sed -i '/ swap / s/^/#/' /etc/fstab
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
sudo cat /proc/sys/net/bridge/bridge-nf-call-iptables
sudo cat /proc/sys/net/bridge/bridge-nf-call-ip6tables
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
# Note that this step was already executed, we’re additionally enabling here IP forwarding
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system
# Install required packages
sudo yum -y install yum-utils device-mapper-persistent-data lvm2

# Add the Docker repository
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Update currently installed packages
sudo yum -y update

# Install containerd
sudo yum -y install containerd.io

# Start containerd automatically at boot
sudo systemctl enable containerd
# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Restart containerd
sudo systemctl restart containerd

yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
mkdir /etc/docker
mkdir -p /etc/systemd/system/docker.service.d
yum install -y docker-ce
systemctl daemon-reload
systemctl restart docker
systemctl enable docker.service
systemctl start docker


# Add the kubernetes repository to the CentOS system:
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

# Set SELinux in permissive mode (effectively disabling it)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Install the kubernetes packages kubelet, kubeadm and kubectl (v1.22.17)
sudo yum install -y kubelet-1.22.17 kubeadm-1.22.17 kubectl-1.22.17 --disableexcludes=kubernetes

# Start kubelet process
sudo systemctl enable --now kubelet

kubeadm init  --cri-socket=/run/containerd/containerd.sock
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
#kubectl apply -f https://github.com/ChaitaliP2001/Installations/blob/main/Weavenet.yaml

#kubectl taint nodes localhost  node-role.kubernetes.io/control-plane:NoSchedule-
#kubectl taint nodes localhost  node-role.kubernetes.io/master:NoSchedule-

