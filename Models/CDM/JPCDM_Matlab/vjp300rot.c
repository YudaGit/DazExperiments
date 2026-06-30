/* ==========================================================================
%  Circular diffusion model 300-step C version. Jones-Pewsey distribution.
%  Uses <rotcat> rather than <vdcircle> so that eta_rad and eta_tan
%  are correct for all phase angles of the stimulus.
%  December 22, 2022
%
%  [T, Gt, Theta, Ptheta, Mt] = vjp300rot(P, tmax, noise);
%   P = [nunorm, kappa, eta, phi, psi, sigma, a]
%  
%  Building: mex vjp300rot.c -lgsl -lgslcblas -lm
% =========================================================================== 
*/

#include <mex.h>
#include <math.h>
#include <gsl/gsl_sf_bessel.h>
#include <gsl/gsl_math.h>

#define kmax 50  /* Maximum number of eigenvalues in dhamana */
#define nw 50    /* Number of steps on circle */
#define nwplus1 51    /* Close the domain */
#define sz 300   /* Number of time steps */
#define nwplus1_sz (nwplus1*300)  
#define NP 7     /* Number of input parameters */
#define njsteps 21 /* Number of steps in drift angle distribution */

const double pi = 3.141592653589793, eps = 1e-15;

double Pmt[nwplus1], J0k[kmax], J0k_squared[kmax], J1k[kmax], Commonscale[sz], 
       Gth[sz], Gts[sz],T0h[sz],T0s[sz], Gt0[sz],
       Gti[nwplus1_sz], Pthetai[nwplus1], Mti[nwplus1];
       
void dserafin(double *T, double *Gt0, double *P0, double tmax) {
    /* 
       -------------------------------------------------------
       Asymptotic approximation to the first-passage-time density
       for Bessel process based on Serafin (2017), p. 3172.
       ----------------------------------------------------------
   */
    const int v = 0; /* 2D process */    
    const double x = 1e-6; /* starting point */
    double a, a2, sigma, sigma2, scale, h, hs, t, jv1, w1, w2, w3, w4, w5; 
    int i, k;

    a = P0[0];
    sigma = P0[1];
    sigma2 = sigma * sigma;
    a2 = a * a;
    scale = a2 / sigma2;
    h = tmax / sz;
    hs = h / scale; /* Rescaled time for nonunity a and sigma */

    jv1 = gsl_sf_bessel_zero_J0(1);

    T[0] = 0;
    Gt0[0] = 0;
 
    /* double gsl_pow_int(double x, int n)*/
       
    for (i = 1; i < sz; i++) {
         T[i] = i * h;
         t = i * hs; /* Compute on scaled time axis */
         w1 = (1 - x) * gsl_pow_int(1 + t, v + 2);
         w2 = pow(x + t, v + 0.5) * pow(t, 1.5);
         w3 = (1 - x) * (1 - x) / (2 * t);
         w4 = jv1 * jv1 * t / 2.0;
         w5 = exp(-w3 - w4);
         Gt0[i] = w1 * w5 / w2;
         Gt0[i] /= scale;
         
    }     
}  /* dserafin */                

void dhamana(double *T, double *Gt0, double *P0, double h) {
    /* 
      ---------------------------------------------------------------
       First-passage-time density for Bessel process.
       Computes roots of J0 using Gnu GSL library.
      ----------------------------------------------------------------
    */
     
    double a, a2, sigma, sigma2, scaler; 
    int i, k;

    a = P0[0];
    sigma = P0[1];
    sigma2 = sigma * sigma;
    a2 = a * a;
    scaler = sigma2 / a2;
    
    T[0] = 0;
    Gt0[0] = 0;

    /* Roots of J0k */
    for (k = 0; k < kmax; k++) { 
        J0k[k] = gsl_sf_bessel_zero_J0(k+1);
    }

    /* Evaluate Bessel function at the roots */
    for (k = 0; k < kmax; k++) {
        J0k_squared[k] = J0k[k] * J0k[k];
        /* J1k[k] = j1(J0k[k]); */  /* besselj in Gnu library */
        J1k[k] = gsl_sf_bessel_J1(J0k[k]); /* GSL library */
    }
    for (i = 1; i < sz; i++) {    
        T[i] = i * h;
        Gt0[i] = 0;
        for (k = 0; k < kmax; k++) {
            Gt0[i] += J0k[k] * exp(-J0k_squared[k] * sigma2 * T[i] / (2.0 * a2)) / J1k[k]; 
        }
        Gt0[i] *= scaler;
        /* if (i <= badix) {
            Gt0[i] = 0;
        } */
    }
}; /* dhamana */


