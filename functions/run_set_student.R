# Run SET on one student's error sequence
# Errors that fit no cause are dropped first, as in the real-data pipeline, so
# windows count explained errors only. For every full window of window_size
# explained errors and every weights x beta setting, isingerr() gives one
# probability per cause. Each output row serves both evaluations:
#  - recovery: compare the window's probabilities with the dominant cause
#  - prediction: compare them with the next explained error (if there is one)
# Window sizes larger than the number of explained errors give no rows.

run_set_student <- function(
  errors,
  window_sizes = cfg$window_size,
  weight_methods = cfg$weight_method,
  betas = cfg$beta,
  tie_order
) {
  errors <- errors %>%
    arrange(error_index) %>%
    mutate(error_id = paste0("e", error_index))

  bi <- suppressMessages(bigrapherr(errors, "m", "n", "response", "error_id"))
  bi <- bi[!rownames(bi) %in% c("misidentified", "unidentified"), , drop = FALSE]

  explained <- colSums(bi) > 0
  bi <- bi[, explained, drop = FALSE]
  errors <- errors[explained, ]
  n_explained <- ncol(bi)

  settings <- expand_grid(weights = weight_methods, beta = betas)
  window_sizes <- window_sizes[window_sizes <= n_explained]
  n_rows <- sum(n_explained - window_sizes + 1) * nrow(settings)
  if (n_rows == 0) {
    return(NULL)
  }

  v_window_size <- integer(n_rows)
  v_window_end <- integer(n_rows)
  v_weights <- character(n_rows)
  v_beta <- numeric(n_rows)
  v_top_cause <- character(n_rows)
  v_next <- integer(n_rows)
  probs <- matrix(NA_real_, n_rows, nrow(bi), dimnames = list(NULL, rownames(bi)))
  row <- 0

  for (w in window_sizes) {
    for (end in w:n_explained) {
      bi_local <- bi[, (end - w + 1):end, drop = FALSE]
      for (k in seq_len(nrow(settings))) {
        p <- isingerr(
          bi_local,
          n_causes = 1,
          beta = settings$beta[k],
          weights = settings$weights[k],
          majority_order = tie_order
        )
        row <- row + 1
        v_window_size[row] <- w
        v_window_end[row] <- end
        v_weights[row] <- settings$weights[k]
        v_beta[row] <- settings$beta[k]
        v_top_cause[row] <- names(p)[1]
        probs[row, ] <- p[rownames(bi)]
      }
    }
  }

  # the error after the window, among explained errors (NA after the last one)
  has_next <- v_window_end < n_explained
  next_pos <- if_else(has_next, v_window_end + 1L, NA_integer_)
  next_causes <- map(next_pos, \(i) {
    if (is.na(i)) character(0) else rownames(bi)[bi[, i] == 1]
  })

  tibble(
    window_size = v_window_size,
    weights = v_weights,
    beta = v_beta,
    n_explained = v_window_end,
    window_start = errors$error_index[v_window_end - v_window_size + 1],
    window_end = errors$error_index[v_window_end],
    top_cause = v_top_cause,
    next_error_index = errors$error_index[next_pos],
    next_true_cause = errors$true_cause[next_pos],
    next_causes = next_causes
  ) %>%
    bind_cols(as_tibble(probs, .name_repair = \(x) paste0("p_", x)))
}
