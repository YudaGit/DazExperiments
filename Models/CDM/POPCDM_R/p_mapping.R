# Trial-to-parameter mapping for POPCDM.
# P order: c(vnorm, eta1, eta2, a, alpha, kappa, ter, st)

default_beta <- function() {
  list(
    # Baselines
    vnorm0 = 2.5,
    eta10 = 0.05,
    eta20 = 0.05,
    a0 = 2.0,
    alpha0 = 2.0,
    kappa0 = 20.0,
    ter0 = 0.30,
    st0 = 0.00,

    # Effects (initial placeholders, tune by fitting)
    b_alpha_R = -0.20,   # redundant cue can flatten coding
    b_kappa_R = -2.00,
    b_v_pre = 0.00,      # pre_dur effect on vnorm
    b_kappa_pre = 0.00,
    b_eta_ret = 0.00,    # reserve for retention effects
    b_ter_pre = 0.00
  )
}

clip_pos <- function(x, lo) pmax(lo, x)

# Compute P vector for one trial.
# trial: output from gen_trial()
# beta: coefficients from default_beta() or fitted values
map_trial_to_params <- function(trial, beta = default_beta()) {
  cueR <- !is.na(trial$cue_type) && trial$cue_type == "R"
  pre <- trial$pre_dur
  ret <- ifelse(is.na(trial$ret_dur), 0, trial$ret_dur)

  alpha <- beta$alpha0 + beta$b_alpha_R * as.numeric(cueR)
  kappa <- beta$kappa0 + beta$b_kappa_R * as.numeric(cueR) + beta$b_kappa_pre * pre
  vnorm <- beta$vnorm0 + beta$b_v_pre * pre
  eta1 <- beta$eta10 + beta$b_eta_ret * ret
  eta2 <- beta$eta20 + beta$b_eta_ret * ret
  a <- beta$a0
  ter <- beta$ter0 + beta$b_ter_pre * pre
  st <- beta$st0

  # Bounds for numerical stability / interpretability.
  vnorm <- clip_pos(vnorm, 1e-4)
  eta1 <- clip_pos(eta1, 0.01)
  eta2 <- clip_pos(eta2, 0.01)
  a <- clip_pos(a, 1e-4)
  alpha <- clip_pos(alpha, 1e-4)
  kappa <- clip_pos(kappa, 1e-4)
  ter <- clip_pos(ter, 0)
  st <- clip_pos(st, 0)

  c(vnorm, eta1, eta2, a, alpha, kappa, ter, st)
}

