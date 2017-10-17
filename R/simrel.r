## ---- Class: Simrel ----
#' @title Simulation of Linear Model Data
#' @description Simulates univariate, bivariate and multivariate linear model data where users can specify few parameters for simulating data with wide range of properties.
#' @import R6
#' @param  n Number of training samples
#' @param p Number of predictor variables
#' @param q Number of relevant predictor variables
#' @param relpos Position of relevant predictor components
#' @param gamma Decay factor of eigenvalues of predictor variables
#' @param R2 Coefficient of determination
#' @param ntest (Optional) Number of test samples
#' @param muX (Optional) Mean vector of predictor variables
#' @param muY (Optional) Mean vector of response variables
#' @param sim.obj (Optional) Previously fitted simulation object, the parameters will be taken from the object
#' @param lambda.min (Optional) Minimum value that eigenvalues can be
#' @return simrel object (A list)
#' @rdname simrel
#' @export
Simrel <- R6::R6Class(
  "Simrel",
  private = list(
    ..parameters = list(
      n          = 100,
      p          = 20,
      q          = 10,
      m          = 1,
      relpos     = c(1, 2, 3),
      ypos       = NULL,
      gamma      = 0.8,
      eta        = 0.3,
      lambda.min = 1e-5,
      rho        = NULL,
      R2         = 0.9,
      ntest      = NULL,
      muX        = NULL,
      muY        = NULL,
      type       = "univariate"
    ),
    ..properties = list(
      relpred    = NULL,
      eigen_x    = NULL,
      eigen_w    = NULL,
      sigma_z    = NULL,
      sigma_zinv = NULL,
      sigma_y    = NULL,
      sigma_w    = NULL,
      sigma_zy   = NULL,
      sigma_zw   = NULL,
      sigma      = NULL,
      rotation_x = NULL,
      rotation_y = NULL,
      beta_z     = NULL,
      beta       = NULL,
      Rsq_y      = NULL,
      Rsq_w      = NULL,
      minerror   = NULL
    ),
    ..get_cov = function(pos, Rsq, eta, p, lambda){
      out      <- vector("numeric", p)
      alph     <- runif(length(pos), -1, 1)
      out[pos] <- sign(alph) * sqrt(Rsq * abs(alph) / sum(abs(alph)) * lambda[pos] * eta)
      return(out)
    },
    ..get_rotate = function(predPos){
      n    <- length(predPos)
      Qmat <- matrix(rnorm(n ^ 2), n)
      Qmat <- scale(Qmat, scale = FALSE)
      qr.Q(qr(Qmat))
    },
    ..is_pd = function(sigma_mat){
      all(eigen(sigma_mat)$values > 0)
    },
    ..get_eigen = function(gamma, p) {
      return((exp(-gamma * (1:p))) / (exp(-gamma)))
    },
    ..predpos = function(p, q, relpos) {
      relpos_list <- if (!is.list(relpos)) list(relpos) else relpos
      irrelpos <- setdiff(seq_len(p), Reduce(union, relpos_list))
      out <- lapply(seq_along(relpos_list), function(i){
        pos      <- relpos_list[[i]]
        ret      <- c(pos, sample(irrelpos, q[i] - length(pos)))
        irrelpos <<- setdiff(irrelpos, ret)
        return(ret)
      })
      if(!is.list(relpos)) out <- unlist(out)
      return(out)
    },
    ..get_data = function(n, p, sigma, rotation_x, m = 1, rotation_y = NULL){
      sigma_rot <- chol(sigma)
      train_cal <- matrix(rnorm(n * (p + m), 0, 1), nrow = n) %*% sigma_rot
      Z <- train_cal[, (m + 1):(m + p), drop = F]
      X <- Z %*% t(rotation_x)
      W <- train_cal[, 1:m, drop = F]
      Y <- if (all(!is.null(m), m > 1)) W %*% t(rotation_y) else W
      list(y = unname(Y), x = X)
    }
  ),
  active = list(
    list_properties = function(){
      properties <- private$..properties
      properties <- properties[!sapply(properties, is.null)]
      str(properties)
      cat("\nProperties of Simulated Data:\n")
      names(properties)
    },
    list_parameters = function(){
      parameters <- private$..parameters
      parameters <- parameters[!sapply(parameters, is.null)]
      str(parameters)
      cat("\nInput Parameters for Simulation:\n")
      names(parameters)
    }
  ),
  public = list(
    initialize = function(...) {
      self$set_parameters(...)
      type <- self$get_parameters("type")
      ## Adding Properties to Simrel Object
      self$set_properties("relpred", expression({
        p      <- self$get_parameters("p")
        q      <- self$get_parameters("q")
        relpos <- self$get_parameters("relpos")
        out <- private$..predpos(p, q, relpos)
        if (!is.list(relpos)) out <- unlist(out)
        return(out)
      }))
      self$set_properties("eigen_x", expression({
        p     <- self$get_parameters("p")
        gamma <- self$get_parameters("gamma")
        private$..get_eigen(gamma, p)
      }))
      self$set_properties("eigen_w", expression({
        l <- length(self$get_parameters("ypos"))
        if (l == 0) return(1)
        eta <- self$get_parameters("eta")
        private$..get_eigen(eta, l)
      }))
      self$set_properties("sigma_z", expression({
        diag(self$get_properties("eigen_x"))
      }))
      self$set_properties("sigma_zinv", expression({
        diag(1 / self$get_properties("eigen_x"))
      }))
    },
    get_parameters = function(key) private$..parameters[[key]],
    set_parameters = function(...) {
      params <- list(...)
      for (key in names(params)) {
        private$..parameters[[key]] <- params[[key]]
      }
    },
    get_properties = function(key) private$..properties[[key]],
    set_properties = function(key, expression) {
      private$..properties[[key]] <- eval(expression)
    },
    get_data = function(){
      n <- self$get_parameters("n")
      p <- self$get_parameters("p")
      m <- self$get_parameters("m")
      sigma <- self$get_properties("sigma")
      rotation_x <- self$get_properties("rotation_x")
      rotation_y <- self$get_properties("rotation_y")
      data <- private$..get_data(n, p, sigma, rotation_x, m, rotation_y)
      data.frame(y = I(data$y), x = I(data$x))
    }
  )
)


