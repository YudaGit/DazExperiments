/* ==========================================================================
 % Extended polar three-component model with 3 x psi parameters.
%  Three component circular model: stimulus + antipode + categories
%  [T, Gt, Theta, Ptheta, Mt] = threesphere300pg(P, Abias, Bbias, Qbias, tmax, badix);
%  P = [phi, vnrm, psi1, psi2, psi3, eta1, eta2, eta3, sigma, a, alpha, pi2, pi3, ascale]
%  phi is stimulus angle; psi1, is elevation of stimulus process; psi2 is
%  is elevation of guessing process. Point of nonzero psi1 is to account
%  for shadow mode. 
%  pi2 = antipode, p23 = guessing
   mex threesphere300pgx.c -lgsl  -lgslcblas -lm
% ===========================================================================
*/

#include <mex.h>
#include <math.h>
#include <gsl/gsl_sf_bessel.h>

#define kmax  50             /* Maximum number of eigenvalues in dhamana */
#define ntheta 50       /* 0 - 2*pi */    /**** coarse grained 36 */

#define nphi (ntheta / 2)   /* 0 - pi */
#define sz 300              /* Number of time steps */
#define nw ntheta
#define nwplus1 (nw + 1)    /* Close the domain */
#define nw2 (nphi * ntheta)    
#define nall (nphi * ntheta * sz) 
#define nwplus1_sz (nwplus1 * sz)  
#define NP 14     /* Number of input parameters */
#define NPJ 8     /* Number of parameters in sphere300 */
#define njsteps 21 /* Number of steps in drift angle distribution */
#define ncat 4  /* Number of bias vectors */

const double pi = 3.141592653589793, eps = 1e-15;

double Jvk[kmax], Jv_plus_one[kmax], Jvk_squared[kmax], Jvk_one_and_half[kmax], 
       Pjk[nw2], Mjk[nw2], Commonscale[sz], Gt0[sz], Gtjk[nall],
       Gt1[nwplus1_sz], Gt2[nwplus1_sz], Gt3[nwplus1_sz],
       Ptheta1[nwplus1], Ptheta2[nwplus1], Ptheta3[nwplus1], 
       Mt1[nwplus1], Mt2[nwplus1], Mt3[nwplus1]; 


void d3hamana(double *T, double *Gt, double *P, double h, int badix) {
   /* First-passage time for 3D Bessel process */
    const double v = 0.5, gamma_v_plus_one = 0.886226925452758;
    double a, a2, sigma, sigma2, scaler, mass; 
    int i, k;

    a = P[0];
    sigma = P[1];
    sigma2 = sigma * sigma;
    a2 = a * a;
    scaler = (sigma2 / a2 / 2.0) * 1 / (pow(2, v-1) * gamma_v_plus_one);
    
    T[0] = 0;
    Gt[0] = 0;
   
    /* Roots of J1k */
    for (k = 0; k < kmax; k++) { 
        Jvk[k] = gsl_sf_bessel_zero_Jnu(v, k+1);
        
    }

    /* Evaluate Bessel function at the roots */
    for (k = 0; k < kmax; k++) {
        Jvk_squared[k] = Jvk[k] * Jvk[k];
        Jv_plus_one[k] = gsl_sf_bessel_Jnu(v+1, Jvk[k]); /* "Jnu" computes fractional orders */
        Jvk_one_and_half[k] = pow(Jvk[k], v + 1);  /* j ^(v-1) * j^2 from derivative of exponent */

    }
    mass = 0;
    for (i = 1; i < sz; i++) {    
        T[i] = i * h;
        Gt[i] = 0;
        for (k = 0; k < kmax; k++) {
            Gt[i] += Jvk_one_and_half[k] * exp(-Jvk_squared[k] * sigma2 * T[i] /(2.0 * a2))
            / Jv_plus_one[k]; 
        }
        Gt[i] *= scaler;
        if (i <= badix) {
            Gt[i] = 0;
        }
        mass += Gt[i] * h;
    }
   /* mexPrintf("Bessel mass = %6.3f\n", mass);*/
}

