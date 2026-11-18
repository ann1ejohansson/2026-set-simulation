# Simulate one student's error sequence
# For each error: draw the item first, then a cause that can produce an error on
# that item, then a plausible response. With probability p_dom the dominant cause
# is used, if it can produce an error on the item; otherwise the cause is drawn
# from the base rates of the causes that can, renormalised.
# Needs `items`, `item_causes`, `lookup`, `lookup_index` and `cause_probs`
# from the generating script.

simulate_student <- function(
  student_id,
  n_errors,
  p_dom,
  dom_cause,
  noise_prob
) {
  map_dfr(seq_len(n_errors), \(j) {
    item <- items[sample.int(nrow(items), 1, prob = items$item_prob), ]
    item_key <- paste(item$m, item$n, sep = ",")

    if (runif(1) < noise_prob) {
      cause <- "noise"
      response <- sample_one(setdiff(cfg$noise_range, item$correct))
    } else {
      # causes that can produce an error on this item
      avail <- item_causes[[item_key]]
      if (!is.na(dom_cause) && dom_cause %in% avail && runif(1) < p_dom) {
        cause <- dom_cause
      } else {
        cause <- sample_one(
          avail,
          prob = cause_probs$prob[match(avail, cause_probs$cause)]
        )
      }
      i <- lookup_index[[paste(cause, item_key, sep = "|")]]
      response <- sample_one(lookup$responses[[i]])
    }

    tibble(
      m = item$m,
      n = item$n,
      correct = item$correct,
      response = response,
      true_cause = cause
    )
  }) %>%
    mutate(
      student_id = student_id,
      error_index = seq_len(n_errors),
      dom_cause = dom_cause,
      .before = 1
    ) %>%
    relocate(true_cause, .after = error_index)
}
