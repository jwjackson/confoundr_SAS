/*
Title: Describing Selection Bias from Dependent Censoring
Author: John W. Jackson
Date: 6/13/2018

#INTRODUCTION

This software implements three diagnostics for confounding/selection-bias [1]( that can be used in 
sequence. Built upon the framework of sequential exchangeability, these apply to any study of 
multivariate exposures e.g. time-varying exposures, direct effects, interaction, and censoring. 
The first two diagnostics pertain to the nature of confounding/selection-bias in the data, while the 
third is meant to examine residual confounding/selection-bias after applying certain adjustment methods. 
These tools are meant to help describe confounding/selection-bias in complex data _after_ investigators 
have selected covariates to adjust for (e.g., through subject-matter knowledge).

+ Diagnostic 1 is a generalization of a Table 1 for multivariate exposures (i.e. multiple exposures 
that are distinct in timing or character). It examines whether the prior covariate means are the same 
across exposure groups, among persons who have followed a particular exposure trajectory up to that 
point in time. Like a Table 1 it is meant to describe whether exposure groups have different 
distributions of prior covariates. 

+ Diagnostic 2 assesses whether there is feedback between exposures and confounders over time. If 
present, it indicates the use of g-methods [2] to control for time-varying confounding for any 
definition of time-varying exposure that is explicitly or implicitly multivariate (e.g., ever use at 
time t). The diagnostic examines whether the covariate mean differs across prior exposure groups, 
after adjustment for covariates (that precede the exposure) through inverse probability weighting 
or propensity score stratification.

+ Diagnostic 3 is meant to be applied after investigators have applied the earlier diagnostics and 
have chosen to use g-methods to adjust for confounding/selection-bias. The form of Diagnostic 3 is 
similar to that of Diagnostic 1 in that it is a generalized Table 1 for weighted or stratified data. 
It can be applied to examine residual confounding/selection-bias when inverse probability weights [3] 
are used to fit Marginal Structural Models. It can also be applied to examine residual confounding/
selection-bias when propensity-score stratification [4] is used to implement the parametric 
g-formula [5] or marginal mean weighting through stratification [6].

#CAPABILITIES

The tools can accommodate:

+ Multivariate exposures that are binary or categorical (and continuous, when used in concert with 
  modeling, see below). 

+ Varying temporal depth of covariate history.

+ Unbalanced, sparse data with irregular measurement of exposures/covariates or missing data

+ Artificial censoring rules.

+ Requests for tables/plots at all times, specific times, or averages over selected dimensions of 
  person-time.

+ Data that are not time-indexed.

+ Data that are supplied in "wide" or "long" format (e.g., from the `twang` and `CBPS` packages).

#USAGE

/*
##WORKFLOW

The software is designed to use data that analysts may readily have on hand in analyses of time-varying
 exposures. This includes time-varying exposures, time-varying covariates, time-varying weights (when 
 applicable), and time-varying propensity-score strata (when applicable). Time-varying exposure history
 strata may also be required, and we provide macros to create these from the exposure variables.

The analysis generally proceeds as follows (see below for examples):

1. Format the data. If needed, use `%widen()` to transform person-time indexed dataframe into person 
indexed dataframe. If needed, use `%makehistory_one()` or `%makehistory_two()` to create variables that 
describe exposure history over time.

2. Create a tidy dataframe. Use `%lengthen()` Restructure the "wide" dataframe into a tidy dataframe 
indexed by person id, exposure measurement time, and covariate measurement time. If desired, use 
`%omit_history()` to omit irrelevant covariate history (that will not be used by the analyst to adjust 
for confounding at time $t$)

3. Create a covariate balance table. Take the tidy dataframe output from `lenthen()` and use `%balance()` 
to create a covariate balance table.

4. Create a trellised covariate balance plot using `%makeplot()`.

We need to run the following preliminary code to define the macros in SAS. As an alternative, you could 
try using `options mautosource sasautos` to tell where the macros are stored. Note that the macros require 
the macros mineoperator option to operate properly. The other macro options are not necessary, but can be 
useful when examining the log file.

One last note is that, with variable names, the macros do a lot of work behind the scenes to identify 
which variable measurements are present in the data, without you having to specify them. This substantialy 
reduces user input, but it comes at the cost of making the variable names ** case-sensitive **.

*/

** Clear contents in the output and log windows **;
   dm 'out;clear;log;clear;';

** Clear titles and footnotes **;
   title;
   footnote;

** Clear temporary data sets in the work library **;
   /*proc datasets nolist lib=work memtype=data kill;run;quit;*/

** Macro options **;
   options minoperator /* mprint mlogic symbolgen*/;

** Assign a fileref to each confoundr macro **;
   filename widedef  "/folders/myfolders/code/confoundr_macros/widen.sas";
   filename hist1def "/folders/myfolders/code/confoundr_macros/makehistory_one.sas";
   filename hist2def "/folders/myfolders/code/confoundr_macros/makehistory_two.sas";
   filename longdef  "/folders/myfolders/code/confoundr_macros/lengthen.sas";
   filename omitdef  "/folders/myfolders/code/confoundr_macros/omit_history.sas";
   filename balncdef "/folders/myfolders/code/confoundr_macros/balance.sas";
   filename applyscp "/folders/myfolders/code/confoundr_macros/apply_scope.sas";
   filename plotdef  "/folders/myfolders/code/confoundr_macros/makeplot.sas";
   filename diagnos  "/folders/myfolders/code/confoundr_macros/diagnose.sas";

** Include the confoundr macros **;
  %include widedef;
  %include hist1def;
  %include hist2def;
  %include longdef;
  %include omitdef;
  %include balncdef;
  %include applyscp;
  %include plotdef;
  %include diagnos;

/*

/*

Let's start the output delivery system to catpure output. If you wish to see the log file, you can use 
`proc printto`.

*/


ods output rtf file="/folders/myfolders/CovariateBalanceProject/output/selectionias_output.rtf" style=minimal;


