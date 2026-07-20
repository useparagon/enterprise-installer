output "s3_associations" {
  description = "Pod Identity associations for S3 access."
  value = {
    for name, assoc in aws_eks_pod_identity_association.s3 :
    name => assoc.association_arn
  }
}
