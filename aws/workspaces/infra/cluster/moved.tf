# Migrate the bastion access entry from the EKS module's managed map to standalone
# resources. Existing deployments keep the same AWS objects in state.
moved {
  from = module.eks.aws_eks_access_entry.this["bastion"]
  to   = aws_eks_access_entry.bastion[0]
}

moved {
  from = module.eks.aws_eks_access_policy_association.this["bastion_bastion"]
  to   = aws_eks_access_policy_association.bastion[0]
}