/*
##DEMONSTRATION OF DIAGNOSTIC 1

Suppose we wished to evaluate the comparative effectiveness of five medications on reducing positive and 
negative symptoms scale in patients with schizophrenia. Our simulated data are loosely based on a large 
comparative effectiveness trial, the CATIE Study [7] available from the National Institutes of Mental Health [8].
 Like many trials in this therapeutic area, it is plagued with high rates of dropout, and decisions to leave the 
 study are sometimes informative of worsening symptom response. Such dropout can bias estimates of comparative
 effectiveness, even when dropout rates are similar across arms [8]. 

Inverse Probability of Censoring Weights are often used to correct such dropout under certain assumptions about 
the dropout process. For example, one might assume that the data censored by dropout are Missing at Random given
 most recent measures of covariates and the treatment arm. If the weights are estimated well, the weighted 
 population will exhibit no association between measures of symptom response and later dropout over time. 
 We will use the `confoundr` diagnostics to first describe these associations in the raw data, before weighting, 
 and then after inverse probability weights have been applied.

Let's load the data from our simulated trial:
*/

** Read in the simulated trial data **;
proc import datafile="/folders/myfolders/data/catie_sas.csv"
   out=catie_sim dbms=csv replace;
   getnames=yes;
run;

/*
In this simulated trial, we have five treatment arms, with measures of symptom response, patient-reported outcomes, 
and history of treatment change, measured monthly or quarterly over 18 months (i.e., 0,1,3,6,9,12,15,18). 
We assume that, at each follow-up visit, study dropout is missing at random given the most recent measures, 
the treatment arm, and baseline covariates among those who have remained in the study. Here is a description of 
some baseline covariates:
*/

proc means mean data=catie_sim maxdec=3;
where time=0;
var agegrp: white black other exacer unemployed site:;
title 'means of baseline variables';
run;

/*
(Most of the names are self-explanatory, but exacer refers to a recent hospitalization, and site is the type of 
clinical trial study site).

Here is a description of time-varying covariates:
*/

proc means mean data=catie_sim maxdec=3;
class time;
vars Chgpansstotal cs14 cs16 cs16 calg1 epsmean qoltot Chgpansstotal pctgain phasechangecum studydisc; 
title 'means of time-varying variables';
run;

/*
+ Chgpansstotal: change in total positive and negative syndrome scale (PANSS) from baseline

+ cs14: Drug use scale

+ cs16: Clinical Global Illness (CGI) Severity Index score

+ calg1: Calgary Depression score

+ epsmean: Simpson-Agnes extrapyramidal symptoms score

+ qoltot: Quality of life score

+ pctgain: Percent weight gain from baseline

+ PhaseChangeCum: Number of treatment changes

+ studydisc: Study dropout by time t+1

Before we begin, a few clarifying points about this example may be helpful. Our use of the diagnostics in this 
example is akin to assessing covariate balance across levels of study dropout. That is, we are treating study 
dropout as an exposure. The sticky point here is that we define study dropout as equal to `1` at the last visit 
and `0` at all times before. This means that we are actually evaluating censoring due to study dropout at time t+1, 
indexed at time t, as is done in most applied studies that use inverse probability of censoring weights. 

Now let us proceed with our first step, to use Diagnostic 1 to describe the selection-bias in the data, e.g., 
how the covariates are _not_ missing completely at random over time (that is, showing that censoring due to dropout 
depends at least on measured covariates).

### STEP 1: FORMAT THE DATAFRAME

Our data formats should obey the following conventions:

+ All covariates should be numeric

+ Underscores should *not* appear in any variable root name. 

+ Exposures

++ A common referent value--to which balance metrics will compare all other levels--should be coded as the lowest 
value

++ In our examples, we have two exposures. The first is treatment assignment, `treatgrp`. It is coded numerically
 as one variable, with the numbers indicating treatment arm at baseline. The second exposure is censoring due to 
 study dropout, `studydisc`, which equals $1$ at a participant's last visit when they exit the study prematurely, 
 and $0$ otherwise.

+ Covariates

++ All categorical exposures should be broken up into numeric indicator variables.

++For example, here is a snapshot of our example data (e.g., the simulated person CATIEID=1440 who dropped out 
after completing three study visits:
*/

proc print data=catie_sim;
where CATIEID=1440;
var CATIEID treatgrp studydisc pctgain;
title 'Snapshot of simulated CATIE dataset';
run;

proc contents data=catie_sim;
run;

/*
Our example data is currently indexed by person-id and time (i.e., it's in "long" format). We need to convert our 
data into a version that is indexed by person-id (i.e., "wide" format). We use the `%widen()` macro to accomplish 
this.
*/

%widen(
 output=catie_sim_w,
 input=catie_sim,
 id=CATIEID,
 time=time,
 exposure=studydisc,
 covariate=treatgrp phasechangecum 
             Chgpansstotal cs14 
             cs16 pctgain 
             epsmean qoltot 
             exacer Bpansstotal 
             unemployed, 
 weight_exposure=wtr             
);

proc print data=catie_sim_w;
where CATIEID=1440;
var CATIEID treatgrp_0 treatgrp_1 studydisc_0 studydisc_1 pctgain_0 pctgain_1;
title 'Snapshot of simulated CATIE dataset, after %widen()';
run;

/*
In this "wide" dataset, each variable measurement appears as its own variable, indexed by time 
(e.g., `var_0, var_1, var_3, var_6, ...`), including static covariates that are measured at baseline and do not 
change over time. Generally, any scheme can be used to index time (e.g., `var_0, var_1, var_2, ...`) and it could 
be arbitrarily different for each covariate, supporting heterogeneous covariate measurement schedules as is common 
in clinical trial and cohort studies.

There is one more housekeeping task. If we wish to obtain balance diagnostics that adjust for prior exposure 
history, or for a categorical baseline variable, we can use the `%makehistory_one()` or (`%makehistory_two()`) 
macro to create these measures in the "wide" dataset. This will create a variable that describes exposure 
history through time t-1, indexed at time t, possibly stratified by a baseline covariate measurement. In our 
example, we want to first compare covariate balance across treatment arms. Because this exposure is static, it 
needs no history variable. We also want to compare at each time t the censored vs. the uncensored, among those in 
the same treatment arm who have remained uncensored before time t. Thus, we need a history variable for censoring 
that tells us which treatment arm they belong to, and summarizes their censoring history. 

We can create the appropriate history strata for our example by using `%makehistory_two()`, with treatment arm 
as the first exposure and studydropout as the second:
*/


