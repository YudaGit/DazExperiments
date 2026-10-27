// Study 2: target-centred von Mises plus a uniform residual component.
// Seven array contexts x two durations; duration changes partially pool
// across contexts. Session effects are centred so cell parameters describe
// an average session on the log-kappa/logit-gamma scales.
data {
  int<lower=1> N;
  vector[N] error_rad;
  array[N] int<lower=1, upper=7> context;
  array[N] int<lower=1, upper=2> duration;
  int<lower=1> S;
  array[N] int<lower=1, upper=S> session;
}
parameters {
  vector[7] log_kappa_50;
  real mean_delta_log_kappa;
  real<lower=0> sd_delta_log_kappa;
  vector[7] delta_log_kappa_z;

  vector[7] logit_gamma_50;
  real mean_delta_logit_gamma;
  real<lower=0> sd_delta_logit_gamma;
  vector[7] delta_logit_gamma_z;

  real<lower=0> sd_session_kappa;
  vector[S] session_kappa_z;
  real<lower=0> sd_session_gamma;
  vector[S] session_gamma_z;
}
transformed parameters {
  matrix[7, 2] log_kappa_cell;
  matrix[7, 2] logit_gamma_cell;
  vector[S] session_kappa;
  vector[S] session_gamma;

  session_kappa = sd_session_kappa * (session_kappa_z - mean(session_kappa_z));
  session_gamma = sd_session_gamma * (session_gamma_z - mean(session_gamma_z));
  for (c in 1:7) {
    log_kappa_cell[c, 1] = log_kappa_50[c];
    log_kappa_cell[c, 2] = log_kappa_50[c] +
      mean_delta_log_kappa + sd_delta_log_kappa * delta_log_kappa_z[c];
    logit_gamma_cell[c, 1] = logit_gamma_50[c];
    logit_gamma_cell[c, 2] = logit_gamma_50[c] +
      mean_delta_logit_gamma + sd_delta_logit_gamma * delta_logit_gamma_z[c];
  }
}
model {
  // Broad regularising priors; inspect sensitivity before manuscript use.
  log_kappa_50 ~ normal(log(5), 1.5);
  mean_delta_log_kappa ~ normal(0, 0.5);
  sd_delta_log_kappa ~ normal(0, 0.5);
  delta_log_kappa_z ~ std_normal();

  logit_gamma_50 ~ normal(-1, 1.75);
  mean_delta_logit_gamma ~ normal(0, 0.75);
  sd_delta_logit_gamma ~ normal(0, 0.75);
  delta_logit_gamma_z ~ std_normal();

  sd_session_kappa ~ normal(0, 0.35);
  session_kappa_z ~ std_normal();
  sd_session_gamma ~ normal(0, 0.5);
  session_gamma_z ~ std_normal();

  for (n in 1:N) {
    real kappa = exp(log_kappa_cell[context[n], duration[n]] +
                     session_kappa[session[n]]);
    real gamma = inv_logit(logit_gamma_cell[context[n], duration[n]] +
                           session_gamma[session[n]]);
    target += log_mix(gamma, -log(2 * pi()),
                      von_mises_lpdf(error_rad[n] | 0, kappa));
  }
}
generated quantities {
  vector[N] log_lik;
  for (n in 1:N) {
    real kappa = exp(log_kappa_cell[context[n], duration[n]] +
                     session_kappa[session[n]]);
    real gamma = inv_logit(logit_gamma_cell[context[n], duration[n]] +
                           session_gamma[session[n]]);
    log_lik[n] = log_mix(gamma, -log(2 * pi()),
                         von_mises_lpdf(error_rad[n] | 0, kappa));
  }
}
