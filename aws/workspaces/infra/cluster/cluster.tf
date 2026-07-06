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

  depends_on = [aws_iam_role.eks_cluster_admin]
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

  name = each.key == "system" ? substr(local.system_node_group_name, 0, 38) : substr("${var.workspace}-${random_string.node_group[each.key].result}", 0, 38)
  use_name_prefix = each.key == "system" ? coalesce(try(each.value.use_name_prefix, null), false) : true

  cluster_name                      = module.eks.cluster_name
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  cluster_service_cidr              = module.eks.cluster_service_cidr
  cluster_version                   = module.eks.cluster_version

  create_iam_role        = false
  iam_role_arn           = aws_iam_role.node_role.arn
  subnet_ids             = var.private_subnet_ids
  vpc_security_group_ids = [module.eks.cluster_security_group_id]

  ami_type       = try(each.value.ami_type, null)
  capacity_type  = each.value.capacity
  desired_size   = try(each.value.desired_size, each.value.min_count)
  instance_types = each.value.instance_types
  max_size       = each.value.max_count
  min_size       = each.value.min_count

  metadata_options = local.metadata_options
  labels           = try(each.value.labels, { "useparagon.com/capacityType" = each.key })

  tags = each.key == "system" ? {
    Name                       = coalesce(try(var.eks_system_managed_node_group.ec2_name_tag, null), local.system_node_group_name)
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
  block_device_mappings = each.key == "system" && try(each.value.ami_type, null) == "BOTTLEROCKET_x86_64" ? local.bottlerocket_system_block_device_mappings : local.default_block_device_mappings

  depends_on = [
    module.eks,
    aws_iam_role.node_role,
    aws_iam_role_policy_attachment.custom_worker_policy_attachment,
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy
  ]
}