%makehistory_two(
 output=catie_sim_wh,
 input=catie_sim_w,
 id=CATIEID,
 exposure_a=treatgrp,
 exposure_b=studydisc,
 times=0 1 3 6 9 12 15 18,
 name_history_a=ht,
 name_history_b=hs
);

proc print data=catie_sim_wh;
where CATIEID=1440;
var CATIEID treatgrp_0 treatgrp_1 studydisc_0 studydisc_1 pctgain_0 pctgain_1 ht_0 ht_1 hs_0 hs_1;
title 'Snapshot of simulated CATIE dataset, after %makehistory_two()';
run;

/*
In our example, we can ignore the treatment arm history variables ht that `%makehistory_two()` created since 
treatment arm is fixed throughout the study. Note that the `%makehistory_one()` and  `make.history.two()` macros 
allow users to stratify history variables by a baseline covariate via the `group` argument. It should never be used 
for a true exposure, as doing so would inaccurately classify any persons who intermittently miss visits throughout 
the study.

### STEP 2: CREATE A TIDY DATAFRAME

The next step is to use `%lengthen()` to transform our "wide" dataframe into one that is jointly indexed by person-id, 
exposure measurement time, and covariate measurement time (i.e., tidy). This data structure is the secret sauce that 
allows for much of this software's flexibility. Here, we have to specify which diagnostic we want because the tidy 
structure for diagnostic 2 (exposure-covariate feedback) differs from the one used for diagnostics 1 and 3 
(time-varying confounding/selection-bias). 

When creating this tidy dataset, `%lengthen()` automatically deletes observations that have missing measurements for 
exposure or a specific covariate at a given time. Thus, it carries out a form of complete case assessment by default. 
There is a mandatory `censoring` argument that we have to supply to let `%lengthen()` know whether there are 
additional observations to remove according to an artificial censoring rule. Since we are evaluating balance for 
censoring due to study dropout, and all data after study dropout are missing, we don't need any artificial 
censoring rules to remove data after study dropout, so we set the `censoring` argument to `no`. However, if we were 
evaluating balance for censoring due to treatment protocol deviation, we would need to set censoring to `yes` and 
use the `censor` argument to specify the appropriate indicator variable `(0=drop, 1=keep)`.
*/


%lengthen(
  output=catie_sim_whl1,
  input=catie_sim_wh,
  id=CATIEID,
  diagnostic=1,
  censoring=no,
  exposure=studydisc,
  temporal_covariate=phasechangecum Chgpansstotal
                       cs14 cs16 
                       pctgain epsmean 
                       qoltot, 
  times_exposure=0 1 3 6 9 12 15 18,  
  times_covariate=0 1 3 6 9 12 15 18, 
  history=hs
);

proc print data=catie_sim_whl1;
where CATIEID=1440 & name_cov='pctgain';
title 'Snapshot of tidy simulated CATIE dataset, after %lengthen() for Diagnostic 1';
run;

/*
You should notice that `%lengthen()` has produced a tidy dataframe where, for diagnostic 1, exposure times are 
greater or equal to covariate times.

####Omitting covariate history

We can use `%omit_history()` to ensure that our balance evaluations accord with our assumption that, at each 
follow-up visit, study dropout is missing at random given the most recent measures of time-varying covariates,
 the treatment arm, and baseline covariates. The `%omit_history()` macro requires that users specify the 
 covariates to be modified (via the `covariate` argument), and how they want to remove irrelevant covariate history 
 (via the `omission` argument). There are three types of omissions that can be specified:

* `fixed`: sets covariate values to missing for certain measurement times t (specified in the `times` argument). 
For example, we might use this for covariate l at time 2 to set all data on l at time 2 to missing, regardless of 
the exposure measurement time. 

* `relative`: sets covariate values to missing only for covariate measurement times at or before a certan distance 
$k$ from the exposure measurement times (specified in `distance` argument). For example, we might use this to set 
data for covariate l with distance 2 to missing data only when it is measured two units or more before the exposure 
measurement time (i.e. t-2, t-3, t-4 and so on).

* `same.time`: sets covariate values to missing only for covariate measurement times that align with exposure 
measurement times (no additional argument needed). This can be useful when, at any given time, an exposure 
precedes a particular covariate.
*/


%omit_history(
  output=catie_sim_whlo1,
  input=catie_sim_whl1,
  covariate_name=phasechangecum Chgpansstotal 
                   cs14 cs16 
                   pctgain epsmean 
                   qoltot, 
  omission=relative, 
  distance=1
);

proc print data=catie_sim_whlo1;
where CATIEID=1440 & name_cov='pctgain';
title 'Snapshot of tidy simulated CATIE dataset, after %omit_history() for Diagnostic 1';
run;

/*
Because `%omit.history()` can be applied repeatedly to the dataset output from `%lengthen()`, users can encode 
different depths of covariate history for each covariate, if desired.

###STEP 3: CREATE A COVARIATE BALANCE TABLE

Now we are ready to use `%balance()` to create a balance table comparing the censored to the uncensored over time. 
As was the case with `%lengthen()` we have to specify what we want to do. The requirements vary (and are detailed 
further down) but at minimum we need to specify the `diagnostic` of interest, what `approach` is used to adjust 
the diagnostic (if any), whether or not additional `censoring` rules are to be applied, and the measurement times 
of interest for exposures and covariates.

We also have to specify the `scope` through which we will examine person-time. 
* `all` provides balance metrics for each exposure-covariate time pairing in the tidy dataset.
* `average` provides balance metrics that standardize over different dimensions of person-time. An additional 
argument, `average_over` is used to specify the dimension to be averaged over: 
+ `strata` averages over strata within levels of exposure values, history, time, and distance
+ `values` averages over strata, non-referent exposure values within levels of history, time, and distance
+ `history` averages over strata, non-referent exposure values and history within levels of time and distance
+ `time` averages over strata, non-referent exposure values, history, and time within levels of distance
+ `distance` averages over non-referent exposure values, history, time and distance. If desired, once can use the 
additional argument `periods` to average over segmented pools of distance, as shown later on.
* `recent` provides balance metrics only for a chosen distance k (specified with the additional argument 
'recency'). Specifying a `scope=recent` with `recency=0` is a quick way to assess balance for the most recent 
covariate measurements. 

There are optional arguments that can help us cope with sparse data. For example, in our example, we can 
optionally specify `sd_ref` to calculate the standardized mean difference using the covariate standard deviation 
from the uncensored at time t given censoring history (the default uses the corresponding pooled estimate). 
If we were taking averages over person-time, we can use `ignore_missing_metric` to decide whether or not to 
report standardized mean differences when some dimensions of person-time lack variation in a covariate (or cases 
where everyone or no one is censored given history).

For our example, in line with our assumptions, let us examine balance for the most recent covariates:
*/

