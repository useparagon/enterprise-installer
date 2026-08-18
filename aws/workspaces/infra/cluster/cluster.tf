check "ami_release_version_homogeneous_ami_family" {
  assert {
    condition = (
      var.ami_release_version == null
      || length(var.ami_release_versions) > 0
      || length(local.managed_node_group_ami_types) <= 1
    )
    error_message = "ami_release_version cannot be used alone when managed node groups span multiple AMI families (e.g. BOTTLEROCKET system + AL2 legacy). Set ami_release_versions keyed by node group (system, ondemand, spot), or leave ami_release_version null."
  }
}

# Creating the EKS cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.26.0"

  cluster_name    = var.workspace
  cluster_version = var.k8s_version

  # networking
  cluster_endpoint_public_access = true
  subnet_ids                     = var.private_subnet_ids
  vpc_id                         = var.vpc_id

  # access
  # NOTE: the bastion access entry is managed separately (see aws_eks_access_entry.bastion
  # below) to avoid a race where the entry is created before the bastion IAM role has
  # propagated, which intermittently fails the apply.
  access_entries = merge(
    {
      eks-admins = {
        kubernetes_groups = ["admin", "cluster-admin"]
        principal_arn     = aws_iam_role.eks_cluster_admin.arn

        policy_associations = {
          eks-admins = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    },
    { for arn in var.eks_admin_arns : arn => {
      kubernetes_groups = ["admin", "cluster-admin"]
      principal_arn     = arn

      policy_associations = {
        "${replace(arn, ":", "-")}" = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    } if arn != "" }
  )

  cluster_security_group_additional_rules = var.bastion_enabled ? {
    bastion_api_access = {
      description              = "Bastion to cluster API"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      type                     = "ingress"
      source_security_group_id = var.bastion_security_group_id
    }
  } : {}

  node_security_group_tags = var.enable_karpenter ? {
    "karpenter.sh/discovery" = var.workspace
  } : {}

  # encryption
  create_kms_key                  = false
  enable_kms_key_rotation         = true
  kms_key_deletion_window_in_days = 7
  cluster_encryption_config = {
    provider_key_arn = module.cluster_kms_key.key_arn
    resources        = ["secrets"]
  }

  # logging
  cluster_enabled_log_types = ["api", "authenticator"]

  cluster_tags = {
    Name = var.workspace
  }

  # NEVER add depends_on here. A module-level depends_on is inherited by the module's
  # data sources, so `data.aws_partition.current` is deferred to apply time whenever any
  # upstream object has a pending change. That makes local.iam_role_policy_prefix unknown
  # at plan time, which makes policy_arn unknown on
  # aws_iam_role_policy_attachment.this["AmazonEKSClusterPolicy"] and
  # ["AmazonEKSVPCResourceController"]. policy_arn is ForceNew, so Terraform silently
  # detaches and re-attaches both managed policies from the live cluster role on an
  # otherwise unrelated apply, which takes the control plane's node/ENI management offline
  # and drives every node NotReady (SEV-1130).
  #
  # aws_iam_role.eks_cluster_admin is already an implicit dependency via access_entries.
  # The egress gate belongs on the node groups, which are what actually bootstrap over the
  # internet; the control plane itself does not need private egress routing.
}

# Managed outside the EKS module so creation is ordered after the cluster (and the
# bastion IAM role) exists, avoiding the intermittent race on bastion upgrades.
resource "aws_eks_access_entry" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  cluster_name      = module.eks.cluster_name
  principal_arn     = var.bastion_role_arn
  kubernetes_groups = ["admin", "cluster-admin"]
  type              = "STANDARD"

  depends_on = [module.eks]
}

resource "aws_eks_access_policy_association" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = var.bastion_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion]
}

resource "random_string" "node_group" {
  for_each = local.legacy_node_groups

  length  = 6
  special = false
  numeric = false
  lower   = true
  upper   = false
  keepers = {
    workspace      = var.workspace
    iam_role_arn   = aws_iam_role.node_role.arn
    subnet_ids     = join(",", var.private_subnet_ids)
    capacity_type  = each.value.capacity
    instance_types = join(",", each.value.instance_types)
  }
}

module "eks_managed_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "20.26.0"

  for_each = local.managed_node_groups

  name            = each.key == "system" ? substr(local.system_node_group_name, 0, 38) : substr("${var.workspace}-${random_string.node_group[each.key].result}", 0, 38)
  use_name_prefix = each.key == "system" ? coalesce(try(each.value.use_name_prefix, null), false) : true

  cluster_name                      = module.eks.cluster_name
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  cluster_service_cidr              = module.eks.cluster_service_cidr
  cluster_version                   = module.eks.cluster_version

  create_iam_role        = false
  iam_role_arn           = aws_iam_role.node_role.arn
  subnet_ids             = var.private_subnet_ids
  vpc_security_group_ids = [module.eks.cluster_security_group_id]

  ami_type = try(each.value.ami_type, null)
  # Prefer per-node-group pins when set; otherwise a single pin only when AMI families are homogeneous.
  ami_release_version = (
    length(var.ami_release_versions) > 0
    ? try(var.ami_release_versions[each.key], null)
    : var.ami_release_version
  )
  use_latest_ami_release_version = var.use_latest_ami_release_version
  capacity_type                  = each.value.capacity
  desired_size                   = try(each.value.desired_size, each.value.min_count)
  instance_types                 = each.value.instance_types
  max_size                       = each.value.max_count
  min_size                       = each.value.min_count

  metadata_options = local.metadata_options
  labels           = try(each.value.labels, { "useparagon.com/capacityType" = each.key })

  tags = each.key == "system" ? {
    Name                      = coalesce(try(var.eks_system_managed_node_group.ec2_name_tag, null), local.system_node_group_name)
    "useparagon.com/nodeRole" = "system"
  } : {}

  taints = [
    for taint in coalesce(try(each.value.taints, []), []) : {
      key    = taint.key
      value  = try(taint.value, null)
      effect = taint.effect
    }
  ]
  update_config = {
    max_unavailable = 1
  }
  ebs_optimized           = true
  disable_api_termination = false
  enable_monitoring       = true
  block_device_mappings   = each.key == "system" && try(each.value.ami_type, null) == "BOTTLEROCKET_x86_64" ? local.bottlerocket_system_block_device_mappings : local.default_block_device_mappings

  # depends_on is safe here only because create_iam_role = false: the data sources this
  # defers (aws_partition, aws_caller_identity) feed nothing but the module's own node role
  # policy ARNs, which are not created. Do not enable create_iam_role without first making
  # these dependencies implicit — see the note on module.eks above.
  depends_on = [
    module.eks,
    terraform_data.egress_ready,
    aws_iam_role.node_role,
    aws_iam_role_policy_attachment.custom_worker_policy_attachment,
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy
  ]
}
