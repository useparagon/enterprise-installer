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
        writeLog "retrying after $${delay}s ($${attempts} left): $*"
        sleep "$delay"
    done
}

function wait_for_apt() {
    local attempts=30
    local delay=10

    while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
        || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 \
        || sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
        attempts=$((attempts - 1))
        if [ "$attempts" -le 0 ]; then
            writeLog "ERROR: timed out waiting for apt/dpkg locks"
            return 1
        fi
        writeLog "waiting for apt/dpkg lock ($${attempts} left)"
        sleep "$delay"
    done
}

# Ubuntu's packaged origins also include the main archive, and a second Allowed-Origins
# block is merged rather than replaced. Move that file out of apt.conf.d so only the
# security origins below apply. dpkg-divert keeps later package upgrades from putting
# it back or prompting on the conffile (GCP re-runs this script).
function use_security_only_origins() {
    local packaged=/etc/apt/apt.conf.d/50unattended-upgrades
    local diverted=/usr/share/unattended-upgrades/50unattended-upgrades.paragon-orig

    if ! sudo dpkg-divert --list "$packaged" | grep -q "$packaged"; then
        sudo mkdir -p /usr/share/unattended-upgrades
        sudo dpkg-divert --local --rename --divert "$diverted" --add "$packaged"
    fi

    sudo tee /etc/apt/apt.conf.d/51paragon-security-origins > /dev/null <<'EOF'
// Paragon bastion: security-only unattended upgrades (PARA-28392)
Unattended-Upgrade::Allowed-Origins {
        "$${distro_id}:$${distro_codename}-security";
        "$${distro_id}ESMApps:$${distro_codename}-apps-security";
        "$${distro_id}ESM:$${distro_codename}-infra-security";
};
Unattended-Upgrade::Automatic-Reboot "false";
EOF
}

function apply_security_updates() {
    writeLog "applying Ubuntu security updates (unattended-upgrades)"

    if ! wait_for_apt; then
        writeLog "ERROR: apt/dpkg locks blocked security updates"
        exit 1
    fi
    if ! retry sudo apt-get update -y; then
        writeLog "ERROR: apt-get update failed before security updates"
        exit 1
    fi
    if ! retry sudo apt-get install -y unattended-upgrades; then
        writeLog "ERROR: failed to install unattended-upgrades"
        exit 1
    fi

    use_security_only_origins
    if ! retry sudo unattended-upgrade --verbose; then
        writeLog "ERROR: unattended-upgrade failed"
        exit 1
    fi

    sudo tail -n 40 /var/log/unattended-upgrades/unattended-upgrades.log 2>/dev/null || true
    if [ -f /var/run/reboot-required ]; then
        writeLog "WARNING: reboot required after security updates (not rebooting during bootstrap)"
        sudo cat /var/run/reboot-required.pkgs 2>/dev/null || true
    else
        writeLog "no reboot required after security updates"
    fi
}

writeLog "paragon setup starting as $(whoami) from $0"
sudo mkdir -p /etc/apt/keyrings

# enable timestamps in shell history
export HISTTIMEFORMAT="%F %T "
echo 'export HISTTIMEFORMAT="%F %T "' >> /home/ubuntu/.bashrc

# Hold apt timers for the whole bootstrap so they cannot take the dpkg lock between
# installs. Stop only; timers are started again on exit and are not disabled.
export DEBIAN_FRONTEND=noninteractive
trap 'sudo systemctl start apt-daily.timer apt-daily-upgrade.timer >/dev/null 2>&1 || true' EXIT
sudo systemctl stop apt-daily.timer apt-daily-upgrade.timer \
    unattended-upgrades.service apt-daily.service apt-daily-upgrade.service 2>/dev/null || true

apply_security_updates

# install misc tools
writeLog "installing misc tools"
sudo apt-get update -y
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    jq \
    make \
    redis-tools \
    unzip

# install cloudflare zero trust and register tunnel
# see https://blog.cloudflare.com/automating-cloudflare-tunnel-with-terraform/
if [[ ! -z "${tunnel_id}" ]]; then
    writeLog "installing cloudflare tunnel"
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb

    sudo mkdir -p /etc/cloudflared

    cat > /etc/cloudflared/cert.json << EOF
{
    "AccountTag"   : "${account_id}",
    "TunnelID"     : "${tunnel_id}",
    "TunnelName"   : "${tunnel_name}",
    "TunnelSecret" : "${tunnel_secret}"
}
EOF

    sudo cat > /etc/cloudflared/config.yml << EOF
tunnel: ${tunnel_id}
credentials-file: /etc/cloudflared/cert.json
logfile: /var/log/cloudflared.log
loglevel: info

ingress:
  - hostname: ${tunnel_name}
    service: ssh://localhost:22
  - hostname: "*"
    service: hello-world
EOF

    sudo cloudflared service install
    sudo systemctl start cloudflared
else
    writeLog "skipped cloudflare tunnel"
fi

# install aws cli v2
writeLog "installing aws cli v2"
sudo apt-get remove -y awscli
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install
aws --version

# install kubectl
KUBECTL_MINOR=${cluster_version}
writeLog "installing kubectl $KUBECTL_MINOR"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$KUBECTL_MINOR/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v$KUBECTL_MINOR/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
sudo apt-get install -y kubectl

# install eksctl
writeLog "installing eksctl"
curl -fsSL "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version

# install helm
writeLog "installing helm"
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | sudo gpg --dearmor -o /etc/apt/keyrings/helm.gpg
echo "deb [signed-by=/etc/apt/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update -y
sudo apt-get install -y helm

# install nodejs
NODE_MAJOR=18
writeLog "installing node $NODE_MAJOR"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt-get update -y
sudo apt-get install -y nodejs
sudo npm install -g npx

# configure aws, eksctl and kubectl
# note that cluster may be still CREATING so wait up to 5 min for that to complete
writeLog "configuring k8s tools as root"
aws configure set region ${aws_region}
max_loops=10
current_loop=0
while [ $current_loop -lt $max_loops ]; do
    # aws eks --region ${aws_region} update-kubeconfig --name ${cluster_name}
    output=$(aws eks --region ${aws_region} update-kubeconfig --name ${cluster_name} 2>&1)
    if [[ ! $output =~ "CREATING" ]]; then
        break
    fi
    echo "Cluster still creating. Waiting for 30s."
    sleep 30
    ((current_loop++))
done
$(eksctl get iamidentitymapping --cluster ${cluster_name} --arn arn:aws:iam::${aws_account_id}:role/${bastion_role} || eksctl create iamidentitymapping --cluster ${cluster_name} --arn arn:aws:iam::${aws_account_id}:role/${bastion_role} --group system:masters --username ${bastion_role})
kubectl config set-context --current --namespace=paragon

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

writeLog "configuring k8s tools as ubuntu"
sudo -u ubuntu aws configure set region ${aws_region}
sudo -u ubuntu aws eks --region ${aws_region} update-kubeconfig --name ${cluster_name}
sudo -u ubuntu kubectl config set-context --current --namespace=paragon

writeLog "paragon setup complete"