%balance(
  output=baltbl1,
  input=catie_sim_whlo1, 
  diagnostic=1, 
  approach=none, 
  censoring=no, 
  scope=recent, 
  recency=0, 
  exposure=studydisc, 
  history=hs, 
  times_exposure=0 1 3 6 9 12 15 18, 
  times_covariate=0 1 3 6 9 12 15 18, 
  sd_ref=yes
);  

proc print data=baltbl1;
where name_cov='pctgain' & time_exposure<=6;
title 'Snapshot of covariate balance table dataset produced by %balance() for Diagnostic 1';
run;

/*
In the table produced by `%balance()`, `E` is the exposure value that the referent value is compared to, `H` 
is the exposure history. The exact format of the output table will depend on the arguments supplied to `%balance()`.
 There are two reasons for this. The first reason is that diagnostics 1, 2, and 3 differ in when they require 
 exposure history `H` and strata `S` (see below for more details), and these variables will only appear when they
have been used to adjust the balance estimate. The second reason kicks in when using `scope=average` and 
`average_over=...` to request balance estimates that average over some dimension of persion-time.

###STEP 4: CREATE A COVARIATE BALANCE PLOT

Our final step is to use `%makeplot()` to create a trellised covariate balance plot. The required syntax is 
detailed below, but it is typically short. All that is required is to specify `diagnostic`, `approach`, `censoring`,
 and `scope` (and if need be, `average_over`) which should all follow the parameters specified in `%balance()`. 
 These are sufficient to tell `%makeplot()` what kind of plot to produce, regardless of the underlying data. 
 There are a host of optional formatting arguments that you can use to produce publication-quality plots. See 
 `?makeplot` for details.
*/

title '';

title 'Plot produced by %makeplot() for Diagnostic 1 and scope=recent';

%makeplot(
  output=balplot1,
  input=baltbl1,
  diagnostic=1,
  approach=none,
  scope=recent,
  label_exposure=Study Dropout,
  label_covariate=Covariate
);

/*
This plot shows the standardized mean difference (x-axis) for each covariate (y-axis) at different pairings of 
dropout and covariate measurement times (panels), among the uncensored in each treatment arm (dots). This plot 
portrays our decision to restrict our pairing of times to those where covariates are measured just prior to 
dropout. We see here that several covariates are strongly associated with dropout over time, with standardized mean 
differences much larger than 0.25 (the chosen reference lines).

The plot produced by `%makeplot()` will vary according to the parameters, which should share those used with 
`%balance()`. For example, if we had used `scope=all` with `%balance()` and `%makeplot()`, this would have arrayed 
the dropout and measurement parings across a two-dimensional grid, where panel columns correspond to covariate 
measurement times and panel rows correspond to dropout times. Such displays are useful for distinguishing balance 
of static covariates that do not vary over time from temporal covariates that do (as shown below). Sometimes, it 
is not possible to estimate certain balance metrics due to lack of variation, as would happen if everyone dropped 
out or shared the same covariate value. When this happens, `%makeplot()` will warn you about how many balance 
estimates are missing from the plot. You can identify these data elements in the balance table where their balance 
estimates will have missing values.

We can use optional arguments in `%makeplot()` to produce a publication-quality plot. See the SAS manual for details. 
Once we are satisfied with the format, we can the SAS output delivery system to save the plot as a PDF with a desired 
height and width. For example:

ods pdf file=c:\ balplot1.pdf;

    %makeplot(output=baltbl1,
	          input=balplot1, 
              diagnostic=1, 
              approach=none, 
              scope=recent,
              label_exposure=Study Dropout,
              label_covariate=Covariate			  
              );

ods pdf close;

(We aren't saving a PDF since our ods rtf file statement is already sending this to a Word document).

/*
###DEMONSTRATION OF DIAGNOSTIC 3

We have seen with diagnostic 1 that there is dependent-censoring over time. That is, study dropout is associated 
with measured covariates. Suppose we wish to remove dependent-censoring by using inverse probability of censoring 
weights to balance these covariates across levels of study dropout. We can use diagnostic 3 to examine how well our 
estimated weights accomplish this task. For demonstration purposes, we are going to pursue a different plot that 
incorporates balance across static covariates measured at baseline, using a limited selection of times to keep the 
plot readable.

To start, we return to our widened dataset and transform it to a tidy dataset under diagnostic 3. The call differs 
from before only in that we have added two extra arguments `static_covariate` and `weight_exposure`. (If we had 
specified these for diagnostic 1, we wouldn't need to reproduce a tidy dataset, because it will share the same 
structure for diagnostics 1 and 3). 
*/

%lengthen(
  output=catie_sim_whl3,
  input=catie_sim_wh,
  id=CATIEID,
  diagnostic=3,
  censoring=no,
  exposure=studydisc,
  temporal_covariate=PhaseChangeCum Chgpansstotal 
                       cs14 cs16 
                       pctgain epsmean 
                       qoltot, 
  static_covariate=exacer Bpansstotal 
                     unemployed, 
  times_exposure=0 1 3 6,  
  times_covariate=0 1 3 6, 
  history=hs,
  weight_exposure=wtr
)

