# copied from 2025-error-tracing/functions/model/original/bigrapherr_new.R (2026-11-19)
bigrapherr <- function(
    df,
    m,
    n,
    response,
    error_id,
    collapse = FALSE) {
  
  if (collapse == TRUE) {
    warning("collapse == TRUE deletes duplicate error_ids which may result in
            a bigraph with fewer errors than requested in window")
    df <- df %>% dplyr::distinct({{ error_id }}, .keep_all = TRUE)
  }
  
  n_rows <- nrow(df)
  
  # Preallocate list instead of growing matrix
  bigraph_list <- vector("list", n_rows)
  
  # Cache columns once 
  m_vec        <- df[[m]]
  n_vec        <- df[[n]]
  response_vec <- df[[response]]
  error_vec    <- df[[error_id]]
  
  # 10% checkpoints 
  checkpoints <- unique(floor(seq(0.1, 1, by = 0.1) * n_rows))
  checkpoint_index <- 1L

  start_time <- Sys.time()
  last_checkpoint <- start_time
  
  for (i in seq_len(n_rows)) {
    
    bigraph_list[[i]] <- classifierr(
      m        = m_vec[i],
      n        = n_vec[i],
      response = response_vec[i],
      error_id = error_vec[i]
    )
    
    if (i %% 1000 == 0) {
      current_time <- Sys.time()
      time_diff <- difftime(current_time, last_checkpoint, units = "secs")
      
      message(sprintf(
        "Processed %d rows out of %d | Last 1000 rows took %.2f seconds",
        i, n_rows, as.numeric(time_diff)
      ))
      
      last_checkpoint <- current_time
    }
    
    if (checkpoint_index <= length(checkpoints) &&
        i >= checkpoints[checkpoint_index]) {
      
      pct <- checkpoint_index * 10
      total_time <- difftime(Sys.time(), start_time, units = "mins")
      
      message(sprintf(
        "Reached %d%% of data (%d/%d) | Total elapsed: %.2f minutes",
        pct, i, n_rows, as.numeric(total_time)
      ))
      
      checkpoint_index <- checkpoint_index + 1L
    }
  }
  
  # bind
  bigraph <- do.call(cbind, bigraph_list)
  
  total_time <- difftime(Sys.time(), start_time, units = "mins")
  message(sprintf(
    "Finished processing %d rows in %.2f minutes",
    n_rows, as.numeric(total_time)
  ))
  
  return(bigraph)
}