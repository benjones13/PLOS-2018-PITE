# These functions are copies from those in the selectiveInference R package
# See https://github.com/selective-inference/R-software


# Main p-value function

poly.pval <- function(y, G, u, v, sigma, bits=NULL) {
  z = sum(v*y)
  vv = sum(v^2)
  sd = sigma*sqrt(vv)

  rho = G %*% v / vv
  vec = (u - G %*% y + rho*z) / rho
  vlo = suppressWarnings(max(vec[rho>0]))
  vup = suppressWarnings(min(vec[rho<0]))

  pv = tnorm.surv(z,0,sd,vlo,vup,bits)
  return(list(pv=pv,vlo=vlo,vup=vup))
}

# Main confidence interval function

poly.int <- function(y, G, u, v, sigma, alpha, gridrange=c(-100,100),
                     gridpts=100, griddepth=2, flip=FALSE, bits=NULL) {

  z = sum(v*y)
  vv = sum(v^2)
  # cat(vv)
  sd = sigma*sqrt(vv)

  rho = G %*% v / vv
  vec = (u - G %*% y + rho*z) / rho
  vlo = suppressWarnings(max(vec[rho>0]))
  vup = suppressWarnings(min(vec[rho<0]))

  xg = seq(z+gridrange[1]*sd,z+gridrange[2]*sd,length=gridpts)
  fun = function(x) { tnorm.surv(z,x,sd,vlo,vup,bits) }
  int = grid.search(xg,fun,alpha/2,1-alpha/2,gridpts,griddepth)

    tailarea = c(fun(int[1]),1-fun(int[2]))

  if (flip) {
    int = -int[2:1]
    # int.ml = -int.ml[2:1]
    tailarea = tailarea[2:1]
  }

  return(list(int = int,
              # int.ml=int.ml,
              tailarea = tailarea))
}





# Confidence interval function
# prediction of observed benefit for treatment ---------------------------------
poly.int1 <- function(y, G, u, v, sigma, alpha, gridrange=c(-100,100),
                     gridpts=100, griddepth=2, flip=FALSE, bits=NULL) {

  z = sum(v*y)
  vv = sum(v^2)
  # cat(vv)
  sd = sigma*(sqrt(vv))
  sd = sqrt(sigma^2+sd^2)
  rho = G %*% v / vv
  vec = (u - G %*% y + rho*z) / rho
  vlo = suppressWarnings(max(vec[rho>0]))
  vup = suppressWarnings(min(vec[rho<0]))

  fun = function(x) { tnorm.surv(z,x,sd = sd,vlo,vup,bits) }
  # cat("\n poly.int1 -> z=", z, "; sd =", sd,"; a=", vlo,"; b=", vup,"; s = ",sqrt(sigma^2))
  int = tryCatch(
   conf.intervals(z,
                  sd = sd,
                  vlo,vup,
                  mu_min = gridrange[1]-20*sd,
                  mu_max = gridrange[2]+20*sd),
   error = function(e) c(-Inf,Inf)
  )
  tailarea = c(fun(int[1]),1-fun(int[2]))

  if (flip) {
    int = -int[2:1]
    tailarea = tailarea[2:1]
  }

  return(list(int = int, tailarea = tailarea))
}

# Confidence interval function
# observed benefit for two patients with same baseline covariates  -------------
poly.int2 <- function(y, G, u, v, sigma, alpha, gridrange=c(-100,100),
                      gridpts=100, griddepth=2, flip=FALSE, bits=NULL) {

  z = sum(v*y)
  vv = sum(v^2)
  sd = sigma*(sqrt(vv))
  sd = sqrt(2*sigma^2+sd^2)
  rho = G %*% v / vv
  vec = (u - G %*% y + rho*z) / rho
  vlo = suppressWarnings(max(vec[rho>0]))
  vup = suppressWarnings(min(vec[rho<0]))
  fun = function(x) { tnorm.surv(z,x,sd = sd,vlo,vup,bits) }
  int = tryCatch(
    conf.intervals(z,
                   sd = sd,
                   vlo,vup,
                   mu_min = gridrange[1]-20*sd,
                   mu_max = gridrange[2]+20*sd),
    error = function(e) c(-Inf,Inf)
    )
  tailarea = c(fun(int[1]),1-fun(int[2]))

  if (flip) {
    int = -int[2:1]
    tailarea = tailarea[2:1]
  }

  return(list(int = int, tailarea = tailarea))
}


