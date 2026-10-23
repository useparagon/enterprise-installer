# Shared TFLint config for all Terraform workspaces.
# Invoke with: tflint --config "$REPO_ROOT/.tflint.hcl" --recursive

config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
