# copied from 2025-error-tracing/functions/model/original/classifierr.R (2026-11-19)
classifierr <- function(m, n, response, error_id, causes = cfg$causes) {

  # Classifier functions for single-digit multiplication tables.
  # Returns 1 if error category can cause error response.
  # Returns 0 if error category cannot cause error response.

  bigraph <- matrix(NA, length(causes) + 2, 1)
  rownames(bigraph) <- c(causes, "misidentified", "unidentified")
  colnames(bigraph) <- error_id

  options(scipen = 999)  # disables scientific notation (e.g., 1e+06)
  correct <- m * n

  # Correct response misidentified as an error
  if (response == correct) {

    bigraph["misidentified", ] <- 1
    bigraph[!rownames(bigraph) %in% "misidentified", ] <- 0

  # Error categories
  } else {

    bigraph["misidentified", ] <- 0

    if ("operator_relevant" %in% causes) {
      bigraph["operator_relevant", ] <- ifelse(response %in% operator_relevant(m = m, n = n, digits = cfg$item_digit_range), 1, 0) }

    if ("table_related" %in% causes) {
      bigraph["table_related", ] <- ifelse(response %in% table_related(m = m, n = n), 1, 0) }

    if ("operand_related" %in% causes) {
      bigraph["operand_related", ] <- ifelse(response %in% operand_related(m = m, n = n), 1, 0) }

    if ("operand_related_both" %in% causes) {
      bigraph["operand_related_both", ] <- ifelse(response %in% operand_related_both(m = m, n = n), 1, 0) }

    if ("double_half" %in% causes) {
      bigraph["double_half", ] <- ifelse(response %in% double_half(m = m, n = n), 1, 0) }

    if ("different_unit" %in% causes) {
      bigraph["different_unit", ] <- ifelse(response %in% different_unit(m = m, n = n), 1, 0) }

    if ("miss_1" %in% causes) {
      bigraph["miss_1", ] <- ifelse(response %in% miss_1(m = m, n = n), 1, 0) }

    if ("miss_10" %in% causes) {
      bigraph["miss_10", ] <- ifelse(response %in% miss_10(m = m, n = n), 1, 0) }

    if ("miss_100" %in% causes) {
      bigraph["miss_100", ] <- ifelse(response %in% miss_100(m = m, n = n), 1, 0) }

    if ("miss_power" %in% causes) {
      bigraph["miss_power", ] <- ifelse(response %in% miss_power(m = m, n = n), 1, 0) }

    if ("m_div_n" %in% causes) {
      bigraph["m_div_n", ] <- ifelse(response %in% m_div_n(m = m, n = n), 1, 0) }

    if ("m_minus_n" %in% causes) {
      bigraph["m_minus_n", ] <- ifelse(response %in% m_minus_n(m = m, n = n), 1, 0) }

    if ("m_plus_n" %in% causes) {
      bigraph["m_plus_n", ] <- ifelse(response %in% m_plus_n(m = m, n = n), 1, 0) }

    if ("typo" %in% causes) {
      bigraph["typo", ] <- ifelse(response %in% typo(m = m, n = n), 1, 0) }

    if ("reverse" %in% causes) {
      bigraph["reverse", ] <- ifelse(response %in% reverse(m = m, n = n), 1, 0) }

    if ("zero" %in% causes) {
      bigraph["zero", ] <- ifelse(response %in% zero(m = m, n = n), 1, 0) }

    # # ten table
    # #  answer to an item in the tables 2 to 10, except mirror-items that are also in the tables 0 and 1
    # #  thus, no 2*1 as the mirror-item is in the table of 1
    # tt <- unique(as.vector(c(2:10)%*%t(2:10)))
    # bigraph["ten.table", ] <- response %in% length(tt[tt != correct])

    # # ten table 100 CHECK MET MARTHE
    # bigraph["ten.table.100", ]

    # # m + n0 error CHECK MET MARTHE
    # #  NB. for operands with up to 4 digits
    # m0 <- unlist(strsplit(gsub("([1-9]+)(0*)([1-9]*)(0*)", "\\1:::\\2:::\\3:::\\4", m), ":::"))
    # m0 <- m0[m0 != ""]
    # n0 <- unlist(strsplit(gsub("([1-9]+)(0*)([1-9]*)(0*)", "\\1:::\\2:::\\3:::\\4", n), ":::"))
    # n0 <- n0[n0 != ""]
    # if(length(m0) == 2 & length(n0) == 2) {
    #         bigraph["m.plus.n0", ] <- response == as.numeric(paste0(as.numeric(m0[1]) + as.numeric(n0[1]), m0[2], n0[2]))
    # } else {
    #         bigraph["m.plus.n0", ] <- 0
    # }

    # # naming error CHECK MET MARTHE
    # bigraph["naming.error", ] <- response %in% as.numeric(c(m,
    #                                                    n,
    #                                                    c(paste(m, n, sep='',collapse='')),
    #                                                    c(paste(n, m, sep='',collapse=''))))

    # # intrusion CHECK MET MARTHE
    # bigraph["intrusion", ]

    # # pastesub CHECK MET MARTHE
    # bigraph["pastesub", ]

    # # addsub CHECK MET MARTHE
    # bigraph["addsub", ]

    # #intrusion van operand in antwoord
    # intrusion=which(answers %in% c(10*splitsen(as.numeric(cor))[1]+n,10*m+splitsen(as.numeric(cor))[2]) & !is.na(answers))
    # if(length(intrusion)>0) dummytable=rbind(dummytable,data.frame(answer=rep(names(fr[intrusion]),fr[intrusion]),error='intrusion'))
    #
    # #paste subresults together 4 x 25 = 820
    # pastesub=which(answers==pastesubresults(m,n))
    # if(length(pastesub)>0) dummytable=rbind(dummytable,data.frame(answer=rep(names(fr[pastesub]),fr[pastesub]),error='pastesub'))
    #
    # #behandel alles als losse eenheden 4 x 25 = 28
    # addsub=which(answers %in% addsubresults(m,n))
    # if(length(addsub)>0) dummytable=rbind(dummytable,data.frame(answer=rep(names(fr[addsub]),fr[addsub]),error='addsub'))

    # Final check: unidentified
    bigraph["unidentified", ] <- all(bigraph[!rownames(bigraph) %in% "unidentified", ] != 1)
  }

  # Stop if NAs in bigraph
  if (any(is.na(bigraph))) {
    stop(" One or more NA's in bigraph: probably some requested causes not implemented in classifierr function. ")
  }

  return(bigraph)
}