void bessel2(double *T, double *Gt0, double *P0, double tmax, double noise) {
      int i, j;
      
      dhamana(T0h, Gth, P0, tmax);
      dserafin(T0s, Gts, P0, tmax);
      
      /* Find first time index for which dhamana exceeds noise floor */
      i = 0; 
      while (Gth[i] < noise && i < sz) {
          i++;
          /*mexPrintf("i =  %4d,  Gti = %12.9f\n"); */
      }     
      for (j = 0; j < sz; j++){
           T[j] = T0h[j];
           /* if less than the noise threshold, dhamana else dserafin */
           if (j <= i) {
               Gt0[j] = Gts[j];
           } else {
               Gt0[j] = Gth[j];
           }    
      }
} /* bessel2 */

void grtrot300(double *T, double *Gt, double *Theta, double *Ptheta, double *Mt, 
              double *P, double tmax, double noise) {
    /* -----------------------------------------------------------------------------------------------
       Calculate first-passage-time density and response probabilities for circular diffusion process
      ------------------------------------------------------------------------------------------------ */
    const double minve = 0.02; /* Underflow in drift */
    double Gt0[sz], P0[2];
    double w, two_pi, h, v1, v2, eta1, eta2, sigma, a, sigma2, mt, a1, a2, b,
           rho, kappa, A, B, C, D, E, F, G, H, v1_2, v2_2, eta1_2, eta2_2, GH_minus_rho2_on_kappa,
           exponent_zt, zt, totalmass, covxy, varx_vary, phi, eta1_minus_eta2, eta1_plus_eta2,
           sin_2_phi, varx, vary, rhox;

    int i, k;

    two_pi = 2.0 * pi;
    w = 2.0 * pi / nw;
  
    /* Parameters */
    h = tmax / sz; 
    v1 = P[0];
    v2 = P[1];
    eta1 = P[2];
    eta2 = P[3];
    if (eta1 <= minve) {
       eta1 = minve;
    }
    if (eta2 < minve) {
       eta2 = minve;
    }     
    sigma = P[4];
    a = P[5];

    /*mexPrintf("w= %6.4f h = %6.4f \n", w, h);    */
    sigma2 = sigma * sigma; 
    eta1_2 = eta1 * eta1;
    eta2_2 = eta2 * eta2;
    v1_2 = v1 * v1;
    v2_2 = v2 * v2;
   /* Correlation depends on rotation of drift vectors. */
    phi = atan(v2 / v1);  /* Rotation angle */
    eta1_minus_eta2 = eta1 - eta2;
    eta1_plus_eta2 = eta1 + eta2;
    sin_2_phi = sin(2.0 * phi);
    covxy = sin_2_phi * eta1_minus_eta2 * eta1_plus_eta2;
    varx = cos(phi) * cos(phi) * eta1_2 + sin(phi) * sin(phi) * eta2_2;
    vary = cos(phi) * cos(phi) * eta2_2 + sin(phi) * sin(phi) * eta1_2;
    /* varx_vary = 4.0 * eta1_2 * eta2_2 + sin_2_phi * sin_2_phi * eta1_minus_eta2 * eta1_minus_eta2 *
            eta1_plus_eta2 * eta1_plus_eta2; */

    varx_vary = 4.0 * eta1_2 * eta2_2 + 
              eta1_minus_eta2 * eta1_minus_eta2 * eta1_plus_eta2 * eta1_plus_eta2
                             * sin_2_phi * sin_2_phi; 
    rho = covxy / sqrt(varx_vary); 
    /* rhox = 1 + (4.0 * eta1_2 * eta2_2) / (eta1_minus_eta2 * eta1_minus_eta2 * 
                  eta1_plus_eta2 * eta1_plus_eta2
                  * sin_2_phi * sin_2_phi);
    rho = sqrt(1 / rhox); */

    kappa = sqrt(1.0 - rho * rho);
   /*mexPrintf("v1= %6.4f v2 = %6.4f eta1 = %6.4f eta2 = %6.4f varx = %6.4f vary = %6.4f\n", 
              v1, v2, eta1, eta2, varx, vary); 
    mexPrintf("phi= %6.4f covxy = %6.4f rho = %6.4f varx*vary = %6.3f kappa = %6.4f \n", 
              phi, covxy, rho, varx_vary, kappa); */

    /* Rescale variances */
    eta1 = sqrt(varx);
    eta2 = sqrt(vary);
    eta1_2 = eta1 * eta1;
    eta2_2 = eta2 * eta2;
    /* mexPrintf("New eta1= %6.4f eta2 = %6.4f\n", eta1, eta2);  */

    /* Density for zero-drift process */
    P0[0] = a;
    P0[1] = sigma;

    /* dhamana(T, Gt0, P0, h, badix); */
    bessel2(T, Gt0, P0, h, noise);


    
    /* Response circle (1 x nw) */
    Theta[0] = -pi;
    /* Close the domain */    
    for (i = 1; i <= nw; i++) {
        Theta[i] = Theta[i-1] + w;
    }

   /* Joint RT distribution (nw * sz) - make Matlab conformant */
   for (k = 0; k < sz; k++) {
       for (i = 0; i < nw; i++) {
            a1 = a * cos(Theta[i]) / sigma2;
            a2 = a * sin(Theta[i]) / sigma2;
            b = T[k] / (2.0 * sigma2);
            A = b * eta1_2;
            B = (a1 - 2.0 * b * v1) * eta1;
            C = a1 * v1 - b * v1_2;
            D = b * eta2_2;
            E = (a2 - 2.0 * b * v2) * eta2;
            F = a2 * v2 - b * v2_2;
            G = 1.0 + 2.0 * kappa * A;
            H = 1.0 + 2.0 * kappa * D;
            GH_minus_rho2_on_kappa = (1.0 + 2.0 * (A + D)) + 4.0 * kappa * A * D;
            exponent_zt = (G * E * E + 2.0 * rho * B * E + B * B * H) / (2.0 * GH_minus_rho2_on_kappa);
            /* zt = exp(C + F) * exp(exponent_zt) / sqrt(kappa * GH_minus_rho2_on_kappa);
            Gt[nw * k + i] = sqrt(kappa) * zt * Gt0[k] / two_pi; */
            zt = exp(C + F) * exp(exponent_zt) / sqrt(GH_minus_rho2_on_kappa);
            Gt[(nw + 1) * k + i] =  zt * Gt0[k] / two_pi; 
        }
        /* Close the domain */
        Gt[(nw + 1) * k + nw] = Gt[(nw + 1) * k];            
    } 
    /* Total mass */
    totalmass = 0;
    for (i = 0; i < nw; i++) {
       for (k = 1; k < sz; k++) {
           totalmass += (Gt[nw * k + i] + Gt[nw * (k - 1) + i]) / 2.0;
       } 
    }
    totalmass *= w * h;
    /* mexPrintf("totalmass = %6.4f\n", totalmass);  */
    /* Integrate joint densities to get means hitting probabilities */
   
    
    for (i = 0; i < nw; i++) {
       Ptheta[i] = 0;
       Mt[i] = 0;
       for (k = 1; k < sz; k++) {
           Ptheta[i] += (Gt[(nw + 1) * k + i] + Gt[(nw + 1) * (k - 1) + i]) /2.0;
           Mt[i] += (T[k] * Gt[(nw + 1) * k + i] + T[k - 1] * Gt[(nw + 1) * (k - 1)+ i]) / 2.0; 

       }
       Ptheta[i] *= h / totalmass;
       Mt[i] *= h / Ptheta[i] / totalmass;  
   }
  /* Close the domain but don't double-count the mass */
   Ptheta[nw] = Ptheta[0];
   Mt[nw] = Mt[0];
 /* mt = a * gsl_sf_bessel_I1(a * munorm/(sigma * sigma)) 
            / gsl_sf_bessel_I0(a * munorm/(sigma * sigma)) / munorm; 
   mexPrintf("mt = %6.4f\n", mt); */
} /* grtrot300 */

