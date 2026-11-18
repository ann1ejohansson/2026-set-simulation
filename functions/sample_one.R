# draw one element of x, with optional sampling weights
sample_one <- function(x, prob = NULL) {
  x[sample.int(length(x), 1, prob = prob)]
}
