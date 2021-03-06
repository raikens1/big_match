#----------------------------------------------------------
### CONTAINS:
# make_issue_table and its helper function
#----------------------------------------------------------

#' Make Issue Table
#'
#' Not meant to be called externally. Produce table of the number of treated and control individuals in each stratum. Also checks for potential problems with treat/control ratio or stratum size which might result in slow or poor quality matching.
#'
#' @param a_set \code{data.frame} with observations as rows, features as columns.  This should be the analysis set from the recently stratified data.
#' @param treat string name of treatment column
#' @return Returns a 3 by [number of strata] dataframe with Treat, Control, Total, Control Proportion, and Potential Issues
#' @keywords internal
make_issue_table <- function(a_set, treat) {
  df <- data.frame(
    treat = a_set[[treat]],
    stratum = a_set$stratum
  ) %>%
    dplyr::group_by(.data$stratum) %>%
    dplyr::summarize(
      Treated = sum(.data$treat),
      Control = as.integer(sum(1 - .data$treat)),
      Total = dplyr::n(),
      .groups = "drop_last"
    ) %>%
    dplyr::mutate(Control_Proportion = .data$Control / .data$Total)

  colnames(df) <- c(
    "Stratum", "Treat",
    "Control", "Total",
    "Control_Proportion"
  )
  df$Potential_Issues <- unname(apply(df, 1, get_issues))

  return(df)
}

#' Get Issues
#'
#' Helper for make_issue_table to return issues string.  Given a row which
#' summarizes the Treat, Control, Total, and Control_Proportion of a stratum,
#' return a string of potential issues with the stratum.
#'
#' @param row a row of the data.frame produced in make_issue_table
#' @return Returns a string of potential issues
#' @keywords internal
get_issues <- function(row) {
  row <- as.numeric(row[4:5])

  # set parameters
  CONTROL_MIN <- 0.2
  CONTROL_MAX <- 0.8
  SIZE_MIN <- 75
  SIZE_MAX <- 4000

  issues <- c(
    if (row[1] > SIZE_MAX) "Too many samples",
    if (row[1] < SIZE_MIN) "Too few samples",
    if (row[2] > CONTROL_MAX) "Not enough treated samples",
    if (row[2] < CONTROL_MIN) "Not enough control samples"
  )

  if (is.null(issues)) {
    issues <- c("none")
  }

  return(paste(issues, collapse = "; "))
}