# Returns Prob(Z in [a,b]), where mean can be a vector, based on
# A UNIFORM APPROXIMATION TO THE RIGHT NORMAL TAIL INTEGRAL, W Bryc
# Applied Mathematics and Computation
# Volume 127, Issues 23, 15 April 2002, Pages 365--374
# https://math.uc.edu/~brycw/preprint/z-tail/z-tail.pdf
bryc.tnorm.area <- function(mean=0, sd=1, a, b) {
  a = (a-mean)/sd
  b = (b-mean)/sd
  n = length(mean)
  0 < a & a < Inf
  term1 = term2 = rep(0,n)
  o = (0 <= a & a < Inf)
  oo = -Inf < a & a < 0
  term1[o] = ff(a[o])*exp(-(a[o]^2)/2)
  term1[oo] = 1-ff(-a[oo])*exp(-(a[oo]^2)/2)
  o = (0 <= b & b < Inf)
  oo = -Inf < b & b < 0
  term2[o] = ff(b[o])*exp(-(b[o]^2)/2)
  term2[oo] = 1-ff(-b[oo])*exp(-(b[oo]^2)/2)
  p = (term1-term2)
  p = pmin(1,pmax(0,p))
  p = sign(p)*p
  return(p)
}
ff <- function(z) {
  return((z^2+5.575192695*z+12.7743632)/
           (z^3*sqrt(2*pi)+14.38718147*z*z+31.53531977*z+2*12.77436324))
}
likelihood <- function(x,mean,sd,a,b){
  t1 = (1/(pnorm((b-mean)/sd)-pnorm((a-mean)/sd)))
  oo = !is.finite(t1)
  t1[oo] = 1/bryc.tnorm.area(mean[oo], sd, a, b)
  t2 = (1/(sd*sqrt(2*pi)))
  t3 = exp(-(x-mean)^2/(2*sd^2))
  t1*t2*t3
}
plot_likelihood <- function(x, sd, a, b, mu_min, mu_max){
  mug <- seq(mu_min,mu_max, 0.01)
  l <- likelihood(x, mug, sd = sd, a = a, b = b)
  max <- optimize(likelihood, interval=c(-10, 10), maximum=TRUE, x = x, sd = sd, a = a, b = b)
  plot(mug, l, "l", main = "likelihood")
  abline(v = max$maximum)
  abline(h = max$objective)
}
loglikelihood <- function(x,mean,sd,a,b) {
  t1 = (1/(pnorm((b-mean)/sd)-pnorm((a-mean)/sd)))
  oo = !is.finite(t1)
  t1[oo] = 1/bryc.tnorm.area(mean[oo], sd, a, b)
  t2 = (1/(sd*sqrt(2*pi)))
  t3 = exp(-(x-mean)^2/(2*sd^2))
  log(t1)+log(t2)+log(t3)
}
plot_loglikelihood <- function(x,sd,a,b, mu_min, mu_max){
  mug <- seq(mu_min,mu_max, 0.01)
  l <- loglikelihood(x, mug, sd = sd, a = a, b = b)
  max <- optimize(loglikelihood, interval=c(-10, 10), maximum=TRUE, x = x, sd = sd, a = a, b = b)
  plot(mug, l, "l", main = "log-likelihood")
  abline(v = max$maximum)
  abline(h = max$objective)
}