void sphere300(double *T, double *Gtjk, double *Pjk, double *Mjk, double *P, double h, int badix) {
    /* -----------------------------------------------------------------------------------------------
       Calculate first-passage-time density and response probabilities for circular diffusion process
       Surface area of 2-sphere is 4 * pi * r2  ~ 12.566
       Area element is sin(phi) * r^2
       P = [v1, v2, v3, eta1, eta2, eta3, sigma, a]
      ------------------------------------------------------------------------------------------------ */
    const double mineta = 1e-3;
    const double eps = 1e-9;  /* Need this to be very small, or else distorts the means */
    const double S2area = 4.0 * pi;
    double P0[2];
    double dw, h2, v1, v2, v3, eta1, eta2, eta3, sigma, a, sigma2, 
           tscale, theta, phi, area_jk, dw_squared,
           eta1onsigma2, eta2onsigma2, eta3onsigma2,
           G11, G21, G31, G12, G22, G32, Girs1, Girs2, Girs3, gjkl, mass, amass;

    int j, k, l, jk, jkl, jkl_minus_one;

    dw = 2.0 * pi / ntheta;  /* Angular increment, same for all dimensions */
    dw_squared = dw * dw;  
    /* Parameters */
    h2 = h / 2.0;
    v1 = P[0];
    v2 = P[1];
    v3 = P[2];
    eta1 = P[3];
    eta2 = P[4];
    eta3 = P[5];
    sigma = P[6];
    a = P[7];
   /* mexPrintf("dw = %6.4f h =%6.4f \n", dw, h); */
   /* mexPrintf("v1 = %6.4f v2 =%6.4f v3 = %6.4f  eta1 = %6.4f eta2 =%6.4f eta3 = %6.4f  sigma=%6.4f a = %6.4f\n,", 
    v1, v2, v3, eta1, eta2, eta3, sigma, a);  */
    if (eta1 < mineta) {
        eta1 = mineta;
    }
    if (eta2 < mineta) {
        eta2 = mineta;
    }
    if (eta3 < mineta) {
        eta3 = mineta;
    }

    sigma2 = sigma * sigma;
    eta1onsigma2 = eta1 * eta1 / sigma2;
    eta2onsigma2 = eta2 * eta2 / sigma2;
    eta3onsigma2 = eta3 * eta3 / sigma2;
    P0[0] = a;
    P0[1] = sigma;

    /* Density of zero-drift process */
    d3hamana(T, Gt0, P0, h, badix); 
    amass = 0;
    for (j = 0; j < nphi; j++) { 
         for (k = 0; k < ntheta; k++) {               
              for (l = 0; l < sz; l++) {
                   jkl = (ntheta * nphi) * l + nphi * k + j;
                   Gtjk[jkl] = 0;
                   amass += Gtjk[jkl];
              }                            
         }        
   }  
  /* mexPrintf("amass = %10.5f\n", amass);     */

   /* Joint RT distribution on 3-sphere - outer sum is time, ranges are 0-pi, 0-pi, 0-2*pi  */
   amass = 0;
   for (l = 0; l < sz; l++) {
       tscale = sqrt((1 / (1 + eta1onsigma2 * T[l])) * (1 / (1 + eta2onsigma2 * T[l])) *
                     (1 / (1 + eta3onsigma2 * T[l])));
       G11 = 2 * eta1 * eta1 * (1 + eta1onsigma2 * T[l]);   
       G21 = 2 * eta2 * eta2 * (1 + eta2onsigma2 * T[l]);   
       G31 = 2 * eta3 * eta3 * (1 + eta3onsigma2 * T[l]);   
       phi =  dw / 2; 
       for (j = 0; j < nphi; j++) { 
            /*theta = dw;*/
            theta = -pi;
            for (k = 0; k < ntheta; k++) {
                 /* Angle-dependent part of Girsanov transformation in hyperspherical coordinates */

                 G12 = v1 + a * eta1onsigma2 * sin(phi) * cos(theta);
                 G22 = v2 + a * eta2onsigma2 * sin(phi) * sin(theta);
                 G32 = v3 + a * eta3onsigma2 * cos(phi);

                 Girs1 = exp((G12 * G12) / G11 - (v1 * v1) / (eta1 * eta1) / 2.0);
                 Girs2 = exp((G22 * G22) / G21 - (v2 * v2) / (eta2 * eta2) / 2.0);
                 Girs3 = exp((G32 * G32) / G31 - (v3 * v3) / (eta3 * eta3) / 2.0);

                 jk =  nphi * k + j;
                 jkl = (ntheta * nphi) * l + nphi * k + j;
                 area_jk = sin(phi) * dw_squared;                 
                 Gtjk[jkl] = tscale * Girs1 * Girs2 * Girs3 * Gt0[l] * area_jk / S2area;
                 /* amass += Gtjk[jkl]; */
                 amass += Girs1 * Girs2 * Girs3 * Gt0[l] * area_jk / S2area;
                 theta += dw;
                 /* mexPrintf("nall= %6d, jlk = %6d\n", nall, jkl); */  
            }
            phi += dw;   
        }
    }
   /* mexPrintf("amass = %10.5f\n", amass);       */

    /* Integrate joint densities to get hitting probabilities and mean RTs */
     
    phi = dw / 2;     
    for (j = 0; j < nphi; j++) {
        for (k = 0; k < ntheta; k++) {
            jk = nphi * k + j;
            Pjk[jk] = 0;
            Mjk[jk] = 0;                               
            for (l = 1; l < sz; l++) {
                jkl = (ntheta * nphi) * l + nphi * k + j;
                jkl_minus_one = (ntheta * nphi) * (l - 1) + nphi * k + j;
                gjkl = (Gtjk[jkl] + Gtjk[jkl_minus_one]) * h / 2.0;
                Pjk[jk] += gjkl;
                Mjk[jk] += (T[l] - h2) * gjkl;
                /*mexPrintf("nw2= %6d, jk = %6d\n", nw2, jk);  */ 
                /*mexPrintf("nall= %6d, jlk = %6d\n", nall, jkl); */
            }
            Mjk[jk] /= (Pjk[jk] + eps);
           /* mexPrintf("j = %6d k = %6d  Mjk= %10.5f\n", j, k, Mjk[jk]);*/
        }
        phi += dw;
    }
    
   /* Diagnostics... */
  /* mass = 0;  
    for (j = 0; j < nphi; j++) {
        for (k = 0; k < ntheta; k++) {
            jk =  nphi * k + j;
            mass += Pjk[jk]; 
        }
    }
    mexPrintf("mass = %10.5f\n", mass); */      
} /* sphere300 */
 
 
void vsphere300(double *T, double *Gt, double *Theta, double *Ptheta, double *Mt, double *P, double tmax, int badix) {
/* -----------------------------------------------------------------------------------------------
    Integrate the probability mass along the meridans 
    P = [v1, v2, v3, eta1, eta2, eta3, sigma, a]   
------------------------------------------------------------------------------------------------ */
    const double eps = 1e-9;
    double mass, phi, dw, dw_squared, h, smass;
    int j, k, l, jk, jkl, kl;

    /* Diffusion on S^2 */

    h = tmax / sz;
    dw = 2.0 * pi / ntheta;   
    dw_squared = dw * dw;
    sphere300(T, Gtjk, Pjk, Mjk, P, h, badix);
    
    Theta[0] = -pi;
    /* Close the domain */
    for (k = 1; k <= nw; k++) {
         Theta[k] = Theta[k-1] + dw;
    }
    
    /* Close the domain .... */
    for (k = 0; k <= ntheta; k++) {   
         Ptheta[k] = 0;
         Mt[k] = 0;
         for (l = 0; l < sz; l++) {
             /*  Gt[(nw + 1) * k + l] = 0; - this was a bug */
             Gt[(nw + 1) * l + k] = 0; 
         } 
    }

   /* Pool mass along meridians */
   for (j = 0; j < nphi; j++) {
       for (k = 0; k < ntheta; k++) {
           for (l = 0; l < sz; l++) {
               jkl = (ntheta * nphi) * l + nphi * k + j;
               kl = (ntheta + 1) * l + k;
               Gt[kl] +=  Gtjk[jkl] / dw;  /* Make joint mass-density function into density */
            }
            Ptheta[k] += Pjk[nphi * k + j];  /* Make mass function into density */
            Mt[k] += Mjk[nphi * k + j] * Pjk[nphi * k + j];
        }   
   }
   /* Close the domain */          
   for (k = 0; k < ntheta; k++) {
      for (l = 0; l < sz; l++) {
            Gt[(ntheta + 1) * l + nw] = Gt[(ntheta + 1) * l];
      }
      Mt[k] /= (Ptheta[k] + eps);
      Ptheta[k] /= dw;
      /*mexPrintf("k = %6d  Pthk= %10.5f\n", k, Ptheta[k]); */
   }
   /* Close the domain but don't double count the mass */
   Mt[nw] = Mt[0];
   Ptheta[nw] = Ptheta[0];   
   /* Diagnostics - CORRECT! */
  /* smass = 0;
   for (k = 0; k < ntheta; k++) {
       smass += Ptheta[k] * dw;
   }    
  mexPrintf("Sphere mass = %8.5f\n", smass); */            
}

