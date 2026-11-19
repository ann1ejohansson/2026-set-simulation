# copied from 2025-error-tracing/functions/helper/order_ties.R (2026-11-19)

# Order ties for isingerr -------------------------------------------------

order_ties <- function(predicted, base_rate) {
  predicted <- sort(predicted, decreasing = TRUE)
  
  t1 <- table(rank(-predicted, ties.method = "min"))
  t1_start <- as.numeric(names(t1))
  prd_new <- numeric(length(predicted))
  prd_names <- character(length(predicted))
  
  for (i in 1:length(t1)) {
    prd_index <- t1_start[i]:(t1_start[i] + t1[i] - 1)
    t2_ind <- predicted[prd_index]
    prd_tmp <- predicted[names(na.omit(t2_ind[base_rate]))]
    prd_new[prd_index] <- prd_tmp
    prd_names[prd_index] <- names(prd_tmp)
  }
  
  names(prd_new) <- prd_names
  return(prd_new)
}
