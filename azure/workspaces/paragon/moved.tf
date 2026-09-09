# Preserve OpenObserve random_* state across module.helm → root (ESO refactor).
moved {
  from = module.helm.random_string.openobserve_email[0]
  to   = random_string.openobserve_email[0]
}

moved {
  from = module.helm.random_password.openobserve_password[0]
  to   = random_password.openobserve_password[0]
}
