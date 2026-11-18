# per cause and m/n combinations, return possible answers
run_cause <- function(cause, m, n) {
  if (cause == "operator_relevant") {
    return(operator_relevant(m, n, digits = cfg$item_digit_range))
  }
  get(cause)(m = m, n = n)
}