double jonespewsey(double theta, double varphi, double kappa, double psi) {
   /* Jones-Pewsey distribution (up to normalization */
   double arg, jparg, jp, one_on_psi, kappa_psi;
   
   if (psi == 0) {
        psi = 1e-9;
   }
   one_on_psi = 1.0 / psi;
   kappa_psi = kappa * psi;

   jparg = (cosh(kappa_psi) + sinh(kappa_psi) * cos(theta - varphi));
   jp = pow(jparg, one_on_psi) / (2.0 * pi);
   return jp;
}



void vjp300rot(double *T, double *Gt, double *Theta, double *Ptheta, double *Mt, 
              double *P, double tmax, double noise) {
    /* ----------------------------------------------------------------------------
       Power of cosine distance drift rate variability
       ---------------------------------------------------------------------------- */
    double Pj[6],  ThetaMu[njsteps], ProbMu[njsteps];
    double v1, v2, phi, nunorm, kappa, sigma, a, psi, eta, 
           inc, sumprob, thetaj, mu1, mu2, sumrj;
    int i, j, k, r, l;

    nunorm= P[0];
    kappa = P[1];
    eta = P[2];
    phi = P[3];
    psi = P[4];
    sigma = P[5];
    a = P[6];

   /* mexPrintf("nunorm = %6.3f kappa = %4.3f  phi = %6.3f psi = %6.3f, sigma = %6.3f, a = %6.3f\n", 
    nunorm, kappa, phi, psi, sigma, a);*/


    /* Across trial variability in phase angle, drift norm is constant. */
    inc = 2 * pi / njsteps;
    sumprob = 0;
    /*mexPrintf("%6.3f %6.3f \n", kappa, psi);*/
    for (j = 0; j < njsteps; j++) {
       ThetaMu[j] = -pi + inc / 2 + j * inc;
       /* ProbMu[j] = exp(-kappa * pow(1 - cos(ThetaMu[j]), rho));   vjp */
       ProbMu[j] = jonespewsey(ThetaMu[j], 0, kappa, psi); 
       sumprob += ProbMu[j];
       /*mexPrintf("%6d %6.3f %6.3f \n", j, ThetaMu[j], ProbMu[j]); */
    }    

    /* Normalize the vjp mass */
    for (j = 0; j < njsteps; j++) {
       ProbMu[j] /= sumprob; 
    } 
    /* mexPrintf("sumprob = %6.3f\n", sumprob); */
 
   /* Initialize the output structures */
    for (k = 0; k <= nw; k++) {
         Ptheta[k] = 0; 
         Mt[k] = 0;       
         for (i = 0; i < sz; i++) {   
             Gt[nwplus1 * k + i] = 0;
         }
     }   
     /* Mix */
     Pj[2] = eta;  /* Radial */
     Pj[3] = 0.01; /* Tangential */
     Pj[4] = sigma;
     Pj[5] = a;

     /* Step across phase angles */
     for (j = 0; j < njsteps; j++) {
         thetaj = ThetaMu[j] + phi;
         mu1 = nunorm * cos(thetaj);
         mu2 = nunorm * sin(thetaj); 
         /*mexPrintf("j =  %4d  mu1 = %6.3f mu2 = %4.3f sigma = %4.3f  a = %4.3f\n", j, mu1, mu2, sigma, a);  */
         Pj[0] = mu1;
         Pj[1] = mu2;
         /* Replaced <vdcircle300> with <grtrot300> because of better eta_rad and eta_tan */
         grtrot300(T, Gti, Theta, Pthetai, Mti, Pj, tmax, noise);
  
         sumrj = 0; 
         for (l = 0; l < nw; l++) {
             sumrj += Pthetai[l];
         }
         /*mexPrintf("sumrj = %6.3f\n", sumrj);*/ 
         for (i = 0; i < nw; i++) {
              Ptheta[i] += ProbMu[j] * Pthetai[i]; 
              Mt[i] += ProbMu[j] * Pthetai[i] * Mti[i];
              for (k = 0; k < sz; k++) {       
                  Gt[nwplus1 * k + i] += ProbMu[j] * Gti[nwplus1 * k + i];
              }
         }
     }
     /* Average */ 
     for (i = 0; i < nw; i++) {
         Mt[i] /= (Ptheta[i] + eps);
     }
     /* Close the domain */
     Mt[nw] = Mt[0];
     Ptheta[nw] = Ptheta[0];
}; /* vjp300rot */


   
 
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
 /*
     =======================================================================
     Matlab gateway routine.
     =======================================================================
 */
 


