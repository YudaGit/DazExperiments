from pathlib import Path
import csv
p=Path('/Users/prefabteam_ysl/Developer/DazExperiments/Projects/Encoding2526/Enc_smallN_2nd/AnalysesR/results/manuscript_20261111')
f=list(csv.DictReader((p/'fitrows.csv').open()))
labels={'shared_bias':'Shared + bias','shared_no_bias':'Shared, no bias','duration_bias':'Duration + bias'}
rows=[]
for z in f:
    rows.append(f"{z['ID']} & {'Cauchy' if z['Family']=='cauchy' else 'MaxGumbel'} & {labels[z['Variant']]} & {z['Parameters']} & {float(z['NLL']):.2f} & {float(z['BIC']):.2f} \\\\")
table='\n'.join(rows)
text=r'''\subsection{Experiment 3}

\subsubsection{Descriptive Recall Performance}

Redundant colours were recalled more precisely than the accompanying unique colours at both exposure durations. This advantage was present for both participants and in both mixed-array contexts (Table~\ref{tab:exp3_descriptive}). Longer exposure reduced circular SD in every condition, but its effects on R and NR recall differed between participants. For YL, the duration-related reduction was larger for NR than R targets in both contexts. For FP, the reduction was slightly larger for R targets. Thus, the redundancy advantage was replicated, while its change with exposure duration was not identical across participants.

\begin{table}[htbp]
\centering
\caption{Circular SD of recall errors in mixed arrays, in degrees.}
\label{tab:exp3_descriptive}
\begin{tabular}{llrrrr}
\hline
Participant & Array & R, 50 ms & NR, 50 ms & R, 250 ms & NR, 250 ms \\
\hline
YL & S4C2 & 19.51 & 37.97 & 17.12 & 27.62 \\
YL & S6C4 & 35.09 & 92.81 & 30.12 & 74.19 \\
FP & S4C2 & 20.94 & 27.06 & 17.99 & 25.74 \\
FP & S6C4 & 27.47 & 56.00 & 18.54 & 48.15 \\
\hline
\end{tabular}
\par\smallskip
\begin{minipage}{0.95\linewidth}
\small\textit{Note.} S denotes physical set size and C denotes unique-colour count. R and NR denote redundant- and nonredundant-colour targets, respectively. Lower circular SD indicates more precise recall. Values summarise the usable trials from all ten sessions per participant.
\end{minipage}
\end{table}

% Insert the descriptive figures here. Refreshed source figures are
% data/YL_preliminary_error_and_cirSD.png and
% data/FP_preliminary_error_and_cirSD.png in the dated analysis folder.

\subsubsection{Can the Constrained Models Account for the Recall Distributions?}

We fitted both model families to the complete datasets using the same load, repetition, and allocation constraints. Analyses included 4,893 trials for YL and 4,895 for FP. Both families used unique-colour count as memory load, a fixed square-root repetition factor, two representational states, and the same rule for preferential R membership. These constraints acted on Cauchy dispersion and MaxGumbel signal amplitude, respectively. The Cauchy model generated reports by combining a latent representation with Gaussian response-mapping variability; MaxGumbel generated reports through unit-scale Gumbel noise and maximum-signal selection. Their response mechanisms were therefore distinct despite their matched allocation constraints.

Each model was fitted separately to each participant by maximum likelihood, using 20 optimisation starts. The best solution converged in every fit. We first fitted a shared-quality model in which the two state-quality parameters were constant across durations, while state membership and R bias could vary with duration. We then removed R bias or allowed state quality to differ between durations. These variants contained 13, 15, or 17 free parameters (Table~\ref{tab:exp3_model_comparison}). Lower negative log likelihood (NLL) indicates better fit, whereas lower BIC indicates a better balance of fit and parameter count. Parameter estimates reported here are maximum-likelihood point estimates.

Both shared-quality models reproduced the main differences between the narrow R distributions and the broader baseline and NR distributions. Their predictions were often similar, although MaxGumbel achieved lower NLL for both participants. With the same 15 parameters, its BIC was lower than the corresponding Cauchy model by 29.69 for YL and 29.07 for FP. Thus, the observed distributions could be described under both response architectures, with the quantitative comparison favouring MaxGumbel within this matched structure.

% Insert fitted-distribution figures here:
% figures/YL_shared_predictions.png and figures/FP_shared_predictions.png.
% Histograms show observed errors; red and blue curves show the shared-quality
% Cauchy and MaxGumbel predictions. Panel heights have separate density scales.

\begin{table}[htbp]
\centering
\caption{Experiment 3 model fits to the complete datasets.}
\label{tab:exp3_model_comparison}
\small
\begin{tabular}{lllrrr}
\hline
Participant & Family & Structure & $k$ & NLL & BIC \\
\hline
''' + table + r'''
\hline
\end{tabular}
\par\smallskip
\begin{minipage}{0.98\linewidth}
\small\textit{Note.} Shared and Duration denote shared and duration-specific state quality; $k$ is the number of free parameters. All variants retain the fixed load and repetition constraints and ten array-by-duration membership parameters. The shared-quality model includes two duration-specific bias parameters; the no-bias model fixes both to zero. The duration-specific-quality model adds two state-quality parameters while retaining the same bias structure. The response-mapping width in Cauchy and tuning-shape parameter in MaxGumbel were estimated freely and shared across conditions. BIC comparisons use the same trials within each participant.
\end{minipage}
\end{table}

\subsubsection{Is Preferential Membership Needed Beyond Repetition Strengthening?}

Preferential membership improved fit beyond the repetition factor, but its support depended on participant and model family. Removing bias left the repetition benefit intact and forced R and NR targets in the same array to share the same better-state probability. In the shared-quality Cauchy model, this restriction increased NLL by 123.66 for YL and 47.02 for FP. Even after accounting for the two additional bias parameters, BIC favoured preferential membership by 230.33 and 77.04, respectively. For YL, the corresponding MaxGumbel comparison also favoured bias, with an NLL improvement of 47.99 and a BIC advantage of 78.99.

FP's MaxGumbel fit showed a smaller benefit from preferential membership. Adding bias reduced NLL by only 3.13, insufficient to offset the two additional parameters: BIC favoured the no-bias variant by 10.73. Preferential membership therefore made a substantial contribution to both Cauchy fits and YL's MaxGumbel fit, whereas FP's shared-quality MaxGumbel model described the data more parsimoniously without it. This comparison evaluates bias within the shared-quality structure.

% Optional comparison figures:
% figures/YL_bias_comparison.png and figures/FP_bias_comparison.png.

\subsubsection{Does Exposure Duration Change State Quality, Membership, or Both?}

Longer exposure increased estimated better-state capacity when state quality was held constant. In the shared-quality Cauchy model, expected capacity in S6C4 increased from 0.70 to 1.57 for YL and from 1.71 to 2.29 for FP. In S6C6, it increased from 0.91 to 2.04 and from 1.59 to 2.57, respectively. The shared-quality MaxGumbel fits showed the same direction of change in these contexts. Because within-state quality and the response parameter were shared across durations, these fits attributed duration-related improvements to changes in membership, including its preferential allocation to R targets.

Allowing state quality to vary with duration tested whether membership changes alone provided a sufficient account. For YL's Cauchy fit, the two additional quality parameters improved NLL by 6.60, but BIC favoured shared quality by 3.79. For FP, the improvement was larger: NLL decreased by 11.92 and BIC favoured duration-specific quality by 6.84. In that fit, both better- and worse-state Cauchy dispersion decreased with longer exposure. MaxGumbel favoured duration-specific quality for both participants, with BIC improvements of 14.25 for YL and 7.29 for FP relative to the corresponding shared-quality models.

Capacity estimates depended on whether state quality could change. YL's estimates generally increased with duration under both quality structures, apart from the near-ceiling two-colour baseline. For FP, allowing quality to improve reversed the estimated capacity change in the larger arrays: fewer representations occupied the better state, but the quality of both states improved. Longer exposure therefore improved recall, while its attribution to more frequent better-state membership or narrower within-state representations depended on the fitted structure.

% Insert figures/capacity_quality_comparison.png here.
% Caption should identify expected capacity as K = N W and distinguish
% shared from duration-specific state quality. Points are fitted estimates,
% not posterior means; no uncertainty intervals have yet been estimated.

\subsubsection{Interim Discussion}

Experiment 3 replicated the redundancy advantage and showed that repetition strengthening alone was insufficient within both shared-quality Cauchy fits. Preferential better-state membership accounted for additional differences between R and NR recall, consistent with unequal allocation among representations. This contribution was also supported by YL's MaxGumbel fit, whereas FP's MaxGumbel comparison favoured the simpler no-bias account.

The duration comparisons qualify the interpretation of better-state capacity. Shared-quality models explained improved recall through increased membership, but allowing state quality to change provided a competitive or better account, particularly for FP. The present fits therefore support separating within-state quality from membership when interpreting duration effects; they do not establish a model-independent increase in better-state capacity. The fixed sample-size and repetition constraints were common to all variants, so their exponents were not independently tested in these comparisons.

Independent response calibration remains a separate step in evaluating the memory--response decomposition. The fits reported here estimated response-mapping width freely for both participants; they did not fix it to visible-colour matching estimates. YL's matching session is available for a subsequent calibration analysis, whereas FP's matching data are not yet available. These results establish the current fit comparisons without treating the response component as independently calibrated.
'''
(p/'Experiment3_Results_draft.tex').write_text(text)
import shutil
shutil.copy(__file__, p/'scripts/write_exp3_results_draft.py')
print(p/'Experiment3_Results_draft.tex')
