# confoundr

INTRODUCTION

This software implements three [diagnostics for confounding/selection-bias](https://www.ncbi.nlm.nih.gov/pubmed/27479649) that can be used in sequence. Built upon the framework of sequential exchangeability, these apply to any study of multivariate exposures e.g. time-varying exposures, direct effects, interaction, and censoring. The first two diagnostics pertain to the nature of confounding/selection-bias in the data, while the third is meant to examine residual confounding/selection-bias after applying certai adjustment methods. These tools are meant to help describe confounding/selection-bias in complex data _after_ investigators have selected covariates to adjust for (e.g., through subject-matter knowledge).

+ *Diagnostic 1* is a generalization of a "Table 1" for multivariate exposures (i.e. multiple exposures that are distinct in timing or character). It examines whether the prior covariate means are the same across exposure groups, among persons who have followed a particular exposure trajectory up to that point in time. Like a "Table 1" it is meant to describe whether exposure groups have different distributions of prior covariates. 

+ *Diagnostic 2* assesses whether there is feedback between exposures and confounders over time. If present, it indicates the use of [g-methods](https://www.ncbi.nlm.nih.gov/pubmed/28039382) to control for time-varying confounding for any definition of time-varying exposure that is explicitly or implicitly multivariate (e.g., ever use at time t). The diagnostic examines whether the covariate mean differs across prior exposure groups, after adjustment for covariates (that precede the exposure) through inverse probability weighting or propensity score stratification.

+ *Diagnostic 3* is meant to be applied after investigators have applied the earlier diagnostics and have chosen to use g-methods to adjust for confounding/selection-bias. The form of Diagnostic 3 is similar to that of Diagnostic 1 in that it is a generalized "Table 1" for weighted or stratified data. It can be applied to examine residual confounding/selection-bias when [inverse probability weights](https://www.ncbi.nlm.nih.gov/pubmed/10955408) are used to fit marginal structural models. It can also be applied to examine residual confounding/selection-bias when [propensity-score stratification](https://www.ncbi.nlm.nih.gov/pubmed/19817741) is used to implement the [parametric g-formula](https://www.ncbi.nlm.nih.gov/pubmed/23533091) or [marginal mean weighting through stratification](https://www.ncbi.nlm.nih.gov/pubmed/21843003).

CAPABILITIES

The tools can accomodate:
* Multivariate exposures that are binary or categorical (and continuous, when used in concert with modeling, see below). 
* Varying temporal depth of covariate history.
* Unbalanced, sparse data with irregular measurement of exposures/covariates or missing data
* Artificial censoring rules.
* Requests for tables/plots at all times, specific times, or averages over selected dimensions of person-time.
* Data that are not time-indexed.
* Data that are supplied in "wide" or "long" format.

To read in the macros, use the following code:

```
** Macro options **;
   options minoperator;

** Assign a fileref to each confoundr macro **;
   filename widedef  "/folders/myfolders/CovariateBalanceProject/confoundr_macros/widen.sas";
   filename hist1def "/folders/myfolders/CovariateBalanceProject/confoundr_macros/makehistory_one.sas";
   filename hist2def "/folders/myfolders/CovariateBalanceProject/confoundr_macros/makehistory_two.sas";
   filename longdef  "/folders/myfolders/CovariateBalanceProject/confoundr_macros/lengthen.sas";
   filename omitdef  "/folders/myfolders/CovariateBalanceProject/confoundr_macros/omit_history.sas";
   filename balncdef "/folders/myfolders/CovariateBalanceProject/confoundr_macros/balance.sas";
   filename applyscp "/folders/myfolders/CovariateBalanceProject/confoundr_macros/apply_scope.sas";
   filename plotdef  "/folders/myfolders/CovariateBalanceProject/confoundr_macros/makeplot.sas";
   filename diagnos  "/folders/myfolders/CovariateBalanceProject/confoundr_macros/diagnose.sas";

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
```

A PDF manual can be downloaded from the main directory. We are also developing a vignette. A .sas file 'selectionbias.sas' can be used to run the vignette with the 'catie_sas.csv' file, both available for download. 

For questions please [contact me](https://www.jhsph.edu/faculty/directory/profile/3410/john-w-jackson).

John W. Jackson, ScD
