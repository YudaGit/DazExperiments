// L1: VM target + uniform guess
// gamma_i = inv_logit(gamma_cd[idx_cd] + session offset)

data {
  int<lower=1> N;
  vector[N] theta;
  array[N] int<lower=1> idx_cd;
  array[N] int<lower=1> idx_sess;
  array[N] int<lower=1> kappa_idx;
  int<lower=1> n_kappa;
  int<lower=1> n_cd;
  int<lower=1> n_sess;
}

parameters {
  vector[n_kappa] log_kappa_base;
  vector[n_sess - 1] log_kappa_sess;
  vector[n_cd] gamma_cd_logit;
  vector[n_sess - 1] gamma_sess_logit;
}

transformed parameters {
  vector<lower=0>[N] kappa;
  vector<lower=0, upper=1>[N] gamma;
  for (i in 1:N) {
    real lk = log_kappa_base[kappa_idx[i]];
    if (idx_sess[i] > 1) {
      lk += log_kappa_sess[idx_sess[i] - 1];
    }
    kappa[i] = fmin(exp(lk), 500.0);

    real gl = gamma_cd_logit[idx_cd[i]];
    if (idx_sess[i] > 1) {
      gl += gamma_sess_logit[idx_sess[i] - 1];
    }
    gamma[i] = inv_logit(gl);
  }
}

model {
  log_kappa_base ~ normal(2, 0.5);
  log_kappa_sess ~ normal(0, 0.35);
  gamma_cd_logit ~ normal(-2.9, 1);   // ~5% guess at reference
  gamma_sess_logit ~ normal(0, 0.5);

  for (i in 1:N) {
    real log_target = log1m(gamma[i]) + von_mises_lpdf(theta[i] | 0, kappa[i]);
    real log_guess = log(gamma[i]) - log(2 * pi());
    target += log_sum_exp([log_target, log_guess]);
  }
}

generated quantities {
  vector[N] log_lik;
  for (i in 1:N) {
    real log_target = log1m(gamma[i]) + von_mises_lpdf(theta[i] | 0, kappa[i]);
    real log_guess = log(gamma[i]) - log(2 * pi());
    log_lik[i] = log_sum_exp([log_target, log_guess]);
  }
}