## ---- Class: UniSimrel ----
#' @title Uni-Response Simulation of Linear Model Data
#' @description Simulates univariate linear model data where users can specify few parameters for simulating data with wide range of properties.
#' @import R6
#' @param  n Number of training samples
#' @param p Number of predictor variables
#' @param q Number of relevant predictor variables
#' @param relpos Position of relevant predictor components
#' @param ypos Position of response components while rotation (see details)
#' @param gamma Decay factor of eigenvalues of predictor variables
#' @param R2 Coefficient of determination
#' @param ntest (Optional) Number of test samples
#' @param muX (Optional) Mean vector of predictor variables
#' @param muY (Optional) Mean vector of response variables
#' @param sim.obj (Optional) Previously fitted simulation object, the parameters will be taken from the object
#' @param lambda.min (Optional) Minimum value that eigenvalues can be
#' @return simrel object (A list)
#' @rdname simrel
#' @export
UniSimrel <- R6::R6Class(
  "UniSimrel",
  inherit = Simrel,
  public = list(
    initialize = function(...){
      super$initialize(...)
      ## Adding Properties to Simrel Object
      self$set_properties("sigma_y", expression({1}))
      self$set_properties("sigma_zy", expression({
        relpos <- self$get_parameters("relpos")
        R2 <- self$get_parameters("R2")
        p <- self$get_parameters("p")
        lambda <- self$get_properties("eigen_x")
        eta <- self$get_properties("eigen_w")
        private$..get_cov(pos = relpos, Rsq = R2, p = p, lambda = lambda, eta = eta)
      }))
      self$set_properties("sigma", expression({
        sigma_zy <- self$get_properties("sigma_zy")
        sigma_y <- self$get_properties("sigma_y")
        sigma_z <- self$get_properties("sigma_z")
        out <- rbind(c(sigma_y, t(sigma_zy)), cbind(sigma_zy,  sigma_z))
        unname(out)
      }))
      self$set_properties("rotation_x", expression({
        relpred <- self$get_properties("relpred")
        p <- self$get_parameters("p")
        irrelpred <- setdiff(1:p, unlist(relpred))
        out <- diag(p)
        out[irrelpred, irrelpred] <- private$..get_rotate(irrelpred)
        out[relpred, relpred] <- private$..get_rotate(relpred)
        return(out)
      }))
      self$set_properties("beta_z", expression({
        sigma_zinv <- self$get_properties("sigma_zinv")
        sigma_zy <- self$get_properties("sigma_zy")
        return(sigma_zinv %*% sigma_zy)
      }))
      self$set_properties("beta", expression({
        rotation_x <- self$get_properties("rotation_x")
        beta_z <- self$get_properties("beta_z")
        return(rotation_x %*% beta_z)
      }))
      self$set_properties("Rsq_y", expression({
        beta_z <- self$get_properties("beta_z")
        sigma_zy <- self$get_properties("sigma_zy")
        c(t(beta_z) %*% sigma_zy)
      }))
      self$set_properties("minerror", expression({
        sigma_y <- self$get_properties("sigma_y")
        Rsq <- self$get_properties("Rsq_y")
        c(sigma_y - Rsq)
      }))
    }
  )
)

