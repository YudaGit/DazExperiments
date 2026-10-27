// L0: Signed error ~ von Mises(0, kappa_i)
// kappa_i = exp(log_kappa_base[kappa_idx[i]] + session offset)
// Session 1 = reference (zero offset).

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
}

transformed parameters {
  vector<lower=0>[N] kappa;
  for (i in 1:N) {
    real lk = log_kappa_base[kappa_idx[i]];
    if (idx_sess[i] > 1) {
      lk += log_kappa_sess[idx_sess[i] - 1];
    }
    kappa[i] = fmin(exp(lk), 500.0);
  }
}

model {
  log_kappa_base ~ normal(2, 0.5);
  log_kappa_sess ~ normal(0, 0.35);
  for (i in 1:N) {
    target += von_mises_lpdf(theta[i] | 0, kappa[i]);
  }
}

generated quantities {
  vector[N] log_lik;
  for (i in 1:N) {
    log_lik[i] = von_mises_lpdf(theta[i] | 0, kappa[i]);
  }
}