ll.root <- function(x, mean, sd, a, b, ll.max) {
  loglikelihood(x, mean, sd, a, b) - ll.max + qchisq(0.95, 1)/2
}
plot_ll.root <- function(x,sd,a,b, mu_min, mu_max, ll.max){
  mug <- seq(mu_min,mu_max, 0.01)
  l <- ll.root(x, mug, sd = sd, a = a, b = b, ll.max)
  plot(mug, l, "l", main = "l(theta) - l(hat{theta}) + 3.84/2 ")

}
conf.intervals <- function(x, sd, a, b, mu_min, mu_max, plot=FALSE){
  max <- optimize(loglikelihood, interval=c(mu_min, mu_max),
                  maximum=TRUE, x = x, sd = sd, a = a, b = b)
  conf.high <- uniroot(f = ll.root,
                       interval=c(max$maximum, mu_max),
                       x = x, sd = sd, a = a, b = b, ll.max = max$objective)
  conf.low <- uniroot(f = ll.root,
                      interval=c(mu_min, max$maximum),
                      x = x, sd = sd, a = a, b = b, ll.max = max$objective)
  if (plot){
    plot_ll.root(x,sd,a,b, mu_min, mu_max, max$objective)
    abline(h=0)
    abline(v=c(conf.low$root, conf.high$root), col="red")
  }

  c(conf.low$root, conf.high$root)
}
##############################
## Calculate the density of the convolution of a centered normal with variance s2
## And a truncated normal with mean sd a b.
dNTN <- function(x, s2=1, mean=0, sd=1, a=-Inf, b=Inf){
  sigma = sd
  sigma2 = sd^2
  s=sqrt(s2)
  # s2=s^2
  alpha = (s2*(x-mean))/(s2+sigma2)
  beta2 = (s2*sigma2)/(s2+sigma2)
  beta = sqrt(beta2)
  c = (mean - b)/sigma
  d = (mean - a)/sigma
  gamma = (sqrt(2*pi)*beta)/(2*pi*s*sigma*(pnorm(d) - pnorm(c)))
  gamma = min(.Machine$double.xmax, gamma)
  f.v = gamma*exp(-((x-mean)^2)/(2*(s2+sigma2)))*
    (pnorm((x-a-alpha)/beta)-pnorm((x-b-alpha)/beta))
  f.v
}

## Calculate the cdf of the convolution ----
pNTN <- function(q, s2=1, mean=0, sd=1, a=-Inf, b=Inf, lower.tail = TRUE){
  if (lower.tail) {
    p <- integrate(f = Vectorize(function(x) dNTN(x, s2=s2, mean=mean, sd=sd, a=a, b=b)),
                   lower = q, upper = Inf)
  } else {
    p <- integrate(f = Vectorize(function(x) dNTN(x, s2=s2, mean=mean, sd=sd, a=a, b=b)),
                   lower = -Inf, upper = q)
  }
  p$value
}




##############################

# Assuming that grid is in sorted order from smallest to largest,
# and vals are monotonically increasing function values over the
# grid, returns the grid end points such that the corresponding
# vals are approximately equal to {val1, val2}

grid.search <- function(grid, fun, val1, val2, gridpts=100, griddepth=2) {
  n = length(grid)
  vals = fun(grid)

  ii = which(vals >= val1)
  jj = which(vals <= val2)
  if (length(ii)==0) return(c(grid[n],Inf))   # All vals < val1
  if (length(jj)==0) return(c(-Inf,grid[1]))  # All vals > val2
  # RJT: the above logic is correct ... but for simplicity, instead,
  # we could just return c(-Inf,Inf)

  i1 = min(ii); i2 = max(jj)
  if (i1==1) lo = -Inf
  else lo = grid.bsearch(grid[i1-1],grid[i1],fun,val1,gridpts,
         griddepth-1,below=TRUE)
  if (i2==n) hi = Inf
  else hi = grid.bsearch(grid[i2],grid[i2+1],fun,val2,gridpts,
         griddepth-1,below=FALSE)
  return(c(lo,hi))
}

# Repeated bin search to find the point x in the interval [left, right]
# that satisfies f(x) approx equal to val. If below=TRUE, then we seek
# x such that the above holds and f(x) <= val; else we seek f(x) >= val.

