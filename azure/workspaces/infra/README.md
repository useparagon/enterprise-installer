# Paragon Azure Infrastructure

## Azure credentials

**Terraform** (this workspace or a parent stack) can authenticate with optional variables `azure_client_id`, `azure_client_secret`, `azure_tenant_id` when this repo is the root, or with `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID` / Azure CLI when those are omitted. When this path is used as a **child module**, the parent stack owns provider auth and typically passes only `azure_subscription_id`.

**Bastion VMs** do not use that principal. The bastion **always** uses its **VMSS system-assigned managed identity** (`az login --identity` in cloud-init); Terraform grants that identity `Azure Kubernetes Service Cluster Admin Role` on the AKS cluster. This is independent of whether Terraform runs as a service principal or OIDC.

To update credentials when the **Terraform** app registration secret expires:

1. In **Azure Portal** go to **Microsoft Entra ID** → **App registrations** → select the app (use the client ID to find it).
2. Open **Certificates & secrets** → **New client secret** → add a description and expiry → **Add**.
3. Copy the new secret **Value** (it is shown only once).
4. Update your tfvars or environment:
   - In `vars.auto.tfvars`: set `azure_client_secret` to the new value.
   - Or set `ARM_CLIENT_SECRET` in your environment (e.g. in CI or a `.env` that is not committed).

Do not commit real secrets to git. Prefer environment variables or a secret manager for `azure_client_secret` / `ARM_CLIENT_SECRET`.

## Redis: legacy vs Azure Managed Redis

