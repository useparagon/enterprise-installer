<p style="text-align:center"><a href="https://www.useparagon.com/" target="blank"><img src="./assets/paragon-logo-dark.png" width="320" alt="Paragon Logo" /></a></p>

<p style="text-align:center"><b>The embedded integration platform for developers.</b></p>

# Paragon Enterprise

## Overview

This repository is a set of tools to help you run Paragon on your own cloud infrastructure. This Paragon installation comes bundled as a set of [Helm](https://helm.sh/) [charts](./charts/) and [Terraform](https://www.terraform.io/) configs and supports deployment to [Kubernetes](https://kubernetes.io/) running in AWS, GCP or Azure. The use of the Terraform workspaces is required and is the only supported method for deploying the infrastructure and application.

Each of the cloud deployments is split into two Terraform workspaces (`infra` and `paragon`). The `infra` workspace provides the infrastructure that is required to run the Paragon service. This includes provisioning the network, Postgresql databases, Kubernetes cluster, Redis clusters, etc. The `paragon` workspace configures and deploys the Helm resources to Kubernetes cluster created by the `infra` workspace.

See the README files in each of the relevant workspace folders for more details.

## Disclaimers

### Modification strongly discouraged.

We're constantly deploying new versions of Paragon's code and infrastructure which often include additional microservices, updates to infrastructure, improved security and more. To ensure new releases of Paragon are compatible with your infrastructure, modifying this repo is strongly discouraged to ensure compatibility with future Helm charts and versions of the repo. Modified Terraform or Helm charts may not be supported.

Instead of making changes, either:

- send a request to our engineering team to modify the repo (preferred)
- open a pull request with your changes

### ⭐️ We offer managed enterprise solutions. ⭐️

If you want to deploy Paragon to your own cloud but don't want to manage the infrastructure, we'll do it for you. Most of our enterprise customers use this solution. Benefits include:

- automatic Paragon and infrastructure upgrades as needed
- continuous monitoring of infrastructure
- cost optimizations on resources

We offer managed enterprise solutions for AWS, Azure and GCP. Please contact **[sales@useparagon.com](mailto:sales@useparagon.com)**, and we'll get you started.

## Getting Started

### Prerequisites

There are a few prerequisites that are required to be able to fully deploy Paragon:

- a Paragon license key
- a domain name that the Paragon microservices can be reached at (e.g. `paragon.example.com`)
- access to add DNS records for the domain name above
- an SMTP provider such as [SendGrid](https://sendgrid.com/)
- a [Docker account](https://www.docker.com/) that has been given read access to our private repositories
- admin credentials for your Cloud Service Provider for provisioning resources

If you don't already have a license, please contact **[sales@useparagon.com](mailto:sales@useparagon.com)**, and we'll get you connected.

The local machine that is being used to perform the setup will also require the following software to be installed:

- [Git](https://github.com/git-guides/install-git)
- [Terraform](https://developer.hashicorp.com/terraform/downloads)

### File Prep

Because the Helm charts are cloud provider agnostic they are stored centrally in the [charts](./charts/) folder. Because Terraform supports so many different ways of storing state (local files, remote buckets, Terraform Cloud, etc.) this repo does not declare a `backend` block in the `main.tf` files. We instead provide `main.tf.example` files that will be copied to `main.tf` if not already present. This allows you to customize the `main.tf` files to meet your specific requirements without it being overridden with changes in the repo. To make the management of all of these files easier we provide a bash script that will make all of the necessary file copies. It will also update the Helm chart versions with a hash of the files to ensure that any changes to the chart files will trigger an update. It should be rerun whenever changes have been made to the charts. The [prepare.sh](./prepare.sh) is run by passing in the cloud provider name like:

```bash
./prepare.sh -p <aws|gcp|azure> -t <VERSION>
```

### Configuration After Prepare

After running `prepare.sh`, you need to configure the following files before running Terraform:

1. **`{provider}/workspaces/infra/vars.auto.tfvars`** - Infrastructure variables (AWS credentials, organization, region, and optional sizing/config). See `{provider}/workspaces/infra/variables.tf` for all available variables.

2. **`{provider}/workspaces/paragon/vars.auto.tfvars`** - Paragon deployment variables (AWS credentials, organization, domain, Docker credentials). See `{provider}/workspaces/paragon/variables.tf` for all available variables.

3. **`{provider}/workspaces/paragon/.secure/values.yaml`** - Helm values containing Paragon application configuration and secrets (VERSION, LICENSE, and all environment variables). This file is created from `charts/values.placeholder.yaml` - see that file for the complete list of configurable values.

### Private container registry (Artifactory / proxy)

To pull images through a customer-provided registry (e.g. Artifactory) instead of public upstreams, configure `global` settings in `.secure/values.yaml`:

```yaml
global:
  imageRegistry: artifactory.example.com/paragon
  imageRepositoryPrefix: ""   # omit key entirely to keep useparagon/ in paths
  imagePullSecrets:
    - name: workday-af-secret
```

- **`imageRegistry`** — prepended to image repository paths (host and optional remote-repo path).
- **`imageRepositoryPrefix`** — when set (including `""`), rewrites the default `useparagon/` prefix. Omit to preserve `useparagon/` in mirrored paths.
- **`imagePullSecrets`** — merged with per-chart pull secrets on all workloads, jobs, and hooks.
- **`testImage`** / **`kubectlImage`** — override busybox (helm tests) and alpine/kubectl (restart cron) defaults.

Per-subchart `image.repository` overrides remain available for third-party images with non-standard mirror paths.

**Terraform pull credentials** (in `vars.auto.tfvars`):

```hcl
docker_registry_server    = "artifactory.example.com"  # must match imageRegistry host
docker_pull_secret_name   = "docker-cfg"               # or customer secret name
create_docker_pull_secret = true                       # false if secret is pre-provisioned
# When create_docker_pull_secret = false, omit docker_username / docker_password /
# docker_email; Terraform will not create or sync a registry pull secret. Point
# global.imagePullSecrets at the pre-provisioned secret name instead.
```

Verify rendered images with `helm template` and grep for unexpected upstream hosts (`docker.io`, `ghcr.io`, `public.ecr.aws`, etc.).

## Usage

### Infrastructure Provisioning

Once the Helm charts and Terraform files have been prepared as above then standard Terraform commands can be used within the `<provider>/workspace/infra` directory to provision the necessary resources. See the `infra` README for your cloud provider more details and any required variables.

```
terraform init
terraform validate
terraform plan
terraform apply
```

After the infrastructure has been provisioned there is no longer a manual secret-export step between the `infra` and `paragon` workspaces. The `infra` workspace writes generated infrastructure secrets directly to the cloud provider secret manager, and the `paragon` workspace reads them from there when it assembles chart configuration.

The only local secret material that still needs to be prepared for the `paragon` workspace is `.secure/values.yaml`, which holds the Paragon application/runtime values that are not generated by the infrastructure workspace.

### Paragon Deployment

Once the infrastructure has been setup then standard Terraform commands can be used within the `<provider>/workspace/paragon` directory to provision the necessary resources. See the `paragon` README for your cloud provider more details and any required variables.

```
terraform init
terraform validate
terraform plan
terraform apply
```

### Paragon Update

To upgrade to a newer Paragon release version:

1. **Run `prepare.sh`** to update charts:
   ```bash
   ./prepare.sh -p <aws|gcp|azure> -t <VERSION>
   ```

2. **Update `VERSION`** in `{provider}/workspaces/paragon/.secure/values.yaml`:
   ```yaml
   global:
     env:
       VERSION: "2025.0903.0729-7d7d9767"  # New version
   ```

3. **Review and apply changes**:
   ```bash
   # Check if infrastructure changes are needed
   cd {provider}/workspaces/infra
   terraform plan
   terraform apply  # If changes are detected
   
   # Update Paragon deployment
   cd ../paragon
   terraform plan
   terraform apply
   ```

This will pull new Docker images and perform a rolling update of all services. Some upgrades may require infrastructure changes (e.g., database migrations, new resources), so review both workspaces before applying.

**Note**: If you encounter errors about resource names exceeding AWS limits (e.g., "name cannot be longer than 32 characters"), use the `migrated_workspace` variable in `{provider}/workspaces/infra/vars.auto.tfvars` to set a shorter workspace name. The default workspace name format `paragon-${organization}-${hash}` can be too long for some AWS resources.