grid.bsearch <- function(left, right, fun, val, gridpts=100, griddepth=1, below=TRUE) {
  n = gridpts
  depth = 1

  while (depth <= griddepth) {
    grid = seq(left,right,length=n)
    vals = fun(grid)

    if (below) {
      ii = which(vals >= val)
      if (length(ii)==0) return(grid[n])   # All vals < val (shouldn't happen)
      if ((i0=min(ii))==1) return(grid[1]) # All vals > val (shouldn't happen)
      left = grid[i0-1]
      right = grid[i0]
    }

    else {
      ii = which(vals <= val)
      if (length(ii)==0) return(grid[1])   # All vals > val (shouldn't happen)
      if ((i0=max(ii))==n) return(grid[n]) # All vals < val (shouldn't happen)
      left = grid[i0]
      right = grid[i0+1]
    }

    depth = depth+1
  }

  return(ifelse(below, left, right))
}

# Returns Prob(Z>z | Z in [a,b]), where mean can be a vector

tnorm.surv <- function(z, mean, sd, a, b, bits=NULL) {
  z = max(min(z,b),a)

  # Check silly boundary cases
  p = numeric(length(mean))
  p[mean==-Inf] = 0
  p[mean==Inf] = 1

  # Try the multi precision floating point calculation first
  o = is.finite(mean)
  mm = mean[o]
  pp = mpfr.tnorm.surv(z,mm,sd,a,b,bits)

  # If there are any NAs, then settle for an approximation
  oo = is.na(pp)
  if (any(oo)) pp[oo] = bryc.tnorm.surv(z,mm[oo],sd,a,b)

  p[o] = pp
  return(p)
}

# Returns Prob(Z>z | Z in [a,b]), where mean cane be a vector, using
# multi precision floating point calculations thanks to the Rmpfr package

mpfr.tnorm.surv <- function(z, mean=0, sd=1, a, b, bits=NULL) {
  # If bits is not NULL, then we are supposed to be using Rmpf
  # (note that this was fail if Rmpfr is not installed; but
  # by the time this function is being executed, this should
  # have been properly checked at a higher level; and if Rmpfr
  # is not installed, bits would have been previously set to NULL)
  if (!is.null(bits)) {
    z = Rmpfr::mpfr((z-mean)/sd, precBits=bits)
    a = Rmpfr::mpfr((a-mean)/sd, precBits=bits)
    b = Rmpfr::mpfr((b-mean)/sd, precBits=bits)
    return(as.numeric((Rmpfr::pnorm(b)-Rmpfr::pnorm(z))/
                      (Rmpfr::pnorm(b)-Rmpfr::pnorm(a))))
  }

  # Else, just use standard floating point calculations
  z = (z-mean)/sd
  a = (a-mean)/sd
  b = (b-mean)/sd
  return((pnorm(b)-pnorm(z))/(pnorm(b)-pnorm(a)))
}

# Returns Prob(Z>z | Z in [a,b]), where mean can be a vector, based on
# A UNIFORM APPROXIMATION TO THE RIGHT NORMAL TAIL INTEGRAL, W Bryc
# Applied Mathematics and Computation
# Volume 127, Issues 23, 15 April 2002, Pages 365--374
# https://math.uc.edu/~brycw/preprint/z-tail/z-tail.pdf

bryc.tnorm.surv <- function(z, mean=0, sd=1, a, b) {
  z = (z-mean)/sd
  a = (a-mean)/sd
  b = (b-mean)/sd
  n = length(mean)

  term1 = exp(z*z)
  o = a > -Inf
  term1[o] = ff(a[o])*exp(-(a[o]^2-z[o]^2)/2)
  term2 = rep(0,n)
  oo = b < Inf
  term2[oo] = ff(b[oo])*exp(-(b[oo]^2-z[oo]^2)/2)
  p = (ff(z)-term2)/(term1-term2)

  # Sometimes the approximation can give wacky p-values,
  # outside of [0,1] ..
  #p[p<0 | p>1] = NA
  p = pmin(1,pmax(0,p))
  return(p)
}

ff <- function(z) {
  return((z^2+5.575192695*z+12.7743632)/
         (z^3*sqrt(2*pi)+14.38718147*z*z+31.53531977*z+2*12.77436324))
}