Branch: `fix/PARA-21251/managed-sync-redis` ([PARA-21251](https://useparagon.atlassian.net/browse/PARA-21251)).

Two optional backends can run independently or **in parallel** during customer migration:

| Variable | Default | Backend | Redis version |
|----------|---------|---------|---------------|
| `redis_enabled` | `true` | `./redis` (`azurerm_redis_cache`) | 6 |
| `redis_managed_enabled` | `false` | `./redis-managed` (`azurerm_managed_redis`) | 7.4 (service default) |

At least one must be `true`. Existing customers keep defaults (`redis_enabled = true`, `redis_managed_enabled = false`) for a no-op plan on Redis.

### Outputs during migration

| Output | When | Contents |
|--------|------|----------|
| `redis` | `redis_enabled = true` (even if managed is also enabled) | Legacy BSP endpoints — **unchanged contract for paragon** |
| `redis` | `redis_enabled = false`, `redis_managed_enabled = true` | Managed Redis endpoints (post-cutover) |
| `redis_managed` | `redis_managed_enabled = true` | Managed Redis endpoints for trial `kubectl` patching |

### Customer migration tfvars sequence

1. **Baseline:** `redis_enabled = true`, `redis_managed_enabled = false`
2. **Parallel deploy:** `redis_enabled = true`, `redis_managed_enabled = true` → apply creates Managed Redis; legacy keeps running; use `terraform output -json redis_managed` for new endpoints
3. **After validation:** `redis_enabled = false`, `redis_managed_enabled = true` → apply destroys legacy; `output redis` switches to managed

### Azure Managed Redis tuning (all regions)

SKUs are **not** legacy `Premium` / `Standard`. Use Managed Redis names such as `Balanced_B10`, `MemoryOptimized_M50`, or `ComputeOptimized_X10`.

One map drives every instance (`for_each` in `./redis-managed`). Globals stay fixed unless you need to change them:

| Variable | Default | Purpose |
|----------|---------|---------|
| `redis_managed_instances_default` | (in `variables.tf` locals) | Per-instance `sku`, `ha_enabled`, `cluster_enabled` |
| `redis_managed_instances` | `null` | Per-key overrides merged into defaults |
| `redis_managed_export_storage_enabled` | `false` | Blob storage + RBAC for on-demand RDB export |
| `redis_managed_export_storage_replication_type` | `LRS` | Replication for export storage account |
| `redis_managed_clustering_policy` | `OSSCluster` | Used when `cluster_enabled = true` |
| `redis_managed_public_network_access` | `Disabled` | Network access |

`redis_multiple_instances` and `managed_sync_enabled` still filter which keys deploy (same as legacy redis).

Built-in default map (used when `redis_managed_instances` is null):

```hcl
cache        = { sku = "Balanced_B10", ha_enabled = true,  cluster_enabled = true }
queue        = { sku = "Balanced_B3",  ha_enabled = true,  cluster_enabled = false }
system       = { sku = "Balanced_B3",  ha_enabled = true,  cluster_enabled = false }
managed-sync = { sku = "Balanced_B10", ha_enabled = true,  cluster_enabled = false }
```

`managed-sync` uses `cluster_enabled = false` (NoCluster policy). Bull/ioredis over a private endpoint cannot use OSS cluster slot discovery (internal shard addresses such as `10.0.16.x:8501` are not reachable with TLS), and a non-cluster client against OSSCluster receives `MOVED` redirects. Use NoCluster for the dedicated managed-sync instance; keep OSSCluster on `cache` when the monorepo client supports it.

Greenfield example:

```hcl
redis_enabled         = false
redis_managed_enabled = true
```

Per-region override example (merged into defaults per key):

```hcl
redis_managed_instances = {
  cache = { sku = "MemoryOptimized_M50" }
  queue = { sku = "MemoryOptimized_M10", ha_enabled = false }
}
```

Development example (disable HA on all instances via overrides):

```hcl
redis_managed_instances = {
  cache  = { ha_enabled = false }
  queue  = { ha_enabled = false }
  system = { ha_enabled = false }
}
```

### Data persistence (RDB / AOF)

Per-instance, merged like other fields. Requires `ha_enabled = true`. Cannot be used with geo-replication.

| `persistence_mode` | `persistence_frequency` | Meaning |
|--------------------|-------------------------|---------|
| `null` (default) | — | No persistence |
| `"rdb"` | `1h`, `6h`, or `12h` (default `1h`) | Snapshots on managed disk (included in SKU) |
| `"aof"` | `1s` (only value) | Append-only log on managed disk |

Example:

```hcl
redis_managed_instances = {
  cache = { persistence_mode = "rdb", persistence_frequency = "1h" }
  queue = { persistence_mode = "aof" }
}
```

### RDB export to Storage (backup copies)

Export is an on-demand Azure operation (CLI/portal), not continuous like legacy Premium RDB-to-storage. Terraform can provision the target storage account:

```hcl
redis_managed_export_storage_enabled = true
```

After apply, use `terraform output redis_managed_export_storage` and run export per [Import and export](https://learn.microsoft.com/azure/redis/how-to-import-export-data). Each instance gets a system-assigned identity with **Storage Blob Data Contributor** on that account.

Confirm SKU availability in the target region before apply.

Requires `azurerm` provider `>= 4.60` in `main.tf` (see `main.tf.example`).

## AKS network profile

The `k8s_*` network variables configure the AKS `network_profile`. Defaults are optimized for greenfield deployments:

| Variable | Default |
| -------- | ------- |
| `k8s_network_plugin` | `azure` |
| `k8s_network_plugin_mode` | `overlay` |
| `k8s_pod_cidr` | `192.168.0.0/16` |
| `k8s_service_cidr` | `172.16.0.0/16` |
| `k8s_dns_service_ip` | `172.16.0.10` |
| `k8s_outbound_type` | `userAssignedNATGateway` |
| `k8s_load_balancer_sku` | `standard` |

All CIDR defaults are RFC 1918 private. `k8s_service_cidr` and `k8s_dns_service_ip` are **immutable after cluster creation** — override them before the first apply if they overlap the customer's address space.

### Legacy deployments

The existing Azure deployments that use node-subnet CNI and the non-private `172.0.0.0/16` service range. Pin these in tfvars:

```hcl
k8s_network_plugin_mode = null
k8s_pod_cidr            = null
k8s_service_cidr        = "172.0.0.0/16"
k8s_dns_service_ip      = "172.0.0.10"
```

Optional staged migrations for legacy clusters (each step is one-way where noted):

1. **NAT Gateway outbound**: remove any `k8s_outbound_type = "loadBalancer"` override and apply — creates the NAT Gateway and switches outbound SNAT.
2. **Azure CNI Overlay** (irreversible): drop the `k8s_network_plugin_mode` and `k8s_pod_cidr` overrides above and apply with the new defaults (or set them explicitly). Pods stop consuming VNet subnet IPs.
3. **Service CIDR / DNS IP**: cannot be changed in-place; requires a new cluster.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 3.0.2 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 4.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.9 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.58.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_bastion"></a> [bastion](#module\_bastion) | ./bastion | n/a |
| <a name="module_cluster"></a> [cluster](#module\_cluster) | ./cluster | n/a |
| <a name="module_kafka"></a> [kafka](#module\_kafka) | ./kafka | n/a |
| <a name="module_network"></a> [network](#module\_network) | ./network | n/a |
| <a name="module_postgres"></a> [postgres](#module\_postgres) | ./postgres | n/a |
| <a name="module_redis"></a> [redis](#module\_redis) | ./redis | n/a |
| <a name="module_redis_managed"></a> [redis\_managed](#module\_redis\_managed) | ./redis-managed | n/a |
| <a name="module_storage"></a> [storage](#module\_storage) | ./storage | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_key_vault.paragon](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_key_vault_access_policy.terraform](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_access_policy) | resource |
| [azurerm_key_vault_secret.runtime_kafka](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_key_vault_secret.runtime_postgres](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_key_vault_secret.runtime_redis](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_key_vault_secret.runtime_storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_auditlogs_lock_enabled"></a> [auditlogs\_lock\_enabled](#input\_auditlogs\_lock\_enabled) | Whether to lock the audit logs container immutability policy. | `bool` | `false` | no |
| <a name="input_auditlogs_retention_days"></a> [auditlogs\_retention\_days](#input\_auditlogs\_retention\_days) | The number of days to retain audit logs before deletion. | `number` | `365` | no |
| <a name="input_azure_client_id"></a> [azure\_client\_id](#input\_azure\_client\_id) | Azure AD application (client) ID for provider auth. Optional if using ARM\_CLIENT\_ID / CLI. | `string` | `null` | no |
| <a name="input_azure_client_secret"></a> [azure\_client\_secret](#input\_azure\_client\_secret) | Azure AD client secret for provider auth. Optional if using ARM\_CLIENT\_SECRET / CLI. | `string` | `null` | no |
| <a name="input_azure_subscription_id"></a> [azure\_subscription\_id](#input\_azure\_subscription\_id) | Azure subscription ID | `string` | n/a | yes |
| <a name="input_azure_tenant_id"></a> [azure\_tenant\_id](#input\_azure\_tenant\_id) | Azure AD tenant ID for provider auth. Optional if using ARM\_TENANT\_ID / CLI. | `string` | `null` | no |
| <a name="input_bastion_vm_size"></a> [bastion\_vm\_size](#input\_bastion\_vm\_size) | VM size for the bastion scale set (e.g. Standard\_B1s). Must be available in the target region. | `string` | `"Standard_B1s"` | no |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token created at https://dash.cloudflare.com/profile/api-tokens. Requires Edit permissions on Account `Cloudflare Tunnel`, `Access: Organizations, Identity Providers, and Groups`, `Access: Apps and Policies` and Zone `DNS` | `string` | `"dummy-cloudflare-tokens-must-be-40-chars"` | no |
| <a name="input_cloudflare_tunnel_account_id"></a> [cloudflare\_tunnel\_account\_id](#input\_cloudflare\_tunnel\_account\_id) | Account ID for Cloudflare account | `string` | `""` | no |
| <a name="input_cloudflare_tunnel_email_domain"></a> [cloudflare\_tunnel\_email\_domain](#input\_cloudflare\_tunnel\_email\_domain) | Email domain for Cloudflare access | `string` | `"useparagon.com"` | no |
| <a name="input_cloudflare_tunnel_enabled"></a> [cloudflare\_tunnel\_enabled](#input\_cloudflare\_tunnel\_enabled) | Flag whether to enable Cloudflare Zero Trust tunnel for bastion | `bool` | `false` | no |
| <a name="input_cloudflare_tunnel_subdomain"></a> [cloudflare\_tunnel\_subdomain](#input\_cloudflare\_tunnel\_subdomain) | Subdomain under the Cloudflare Zone to create the tunnel | `string` | `""` | no |
| <a name="input_cloudflare_tunnel_zone_id"></a> [cloudflare\_tunnel\_zone\_id](#input\_cloudflare\_tunnel\_zone\_id) | Zone ID for Cloudflare domain | `string` | `""` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Type of environment being deployed to. | `string` | `"enterprise"` | no |
| <a name="input_eventhub_auto_inflate_enabled"></a> [eventhub\_auto\_inflate\_enabled](#input\_eventhub\_auto\_inflate\_enabled) | Whether to enable auto-inflate for the Event Hubs namespace. | `bool` | `true` | no |
| <a name="input_eventhub_capacity"></a> [eventhub\_capacity](#input\_eventhub\_capacity) | The capacity units for the Event Hubs namespace (1-20 for Standard, 1-8 for Premium). | `number` | `1` | no |
| <a name="input_eventhub_maximum_throughput_units"></a> [eventhub\_maximum\_throughput\_units](#input\_eventhub\_maximum\_throughput\_units) | The maximum throughput units for auto-inflate (only applicable when auto\_inflate\_enabled is true). | `number` | `20` | no |
| <a name="input_eventhub_namespace_sku"></a> [eventhub\_namespace\_sku](#input\_eventhub\_namespace\_sku) | The SKU name for the Event Hubs namespace (Basic, Standard, Premium). | `string` | `"Standard"` | no |
| <a name="input_k8s_default_node_pool_vm_size"></a> [k8s\_default\_node\_pool\_vm\_size](#input\_k8s\_default\_node\_pool\_vm\_size) | VM size for the AKS default (system) node pool. Must be available in the target region (e.g. Standard\_B2s\_v2 in japaneast). | `string` | `"Standard_B2s"` | no |
| <a name="input_k8s_dns_service_ip"></a> [k8s\_dns\_service\_ip](#input\_k8s\_dns\_service\_ip) | IP address within k8s\_service\_cidr for the cluster DNS service. Immutable after cluster creation. | `string` | `"172.16.0.10"` | no |
| <a name="input_k8s_load_balancer_sku"></a> [k8s\_load\_balancer\_sku](#input\_k8s\_load\_balancer\_sku) | SKU for the AKS load balancer. | `string` | `"standard"` | no |
| <a name="input_k8s_max_node_count"></a> [k8s\_max\_node\_count](#input\_k8s\_max\_node\_count) | Maximum number of node Kubernetes can scale up to. | `number` | `50` | no |
| <a name="input_k8s_min_node_count"></a> [k8s\_min\_node\_count](#input\_k8s\_min\_node\_count) | Minimum number of node Kubernetes can scale down to. | `number` | `3` | no |
| <a name="input_k8s_network_plugin"></a> [k8s\_network\_plugin](#input\_k8s\_network\_plugin) | AKS network plugin. Use `azure` (recommended) or legacy `kubenet`. | `string` | `"azure"` | no |
| <a name="input_k8s_network_plugin_mode"></a> [k8s\_network\_plugin\_mode](#input\_k8s\_network\_plugin\_mode) | Azure CNI mode. `overlay` assigns pod IPs from k8s\_pod\_cidr (default, IP-efficient). Set to null for legacy node-subnet mode (pod IPs from the VNet). | `string` | `"overlay"` | no |
| <a name="input_k8s_network_policy"></a> [k8s\_network\_policy](#input\_k8s\_network\_policy) | Network policy engine. Leave null to disable, or set to `azure`, `calico`, or `cilium`. | `string` | `null` | no |
| <a name="input_k8s_ondemand_node_instance_type"></a> [k8s\_ondemand\_node\_instance\_type](#input\_k8s\_ondemand\_node\_instance\_type) | The compute instance type to use for Kubernetes on demand nodes. | `string` | `"Standard_B2ms"` | no |
| <a name="input_k8s_outbound_type"></a> [k8s\_outbound\_type](#input\_k8s\_outbound\_type) | AKS outbound connectivity type. Use `userAssignedNATGateway` when the private subnet has a NAT Gateway (recommended). | `string` | `"userAssignedNATGateway"` | no |
| <a name="input_k8s_pod_cidr"></a> [k8s\_pod\_cidr](#input\_k8s\_pod\_cidr) | Pod overlay CIDR (RFC 1918 private). Used when k8s\_network\_plugin\_mode is `overlay` or k8s\_network\_plugin is `kubenet`. Must not overlap vpc\_cidr or k8s\_service\_cidr. | `string` | `"192.168.0.0/16"` | no |
| <a name="input_k8s_service_cidr"></a> [k8s\_service\_cidr](#input\_k8s\_service\_cidr) | Kubernetes service CIDR block (RFC 1918 private). Immutable after cluster creation. | `string` | `"172.16.0.0/16"` | no |
| <a name="input_k8s_sku_tier"></a> [k8s\_sku\_tier](#input\_k8s\_sku\_tier) | The SKU Tier of the AKS cluster (`Free`, `Standard` or `Premium`). | `string` | `"Premium"` | no |
| <a name="input_k8s_spot_instance_percent"></a> [k8s\_spot\_instance\_percent](#input\_k8s\_spot\_instance\_percent) | The percentage of spot instances to use for Kubernetes nodes. | `number` | `75` | no |
| <a name="input_k8s_spot_node_instance_type"></a> [k8s\_spot\_node\_instance\_type](#input\_k8s\_spot\_node\_instance\_type) | The compute instance type to use for Kubernetes spot nodes. | `string` | `"Standard_B2ms"` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | The version of Kubernetes to run in the cluster. | `string` | `"1.33"` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure geographic region to deploy resources in. | `string` | n/a | yes |
| <a name="input_managed_sync_enabled"></a> [managed\_sync\_enabled](#input\_managed\_sync\_enabled) | Whether to enable managed sync. | `bool` | `false` | no |
| <a name="input_organization"></a> [organization](#input\_organization) | Name of organization to include in resource names. | `string` | n/a | yes |
| <a name="input_postgres_base_sku_name"></a> [postgres\_base\_sku\_name](#input\_postgres\_base\_sku\_name) | PostgreSQL SKU for secondary instances. Use GP\_Standard\_D2ads\_v5 for HA support. SKU availability may vary by Azure region. | `string` | `"B_Standard_B2s"` | no |
| <a name="input_postgres_instances"></a> [postgres\_instances](#input\_postgres\_instances) | Per-instance PostgreSQL overrides. Each key is a logical name (cerberus, eventlogs, hermes, triggerkit, zeus, managed\_sync, paragon).<br/>Both sku and redundant must be set on each entry you include. Omitted keys use built-in defaults (no HA). Null uses defaults for all instances. | <pre>map(object({<br/>    sku       = string<br/>    redundant = bool<br/>  }))</pre> | `null` | no |
| <a name="input_postgres_multiple_instances"></a> [postgres\_multiple\_instances](#input\_postgres\_multiple\_instances) | Whether or not to create multiple Postgres instances. Used for higher volume installations. | `bool` | `true` | no |
| <a name="input_postgres_sku_name"></a> [postgres\_sku\_name](#input\_postgres\_sku\_name) | PostgreSQL SKU name (e.g. `B_Standard_B2s` or `GP_Standard_D2ds_v5`) | `string` | `"GP_Standard_D2ds_v5"` | no |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL version (14, 15 or 16) | `string` | `"14"` | no |
| <a name="input_redis_base_capacity"></a> [redis\_base\_capacity](#input\_redis\_base\_capacity) | Default capacity of the Redis cache for instances that don't use the main redis\_capacity. | `number` | `1` | no |
| <a name="input_redis_base_sku_name"></a> [redis\_base\_sku\_name](#input\_redis\_base\_sku\_name) | Default SKU Name of the Redis cache (`Basic`, `Standard` or `Premium`) for instances that don't use the main redis\_sku\_name. | `string` | `"Standard"` | no |
| <a name="input_redis_capacity"></a> [redis\_capacity](#input\_redis\_capacity) | Used to configure the capacity of the Redis cache. | `number` | `1` | no |
| <a name="input_redis_enabled"></a> [redis\_enabled](#input\_redis\_enabled) | Deploy Azure Cache for Redis (legacy module). When false, no legacy Redis resources are created. | `bool` | `true` | no |
| <a name="input_redis_managed_clustering_policy"></a> [redis\_managed\_clustering\_policy](#input\_redis\_managed\_clustering\_policy) | Clustering policy when cluster\_enabled is true on an instance. | `string` | `"OSSCluster"` | no |
| <a name="input_redis_managed_enabled"></a> [redis\_managed\_enabled](#input\_redis\_managed\_enabled) | Deploy Azure Managed Redis (Redis 7.4). When false, the redis-managed module is not created. May be true alongside redis\_enabled during customer migration (both modules run in parallel). | `bool` | `false` | no |
| <a name="input_redis_managed_export_storage_enabled"></a> [redis\_managed\_export\_storage\_enabled](#input\_redis\_managed\_export\_storage\_enabled) | Create blob storage and grant Managed Redis identities access for on-demand RDB export (CLI/portal). | `bool` | `false` | no |
| <a name="input_redis_managed_export_storage_replication_type"></a> [redis\_managed\_export\_storage\_replication\_type](#input\_redis\_managed\_export\_storage\_replication\_type) | Replication type for the optional Managed Redis export storage account. | `string` | `"LRS"` | no |
| <a name="input_redis_managed_instances"></a> [redis\_managed\_instances](#input\_redis\_managed\_instances) | Overrides for Azure Managed Redis instances (Redis 7.4). Each key is a logical name (cache, queue, system, managed-sync).<br/>Merged per key with redis\_managed\_instances\_default (sku, ha\_enabled, cluster\_enabled, persistence\_*). Null uses defaults only. | <pre>map(object({<br/>    sku                   = optional(string)<br/>    ha_enabled            = optional(bool)<br/>    cluster_enabled       = optional(bool)<br/>    persistence_mode      = optional(string)<br/>    persistence_frequency = optional(string)<br/>  }))</pre> | `null` | no |
| <a name="input_redis_managed_public_network_access"></a> [redis\_managed\_public\_network\_access](#input\_redis\_managed\_public\_network\_access) | Public network access for Azure Managed Redis (Disabled recommended). | `string` | `"Disabled"` | no |
| <a name="input_redis_multiple_instances"></a> [redis\_multiple\_instances](#input\_redis\_multiple\_instances) | Whether or not to create multiple Redis instances. | `bool` | `true` | no |
| <a name="input_redis_sku_name"></a> [redis\_sku\_name](#input\_redis\_sku\_name) | The SKU Name of the Redis cache (`Basic`, `Standard` or `Premium`). | `string` | `"Premium"` | no |
| <a name="input_redis_ssl_only"></a> [redis\_ssl\_only](#input\_redis\_ssl\_only) | Flag whether only SSL connections are allowed. | `bool` | `false` | no |
| <a name="input_ssh_whitelist"></a> [ssh\_whitelist](#input\_ssh\_whitelist) | An optional list of IP addresses to whitelist SSH access. | `string` | `""` | no |
| <a name="input_storage_account_tier"></a> [storage\_account\_tier](#input\_storage\_account\_tier) | Storage account tier. Use "Standard" for new deployments that need public CDN container access (Premium BlockBlobStorage does not support it). | `string` | `"Premium"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR for the virtual network. A `/16` (65,536 IPs) or larger is recommended. | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_auditlogs_bucket"></a> [auditlogs\_bucket](#output\_auditlogs\_bucket) | The bucket used to store audit logs. |
| <a name="output_bastion"></a> [bastion](#output\_bastion) | Bastion server connection info. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the AKS cluster. |
| <a name="output_kafka"></a> [kafka](#output\_kafka) | Connection info for Kafka (Event Hubs for Kafka). |
| <a name="output_logs_container"></a> [logs\_container](#output\_logs\_container) | The bucket used to store system logs. |
| <a name="output_postgres"></a> [postgres](#output\_postgres) | Connection info for Postgres. |
| <a name="output_redis"></a> [redis](#output\_redis) | Primary Redis connection info for the paragon workspace. During migration (both modules enabled), returns legacy endpoints until redis\_enabled is set to false. |
| <a name="output_redis_managed"></a> [redis\_managed](#output\_redis\_managed) | Azure Managed Redis 7.4 endpoints (null when redis\_managed\_enabled is false). Use during migration for kubectl trial routing while output redis still points at legacy. |
| <a name="output_redis_managed_export_storage"></a> [redis\_managed\_export\_storage](#output\_redis\_managed\_export\_storage) | Blob storage for on-demand Azure Managed Redis RDB export (null when disabled or legacy Redis). |
| <a name="output_resource_group"></a> [resource\_group](#output\_resource\_group) | Resource Group that infrastructure was deployed to. |
| <a name="output_storage"></a> [storage](#output\_storage) | Object storage connection info. |
| <a name="output_workspace"></a> [workspace](#output\_workspace) | The resource group that all resources are associated with. |
<!-- END_TF_DOCS -->

## Updates

This Terraform documentation can be automatically regenerated with:

```
terraform-docs markdown table --output-file README.md --output-mode inject .
```
