# 01. GENERATE ERROR SEQUENCES
# for each error: draw an item, then a cause that can produce an error on
# that item, then a plausible response.
#  - with probability p_dom: the dominant cause, if it can produce an error on
#    the item (m_div_n, m_minus_n, reverse and m_plus_n cannot on every item)
#  - otherwise: a cause drawn from the base rates of the causes that can,
#    renormalised on that item
# so items are spread the same for every student, and p_dom is the chance of
# the dominant error *when the item allows it*.
# generate for each student and dominant cause

# simulation settings ----

source("scripts/cfg.R")
# conditions to generate
n_cond <- length(cfg$n_errors) *
  length(cfg$noise_prob) *
  (any(cfg$p_dom == 0) + sum(cfg$p_dom > 0) * length(cfg$dom_causes))
message(sprintf(
  "Generating %d conditions across %s cause profiles (n = %d), %s errors",
  n_cond,
  format(n_cond * cfg$n_students, big.mark = ","),
  cfg$n_students,
  format(
    n_cond / length(cfg$n_errors) * sum(cfg$n_errors) * cfg$n_students,
    big.mark = ","
  )
))


# output dir: start from an empty folder so no files from earlier runs remain
stopifnot(dirname(cfg$data_dir) == "data", nzchar(run))
if (dir.exists(cfg$data_dir)) {
  unlink(cfg$data_dir, recursive = TRUE)
}
dir.create(cfg$data_dir, recursive = TRUE, showWarnings = FALSE)

# generate items ----

# create lookup table
# responses each cause can produce on each item

items <- expand_grid(m = cfg$item_digit_range, n = cfg$item_digit_range) %>%
  mutate(correct = m * n, item_prob = 1 / n())

cause_responses <- items %>%
  expand_grid(cause = cfg$causes) %>%
  mutate(
    raw = pmap(list(cause, m, n), run_cause),
    # plausible = a wrong, non-negative whole number a student can type
    responses = map2(raw, correct, \(x, correct) {
      unique(x[!is.na(x) & x >= 0 & x == round(x) & x != correct])
    }),
    n_responses = map_int(responses, length)
  )

# theoretical base rates
# number of responses a cause can produce over all items,
# divided by the number of distinct erroneous responses over all
# items.
n_all <- cause_responses %>%
  group_by(m, n) %>%
  summarise(n_unique = sum(!is.na(unique(unlist(raw)))), .groups = "drop") %>%
  pull(n_unique) %>%
  sum()

base_rate_theoretical <- cause_responses %>%
  group_by(name = cause) %>%
  summarise(value = sum(map_int(raw, \(x) sum(!is.na(x))))) %>%
  mutate(base_rate = value / n_all) %>%
  arrange(desc(base_rate))

# causes overlap, so these rates do not sum to 1: normalise for sampling
cause_probs <- base_rate_theoretical %>%
  mutate(prob = base_rate / sum(base_rate)) %>%
  select(cause = name, prob)

# generate errors -----

lookup <- cause_responses %>%
  filter(n_responses > 0) %>%
  select(cause, m, n, correct, item_prob, responses)

# causes that can produce an error on each item, keyed "m,n"
item_causes <- split(lookup$cause, paste(lookup$m, lookup$n, sep = ","))

# row in lookup for each cause and item, keyed "cause|m,n"
lookup_index <- as.list(seq_len(nrow(lookup))) %>%
  setNames(paste(lookup$cause, paste(lookup$m, lookup$n, sep = ","), sep = "|"))

## run each condition ----

# metadata
conditions <- expand_grid(
  n_errors = cfg$n_errors,
  p_dom = cfg$p_dom,
  dom_cause = cfg$dom_causes,
  noise_prob = cfg$noise_prob
) %>%
  # with p_dom = 0 the dominant cause plays no role, so keep one baseline per n_errors
  mutate(dom_cause = if_else(p_dom == 0, NA_character_, dom_cause)) %>%
  distinct() %>%
  mutate(
    condition_id = row_number(),
    seed = cfg$seed + condition_id,
    # file name shows the condition's parameters
    file = sprintf(
      "c%03d_n%03d_pdom%.2f_%s_noise%.2f.rds",
      condition_id,
      n_errors,
      p_dom,
      replace_na(dom_cause, "none"),
      noise_prob
    ),
    .before = 1
  )

