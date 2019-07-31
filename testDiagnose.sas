/* Erin Schnellinger */
/* 14 April 2019 */

/* Last Modified: 10 July 2019 */
/* Updated name of history variable to match that in diagnose */

/* Program to test the %diagnose() SAS Macro */

** Clear contents in the output and log windows **;
   dm 'out;clear;log;clear;';

** Clear titles and footnotes **;
   title;
   footnote;

** Clear temporary data sets in the work library **;
   proc datasets nolist lib=work memtype=data kill;run;quit;
   
   
** Macro options **;
   options minoperator /* mprint mlogic symbolgen*/;

** Assign a fileref to each confoundr macro **;
   filename widedef  "/folders/myfolders/confoundr_SAS-master/widen.sas";
   filename hist1def "/folders/myfolders/confoundr_SAS-master/makehistory_one.sas";
   filename hist2def "/folders/myfolders/confoundr_SAS-master/makehistory_two.sas";
   filename longdef  "/folders/myfolders/confoundr_SAS-master/lengthen.sas";
   filename omitdef  "/folders/myfolders/confoundr_SAS-master/omit_history.sas";
   filename balncdef "/folders/myfolders/confoundr_SAS-master/balance.sas";
   filename applyscp "/folders/myfolders/confoundr_SAS-master/apply_scope.sas";
   filename plotdef  "/folders/myfolders/confoundr_SAS-master/makeplot.sas";
   filename diagnos  "/folders/myfolders/confoundr_SAS-master/diagnose.sas";

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
  
  
*----------------------------*;
* Test the %diagnose() macro *;
*----------------------------*;

** Import the relevant toy data sets **;

proc import datafile="/folders/myfolders/confoundr_SAS-master/data/toy_wide_dropoutY.csv"
   out=df_twdy dbms=csv replace;
   getnames=yes;
run;


*---------------------------------------------*;
* Check Diagnostic 1, scope recent, recency 0 *;
*---------------------------------------------*;

%diagnose(
 input=df_twdy, 
 output=df_twdy_d, 
 diagnostic=1, 
 scope=recent, 
 censoring=no, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2,
 exposure=a, 
 temporal_covariate=l m n, 
 static_covariate=o p, 
 history=haone, 
 recency=0
);


/* Create macro variables with true values for ID=1 */
%LET name_list = E H name_cov time_exposure time_covariate D SMD N Nexp;
%LET E = 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1;
%LET H = H H H H H H0 H0 H0 H00 H00 H00 H01 H01 H01 H1 H1 H1 H10 H10 H10 H11 H11 H11;
%LET name_cov = l m n o p l m n l m n l m n l m n l m n l m n;
%LET time_exposure = 0 0 0 0 0 1 1 1 2 2 2 2 2 2 1 1 1 2 2 2 2 2 2;
%LET time_covariate = 0 0 0 0 0 1 1 1 2 2 2 2 2 2 1 1 1 2 2 2 2 2 2;
%LET D = 0.026093 0.217244 0.172947 0.34195 0.242385 0.214185 0.156257;
%LET SMD = 0.055902 0.469622 0.372957 0.74633 0.512765 0.438246 0.366016;
%LET N = 1000 511 282 193 489 169 203;
%LET Nexp = 489 209 85 110 265 80 141;	


** Generate list of variables in df_twdy_d, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdy_d data set */
   proc contents data=df_twdy_d out=rawVar(keep=name) noprint;
   run;

   /* Create a macro variable, rawVarList, which contains a list of all of the column names */
   data _null_;
      set rawVar;
      retain rawVarList;
      length rawVarList $7500.;
      if _n_ = 1 then rawVarList = name;
      else rawVarList = catx(' ', rawVarList, name);
      call symput('rawVarList', rawVarList);
   run; 


