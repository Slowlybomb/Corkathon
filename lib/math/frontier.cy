pub fn weights(sol_mu: f64[], sol_one: f64[], sol_hold: f64[], mu: f64[],
               held: f64[], dim: u32, target: f64, lam: f64,
               out: f64[]) -> f64
    mut sum_one = 0.0
    mut sum_mu = 0.0
    mut mu_dot_mu = 0.0
    mut sum_hold = 0.0
    mut mu_dot_hold = 0.0
    mut i = 0
    while i < dim do
        sum_one = sum_one + sol_one[i]
        sum_mu = sum_mu + sol_mu[i]
        mu_dot_mu = mu_dot_mu + mu[i] * sol_mu[i]
        sum_hold = sum_hold + sol_hold[i]
        mu_dot_hold = mu_dot_hold + mu[i] * sol_hold[i]
        i = i + 1
    end
    mut det = sum_one * mu_dot_mu - sum_mu * sum_mu
    mut rhs_budget = 1.0 - lam * sum_hold
    mut rhs_target = target - lam * mu_dot_hold
    mut gain_one = (mu_dot_mu * rhs_budget - sum_mu * rhs_target) / det
    mut gain_mu = (sum_one * rhs_target - sum_mu * rhs_budget) / det
    mut norm_sq = 0.0
    mut held_dot_new = 0.0
    mut j = 0
    while j < dim do
        mut wj = lam * sol_hold[j] + gain_one * sol_one[j] + gain_mu * sol_mu[j]
        out[j] = wj
        norm_sq = norm_sq + wj * wj
        held_dot_new = held_dot_new + held[j] * wj
        j = j + 1
    end
    return lam * held_dot_new + gain_one + gain_mu * target - lam * norm_sq
end