## ---- Class: MultiSimrel ----
#' @title Multi-Response Simulation of Linear Model Data
#' @description Simulates multivariate linear model data where users can specify few parameters for simulating data with wide range of properties.
#' @import R6
#' @param  n Number of training samples
#' @param p Number of predictor variables
#' @param q Number of relevant predictor variables
#' @param relpos Position of relevant predictor components
#' @param ypos Position of response components while rotation (see details)
#' @param gamma Decay factor of eigenvalues of predictor variables
#' @param R2 Coefficient of determination
#' @param ntest (Optional) Number of test samples
#' @param muX (Optional) Mean vector of predictor variables
#' @param muY (Optional) Mean vector of response variables
#' @param sim.obj (Optional) Previously fitted simulation object, the parameters will be taken from the object
#' @param lambda.min (Optional) Minimum value that eigenvalues can be
#' @return simrel object (A list)
#' @rdname simrel
#' @export
MultiSimrel <- R6::R6Class(
  "MultiSimrel",
  inherit = Simrel,
  public = list(
    initialize = function(...){
      if(missing(...)) {
        super$initialize(
          q = c(6, 7),
          m = 3,
          relpos = list(c(1, 2), c(3, 4, 5)),
          ypos = list(1, c(2, 3)),
          R2 = c(0.7, 0.9),
          type = "multivariate"
        )
      } else {
        super$initialize(...)
      }
      
      ## Adding Properties to Simrel Object
      self$set_properties("sigma_w", expression({
        eigen_w <- self$get_properties("eigen_w")
        m <- self$get_parameters("m")
        diag(c(eigen_w, rep(1, m - length(eigen_w))))
      }))
      self$set_properties("sigma_zw", expression({
        relpos <- self$get_parameters("relpos")
        m <- self$get_parameters("m")
        R2 <- self$get_parameters("R2")
        p <- self$get_parameters("p")
        lambda <- self$get_properties("eigen_x")
        eta <- self$get_properties("eigen_w")
        out <- mapply(private$..get_cov, pos = relpos, Rsq = R2, eta = eta, 
               MoreArgs = list(p = p, lambda = lambda))
        cbind(out, rep(0, m - length(eta)))
      }))
      self$set_properties("sigma", expression({
        sigma_zw <- self$get_properties("sigma_zw")
        sigma_w <- self$get_properties("sigma_w")
        sigma_z <- self$get_properties("sigma_z")
        out <- cbind(rbind(sigma_w, sigma_zw), rbind(t(sigma_zw), sigma_z))
        unname(out)
      }))
      self$set_properties("rotation_x", expression({
        relpred <- self$get_properties("relpred")
        p <- self$get_parameters("p")
        irrelpred <- setdiff(1:p, unlist(relpred))
        out <- diag(p)
        out[irrelpred, irrelpred] <- private$..get_rotate(irrelpred)
        for (pos in relpred) {
          rotMat         <- private$..get_rotate(pos)
          out[pos, pos] <- rotMat
        }
        return(out)
      }))
      self$set_properties("rotation_y", expression({
        ypos <- self$get_parameters("ypos")
        m <- self$get_parameters("m")
        out <- diag(m)
        for (pos in ypos) {
          rotMat         <- private$..get_rotate(pos)
          out[pos, pos]  <- rotMat
        }
        return(out)
      }))
      self$set_properties("sigma_y", expression({
        rotation_y <- self$get_properties("rotation_y")
        sigma_w <- self$get_properties("sigma_w")
        t(rotation_y) %*% sigma_w %*% rotation_y
      }))
      self$set_properties("sigma_zy", expression({
        rotation_y <- self$get_properties("rotation_y")
        sigma_zw <- self$get_properties("sigma_zw")
        rotation_y %*% t(sigma_zw)
      }))
      self$set_properties("sigma_xy", expression({
        rotation_x <- self$get_properties("rotation_x")
        rotation_y <- self$get_properties("rotation_y")
        sigma_zw <- self$get_properties("sigma_zw")
        rotation_y %*% t(sigma_zw) %*% t(rotation_x)
      }))
      self$set_properties("beta_z", expression({
        sigma_zinv <- self$get_properties("sigma_zinv")
        sigma_zw <- self$get_properties("sigma_zw")
        return(sigma_zinv %*% sigma_zw)
      }))
      self$set_properties("beta", expression({
        rotation_x <- self$get_properties("rotation_x")
        rotation_y <- self$get_properties("rotation_y")
        beta_z <- self$get_properties("beta_z")
        return(rotation_x %*% beta_z %*% t(rotation_y))
      }))
      self$set_properties("Rsq_w", expression({
        beta_z <- self$get_properties("beta_z")
        sigma_zw <- self$get_properties("sigma_zw")
        sigma_w <- self$get_properties("sigma_w")
        unname(t(beta_z) %*% sigma_zw %*% solve(sigma_w))
      }))
      self$set_properties("Rsq_y", expression({
        rotation_y <- self$get_properties("rotation_y")
        Rsq_w <- self$get_properties("Rsq_w")
        t(rotation_y) %*% Rsq_w %*% rotation_y
      }))
      self$set_properties("minerror", expression({
        sigma_y <- self$get_properties("sigma_y")
        Rsq <- self$get_properties("Rsq_y")
        unname(sigma_y - Rsq)
      }))
    }
  )
)



## ---- Wrapper Function ----
#' @title Multi-Response Simulation of Linear Model Data
#' @description Simulates multivariate linear model data where users can specify few parameters for simulating data with wide range of properties.
#' @import R6
#' @param  type Number of training samples
#' @param ... All required arguments for different types of simulation
#' @export
simulater <- function(type, ...){
  if (type == "univariate") {
    sobj <- UniSimrel$new(...)
    return(sobj)
  }
  if (type == "multivariate") {
    sobj <- MultiSimrel$new(...)
    return(sobj)
  }
  return(paste(type, "is unknown"))
}