proc print data=catie_sim_whl3;
title 'Snapshot of tidy simulated CATIE dataset, after %lengthen() for Diagnostic 3';
where CATIEID=1440 & name_cov='pctgain';
run;

/*
In this new tidy dataset, the weights appear as an extra column, and the static covariates appear as extra rows, 
but only at the baseline covariate measurement time. The next step is to use `%omit_history()` as we did before to 
encode our assumption about dependent censoring through the most recently measured temporal covariates.
*/

%omit_history(
  output=catie_sim_whlo3,
  input=catie_sim_whl3,
  covariate_name=phasechangecum Chgpansstotal cs14 cs16 pctgain epsmean qoltot,
  omission=relative,
  distance=1
);  

proc print data=catie_sim_whlo3;
title 'Snapshot of tidy simulated CATIE dataset, after %omit_history() for Diagnostic 3';
where CATIEID=1440 & name_cov='pctgain';
run;

/*
The next step is to use `%balance()` as we did before, but this time with `scope=all` under the restricted set of 
measurement times, `approach=weight`, and an additional argument `weight_exposure` to specify the inverse 
probabilty of censoring weights. Again, in our example we are treating study dropout as the exposure and our data 
are already implicitly censored by study dropout, which is why we specified `censoring=no`. We have no other 
censoring mechanisms to incorporate via the `censor` argument. For the same reason, we have no other inverse 
probability of censoring weights to incorporate (e.g., due to protocol violation) via the `weight_censor` argument. 
In this example, all that is needed is to specify the `weight_exposure` argument because we are treating study 
dropout as an exposure and there are no further censoring mechanisms to account for.
*/

%balance(
  output=baltbl3,
  input=catie_sim_whlo3,
  diagnostic=3,
  approach=weight,
  censoring=no,
  scope=all,
  exposure=studydisc,
  history=hs,
  times_exposure=0 1 3 6,
  times_covariate=0 1 3 6,
  sd_ref=yes,
  weight_exposure=wtr
);

proc print data=baltbl3;
title 'Snapshot of covariate balance table produced by %balance() for Diagnostic 3';
where name_cov='pctgain';
run;

/*
We are now ready to produce our balance plot via `%makeplot()`:
*/

title 'Plot produced by %makeplot() for Diagnostic 3 and scope=all';

%makeplot(
  output=balplot3,
  input=baltbl3,
  diagnostic=3,
  approach=weight,
  scope=all,
  label_exposure=Study Dropout,
  label_covariate=Covariate
);

/*
We see in this plot that the weights have effectively reduced much of the imbalance for most covariates, at least 
through time 6. However, we also see that strong imbalances persist for other covariates at certain time points and 
treatment arms, a potential signal that our model for study dropout is not flexible enough [10], or that other 
issues, such as positivity violations are at play. Imbalances can also persist when inverse probability weights are 
truncated to certain thresholds [11]. The plot is also informative in that we see persistent imbalances across 
baseline covariates as well. This is to be expected as these variables were used to stabilize the weights. 
This re-emphasizes the need to condition our final analyses on these baseline covariates.

A natural question is whether we can produce plots that adjust for baseline covariates. There are two options. 
If there are only a few such covariates and these can be combined into a master categorical variable, this variable 
can be wrapped into the history strata using either `%makehistory()` macro. Averaging over history with 
`%balance()` will then adjust for this categorical variable. The alternative is to merge baseline covariates to the 
tidy dataset produced by `%lengthen()`, and then use the `broom` package to produce balance estimates that adjust for 
multiple covariates, even continuous ones. If the output were reformatted appropriately, it could be plotted with 
`%makeplot()` or with SAS GRAPH PROC PANEL directly. This latter extension with modeling has not yet been 
automated into the software.

In all, assessments such as diagnostics 1 and 3 can be critical for describing the nature of time-varying 
confounding, and also selection-bias as we have demonstrated in this example. These assessments are certainly 
of use to investigators who can examine such issues and adapt their modeling approaches accordingly. Next, we turn 
to diagnostic 2, which tells us even more about the nature of time-varying confounding and/or selection-bias in 
complex longitudinal data.

###DEMONSTRATION OF DIAGNOSTIC 2

In addition to describing selection-bias before and after applying inverse probability of censoring weights, 
we can also examine whether covariates are affected by exposure or an unmeasured cause of exposure. If it were 
present, conditioning on covariates during follow-up would not only potentially block treatment effects, 
conditioning would induce selection-bias, and so would not be a desirable approach for resolving the selection-bias. 
Treatment-confounder feedback motivates the use of inverse probability of censoring weights, or a time-varying 
application of multiple imputation, to resolve the selection-bias. 

To evaluate treatment-confounder feedback, we simply assess the balance of each covariate measurement across 
each prior exposure measurement, adjusting for confounders that precede the exposure. Thankfully, we can use the 
same macros (and thus workflow) as before to produce a plot that describes treatment-confounder feedback. 
Recall that, in our study design, treatment arm is held fixed throughout the study. As a result, the plot will be 
much simpler than it would be if we wanted to evaluate feedback for a treatment that varied over time. Moreover, 
because the treatment arm assignment is randomized, there is no need to adjust for baseline covariates via 
adjustment with inverse probability weights or propensity score strata. In more general settings, we would need 
to indicate the root name of variables for (i) treatment history and inverse probability of treatment weights or 
(ii) propensity-score strata to adjust for prior treatment and covariate history that could confound this assessment. 

In the presence of study dropout, as in our example, assessments of treatment-confounder feedback can suffer selection-bias. 
To address this, we include the root name of `studydisc` and its corresponding inverse probability of censoring 
weights `wtr` after having lagged these variables to align with covariate measurements at time t rather than 
time t+1 (as was the case, implicitly so, in this example). 
*/

proc import datafile="/folders/myfolders/data/catie_sas.csv"
   out=catie_sim dbms=csv replace;
   getnames=yes;
run;

proc sort data=catie_sim;
by CATIEID time;
run;

