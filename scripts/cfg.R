# Configuration for the SET simulation
# Scripts are located in 2025-set/2026-set-simulation

library(tidyverse)

# define run
run <- "code-testing"

cfg <- list(
  # simulation functions, plus copies of the original bigraph's error functions
  fun_dir = "functions",
  data_dir = file.path("data", run),
  results_dir = file.path("results", run),

  causes = c(
    "operator_relevant",
    "operand_related",
    "double_half",
    "different_unit",
    "miss_1",
    "miss_10",
    "miss_100",
    "miss_power",
    "m_div_n",
    "m_minus_n",
    "m_plus_n",
    "typo",
    "reverse",
    "zero"
  ),

  # item pool: all m x n with m, n in item_digit_range, drawn uniformly for now
  item_digit_range = 1:9,

  # generation factors (full factorial over these)
  n_errors = c(5, 10, 15, 20, 30, 50, 100),
  p_dom = c(0, 0.1, 0.3, 0.5, 0.7, 0.9, 1), # 0 = null model: every error's cause drawn independently from base rates
  noise_prob = 0,
  n_students = 3,
  seed = 20261117,

  # each of these causes becomes its own dominant-cause scenario (only when p_dom > 0).
  # m_div_n, m_minus_n, reverse and m_plus_n cannot produce an error on every item:
  # for these, p_dom applies only on items where they can (see 01-generate-errors.R)
  dom_causes = c(
    "operator_relevant",
    "operand_related",
    "double_half",
    "different_unit",
    "miss_1",
    "miss_10",
    "miss_100",
    "miss_power",
    "m_div_n",
    "m_minus_n",
    "m_plus_n",
    "typo",
    "reverse",
    "zero"
  ),

  # responses a noise error can produce (any wrong whole number in this range)
  noise_range = 0:100,

  # SET settings
  window_size = seq(10, 50, 10),
  weight_method = c("none", "error", "cause", "cause*error"),
  beta = seq(0, 1.5, .5)
)

walk(
  list.files(
    cfg$fun_dir,
    pattern = "\\.R$",
    full.names = TRUE,
    recursive = TRUE
  ),
  source
)
