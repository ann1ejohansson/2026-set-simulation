# copied from 2025-error-tracing/functions/model/original/majority_voterr.R (2026-11-19)

# Majority vote baseline predictions --------------------------------------
# n_causes must be 1: ranking becomes too difficult with 2 or more causes
#  (i.e., how to compute a 'majority rate' for 2 or more causes?)
# all_causes must be TRUE: else it uses information from the bigraph,
#  which is unwanted for the baseline
# majority_rate should be given such that ties can be taken into account

majority_voterr <- function(bigraph_obs,
                            n_causes = 1,
                            majority_order,
                            majority_rate,
                            # all_causes = TRUE,
                            slip = "slip") {
  
  rs <- rowSums(bigraph_obs)
  
  # Remove a slip category if present
  rs <- rs[!(names(rs) %in% slip)]
  
  # # If all_causes is FALSE, only selected the causes that could've caused the
  # #  observed errors
  # if(all_causes == FALSE) {
  #   rs <- rs[rs > 0]
  # }
  
  # Compute total number of causes in considered bigraph
  tot_causes <- length(rs)
  
  # Throw error if # causes in bigraph is smaller than requested in n_causes
  if(tot_causes < n_causes) {
    stop("Fewer causes could be identified than requested in `n_causes`.")
  }
  
  # Create combinations of causes to pick from
  pick <- combn(tot_causes, n_causes)
  
  p <- c()
  nms <- c()
  for (i in 1:ncol(pick)) {
    p[i] <- majority_rate[i]
    nms[i] <- majority_order[i]
    # nms[i] <- paste(majority_order[majority_order %in% names(rowSums(bi_local))][pick[, i]], collapse = " & ")  # retains majority order across n_causes
  }
  
  names(p) <- nms
  return(p)
}