data catie_alt;
set catie_sim;
wtrLag=lag(wtr);
studydiscLag=lag(studydisc);
run;

data catie_alt;
set catie_alt;
by CATIEID time;
if first.CATIEID then do;
  wtrLag=1;
  studydiscLag=0;
end;
run;

proc print data=catie_alt;
where CATIEID IN (1439,1440,1443);
var CATIEID time studydisc studydiscLag wtr wtrLag pctgain;
title 'Snapshot of simulated CATIE dataset, lagging study dropout and IPCW'; 
run;

/*
In our example, `studydiscLag` becomes a constant of `0`. However, `%lengthen()` requires a variable describing 
censoring indicators whenever `weight_censor()` is used, so we include it.
*/


%widen(
 output=catie_alt_w,
 input=catie_alt,
 id=CATIEID,
 time=time,
 exposure=treatgrp,
 covariate=phasechangecum Chgpansstotal 
             cs14 cs16 
             pctgain epsmean 
             qoltot 
             exacer Bpansstotal unemployed,
 censor=studydiscLag,
 weight_censor=wtrLag             
);

proc print data=catie_alt_w;
where CATIEID=1440;
var CATIEID treatgrp_0 treatgrp_1 wtrLag_0 wtrLag_1 studydiscLag_0 studydiscLag_1 pctgain_0 pctgain_1;
title 'Snapshot of simulated CATIE dataset, after %widen()'; 
run;

%lengthen(
  output=catie_alt_wl2,
  input=catie_alt_w,
  id=CATIEID,
  diagnostic=2,
  censoring=yes,
  exposure=treatgrp,
  temporal_covariate=phasechangecum Chgpansstotal 
                       cs14 cs16 
                       pctgain epsmean 
                       qoltot,
  times_exposure=0, 
  times_covariate=0 1 3 6 9 12 15 18,
  censor=studydiscLag,
  weight_censor=wtrLag
);

proc print data=catie_alt_wl2;
where CATIEID=1440 & name_cov='pctgain';
title 'Snapshot of tidy simulated CATIE dataset, after %lengthen() for Diagnostic 2';
run;

/*
`%lengthen()` generally creates a tidy dataset as before, but now restricted to observtions where exposure times 
precede covariate times. Through our call, We have further restricted the baseline exposure time since it is fixed 
over time. Furthermore, when `%lengthen()` incorporates weights via `weight_censor`, it aligns them with measurement 
times of _covariates_ rather than exposures, in contrast to diagnostic 3. We can skip `%omit_history()` with 
diagnostic 2 as it is not relevant for assessing treatment-confounder feedback. When exposures vary over time, 
the balance of all prior exposures needs to be assessed. With our example, we are only concerned with the treatment
arm assignment at baseline.

With `%balance()` and `%makeplot()` we have an array of possibilities. Here, we specify `scope=average` and 
`average_over=distance` to demonstrate how balance metrics can be averaged over person-time, to concisely 
summarize information over all follow-up times:  
*/

%balance(input=catie_alt_wl2,
  output=baltbl2,  
  diagnostic=2,
  approach=weight,  /* Approach must be 'weight' or 'stratify' for diagnostic 2 */
  censoring=yes,
  scope=average,
  average_over=distance,
  periods= 0:3 6:9 12:18,
  exposure=treatgrp,
  times_exposure=0,
  times_covariate=0 1 3 6 9 12 15 18,
  weight_exposure=wtrLag,  /* Also required to specify exposure weight and history for diagnostic 2 */
  history=studydiscLag/*,
  sort_order=Chgpansstotal cs16 
               pctgain epsmean 
               qoltot PhaseChangeCum 
               cs14*/
);

proc print data=baltbl2;
where name_cov='pctgain';
title 'Snapshot of covariate balance table produced by %balance() for Diagnostic 2';
run;

/*
We also make use of the optional `sort.order` argument in `%balance()` to order the covariates in the table, 
which will carry through to `%makeplot()`.

title 'Plot produced by %makeplot() for Diagnostic 2 with scope=average';
*/
%makeplot(
  output=balplot2,
  input=baltbl2,
  diagnostic=2,
  approach=none,
  scope=average,
  average_over=distance,
  label_exposure=Treatment Group,
  label_covariate=Covariate,
  columns_per_page=3  /* Add the 'columns_per_page' argument to adjust plot formatting */ 
);

/*
In this plot, each panel represents the average balance of a covariate at time t across levels of the 
treatment arm at baseline (at t=0). We only see one dot because, `%balance()` first computed metrics comparing 
each non-referent value to a referent value, took a weighted average of these, and then further took weighted 
averages according to the spacing between treatment arm and covariate measurements. We see that at near and 
distant intervals, the change in pansstotal score, and the percentage of weight gain, appears to differ across 
treatment arms. Because this is a randomized study, we do not expect these differences  to be attributable to 
confounding by baseline covariates. Moreover, we have reduced the contribution of selection-bias by incorporating 
inverse probability of censoring weights. Therefore, it appears that both change in total PANSS score and 
percentage of weight gain is involved in treatment-confounder feedback.

##ITERATIVE PROCESSING FOR LARGE DATA

One drawback of using a tidy data structure to drive the macros is that, it may take substantial memory to 
process data from studies with a large number of persons, measurements, and/or covariates. To cope with this, 
we provide the `diagnose()` macro that takes the "wide" dataframe and iteratively calls `%lengthen()` and 
`%balance()` by looping over covariates. In the future we will extend this capability to allow for looping 
over measurement times as well. The output data from `diagnose()` can be read directly into `%makeplot()`.

Note that there is an important change in workflow when users wish to use the `diagnose()` macro and also 
remove irrelevant covariate history from the balance table calculations and plot. Users who wish to do so will 
need to first use `diagnose()` with `scope=all`. Then `%omit_history()` can be applied to the dataset output from 
`diagnose()`. From that point, if desired, `%apply_scope()` can be used to restrict to a certain recency or obtain 
summaries over person-time. This workflow change allows users to iterate while ensuring that the metrics ignore 
covariate history the user deems irrelevant to confounding.
*/

