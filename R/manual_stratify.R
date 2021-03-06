#----------------------------------------------------------
### CONTAINS:
# manual_stratify its helper functions
#----------------------------------------------------------
#----------------------------------------------------------
### MANUAL STRATIFY
#----------------------------------------------------------

#' Manual Stratify
#'
#' Stratifies a data set based on a set of blocking covariates specified by the
#' user. Creates a \code{manual_strata} object, which can be passed to
#' \code{\link{strata_match}} for stratified matching or unpacked by the user to be
#' matched by some other means.
#'
#' @param data data.frame with observations as rows, features as columns
#' @param strata_formula the formula to be used for stratification.  (e.g. \code{treat
#'   ~ X1}) the variable on the left is taken to be the name of the treatment
#'   assignment column, and the variables on the left are taken to be the
#'   variables by which the data should be stratified
#' @param force a boolean. If true, run even if a variable appears continuous.
#'   (default = FALSE)
#' @return Returns a \code{manual_strata} object.  This contains: \itemize{
#'
#'   \item \code{treat} - a string giving the name of the column encoding
#'   treatment assignment
#'
#'   \item \code{covariates} - a character vector with the names of the
#'   categorical columns on which the data were stratified
#'
#'   \item \code{analysis_set} - the data set with strata assignments
#'
#'   \item \code{call} - the call to \code{manual_stratify} used to generate this
#'   object
#'
#'   \item \code{issue_table} - a table of each stratum and potential issues of
#'   size and treat:control balance
#'
#'   \item \code{strata_table} - a table of each stratum and the covariate bin
#'   to which it corresponds
#'
#'   }
#' @seealso \code{\link{auto_stratify}}, \code{\link{new_manual_strata}}
#' @export
#' @examples
#' # make sample data set
#' dat <- make_sample_data(n = 75)
#'
#' # stratify based on B1 and B2
#' m.strat <- manual_stratify(dat, treat ~ B1 + B2)
#'
#' # diagnostic plot
#' plot(m.strat)
manual_stratify <- function(data, strata_formula, force = FALSE) {
  check_inputs_manual_stratify(data, strata_formula, force)

  # if input data is grouped, all sorts of strange things happen
  data <- data %>% dplyr::ungroup()

  treat <- all.vars(strata_formula)[1]
  covariates <- all.vars(strata_formula)[-1]

  # helper function to extract group labels from dplyr
  get_next_integer <- function() {
    i <- 0
    function(u, v) {
      i <<- i + 1
    }
  }
  get_integer <- get_next_integer()

  # Interact covariates
  grouped_table <- dplyr::group_by_at(data, covariates) %>%
    dplyr::mutate(stratum = as.integer(get_integer()))

  analysis_set <- grouped_table %>%
    dplyr::ungroup()

  strata_table <- grouped_table %>%
    dplyr::summarize(
      stratum = dplyr::first(.data$stratum),
      size = dplyr::n(),
      .groups = "drop_last"
    )

  issue_table <- make_issue_table(analysis_set, treat)

  result <- new_manual_strata(
    analysis_set = analysis_set,
    treat = treat,
    call = match.call(),
    issue_table = issue_table,
    covariates = covariates,
    strata_table = strata_table
  )
  return(result)
}

#----------------------------------------------------------
### Helpers
#----------------------------------------------------------

#' Warn if continuous
#'
#' Throws an error if a column is continuous
#'
#' Not meant to be called externally. Only categorical or binary covariates
#' should be used to manually stratify a data set.  However, it's hard to tell
#' for sure if something is continuous or just discrete with real-numbered
#' values. Returns without throwing an error if the column is a factor, but
#' throws an error or warning if the column has many distinct values.
#'
#' @param column vector or factor column from a \code{data.frame}
#' @param name name of the input column
#' @param force, a boolean. If true, warn but do not stop
#' @param n, the number of rows in the data set
#' @return Does not return anything
#' @keywords internal
warn_if_continuous <- function(column, name, force, n) {
  if (is.factor(column) | !is.numeric(column)) {
    return() # assume all factors are discrete
  } else {
    values <- length(unique(column))
    if (values > min(c(15, 0.3 * n))) {
      if (force == FALSE) {
        stop(paste("There are ", values,
          " distinct values for ", name,
          ". Is it continuous?",
          sep = ""
        ))
      } else {
        warning(paste("There are ", values,
          " distinct values for ", name,
          ". Is it continuous?",
          sep = ""
        ), immediate. = T)
      }
    }
    return()
  }
}

#----------------------------------------------------------
### INPUT CHECKERS
#----------------------------------------------------------

#' Check inputs to manual_stratify
#'
#' Not meant to be called externally.  Checks validity of formula, types of all inputs to manual stratify, and warns if covariates are continuous.
#'
#' @inheritParams manual_stratify
#'
#' @return nothing; produces errors and warnings if anything is wrong
#' @keywords internal
check_inputs_manual_stratify <- function(data, strata_formula, force) {
  # check input types
  if (!is.data.frame(data)) stop("data must be a data.frame")
  if (!inherits(strata_formula, "formula")) {
    stop("strata_formula must be a formula")
  }
  if (!is.logical(force)) stop("force must equal either TRUE or FALSE")
  if (!all(is.element(all.vars(strata_formula), colnames(data)))) {
    stop("not all variables in stat_formula appear in data")
  }

  covariates <- all.vars(strata_formula)[-1]
  n <- dim(data)[1]

  if (!is_binary(data[[all.vars(strata_formula)[1]]])) {
    stop("treatment column must be binary or logical")
  }

  # Check that all covariates are discrete
  for (i in 1:length(covariates)) {
    warn_if_continuous(data[[covariates[i]]], covariates[i], force, n)
  }
}