double *T, *Gt, *Theta, *Ptheta, *Mt, *P;
 
double tmax, noise;
 
unsigned n, m;

    if (nrhs != 3) {
         mexErrMsgTxt("vjp300rot: Requires 3 input args.");
    } else if (nlhs != 5) {
        mexErrMsgTxt("vjp300rot: Requires 5 output args."); 
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
        mexErrMsgTxt("vjp300rot: Wrong size P");
    } else {
        P = mxGetPr(prhs[0]);
    }
    /* tmax */
    m = mxGetM(prhs[1]);
    n = mxGetN(prhs[1]);
    if (!mxIsDouble(prhs[1]) || !(m * n == 1)) {
        mexErrMsgTxt("vjp300rot: tmax must be a scalar");
    } else { 
        tmax = mxGetScalar(prhs[1]);
    }
    if (tmax <= 0.0) {
        mexPrintf("tmax =  %6.2f \n", tmax);
        mexErrMsgTxt("tmax must be positive");
    } 

    /* noise */
    m = mxGetM(prhs[2]);
    n = mxGetN(prhs[2]);
    if (!mxIsDouble(prhs[2]) || !(m * n == 1)) {
        mexErrMsgTxt("vjp300rot: badi must be a scalar");
    } else { 
        /*badi = mxGetScalar(prhs[2]);
        badix = (int)(badi+0.5); */
        noise = mxGetScalar(prhs[2]);

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

    vjp300rot(T, Gt, Theta, Ptheta, Mt, P, tmax, noise);
}