# expected share of each true cause per condition, under this sampling model.
# per item: a = whether a cause can produce an error on it, q = its renormalised
# base rate among the causes that can. Then for cause c with dominant cause d:
# (1 - noise_prob) * mean over items of
#   p_dom * a_d * [c is d] + (1 - p_dom * a_d) * q_c
item_q <- items %>%
  select(m, n, item_prob) %>%
  expand_grid(cause_probs) %>%
  left_join(
    distinct(lookup, cause, m, n) %>% mutate(a = 1),
    by = c("cause", "m", "n")
  ) %>%
  mutate(a = replace_na(a, 0)) %>%
  group_by(m, n) %>%
  mutate(q = a * prob / sum(a * prob)) %>%
  ungroup()

expected_shares <- conditions %>%
  select(condition_id, p_dom, dom_cause, noise_prob) %>%
  expand_grid(item_q) %>%
  left_join(
    select(item_q, m, n, dom_cause = cause, a_dom = a),
    by = c("m", "n", "dom_cause")
  ) %>%
  mutate(
    a_dom = replace_na(a_dom, 0),
    is_dom = !is.na(dom_cause) & cause == dom_cause,
    share = p_dom * a_dom * is_dom + (1 - p_dom * a_dom) * q
  ) %>%
  group_by(condition_id, cause) %>%
  summarise(
    expected = (1 - first(noise_prob)) * sum(item_prob * share),
    .groups = "drop"
  ) %>%
  bind_rows(transmute(
    conditions,
    condition_id,
    cause = "noise",
    expected = noise_prob
  )) %>%
  filter(expected > 0)

# create error sequence per condition
# saved to /data
for (k in seq_len(nrow(conditions))) {
  cond <- conditions[k, ]
  set.seed(cond$seed)

  errors <- map_dfr(seq_len(cfg$n_students), \(s) {
    simulate_student(
      s,
      cond$n_errors,
      cond$p_dom,
      cond$dom_cause,
      cond$noise_prob
    )
  }) %>%
    mutate(
      condition_id = cond$condition_id,
      n_errors = cond$n_errors,
      p_dom = cond$p_dom,
      noise_prob = cond$noise_prob,
      seed = cond$seed,
      .before = 1
    )

  write_rds(errors, file.path(cfg$data_dir, cond$file))
}

write_rds(conditions, file.path(cfg$data_dir, "conditions.rds"))
write_csv(conditions, file.path(cfg$data_dir, "conditions.csv"))
write_rds(
  base_rate_theoretical,
  file.path(cfg$data_dir, "base_rate_theoretical.rds")
)
write_rds(cause_probs, file.path(cfg$data_dir, "cause_probs.rds"))
write_rds(cause_responses, file.path(cfg$data_dir, "cause_responses.rds"))
write_rds(expected_shares, file.path(cfg$data_dir, "expected_shares.rds"))

# size of the generated data ----
out_files <- c(
  file.path(cfg$data_dir, conditions$file),
  file.path(
    cfg$data_dir,
    c(
      "conditions.rds",
      "conditions.csv",
      "base_rate_theoretical.rds",
      "cause_probs.rds",
      "cause_responses.rds",
      "expected_shares.rds"
    )
  )
)
message(sprintf(
  "Generated %d conditions, %s errors from %s students: %s on disk in %s",
  nrow(conditions),
  format(sum(conditions$n_errors) * cfg$n_students, big.mark = ","),
  format(nrow(conditions) * cfg$n_students, big.mark = ","),
  format(
    structure(sum(file.size(out_files)), class = "object_size"),
    units = "auto"
  ),
  cfg$data_dir
))
