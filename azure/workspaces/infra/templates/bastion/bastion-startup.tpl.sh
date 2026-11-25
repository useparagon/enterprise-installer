#!/bin/bash
set +e

function writeLog() {
    echo -e "\n\n$(date -Iseconds) $1\n"
}

function retry() {
    local attempts=12
    local delay=10

    until "$@"; do
        attempts=$((attempts - 1))
        if [ "$attempts" -le 0 ]; then
            return 1
        fi
        sleep "$delay"
    done
}

# Prefer the host Ubuntu suite for azure-cli when it publishes packages; otherwise fall back.
function resolve_azure_cli_dist() {
    local dist candidate
    dist=$(lsb_release -cs)
    if curl -fsSL "https://packages.microsoft.com/repos/azure-cli/dists/${dist}/main/binary-amd64/Packages" 2>/dev/null | grep -q '^Package: azure-cli$'; then
        echo "$dist"
        return 0
    fi
    for candidate in noble jammy; do
        if curl -fsSL "https://packages.microsoft.com/repos/azure-cli/dists/${candidate}/main/binary-amd64/Packages" 2>/dev/null | grep -q '^Package: azure-cli$'; then
            echo "$candidate"
            return 0
        fi
    done
    echo "$dist"
}

writeLog "paragon setup starting as $(whoami) from $0"
sudo mkdir -p /etc/apt/keyrings

# enable timestamps in shell history
export HISTTIMEFORMAT="%F %T "
if ! grep -qF 'HISTTIMEFORMAT=' /home/ubuntu/.bashrc 2>/dev/null; then
    echo 'export HISTTIMEFORMAT="%F %T "' >> /home/ubuntu/.bashrc
fi

# unattended support
export DEBIAN_FRONTEND=noninteractive
sudo systemctl stop unattended-upgrades || true

# install misc tools
writeLog "installing misc tools"
sudo apt-get update -y
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    jq \
    lsb-release \
    make \
    redis-tools \
    unzip

# install cloudflare zero trust and register tunnel
# see https://blog.cloudflare.com/automating-cloudflare-tunnel-with-terraform/
if [[ -n "${tunnel_id}" ]]; then
    writeLog "installing cloudflare tunnel"
    curl -fsSL --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb

    sudo mkdir -p /etc/cloudflared
    sudo tee /etc/cloudflared/cert.json > /dev/null << EOF
{
    "AccountTag"   : "${account_id}",
    "TunnelID"     : "${tunnel_id}",
    "TunnelName"   : "${tunnel_name}",
    "TunnelSecret" : "${tunnel_secret}"
}
EOF
    sudo chmod 600 /etc/cloudflared/cert.json

    sudo tee /etc/cloudflared/config.yml > /dev/null << EOF
tunnel: ${tunnel_id}
credentials-file: /etc/cloudflared/cert.json
logfile: /var/log/cloudflared.log
loglevel: info

ingress:
  - hostname: ${tunnel_name}
    service: ssh://localhost:22
  - service: http_status:404
EOF

    sudo cloudflared service install
    sudo systemctl start cloudflared
else
    writeLog "skipped cloudflare tunnel"
fi

# install azure cli
writeLog "installing azure cli"
AZ_DIST=$(resolve_azure_cli_dist)
writeLog "using azure-cli apt suite: $AZ_DIST"
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ ${AZ_DIST} main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-get update -y
sudo apt-get install -y azure-cli
az version

# install kubectl
KUBECTL_MINOR=${cluster_version}
writeLog "installing kubectl $KUBECTL_MINOR"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$KUBECTL_MINOR/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v$KUBECTL_MINOR/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
sudo apt-get install -y kubectl
kubectl version --client

# install helm
writeLog "installing helm"
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | sudo gpg --dearmor -o /etc/apt/keyrings/helm.gpg
echo "deb [signed-by=/etc/apt/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update -y
sudo apt-get install -y helm

# install nodejs
NODE_MAJOR=24
writeLog "installing node $NODE_MAJOR"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt-get update -y
sudo apt-get install -y nodejs
node --version

# Create and configure aliases file
writeLog "configuring aliases for ubuntu"
cat > /home/ubuntu/.bash_aliases << 'EOF'
# Kubernetes aliases
alias k=kubectl
alias kd="kubectl describe"
alias kev="kubectl get events --sort-by='.lastTimestamp'"
alias kex="kubectl exec -it"
alias kg="kubectl get"
alias kl="kubectl logs"
alias krr="kubectl get deployments --no-headers -o custom-columns=\":metadata.name\" | xargs -I {} kubectl rollout restart deployment/{}"
alias kw="watch kubectl get pods"
alias kwf="watch -- 'kubectl get pods | grep -v fluent | grep -v node-exporter'"
alias kwn='watch -- "kubectl get pods | grep -v '\'' Running * 0'\''"'

kls() {
  local name=$1
  if [ -z "$name" ]; then
    echo "Usage: kls <service-name>"
    return 1
  fi
  shift
  kubectl logs -n paragon -l app.kubernetes.io/name="$name" --all-containers=true --prefix=true "$@"
}

ksec() {
  local name=$${1:-paragon-secrets}
  kubectl get secret $name -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key): \(.value | @base64d)"' | sort
}

# Common aliases
alias ll="ls -Ahl"
alias hi="history | grep"
EOF

# Ensure proper permissions
chown ubuntu:ubuntu /home/ubuntu/.bash_aliases
chmod 644 /home/ubuntu/.bash_aliases

# configure az, aks and kubectl
writeLog "configuring k8s tools as ubuntu"
# The bastion identity is only assigned on the cluster, so the subscription is not
# guaranteed to be listed for it and az login would otherwise fail outright.
if ! retry sudo -u ubuntu az login --identity --client-id ${managed_identity_client_id} --allow-no-subscriptions; then
    writeLog "managed identity login failed after retries"
    exit 1
fi
if sudo -u ubuntu az account set --subscription ${subscription_id}; then
    if ! retry sudo -u ubuntu az aks get-credentials --admin --overwrite-existing --resource-group ${resource_group} --name ${cluster_name}; then
        writeLog "retrieving AKS admin credentials failed after retries"
        exit 1
    fi
else
    writeLog "no subscription context for the bastion identity, reading the admin kubeconfig from the cluster resource"
    sudo -u ubuntu mkdir -p /home/ubuntu/.kube
    if ! retry sudo -u ubuntu bash -c 'set -o pipefail; az rest --method post --url "https://management.azure.com/subscriptions/${subscription_id}/resourceGroups/${resource_group}/providers/Microsoft.ContainerService/managedClusters/${cluster_name}/listClusterAdminCredential?api-version=2024-05-01" --query "kubeconfigs[0].value" --output tsv | base64 -d > /home/ubuntu/.kube/config'; then
        writeLog "retrieving AKS admin credentials failed after retries"
        exit 1
    fi
    sudo -u ubuntu chmod 600 /home/ubuntu/.kube/config
fi
if ! sudo -u ubuntu kubectl config set-context --current --namespace=paragon; then
    writeLog "configuring the kubectl namespace failed"
    exit 1
fi

writeLog "paragon setup complete"