/* Compare rawVarList to true name list */
%macro checkname;
proc IML;
   %LET numNames = %sysfunc(countw(&rawVarList., ' '));  /* Count the total number of names in raw list */

   %do i=1 %to &numNames;  
      %LET numVar&&i = %scan(&rawVarList.,&&i, ' ');  /* Grab the individual names in the raw list */
   %end;

   %do i=1 %to &numNames.;  /* Check if any individual name is missing from the true name list */
      %if NOT %eval(&&numVar&i in(&name_list.)) %then %do;
         %put ERROR: Some variables in the lengthen output data set are not in the true name list;
         %ABORT;
      %end;
   %end;
quit;
%mend;

%checkname;


/* Also compare true name list to raw name list */
%macro checkname2;
proc IML;
   %LET numNames = %sysfunc(countw(&name_list., ' '));  /* Count the total number of names in true list */

   %do i=1 %to &numNames;  
      %LET numVar&&i = %scan(&name_list.,&&i, ' ');  /* Grab the individual names in the true list */
   %end;

   %do i=1 %to &numNames.;  /* Check if any individual name is missing from the true name list */
      %if NOT %eval(&&numVar&i in(&rawVarList.)) %then %do;
         %put ERROR: Some variables in the true list are not in the lengthen output data set;
         %ABORT;
      %end;
   %end;
quit;
%mend;

%checkname2;


/* Check Number of Rows */
   proc sql noprint;
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdy_t */
       from df_twdy_d;
   quit;
     
   %if &numRow1. ne 23 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   
   
/* Compare history in df_twdy_d and true list */
proc sql noprint;                              
 select H into :df_twdy_d_haone_List separated by ' '
 from df_twdy_d;
quit;
%put df_twdy_d_haone_List = &df_twdy_d_haone_List; 

%if &df_twdy_d_haone_List. ne &H. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare name_cov in df_twdy_d and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_d_name_cov_List separated by ' '
 from df_twdy_d;
quit;
%put df_twdy_d_name_cov_List = &df_twdy_d_name_cov_List; 

%if &df_twdy_d_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_d and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_d_time_exposure_List separated by ' '
 from df_twdy_d;
quit;
%put df_twdy_d_time_exposure_List = &df_twdy_d_time_exposure_List; 

%if &df_twdy_d_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_d and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_d_time_covariate_List separated by ' '
 from df_twdy_d;
quit;
%put df_twdy_d_time_covariate_List = &df_twdy_d_time_covariate_List; 

%if &df_twdy_d_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Subset to include only records with name_cov="l" */
data df_twdy_d_name_cov_l;
   set df_twdy_d;
   if name_cov eq "l";
run;

/* Compare D in df_twdy_d_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(D), 0.0000001) into :df_twdy_d_D_List separated by ' '
 from df_twdy_d_name_cov_l;
quit;
%put df_twdy_d_D_List = &df_twdy_d_D_List; 

%if &df_twdy_d_D_List. ne &D. %then %do;
  %put ERROR: At least one D does not match.;
%end;


/* Compare SMD in df_twdy_d_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(SMD), 0.0000001) into :df_twdy_d_SMD_List separated by ' '
 from df_twdy_d_name_cov_l;
quit;
%put df_twdy_d_SMD_List = &df_twdy_d_SMD_List; 

%if &df_twdy_d_SMD_List. ne &SMD. %then %do;
  %put ERROR: At least one SMD does not match.;
%end;


/* Compare N in df_twdy_d_name_cov_l and true list */
proc sql noprint;                              
 select round(N, 0.0000001) into :df_twdy_d_N_List separated by ' '
 from df_twdy_d_name_cov_l;
quit;
%put df_twdy_d_N_List = &df_twdy_d_N_List; 

%if &df_twdy_d_N_List. ne &N. %then %do;
  %put ERROR: At least one N does not match.;
%end;


/* Compare Nexp in df_twdy_d_name_cov_l and true list */
proc sql noprint;                              
 select round(Nexp, 0.0000001) into :df_twdy_d_Nexp_List separated by ' '
 from df_twdy_d_name_cov_l;
quit;
%put df_twdy_d_Nexp_List = &df_twdy_d_Nexp_List; 

%if &df_twdy_d_Nexp_List. ne &Nexp. %then %do;
  %put ERROR: At least one Nexp does not match.;
%end;



** End of tests for %diagnose() **;