/*debugging
%diagnose(output=diagtbl3,  
  input=catie_sim_wh,
  id=CATIEID,
  diagnostic=3,
  approach=weight,
  censoring=no,
  scope=all,
  exposure=studydisc,
  history=hs,
  temporal_covariate=phasechangecum 
                       Chgpansstotal cs14 
                       cs16 pctgain 
                       epsmean qoltot, 
  times_exposure=0 1 3 6 9 12 15 18,
  times_covariate=0 1 3 6 9 12 15 18,
  weight_exposure=wtr
);

%omit_history(
  output=diagtbl3_o,
  input=diagtbl3,
  covariate_name=PhaseChangeCum Chgpansstotal 
                   cs14 cs16 
                   pctgain epsmean 
                   qoltot,
  omission=relative,
  distance=1
);

%apply_scope(
  output=diagtbl3_oa,
  input=diagtbl3_o,
  diagnostic=3,
  approach=weight,
  scope=recent,
  recency=0
);

title 'Plot produced by %makeplot() for Diagnostic 3';

%makeplot(
  input=diagplot3_oa,
  diagnostic=3,
  approach=weight,
  scope=recent,
  average_over=distance,
  label_exposure=Treatment Group,
  label_covariate=Covariate
);
*/

/*
##ADAPTING DATA THAT IS NOT TIME-INDEXED

Sometimes data are not indexed by measurement times. For example, suppose our trial only had one point of 
follow-up. We might receive a dataset like the following:
*/

data catie_sim_x;
set catie_sim;
where time=0;
drop time;
run;

proc print data=catie_sim_x;
where CATIEID=1440;
var CATIEID treatgrp studydisc pctgain leadpansstotal;
title 'Example of dataset that has follow up data but is not time-indexed';
run;

/*
Let's say we want to evaluate covariate balance across treatment arms, and then covariate balance across 
levels of study dropout by visit 1 given treatment arm. All we need to do is add a constant time index to the 
data, and then we can proceed exactly as we did before. For example:
*/

/*debugging
data catie_sim_0;
set catie_sim_x;
time=0;
run;

%widen(
 output=catie_sim_0w,
 input=catie_sim_0,
 id=CATIEID,
 time=time,
 exposure=studydisc,
 covariate=treatgrp cs14 cs16 weight 
             pansstotal epsmean 
             qoltot 
             exacer unemployed 
             white black 
             agegrp1824 agegrp2534)
); 

catie_sim_0wh <- makehistory_two(
 input=catie_sim_0w,
 id=CATIEID,
 exposure_a=treatgrp,
 exposure_b=studydisc,
 times=0,
 name_history_a=ht,
 name_history_b=hs
)

*balance across treatment arm;
%diagnose(
  output=diagtbl_0t,
  input=catie_sim_0wh,
  id=CATIEID,
  diagnostic=1,
  approach=none,
  censoring=no,
  scope=all,
  exposure=treatgrp,
  history=ht,
  temporal_covariate=PhaseChangeCum Chgpansstotal 
                       cs14 cs16 pctgain 
                       epsmean qoltot 
  static_covariate=exacer Bpansstotal unemployed 
                     white black 
                     agegrp1824,agegrp25344,
  times_exposure=0,
  times_covariate=0
);

print data=diagtbl_0t;
title 'Snapshot of balance table [across treatment arm] produced by %diagnose() for Diagnostic 1';
run;

*balance across censoring given treatment arm;
%diagnose(
  output=diagtbl_0s,
  input=catie_sim_0wh,
  id=CATIEID,
  diagnostic=1,
  approach=none,
  censoring=no,
  scope=all,
  exposure=studydisc,
  history=hs,
  temporal_covariate=PhaseChangeCum Chgpansstotal 
                       cs14 cs16 pctgain 
                       epsmean qoltot 
  static_covariate=exacer Bpansstotal 
                     unemployed white black 
                     agegrp1824,agegrp25344),
  times_exposure=0,
  times_covariate=0
);

print data=diagtbl_02;
title 'Snapshot of balance table [across dropout|treatment arm] produced by %diagnose() for Diagnostic 1';
run;
*/

/*
You can use the exact same procedure to appropriately examine covariate balance in a study of multiple distinct 
exposures, such as interaction or mediation [12].

#REQUIRED ARGUMENTS, BY macro

##Required arguments for `%lengthen()` by diagnostic, approach, and censoring arguments |

Diagnostic |  Approach  | Censoring | Additional Args
:----------|:-----------|:----------|:----------------------------------------------------------------------
1          |none        |no         |id, exposure, ...covariate, times..., history
1	       |none        |yes        |id, exposure, ...covariate, times..., history, censor
2	       |none        |no         |id, exposure, ...covariate, times..., 
2	       |none        |yes        |id, exposure, ...covariate, times..., history, censor
2	       |weight      |no         |id, exposure, ...covariate, times..., history, weight_exposure
2	       |weight      |yes        |id, exposure, ...covariate, times..., history, weight_exposure
2	       |stratify    |no         |id, exposure, ...covariate, times..., strata
2	       |stratify    |yes        |id, exposure, ...covariate, times..., strata, censor
3	       |weight      |no         |id, exposure, ...covariate, times..., history, weight_exposure
3	       |weightâ     |yes        |id, exposure, ...covariate, times..., history, weight_exposure, censor
3	       |stratify    |no         |id, exposure, ...covariate, times..., history, strata
3	       |stratify    |yes        |id, exposure, ...covariate, times..., history, strata, censor

* Either `temporal_covariate` or `static_covariate` or both may be specified.

* Both `times.exposure` and `times.covariate` must be specified.

##Required arguments for `%balance()` by diagnostic, approach, and censoring arguments |

Diagnostic |  Approach  | Censoring | Additional Args in addition to Scope                                                 
:----------|:-----------|:----------|:---------------------------------------------------
1          |no          |no         |exposure, times..., history
1	       |no          |yes        |exposure, times..., history, censor
2	       |no          |no         |exposure, times.., 
2	       |no          |yes        |exposure, times..., history, censor
2	       |weight      |no         |exposure, times..., history, weight_exposure
2	       |weight      |yes        |exposure, times..., history, weight_exposure
2	       |stratify    |no         |exposure, times..., strata
2	       |stratify    |yes        |exposure, times..., strata, censor
3	       |weight      |no         |exposure, times..., history, weight_exposure
3	       |weight      |yes        |exposure, times..., history, weight_exposure, censor
3	       |stratify    |no         |exposure, times..., history, strata
3	       |stratify    |yes        |exposure, times..., history, strata, censor

* Specifying `scope=average` will require the `average_over` argument. 

* Specifying `average_over=distance` allows for optional use of the `periods` argument. 

* Specifying `scope=recent` will require the `recency` argument.

##Required arguments for `%balance()` by diagnostic, approach, and censoring arguments |

Diagnostic |  Approach  | Censoring | Additional Args in addition to Scope _and_ Metric                                                
:----------|:-----------|:----------|:-------------------------------------------------
1          |no          |no	        | 
1          |no          |yes	    | 
2          |no          |no         |
2          |no          |yes        |
2          |weight      |no         |
2          |weight      |yes        |
2          |stratify    |no         |stratum
2          |stratify    |yes        |stratum
3          |weight      |no         |
3          |weight      |yes        |
3          |stratify    |no         |stratum
3          |stratify    |yes        |stratum

* Specifying `scope=average` will require the `average_over` argument. 

##Requirements for other macros

Generally, `%apply_scope()` will follow `%balance()`. `diagnose()` will follow the combination of `%lengthen()` and 
`%balance()`.

#USING `%lengthen()` WITH MODELS INSTEAD OF `%balance()`
*/