void threesphere300pg(double *T, double *Gt, double *Theta, double *Ptheta, double *Mt, 
              double *P, double *Abias, double *Bbias, double *Qbias, double tmax, int badix) {
    /* ----------------------------------------------------------------------------
       Power of cosine distance drift rate variability
       ---------------------------------------------------------------------------- */
    const double cof = 0.02;
    double Pj[NPJ], phi, vnrm, psi1, psi2, psi3, ThetaMu[njsteps], ProbMu[njsteps];
    double eta1, eta2, eta3, sigma, a, pi2, pi3, alpha, 
           inc, sumprob, mu1, mu2, mu3, sumrj, ascale,  
           sum_bias_cos, sum_bias_sin, distance, circular_distance, decayed_bias;

    int i, j, k, r, l, mix;

    phi = P[0];
    vnrm = P[1];
    psi1 = P[2];
    psi2 = P[3]; 
    psi3 = P[4];
    eta1 = P[5];
    eta2 = P[6];
    eta3 = P[7];
    sigma = P[8];
    a = P[9];
    alpha = P[10];
    pi2 = P[11];
    pi3 = P[12];
    ascale = P[13];
       
    if (pi2 < cof && pi3 < cof) {
        mix = 1;
    } else if (pi2 >= cof && pi3 < cof) {
        mix = 2;
    } else if (pi2 < cof && pi3 >= cof) {
        mix = 3;
    } else {
        mix = 4;
    }
  /* mexPrintf("mix = %6d\n", mix); 
   mexPrintf("pi3 = %6.3f\n", pi3);*/
      /* --------------------------------------------------------------
         Implement 3-component mixture; "guessing" is 4 equally-weighted
         bias categories.             
         Pj = [v1, v2, v3, eta1, eta2, eta3, sigma, a]
       ---------------------------------------------------------------*/

     /* v1 and v2 vary with phi because of categories */
     Pj[3] = eta1;    /* Radial */
     Pj[4] = eta2; /* Tangential  is negligible */
     Pj[5] = eta3;   /* Elevation */
     Pj[6] = sigma;
     Pj[7] = a;    
    /* mexPrintf("eta1 = %6.3f  eta2 = %6.3f  eta3 = %6.3f\n", eta1, eta2, eta3);   */
    /* Initialize the output structures */
    for (i = 0; i <= nw; i++) {
         Ptheta[i] = 0; 
         Mt[i] = 0;       
         for (k = 0; k < sz; k++) {   
             Gt[nwplus1 * k + i] = 0;
         }
     }   

     /* Step across phase angles for the stimulus-driven responses */
     sum_bias_cos = 0;
     sum_bias_sin = 0;
     /* Sum of bias vectors exponentially weighted by distance from phase angle of drift component. */
     for (r = 0; r < ncat; r++) {
          distance = Abias[r] - phi;  /* Distance between phase angle of drift and r-th bias vector */
          circular_distance = 1 - cos(distance);
          decayed_bias = cos(psi1) * vnrm * Bbias[r] * exp(-alpha * circular_distance); 
          sum_bias_cos += decayed_bias * cos(distance);
          sum_bias_sin += decayed_bias * sin(distance);
     }              
     mu1 = cos(psi1) * vnrm + sum_bias_cos; /* Radial */
     /*mexPrintf("psi1 = %6.3f\n", psi1);     */
     mu2 = sum_bias_sin; /* Tangential */  
     mu3 = sin(psi1) * vnrm;  /* Elevation */
     /*mexPrintf("mu1 = %6.3f, vnrm = %6.3f, psi1 = %6.3f psi2 = %6.3f\n", mu1, vnrm, psi1, psi2);  */
     Pj[0] = mu1;
     Pj[1] = mu2;     
     Pj[2] = mu3;
     /*mexPrintf("mu1 = %6.3f, mu2 = %6.3f, mu3 = %6.3f\n", mu1, mu2, mu3);   */
     vsphere300(T, Gt1, Theta, Ptheta1, Mt1, Pj, tmax, badix); 
     
     /* Antipodal process with scaled reversed radial drift */
     if (mix == 2 || mix == 4) {
          /*mexPrintf("psi2 = %6.3f\n", psi2);*/
          mu1 = -ascale * cos(psi2) * vnrm + sum_bias_cos;  /* ### + -> - */  
          mu3 = ascale * sin(psi2) * vnrm ;  /* Elevation */       
          Pj[0] = mu1;
          Pj[1] = mu2;     
          Pj[2] = mu3;
         vsphere300(T, Gt2, Theta, Ptheta2, Mt2, Pj, tmax, badix); 
         /* mexPrintf("mu1 = %6.3f, mu2 = %6.3f, mu3 = %6.3f\n", mu1, mu2, mu3);    */
     }
     if (mix == 3 || mix == 4) {      
         /* Guessing process with elevation psi3 */
         sum_bias_cos = 0;
         sum_bias_sin = 0;
         /* Sum of bias vectors exponentially weighted by distance from phase angle of drift component. */
         for (r = 0; r < ncat; r++) {
              distance = Abias[r] - phi;  /* Distance between phase angle of drift and r-th bias vector */
              circular_distance = 1 - cos(distance);
              decayed_bias = cos(psi3) *  vnrm * Bbias[r] * exp(-alpha * circular_distance); 
              sum_bias_cos += decayed_bias * cos(distance);
              sum_bias_sin += decayed_bias * sin(distance);
         }              
         mu1 = cos(psi3) * vnrm + sum_bias_cos; /* Radial */
         mu2 = sum_bias_sin; /* Tangential */   
         mu3 = sin(psi3) * vnrm;  /* Elevation */
         Pj[0] = mu1;
         Pj[1] = mu2;
         Pj[2] = mu3;
         /*mexPrintf("mu1 = %6.3f, mu2 = %6.3f, mu3 = %6.3f\n", mu1, mu2, mu3);     */
         vsphere300(T, Gt3, Theta, Ptheta3, Mt3, Pj, tmax, badix); 
     }
     /* make all i < nw into i <= nw because of closed domains */ 
     switch (mix) {
        case 1:  /* Pure stimulus */        
           for (i = 0; i <= nw; i++) {
                Ptheta[i] += Ptheta1[i]; 
                Mt[i] += Ptheta1[i] * Mt1[i];  
                for (k = 0; k < sz; k++) {       
                     Gt[nwplus1 * k + i] += Gt1[nwplus1 * k + i];
                }
           }
           break;
        case 2: /* Stimulus + antipodal */
           /* Stimulus */
           for (i = 0; i <= nw; i++) {
                Ptheta[i] += (1.0 - pi2) * Ptheta1[i] + pi2 * Ptheta2[i]; 
                Mt[i] += (1.0 - pi2) * Ptheta1[i] * Mt1[i] + pi2 * Ptheta2[i] * Mt2[i];  
                for (k = 0; k < sz; k++) {       
                     Gt[nwplus1 * k + i] += (1.0 - pi2) * Gt1[nwplus1 * k + i] + pi2 * Gt2[nwplus1 * k + i];
                }
            } 
            break;
        case 3: /* Stimulus + guessing */
             /* Stimulus */
            for (i = 0; i <= nw; i++) {
                Ptheta[i] += (1.0 - pi3) * Ptheta1[i] + pi3 * Ptheta3[i]; 
                Mt[i] += (1.0 - pi3) * Ptheta1[i] * Mt1[i] + pi3 * Ptheta3[i] * Mt3[i];  
                for (k = 0; k < sz; k++) {       
                     Gt[nwplus1 * k + i] += (1.0 - pi3) * Gt1[nwplus1 * k + i] + pi3 * Gt3[nwplus1 * k + i];
                }
            } 
            break;
        case 4: /* Stimulus + antipode + guessing */
           /* Stimulus */
           for (i = 0; i <= nw; i++) {
                Ptheta[i] += (1.0 - (pi2 + pi3)) * Ptheta1[i] + pi2 * Ptheta2[i] + pi3 * Ptheta3[i];  
                Mt[i] += (1.0 - (pi2 + pi3)) * Ptheta1[i] * Mt1[i] 
                       + pi2 * Ptheta2[i] * Mt2[i] + pi3 * Ptheta3[i] * Mt3[i];
                for (k = 0; k < sz; k++) {       
                     Gt[nwplus1 * k + i] += (1.0 - (pi2 + pi3)) * Gt1[nwplus1 * k + i] 
                                          + pi2 * Gt2[nwplus1 * k + i] + pi3 * Gt3[nwplus1 * k + i];
                }
            }            
             break; 
         default:
         mexPrintf("Bad mixing parameter, can't intepret...\n");
     }       
 
    /* Average */ 
    for (i = 0; i < nw; i++) {
        Mt[i] /= (Ptheta[i] + eps);
    }
    /* Close the domain */
    Mt[nw] = Mt[0];
    Ptheta[nw] = Ptheta[0];
}; /* threesphere300pg */


   
 
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
 /*
     =======================================================================
     Matlab gateway routine.
     =======================================================================
 */
 