# Return Prob(Z>z | Z in [a,b]), where mean can be a vector, based on
# Riemann approximation tricks, by Max G'Sell

gsell.tnorm.surv <- function(z, mean=0, sd=1, a, b) {
  return(max.approx.frac(a/sd,b/sd,z/sd,mean/sd))
}


##############################

forwardStop <- function(pv, alpha=.10){
  if (alpha<0 || alpha>1) stop("alpha must be in [0,1]")
  if (min(pv,na.rm=T)<0 || max(pv,na.rm=T)>1) stop("pvalues must be in [0,1]")
  val=-(1/(1:length(pv)))*cumsum(log(1-pv))
  oo = which(val <= alpha)
  if (length(oo)==0) out=0
  else out = oo[length(oo)]
  return(out)
}

##############################

aicStop <- function(x, y, action, df, sigma, mult=2, ntimes=2) {
  n = length(y)
  k = length(action)
  aic = numeric(k)
  G = matrix(0,nrow=0,ncol=n)
  u = numeric(0)
  count = 0

  for (i in 1:k) {
    A = action[1:i]
    aic[i] = sum(lsfit(x[,A],y,intercept=F)$res^2) + mult*sigma^2*df[i]

    j = action[i]
    if (i==1) xtil = x[,j]
    else xtil = lsfit(x[,action[1:(i-1)]],x[,j],intercept=F)$res
    s = sign(sum(xtil*y))

    if (i==1 || aic[i] <= aic[i-1]) {
      G = rbind(G,s*xtil/sqrt(sum(xtil^2)))
      u = c(u,sqrt(mult)*sigma)
      count = 0
    }

    else {
      G = rbind(G,-s*xtil/sqrt(sum(xtil^2)))
      u = c(u,-sqrt(mult)*sigma)
      count = count+1
      if (count == ntimes) break
    }
  }

  if (i < k) {
    khat = i - ntimes
    aic = aic[1:i]
  }
  else khat = k

  return(list(khat=khat,G=G,u=u,aic=aic,stopped=(i<k)))
}

#these next two functions are used by the binomial and Cox options of fixedLassoInf

mypoly.pval.lee=
function(y, A, b, eta, Sigma, bits=NULL) {
    # compute pvalues from poly lemma:  full version from Lee et al for full matrix Sigma
    nn=length(y)
    eta=as.vector(eta)
  temp = sum(eta*y)
   vv=as.numeric(matrix(eta,nrow=1,ncol=nn)%*%Sigma%*%eta)
   cc = Sigma%*%eta/vv

 z=(diag(nn)-matrix(cc,ncol=1)%*%eta)%*%y
    rho=A%*%cc

  vec = (b- A %*% z)/rho
  vlo = suppressWarnings(max(vec[rho<0]))
  vup = suppressWarnings(min(vec[rho>0]))
  sd=sqrt(vv)
  pv = tnorm.surv(temp,0,sd,vlo,vup,bits)
  return(list(pv=pv,vlo=vlo,vup=vup,sd=sd))
}



mypoly.int.lee=
   function(y,eta,vlo,vup,sd, alpha, gridrange=c(-100,100),gridpts=100, griddepth=2, flip=FALSE, bits=NULL) {
    # compute sel intervals from poly lemmma, full version from Lee et al for full matrix Sigma

  temp = sum(eta*y)

  xg = seq(gridrange[1]*sd,gridrange[2]*sd,length=gridpts)
  fun = function(x) { tnorm.surv(temp,x,sd,vlo,vup,bits) }

  int = grid.search(xg,fun,alpha/2,1-alpha/2,gridpts,griddepth)
  tailarea = c(fun(int[1]),1-fun(int[2]))

  if (flip) {
    int = -int[2:1]
    tailarea = tailarea[2:1]
  }

  return(list(int=int,tailarea=tailarea))
}



mydiag=function(x){
    if(length(x)==1) out=x
    if(length(x)>1) out=diag(x)
       return(out)
   }

