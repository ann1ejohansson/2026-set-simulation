# copied from 2025-error-tracing/functions/model/original/isingerr.R (2026-11-19)
# Compute Ising cause probabilities
#  Args
#   all_causes: whether model computes probabilities for all causes in
#    theoretical framework (TRUE) or causes in the bigraph (FALSE)
#   slip: name of slip column in the bigraph

isingerr <- function(bigraph_obs,
                     n_causes,
                     beta = .5,
                     weights = "none",
                     all_causes = TRUE,  # FALSE gives NA if no possible causes are found!
                     slip = "slip",
                     ...) {

  # Specificity principle
  weighted_errors <- t(t(bigraph_obs) / colSums(bigraph_obs))

  # Law of diminishing returns (power law of practice with exponential function)
  # weighted_causes <- bigraph_obs*exp(-1*(rowSums(bigraph_obs)-.5))  # with b = .5 and c = 0

  # Law of diminishing returns (power law of practice with power function)
  weighted_causes <- bigraph_obs * rowSums(bigraph_obs)^-.5  # with b = .5 and c = 0
  weighted_causes[is.nan(weighted_causes)] <- 0  # fix 0^-.5

  # Law of diminishing returns (simple division, equals to power law of practice with b = 1, makes no sense)
  # weighted_causes <- bigraph_obs/rowSums(bigraph_obs)

  # Law of diminishing returns (division by logarithm), row sums + 1 for convenience
  # weighted_causes <- bigraph_obs/log(rowSums(bigraph_obs)+1)  # log transformation returns -Inf for log(0) and 0 for log(1)
  # weighted_causes[is.nan(weighted_causes)] <- 0  # ugly, to deal with 0/log(1) (?)

  # Law of diminishing returns (division by logarithm), without row sums + 1
  # weighted_causes <- bigraph_obs/log(rowSums(bigraph_obs))  # log transformation returns -Inf for log(0) and 0 for log(1)
  # weighted_causes[is.na(weighted_causes)] <- 0  # ugly, to deal with ?/sqrt(0) (?)
  # weighted_causes[is.nan(weighted_causes)] <- 0  # ugly, to deal with 0/log(1) (?)
  # weighted_causes[is.infinite(weighted_causes)] <- 2  # ugly, to deal with log(1) (?): edges get weight 2 if it has a single cause

  # Method 1: ockham's razor (unweighted)
  if (weights == "none") {
    w_bi <- bigraph_obs
  }

  # Method 2: specificity (weighted by error)
  if (weights == "error") {
    w_bi <- weighted_errors
  }

  # Method 3: law of diminishing returns (weighted by cause)
  if (weights == "cause") {
    w_bi <- weighted_causes
  }

  # Method 4: law of diminishing returns (weighted by cause) * specificity
  #  (weighted by error)
  if (weights == "cause*error") {
    w_bi <- weighted_errors * weighted_causes
  }

  # rs <- rowSums(w_bi) * beta  # beta determines softmax/hardmax
  rs <- rowSums(w_bi) * 2 * beta  # beta determines softmax/hardmax

  # Remove a slip category if present
  rs <- rs[!(names(rs) %in% slip)]

  # If all_causes is FALSE, only selected the causes that could've caused the
  #  observed errors
  if (all_causes == FALSE) {
    rs <- rs[rs > 0]
  }

  # Throw error if bigraph is empty / no causes were identified
  # if(length(rs) == ) {
  #     stop(" Bigraph is empty, no causes could be identified. ")
  # }

  # Compute total number of causes in considered bigraph
  tot_causes <- length(rs)

  # Throw error if # causes in bigraph is smaller than requested in n_causes
  if (tot_causes < n_causes) {
    stop("Fewer causes could be identified than requested in `n_causes`.")
  }

  # Create combinations of causes to pick from
  pick <- combn(tot_causes, n_causes)

  p <- c()
  nms <- c()
  for (i in 1:ncol(pick)) {
    p[i] <- exp(sum(rs[pick[, i]])) / sum(exp(colSums(combn(rs, n_causes))))
    nms[i] <- paste(names(rs[pick[, i]]), collapse = " & ")
  }

  # Error handling: must sum to 1, see
  # https://stackoverflow.com/questions/9508518/why-are-these-numbers-not-equal)
  if (!isTRUE(all.equal(sum(p), 1))) {  # or use dplyr's near()
    stop("Predicted probabilities do not sum to 1. Proceed at your own risk.")
  }

  names(p) <- nms

  if (hasArg(majority_order)) {
    dots <- list(...)
    p <- order_ties(p, dots$majority_order)
  }

  return(p)
}