/*still debugging
proc means mean std nway;
var chgpansstotal cs14 cs16 pctgain epsmean qoltot exacer Bpansstotal unemployed;
output out=stat;
run;

data catie_sim_s;
set catie_sim;
Chgpansstotal=(Chgpansstotal-#)/#;
cs14=(cs14-#)/#;
cs16=(cs16-#)/#;
pctgain=(pctgain-#)/#;
epsmean=(epsmean-#)/#;
qoltot=(qoltot-#)/#;
run;

%widen(
 output=catie_sim_sw,
 input=catie_sim_s,
 id=CATIEID,
 time=time,
 exposure=studydisc,
 covariate=treatgrp PhaseChangeCum 
             Chgpansstotal 
             cs14 cs16 
             pctgain epsmean qoltot 
             exacer Bpansstotal 
             unemployed,
 weight_exposure=wtr             
);

%makehistory_two(
 output=catie_sim_swh,
 input=catie_sim_sw,
 id=CATIEID,
 exposure_a=treatgrp,
 exposure_b=studydisc,
 times=0 1 3 5 9 12 15 18,
 name_history_a=ht,
 name_history_b=hs
);

%lengthen(
  output=catie_sim_swhl3,
  input=catie_sim_swh,
  id=CATIEID,
  diagnostic=3,
  censoring=no,
  exposure=studydisc,
  temporal_covariate=PhaseChangeCum Chgpansstotal 
                       cs14,cs16 pctgain 
                       epsmean qoltot 
  times_exposure=0 1 3 5 9 12 15 18, 
  times_covariate=0 1 3 5 9 12 15 18,
  history=hs,
  weight_exposure=wtr
);

%omit.history(
  output=catie_sim_swhlo3,
  input=catie_sim_swhl3,
  covariate_name=PhaseChangeCum Chgpansstotal 
                   cs14 cs16 pctgain 
                   epsmean qoltot,
  omission=relative,
  distance=1
);

/*
Here is the model-based SMD (via PROC MIXED). Alternatively, could use PROC GLM (see manual):
*/

/*still debugging
data catie_sim_mod;
set catie_sim_swhlo3;
time=time_exposure;
history=hs;
run;
*/

/*still debugging
ods output LComponents=mixedEstimates;  * Store the parameter estimates;
proc mixed data=catie_sim_mod;
   class studydisc(REF=FIRST)
   model value_cov = studydisc / SOLUTION LCOMPONENTS;
   weight wtr;
   by name_cov history time;
run;
quit;

data modtbl (keep=name_cov estimate time history);
   set mixedEstimates;
   where effect eq "studydisc";
   SMD=estimate;
   H=history;
   time.exposure=time;
   time.covariate-time;
   drop estimate history time;
run;

proc print data=modtbl;
title 'Covariate balance table produced via modeling on tidy dataset by %omit_history() for Diagnostic 3';
run;
*/

/*
Because we have formatted the table to like the output from `%balance()`, we can read this directly into 
`%makeplot()`:
*/

/*still debugging
%makeplot(
  input=modtbl,
  diagnostic=3,
  approach=weight,
  scope=recent,
  label_exposure=Treatment Group,
  label_covariate=Covariate
);
*/

/*

Let's close the output delivery system to catpure output.

/*

output rtf close;

/*
As implemented, this approach mimicks what the balance macro would do--estimate balance within each level of 
time and history. However, if we moved history and/or time from the `by` statement to the right-hand side 
of the model, we would begin to incorporate assumptions about model form and its constancy across covariates. Our 
estimates would rely on these assumptions being correct. The chief advantage of this approach is that, with some 
merging of baseline covariates to the lengthened dataset, we can leverage our assumptions to condition balance 
estimates on several covariates, including continuous ones, when this is desired.
*/

/*
#REFERENCES

[1] https://www.ncbi.nlm.nih.gov/pubmed/27479649

[2] https://www.ncbi.nlm.nih.gov/pubmed/28039382

[3] https://www.ncbi.nlm.nih.gov/pubmed/10955408

[4] https://www.ncbi.nlm.nih.gov/pubmed/19817741

[5] https://www.ncbi.nlm.nih.gov/pubmed/?term=23533091

[6] https://www.ncbi.nlm.nih.gov/pubmed/21843003

[7] https://www.ncbi.nlm.nih.gov/pubmed/16172203

[8] https://ndar.nih.gov/

[9] https://www.ncbi.nlm.nih.gov/pubmed/?term=28535177

*/

