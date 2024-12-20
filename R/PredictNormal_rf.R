#' Predict normative retina sensitivity - random forest
#' @param model A string.
#' @param dt A numeric matrix from SensForFit.
#' @param exam A string.
#' @param CalibSplit A number.
#' @param coverage A number.
#' @export
#' @import ranger
#' @import stats
#' @export
PredictNormal_rf <- function(dt, exam="Mesopic", model="LMM", CalibSplit=0.2, coverage=0.95 #,
                              # other_predict = NULL
){
  nFold <- max(dt$fold)
  cv_mae <- list()
  cv_mace <- list()

  for (i in 1:nFold) {
    # Train-test split
    train <- dt[dt$fold != i,]
    set.seed(123+i)
    calibration <- sample(unique(train$Patient), CalibSplit * length(unique(train$Patient)))
    calib <- train[train$Patient %in% calibration,]
    train <- train[!train$Patient %in% calibration,]
    test <- dt[dt$fold == i,]

    # Fit random forest with quantile regression
    rf <- ranger::ranger(
      formula = MeanSens ~ Age + x + y + eccentricity + angle + Eye,
      data = train,
      num.trees = 500,
      mtry = floor(sqrt(ncol(train) - 1)),
      quantreg = TRUE                     # Enable quantile regression
    )

    # Predict quantiles for calibration set
    calib_pred <- predict(rf, data=calib)[["predictions"]]
    calib_residuals <- abs(calib$MeanSens - calib_pred)
    quantiles <- quantile(calib_residuals, coverage)
    test_pred <- predict(rf, data = test)[["predictions"]]
    lower_bound <- test_pred-quantiles  # 2.5th percentile
    upper_bound <- test_pred+quantiles  # 97.5th percentile

    # Calculate observed coverage
    observed_coverage <- mean(test$MeanSens >= lower_bound & test$MeanSens <= upper_bound)

    # Nominal coverage
    coverage <- coverage

    # MACE calculation
    fold_mace <- abs(observed_coverage - coverage)

    # Store results
    cv_mae[[i]] <- mean(abs((lower_bound + upper_bound) / 2 - test$MeanSens))
    cv_mace[[i]] <- fold_mace
  }
  # Compute overall metrics
  cv_mae_overall <- mean(unlist(cv_mae))
  cv_mace_overall <- mean(unlist(cv_mace))
  return(c("RF", cv_mae_overall, cv_mace_overall))
}