int badix; 

double *T, *Gt, *Theta, *Ptheta, *Mt, *P, *Abias, *Bbias, *Qbias;
 
double tmax, badi;
 
unsigned n, m;

    if (nrhs != 6) {
         mexErrMsgTxt("threesphere300pg: Requires 6 input args.");
    } else if (nlhs != 5) {
        mexErrMsgTxt("threesphere300pg: Requires 5 output args."); 
    }

    /*
      -----------------------------------------------------------------------
      Check all input argument dimensions.
      -----------------------------------------------------------------------   
    */

    /* P */
    m = mxGetM(prhs[0]);
    n = mxGetN(prhs[0]);
    if (!mxIsDouble(prhs[0]) || !(m * n == NP)) {
        mexPrintf("P is %4d x %4d \n", m, n);
        mexErrMsgTxt("threesphere300pg: Wrong size P");
    } else {
        P = mxGetPr(prhs[0]);
    }
    
   /* Abias */        
    m = mxGetM(prhs[1]);
    n = mxGetN(prhs[1]);
    if (!mxIsDouble(prhs[1]) || !(m * n == ncat)) {
        mexPrintf("Abias is %4d x %4d \n", m, n);
        mexErrMsgTxt("threesphere300pg: Wrong size Abias");
    } else {
        Abias = mxGetPr(prhs[1]);
    }
    m = mxGetM(prhs[2]);
    n = mxGetN(prhs[2]);
    if (!mxIsDouble(prhs[2]) || !(m * n == ncat)) {
        mexPrintf("Bbias is %4d x %4d \n", m, n);
        mexErrMsgTxt("threesphere300pg: Wrong size Bbias");
    } else {
        Bbias = mxGetPr(prhs[2]);               
    }
  
    m = mxGetM(prhs[3]);
    n = mxGetN(prhs[3]);
    if (!mxIsDouble(prhs[3]) || !(m * n == ncat)) {
        mexPrintf("Qbias is %4d x %4d \n", m, n);
        mexErrMsgTxt("threesphere300pg: Wrong size Qbias");
    } else {
        Qbias = mxGetPr(prhs[3]);               
    }    
      
    /* tmax */
    m = mxGetM(prhs[4]);
    n = mxGetN(prhs[4]);
    if (!mxIsDouble(prhs[4]) || !(m * n == 1)) {
        mexErrMsgTxt("threesphere300pg: tmax must be a scalar");
    } else { 
        tmax = mxGetScalar(prhs[4]);
    }
    if (tmax <= 0.0) {
        mexPrintf("tmax =  %6.2f \n", tmax);
        mexErrMsgTxt("tmax must be positive");
    } 

    /* badix */
    m = mxGetM(prhs[5]);
    n = mxGetN(prhs[5]);
    if (!mxIsDouble(prhs[5]) || !(m * n == 1)) {
        mexErrMsgTxt("threesphere300pg: badi must be a scalar");
    } else { 
        badi = mxGetScalar(prhs[5]);
        badix = (int)(badi+0.5); 
    }     
    
    /*
      -----------------------------------------------------------------------
      Create output arrays.
      -----------------------------------------------------------------------
    */
 
    /* T */
    plhs[0] = mxCreateDoubleMatrix(1, sz, mxREAL);
    T = mxGetPr(plhs[0]);
    
    /* Gt */
    plhs[1] = mxCreateDoubleMatrix(nwplus1, sz, mxREAL);
    Gt = mxGetPr(plhs[1]);
    
     /* Theta */
    plhs[2] = mxCreateDoubleMatrix(1, nwplus1, mxREAL);
    Theta = mxGetPr(plhs[2]);


    /* Ptheta */
    plhs[3] = mxCreateDoubleMatrix(1, nwplus1, mxREAL);
    Ptheta = mxGetPr(plhs[3]);

    /* Mt */
    plhs[4] = mxCreateDoubleMatrix(1, nwplus1, mxREAL);
    Mt = mxGetPr(plhs[4]);


    /*
      -----------------------------------------------------------------------
      Run the C-function.
      -----------------------------------------------------------------------
    */

    threesphere300pg(T, Gt, Theta, Ptheta, Mt, P, Abias, Bbias, Qbias, tmax, badix);
}


