// L2: VM target + swap (3 non-target VM bumps) + uniform guess
// Stick-break: beta (swap) first, then gamma = (1-beta)*gfrac (guess).
// kappa shared for target and swap bumps (per trial).

data {
  int<lower=1> N;
  vector[N] theta;
  vector[N] mu1;
  vector[N] mu2;
  vector[N] mu3;
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
  vector[n_cd] beta_cd_logit;
  vector[n_sess - 1] beta_sess_logit;
  vector[n_cd] gfrac_cd_logit;
  vector[n_sess - 1] gfrac_sess_logit;
}

transformed parameters {
  vector<lower=0>[N] kappa;
  vector<lower=0, upper=1>[N] beta;
  vector<lower=0, upper=1>[N] gamma;
  vector<lower=0, upper=1>[N] p_target;

  for (i in 1:N) {
    real lk = log_kappa_base[kappa_idx[i]];
    if (idx_sess[i] > 1) {
      lk += log_kappa_sess[idx_sess[i] - 1];
    }
    kappa[i] = fmin(exp(lk), 500.0);

    real bl = beta_cd_logit[idx_cd[i]];
    if (idx_sess[i] > 1) {
      bl += beta_sess_logit[idx_sess[i] - 1];
    }
    beta[i] = inv_logit(bl);

    real gfl = gfrac_cd_logit[idx_cd[i]];
    if (idx_sess[i] > 1) {
      gfl += gfrac_sess_logit[idx_sess[i] - 1];
    }
    gamma[i] = (1 - beta[i]) * inv_logit(gfl);
    p_target[i] = 1 - beta[i] - gamma[i];
  }
}

model {
  log_kappa_base ~ normal(2, 0.5);
  log_kappa_sess ~ normal(0, 0.35);
  beta_cd_logit ~ normal(-2.2, 1);
  beta_sess_logit ~ normal(0, 0.5);
  gfrac_cd_logit ~ normal(-1.7, 1);
  gfrac_sess_logit ~ normal(0, 0.5);

  for (i in 1:N) {
    if (p_target[i] < 1e-6) {
      target += -1e6;
      continue;
    }
    real log_t = log(p_target[i]) + von_mises_lpdf(theta[i] | 0, kappa[i]);
    real log_s1 = log(beta[i] / 3) + von_mises_lpdf(theta[i] | mu1[i], kappa[i]);
    real log_s2 = log(beta[i] / 3) + von_mises_lpdf(theta[i] | mu2[i], kappa[i]);
    real log_s3 = log(beta[i] / 3) + von_mises_lpdf(theta[i] | mu3[i], kappa[i]);
    real log_swap = log_sum_exp([log_s1, log_s2, log_s3]);
    real log_g = log(gamma[i]) - log(2 * pi());
    target += log_sum_exp([log_t, log_swap, log_g]);
  }
}

generated quantities {
  vector[N] log_lik;
  for (i in 1:N) {
    real log_t = log(p_target[i]) + von_mises_lpdf(theta[i] | 0, kappa[i]);
    real log_s1 = log(beta[i] / 3) + von_mises_lpdf(theta[i] | mu1[i], kappa[i]);
    real log_s2 = log(beta[i] / 3) + von_mises_lpdf(theta[i] | mu2[i], kappa[i]);
    real log_s3 = log(beta[i] / 3) + von_mises_lpdf(theta[i] | mu3[i], kappa[i]);
    real log_swap = log_sum_exp([log_s1, log_s2, log_s3]);
    real log_g = log(gamma[i]) - log(2 * pi());
    log_lik[i] = log_sum_exp([log_t, log_swap, log_g]);
  }
}
