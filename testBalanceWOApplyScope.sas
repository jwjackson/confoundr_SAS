/* Erin Schnellinger */
/* Last Updated: 27 June 2019 */

/* Program to test the %balance() SAS Macro without Apply Scope */

** Clear contents in the output and log windows **;
   dm 'out;clear;log;clear;';

** Clear titles and footnotes **;
   title;
   footnote;

** Clear temporary data sets in the work library **;
   proc datasets nolist lib=work memtype=data kill;run;quit;
   
   
** Macro options **;
   options minoperator mprint mlogic symbolgen;

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
  
  
*-----------------------------------------------*;
* Test the %balance() macro without Apply Scope *;
*-----------------------------------------------*;

** Import the relevant toy data sets **;

proc import datafile="/folders/myfolders/confoundr_SAS-master/data/toy_wide_dropoutY.csv"
   out=df_twdy dbms=csv replace;
   getnames=yes;
run;


*---------------------------------------------*;
* Check Diagnostic 1, no censoring, scope all *;
*---------------------------------------------*;

%lengthen(
 input=df_twdy, 
 output=df_twdy_t, 
 diagnostic=1, 
 censoring=no, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a, 
 temporal_covariate=l m, 
 static_covariate=p, 
 history=haone
);


%balance(
 input=df_twdy_t, 
 output=df_twdy_b, 
 diagnostic=1, 
 approach=none, 
 censoring=no, 
 scope=all, 
 times_exposure=0 1 2, 
 times_covariate= 0 1 2, 
 exposure=a,
 history=haone
);


/* Create macro variables with true values for name_cov="l" */
%LET name_list = E H name_cov time_exposure time_covariate D SMD N Nexp;
%LET E = 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1;
%LET name_cov = l l l l l l l l l l l l l l l l l;
%LET time_exposure = 0 1 1 2 2 2 2 2 2 1 1 2 2 2 2 2 2;
%LET time_covariate = 0 0 1 0 1 2 0 1 2 0 1 0 1 2 0 1 2;
%LET H = H H0 H0 H00 H00 H00 H01 H01 H01 H1 H1 H10 H10 H10 H11 H11 H11;

** SAS reports a maximum of 6 digits after the decimal point. Additionally, **;
** negative signs are interpreted as characters, and thus throw an error. To **;
** avoid this error, use the absolute value of D or SMD, and round the result. **;
*%LET D = 0.02609263 0.15209607 0.21724389 0.05392655 0.11621380 0.17294715 0.20766703 0.08740416 0.34194962 0.10434636 0.24238544 -0.01839888 0.03426966 0.21418539 0.05650881 0.02276367 0.15625715;
%LET D = 0.026093 0.152096 0.217244 0.053927 0.116214 0.172947 0.207667 0.087404 0.34195 0.104346 0.242385 0.018399 0.03427 0.214185 0.056509 0.022764 0.156257;

*%LET SMD = 0.05590150 0.33343944 0.46962221 0.12520235 0.27013382 0.37295726 0.43471684 0.17484151 0.74633007 0.22225472 0.51276500 -0.04110115 0.06881350 0.43824548 0.11523424 0.04989958 0.36601604;
%LET SMD = 0.055902 0.333439 0.469622 0.125202 0.270134 0.372957 0.434717 0.174842 0.74633 0.222255 0.512765 0.041101 0.068814 0.438246 0.115234 0.0499 0.366016;

%LET N = 1000 511 511 282 282 282 193 193 193 489 489 169 169 169 203 203 203;
%LET Nexp = 489 209 209 85 85 85 110 110 110 265 265 80 80 80 141 141 141;


** Generate list of variables in df_twdy_b, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdy_b data set */
   proc contents data=df_twdy_b out=rawVar(keep=name) noprint;
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
       from df_twdy_b;
   quit;
     
   %if &numRow1. ne 41 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   
  
/* Subset to include only records with name_cov="l" */
data df_twdy_b_name_cov_l;
   set df_twdy_b;
   if name_cov eq "l";
run;


/* Compare H in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select H into :df_twdy_b_H_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_H_List = &df_twdy_b_H_List; 

%if &df_twdy_b_H_List. ne &H. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare name_cov in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_b_name_cov_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_name_cov_List = &df_twdy_b_name_cov_List; 

%if &df_twdy_b_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_b_time_exposure_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_exposure_List = &df_twdy_b_time_exposure_List; 

%if &df_twdy_b_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_b_time_covariate_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_covariate_List = &df_twdy_b_time_covariate_List; 

%if &df_twdy_b_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare D in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(D), 0.0000001) into :df_twdy_b_D_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_D_List = &df_twdy_b_D_List; 

%if &df_twdy_b_D_List. ne &D. %then %do;
  %put ERROR: At least one D does not match.;
%end;


/* Compare SMD in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(SMD), 0.0000001) into :df_twdy_b_SMD_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_SMD_List = &df_twdy_b_SMD_List; 

%if &df_twdy_b_SMD_List. ne &SMD. %then %do;
  %put ERROR: At least one SMD does not match.;
%end;


/* Compare N in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(N, 0.0000001) into :df_twdy_b_N_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_N_List = &df_twdy_b_N_List; 

%if &df_twdy_b_N_List. ne &N. %then %do;
  %put ERROR: At least one N does not match.;
%end;


/* Compare Nexp in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(Nexp, 0.0000001) into :df_twdy_b_Nexp_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_Nexp_List = &df_twdy_b_Nexp_List; 

%if &df_twdy_b_Nexp_List. ne &Nexp. %then %do;
  %put ERROR: At least one Nexp does not match.;
%end;



*------------------------------------------*;
* Check Diagnostic 1, censoring, scope all *;
*------------------------------------------*;

%lengthen(
 input=df_twdy, 
 output=df_twdy_t, 
 diagnostic=1, 
 censoring=yes, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a, 
 temporal_covariate=l m, 
 static_covariate=p, 
 history=haone,
 censor=s
);


%balance(
 input=df_twdy_t, 
 output=df_twdy_b, 
 diagnostic=1, 
 approach=none, 
 censoring=yes, 
 scope=all, 
 times_exposure=0 1 2, 
 times_covariate= 0 1 2, 
 exposure=a,
 history=haone
);


/* Create macro variables with true values for name_cov="l" */
%LET name_list = E H name_cov time_exposure time_covariate D SMD N Nexp;
%LET E = 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1;
%LET name_cov = l l l l l l l l l l l l l l l l l;
%LET time_exposure = 0 1 1 2 2 2 2 2 2 1 1 2 2 2 2 2 2;
%LET time_covariate = 0 0 1 0 1 2 0 1 2 0 1 0 1 2 0 1 2;
%LET H = H H0 H0 H00 H00 H00 H01 H01 H01 H1 H1 H10 H10 H10 H11 H11 H11;
*%LET D = 0.02609263 0.13873884 0.22327564 0.05386251 0.11139746 0.16770827 0.19251701 0.05605442 0.31510204 0.12189932 0.27740694 -0.05938834 0.02489331 0.18492176 -0.02593126 -0.05947726 0.11648487;
%LET D = 0.026093 0.138739 0.223276 0.053863 0.111398 0.167708 0.192517 0.056054 0.315102 0.121899 0.277407 0.059388 0.024893 0.184922 0.025931 0.059477 0.116485;
*%LET SMD = 0.05590150 0.30519938 0.48385999 0.12382796 0.25878327 0.36035888 0.40310289 0.11231286 0.68107384 0.25901317 0.58458062 -0.13265952 0.04991489 0.37730425 -0.05216420 -0.13248591 0.28258688;
%LET SMD = 0.055902 0.305199 0.48386 0.123828 0.258783 0.360359 0.403103 0.112313 0.681074 0.259013 0.584581 0.13266 0.049915 0.377304 0.052164 0.132486 0.282587;
%LET N = 1000 475 475 270 270 270 173 173 173 372 372 150 150 150 156 156 156;
%LET Nexp = 489 193 193 83 83 83 98 98 98 203 203 74 74 74 113 113 113;


** Generate list of variables in df_twdy_b, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdy_b data set */
   proc contents data=df_twdy_b out=rawVar(keep=name) noprint;
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
       from df_twdy_b;
   quit;
     
   %if &numRow1. ne 41 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   
  
/* Subset to include only records with name_cov="l" */
data df_twdy_b_name_cov_l;
   set df_twdy_b;
   if name_cov eq "l";
run;


/* Compare H in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select H into :df_twdy_b_H_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_H_List = &df_twdy_b_H_List; 

%if &df_twdy_b_H_List. ne &H. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare name_cov in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_b_name_cov_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_name_cov_List = &df_twdy_b_name_cov_List; 

%if &df_twdy_b_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_b_time_exposure_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_exposure_List = &df_twdy_b_time_exposure_List; 

%if &df_twdy_b_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_b_time_covariate_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_covariate_List = &df_twdy_b_time_covariate_List; 

%if &df_twdy_b_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare D in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(D), 0.0000001) into :df_twdy_b_D_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_D_List = &df_twdy_b_D_List; 

%if &df_twdy_b_D_List. ne &D. %then %do;
  %put ERROR: At least one D does not match.;
%end;


/* Compare SMD in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(SMD), 0.0000001) into :df_twdy_b_SMD_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_SMD_List = &df_twdy_b_SMD_List; 

%if &df_twdy_b_SMD_List. ne &SMD. %then %do;
  %put ERROR: At least one SMD does not match.;
%end;


/* Compare N in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(N, 0.0000001) into :df_twdy_b_N_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_N_List = &df_twdy_b_N_List; 

%if &df_twdy_b_N_List. ne &N. %then %do;
  %put ERROR: At least one N does not match.;
%end;


/* Compare Nexp in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(Nexp, 0.0000001) into :df_twdy_b_Nexp_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_Nexp_List = &df_twdy_b_Nexp_List; 

%if &df_twdy_b_Nexp_List. ne &Nexp. %then %do;
  %put ERROR: At least one Nexp does not match.;
%end;



*-----------------------------------------------------*;
* Check Diagnostic 2, no censoring, weight, scope all *;
*-----------------------------------------------------*;

%lengthen(
 input=df_twdy, 
 output=df_twdy_t, 
 diagnostic=2, 
 censoring=no, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a, 
 temporal_covariate=l m, 
 static_covariate=p, 
 history=haone,
 weight_exposure=wax
);


%balance(
 input=df_twdy_t, 
 output=df_twdy_b, 
 diagnostic=2, 
 approach=weight, 
 censoring=no, 
 scope=all, 
 times_exposure=0 1 2, 
 times_covariate= 0 1 2, 
 exposure=a,
 history=haone,
 weight_exposure=wax
);


/* Create macro variables with true values for name_cov="l" */
%LET name_list = E H name_cov time_exposure time_covariate D SMD N Nexp;
%LET E = 1 1 1 1;
%LET name_cov = l l l l;
%LET time_exposure = 0 0 1 1;
%LET time_covariate = 1 2 2 2;
%LET H = H H H0 H1;
*%LET D = 0.2704053 0.1706721 0.1935464 0.2826376;
%LET D = 0.270405 0.170672 0.193546 0.282638;
*%LET SMD = 0.5624117 0.3462512 0.4054861 0.6096874;
%LET SMD = 0.562412 0.346251 0.405486 0.609687;
%LET N = 1000.345 846.7623 488.2676 358.0988;
%LET Nexp = 489.1822 371.5281 207.5916 195.296;


** Generate list of variables in df_twdy_b, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdy_b data set */
   proc contents data=df_twdy_b out=rawVar(keep=name) noprint;
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
       from df_twdy_b;
   quit;
     
   %if &numRow1. ne 8 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   
  
/* Subset to include only records with name_cov="l" */
data df_twdy_b_name_cov_l;
   set df_twdy_b;
   if name_cov eq "l";
run;


/* Compare H in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select H into :df_twdy_b_H_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_H_List = &df_twdy_b_H_List; 

%if &df_twdy_b_H_List. ne &H. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare name_cov in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_b_name_cov_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_name_cov_List = &df_twdy_b_name_cov_List; 

%if &df_twdy_b_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_b_time_exposure_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_exposure_List = &df_twdy_b_time_exposure_List; 

%if &df_twdy_b_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_b_time_covariate_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_covariate_List = &df_twdy_b_time_covariate_List; 

%if &df_twdy_b_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare D in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(D), 0.0000001) into :df_twdy_b_D_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_D_List = &df_twdy_b_D_List; 

%if &df_twdy_b_D_List. ne &D. %then %do;
  %put ERROR: At least one D does not match.;
%end;


/* Compare SMD in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(SMD), 0.0000001) into :df_twdy_b_SMD_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_SMD_List = &df_twdy_b_SMD_List; 

%if &df_twdy_b_SMD_List. ne &SMD. %then %do;
  %put ERROR: At least one SMD does not match.;
%end;


/* Compare N in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(N, 0.0000001) into :df_twdy_b_N_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_N_List = &df_twdy_b_N_List; 

%if &df_twdy_b_N_List. ne &N. %then %do;
  %put ERROR: At least one N does not match.;
%end;


/* Compare Nexp in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(Nexp, 0.0000001) into :df_twdy_b_Nexp_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_Nexp_List = &df_twdy_b_Nexp_List; 

%if &df_twdy_b_Nexp_List. ne &Nexp. %then %do;
  %put ERROR: At least one Nexp does not match.;
%end;



*------------------------------------------------------------*;
* Check Diagnostic 2, censoring, weight, stratify, scope all *;
*------------------------------------------------------------*;

%lengthen(
 input=df_twdy, 
 output=df_twdy_t, 
 diagnostic=2, 
 censoring=yes, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a, 
 temporal_covariate=l m, 
 static_covariate=p,
 censor=s,
 history=haone,
 weight_exposure=wax,
 weight_censor=wsx
);


%balance(
 input=df_twdy_t, 
 output=df_twdy_b, 
 diagnostic=2, 
 approach=weight, 
 censoring=yes, 
 scope=all, 
 times_exposure=0 1 2, 
 times_covariate= 0 1 2, 
 exposure=a,
 history=haone,
 weight_exposure=wax,
 weight_censor=wsx
);


/* Create macro variables with true values for name_cov="l" */
%LET name_list = E H name_cov time_exposure time_covariate D SMD N Nexp;
%LET E = 1 1 1 1;
%LET name_cov = l l l l;
%LET time_exposure = 0 0 1 1;
%LET time_covariate = 1 2 2 2;
%LET H = H H H0 H1;
*%LET D = 0.2374073 0.1692529 0.2284099 0.3389303;
%LET D = 0.237407 0.169253 0.22841 0.33893;
*%LET SMD = 0.4907694 0.3434338 0.4778534 0.7431715;
%LET SMD = 0.490769 0.343434 0.477853 0.743172;
%LET N = 847.198 728.3102 378.8492 336.3361;
%LET Nexp = 418.598 361.0482 163.0554 174.2889;


** Generate list of variables in df_twdy_b, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdy_b data set */
   proc contents data=df_twdy_b out=rawVar(keep=name) noprint;
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
       from df_twdy_b;
   quit;
     
   %if &numRow1. ne 8 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   
  
/* Subset to include only records with name_cov="l" */
data df_twdy_b_name_cov_l;
   set df_twdy_b;
   if name_cov eq "l";
run;


/* Compare H in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select H into :df_twdy_b_H_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_H_List = &df_twdy_b_H_List; 

%if &df_twdy_b_H_List. ne &H. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare name_cov in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_b_name_cov_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_name_cov_List = &df_twdy_b_name_cov_List; 

%if &df_twdy_b_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_b_time_exposure_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_exposure_List = &df_twdy_b_time_exposure_List; 

%if &df_twdy_b_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_b_time_covariate_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_covariate_List = &df_twdy_b_time_covariate_List; 

%if &df_twdy_b_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare D in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(D), 0.0000001) into :df_twdy_b_D_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_D_List = &df_twdy_b_D_List; 

%if &df_twdy_b_D_List. ne &D. %then %do;
  %put ERROR: At least one D does not match.;
%end;


/* Compare SMD in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(SMD), 0.0000001) into :df_twdy_b_SMD_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_SMD_List = &df_twdy_b_SMD_List; 

%if &df_twdy_b_SMD_List. ne &SMD. %then %do;
  %put ERROR: At least one SMD does not match.;
%end;


/* Compare N in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(N, 0.0000001) into :df_twdy_b_N_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_N_List = &df_twdy_b_N_List; 

%if &df_twdy_b_N_List. ne &N. %then %do;
  %put ERROR: At least one N does not match.;
%end;


/* Compare Nexp in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(Nexp, 0.0000001) into :df_twdy_b_Nexp_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_Nexp_List = &df_twdy_b_Nexp_List; 

%if &df_twdy_b_Nexp_List. ne &Nexp. %then %do;
  %put ERROR: At least one Nexp does not match.;
%end;



*-------------------------------------------------------*;
* Check Diagnostic 2, no censoring, stratify, scope all *;
*-------------------------------------------------------*;

%lengthen(
 input=df_twdy, 
 output=df_twdy_t, 
 diagnostic=2, 
 censoring=no, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a, 
 temporal_covariate=l m, 
 static_covariate=p,
 strata=e5
);


%balance(
 input=df_twdy_t, 
 output=df_twdy_b, 
 diagnostic=2, 
 approach=stratify, 
 censoring=no, 
 scope=all, 
 times_exposure=0 1 2, 
 times_covariate= 0 1 2, 
 exposure=a,
 strata=e5
);


/* Create macro variables with true values for name_cov="l" */
%LET name_list = E S name_cov time_exposure time_covariate D SMD N Nexp;
%LET E = 1 1 1 1 1 1 1;
%LET name_cov = l l l l l l l;
%LET S = 1 2 3 3 3 4 5;
%LET time_exposure = 1 1 0 0 1 1 1;
%LET time_covariate = 2 2 1 2 2 2 2;
*%LET D = 0.2405892 0.1935185 0.2729881 0.1713809 0.2397481 0.2871219 0.2139037;
%LET D = 0.240589 0.193519 0.272988 0.171381 0.239748 0.287122 0.213904;
*%LET SMD = 0.5127960 0.4022628 0.5677838 0.3476923 0.4914239 0.6232376 0.4875769;
%LET SMD = 0.512796 0.402263 0.567784 0.347692 0.491424 0.623238 0.487577;
%LET N = 180 174 1000 847 173 154 166;
%LET Nexp = 39 54 489 372 82 89 132;


** Generate list of variables in df_twdy_b, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdy_b data set */
   proc contents data=df_twdy_b out=rawVar(keep=name) noprint;
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
       from df_twdy_b;
   quit;
     
   %if &numRow1. ne 14 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   
  
/* Subset to include only records with name_cov="l" */
data df_twdy_b_name_cov_l;
   set df_twdy_b;
   if name_cov eq "l";
run;


/* Compare S in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select S into :df_twdy_b_S_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_S_List = &df_twdy_b_S_List; 

%if &df_twdy_b_S_List. ne &S. %then %do;
  %put ERROR: At least one strata value does not match.;
%end;


/* Compare name_cov in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_b_name_cov_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_name_cov_List = &df_twdy_b_name_cov_List; 

%if &df_twdy_b_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_b_time_exposure_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_exposure_List = &df_twdy_b_time_exposure_List; 

%if &df_twdy_b_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_b_time_covariate_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_covariate_List = &df_twdy_b_time_covariate_List; 

%if &df_twdy_b_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare D in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(D), 0.0000001) into :df_twdy_b_D_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_D_List = &df_twdy_b_D_List; 

%if &df_twdy_b_D_List. ne &D. %then %do;
  %put ERROR: At least one D does not match.;
%end;


/* Compare SMD in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(SMD), 0.0000001) into :df_twdy_b_SMD_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_SMD_List = &df_twdy_b_SMD_List; 

%if &df_twdy_b_SMD_List. ne &SMD. %then %do;
  %put ERROR: At least one SMD does not match.;
%end;


/* Compare N in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(N, 0.0000001) into :df_twdy_b_N_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_N_List = &df_twdy_b_N_List; 

%if &df_twdy_b_N_List. ne &N. %then %do;
  %put ERROR: At least one N does not match.;
%end;


/* Compare Nexp in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(Nexp, 0.0000001) into :df_twdy_b_Nexp_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_Nexp_List = &df_twdy_b_Nexp_List; 

%if &df_twdy_b_Nexp_List. ne &Nexp. %then %do;
  %put ERROR: At least one Nexp does not match.;
%end;



*----------------------------------------------------*;
* Check Diagnostic 2, censoring, stratify, scope all *;
*----------------------------------------------------*;

%lengthen(
 input=df_twdy, 
 output=df_twdy_t, 
 diagnostic=2, 
 censoring=yes, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a, 
 temporal_covariate=l m, 
 static_covariate=p,
 strata=e5,
 weight_censor=wsx,
 censor=s
);


%balance(
 input=df_twdy_t, 
 output=df_twdy_b, 
 diagnostic=2, 
 approach=stratify, 
 censoring=yes, 
 scope=all, 
 times_exposure=0 1 2, 
 times_covariate= 0 1 2, 
 exposure=a,
 strata=e5,
 weight_censor=wsx
);


/* Create macro variables with true values for name_cov="l" */
%LET name_list = E S name_cov time_exposure time_covariate D SMD N Nexp;
%LET E = 1 1 1 1 1 1 1;
%LET name_cov = l l l l l l l;
%LET S = 1 2 3 3 3 4 5;
%LET time_exposure = 1 1 0 0 1 1 1;
%LET time_covariate = 2 2 1 2 2 2 2;
*%LET D = 0.2237924 0.2001997 0.2400822 0.1704699 0.3568130 0.3308707 0.2447526;
%LET D = 0.223792 0.2002 0.240082 0.17047 0.356813 0.330871 0.244753;
*%LET SMD = 0.4717475 0.4186004 0.4963027 0.3459036 0.7391421 0.7126800 0.5709485;
%LET SMD = 0.471748 0.4186 0.496303 0.345904 0.739142 0.71268 0.570949;
%LET N = 153.6263 143.5396 846.8752 728.0074 153.636 128.5053 148.7002;
%LET Nexp = 31.66276 44.50004 418.29 360.9467 70.78702 74.55275 118.3354;


** Generate list of variables in df_twdy_b, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdy_b data set */
   proc contents data=df_twdy_b out=rawVar(keep=name) noprint;
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
       from df_twdy_b;
   quit;
     
   %if &numRow1. ne 14 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   
  
/* Subset to include only records with name_cov="l" */
data df_twdy_b_name_cov_l;
   set df_twdy_b;
   if name_cov eq "l";
run;


/* Compare S in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select S into :df_twdy_b_S_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_S_List = &df_twdy_b_S_List; 

%if &df_twdy_b_S_List. ne &S. %then %do;
  %put ERROR: At least one strata value does not match.;
%end;


/* Compare name_cov in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_b_name_cov_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_name_cov_List = &df_twdy_b_name_cov_List; 

%if &df_twdy_b_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_b_time_exposure_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_exposure_List = &df_twdy_b_time_exposure_List; 

%if &df_twdy_b_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_b_time_covariate_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_covariate_List = &df_twdy_b_time_covariate_List; 

%if &df_twdy_b_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare D in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(D), 0.0000001) into :df_twdy_b_D_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_D_List = &df_twdy_b_D_List; 

%if &df_twdy_b_D_List. ne &D. %then %do;
  %put ERROR: At least one D does not match.;
%end;


/* Compare SMD in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(SMD), 0.0000001) into :df_twdy_b_SMD_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_SMD_List = &df_twdy_b_SMD_List; 

%if &df_twdy_b_SMD_List. ne &SMD. %then %do;
  %put ERROR: At least one SMD does not match.;
%end;


/* Compare N in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(N, 0.0000001) into :df_twdy_b_N_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_N_List = &df_twdy_b_N_List; 

%if &df_twdy_b_N_List. ne &N. %then %do;
  %put ERROR: At least one N does not match.;
%end;


/* Compare Nexp in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(Nexp, 0.0000001) into :df_twdy_b_Nexp_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_Nexp_List = &df_twdy_b_Nexp_List; 

%if &df_twdy_b_Nexp_List. ne &Nexp. %then %do;
  %put ERROR: At least one Nexp does not match.;
%end;



*-----------------------------------------------------*;
* Check Diagnostic 3, no censoring, weight, scope all *;
*-----------------------------------------------------*;

%lengthen(
 input=df_twdy, 
 output=df_twdy_t, 
 diagnostic=3, 
 censoring=no, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a, 
 temporal_covariate=l m, 
 static_covariate=p,
 history=haone,
 weight_exposure=wax
);


%balance(
 input=df_twdy_t, 
 output=df_twdy_b, 
 diagnostic=3, 
 approach=weight, 
 censoring=no, 
 scope=all, 
 times_exposure=0 1 2, 
 times_covariate= 0 1 2, 
 exposure=a,
 history=haone,
 weight_exposure=wax,
 sort_order=alphabetical,
 loop=no,
 ignore_missing_metric=no,
 metric=SMD,
 sd_ref=no
);


/* Create macro variables with true values for name_cov="l" */
%LET name_list = E H name_cov time_exposure time_covariate D SMD N Nexp;
%LET E = 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1;
%LET name_cov = l l l l l l l l l l l l l l l l l;
%LET H = H H0 H0 H00 H00 H00 H01 H01 H01 H1 H1 H10 H10 H10 H11 H11 H11;
%LET time_exposure = 0 1 1 2 2 2 2 2 2 1 1 2 2 2 2 2 2;
%LET time_covariate = 0 0 1 0 1 2 0 1 2 0 1 0 1 2 0 1 2;
*%LET D = 0.0132437982 0.0281118841 0.0473004498 -0.0007154549 0.0219660364 -0.0602237719, 0.0950079294 -0.0144350060 0.1212943137 0.0351917311 0.0522696694 -0.0457638834 -0.0577264801 -0.1349804239 0.0409262647 -0.0889460751 -0.0077944626;
%LET D = 0.013244 0.028112 0.047301 0.000716 0.021966 0.060224 0.095008 0.014435 0.121294 0.035192 0.05227 0.045764 0.057727 0.13498 0.040926 0.088946 0.007795;
*%LET SMD = 0.028373838 0.061484448 0.101989826 -0.001662109 0.051121193 -0.129995531 0.198281755 -0.028867581 0.265780729 0.074945005 0.110601626 -0.102210629 -0.115926434 -0.276297658 0.083479654 -0.194916554 -0.018217258;
%LET SMD = 0.028374 0.061484 0.10199 0.001662 0.051121 0.129996 0.198282 0.028868 0.265781 0.074945 0.110602 0.102211 0.115926 0.276298 0.08348 0.194917 0.018217;
*%LET N = 1000.3453 521.9669 521.9669 289.7041 289.7041 289.7041 191.3426 191.3426 191.3426 476.0281 476.0281 184.6182 184.6182 184.6182 193.8664 193.8664 193.8664;
%LET N = 1000.345 521.9669 521.9669 289.7041 289.7041 289.7041 191.3426 191.3426 191.3426 476.0281 476.0281 184.6182 184.6182 184.6182 193.8664 193.8664 193.8664;
*%LET Nexp = 489.18220 222.78259 222.78259 84.95693 84.95693 84.95693 113.88562 113.88562 113.88562 258.93368 258.93368 85.55982 85.55982 85.55982 132.49058 132.49058 132.49058;
%LET Nexp = 489.1822 222.7826 222.7826 84.95693 84.95693 84.95693 113.8856 113.8856 113.8856 258.9337 258.9337 85.55982 85.55982 85.55982 132.4906 132.4906 132.4906;


** Generate list of variables in df_twdy_b, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdy_b data set */
   proc contents data=df_twdy_b out=rawVar(keep=name) noprint;
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
       from df_twdy_b;
   quit;
     
   %if &numRow1. ne 41 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   
  
/* Subset to include only records with name_cov="l" */
data df_twdy_b_name_cov_l;
   set df_twdy_b;
   if name_cov eq "l";
run;


/* Compare name_cov in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_b_name_cov_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_name_cov_List = &df_twdy_b_name_cov_List; 

%if &df_twdy_b_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_b_time_exposure_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_exposure_List = &df_twdy_b_time_exposure_List; 

%if &df_twdy_b_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_b_time_covariate_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_covariate_List = &df_twdy_b_time_covariate_List; 

%if &df_twdy_b_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare D in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(D), 0.0000001) into :df_twdy_b_D_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_D_List = &df_twdy_b_D_List; 

%if &df_twdy_b_D_List. ne &D. %then %do;
  %put ERROR: At least one D does not match.;
%end;


/* Compare SMD in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(SMD), 0.0000001) into :df_twdy_b_SMD_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_SMD_List = &df_twdy_b_SMD_List; 

%if &df_twdy_b_SMD_List. ne &SMD. %then %do;
  %put ERROR: At least one SMD does not match.;
%end;


/* Compare N in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(N, 0.0000001) into :df_twdy_b_N_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_N_List = &df_twdy_b_N_List; 

%if &df_twdy_b_N_List. ne &N. %then %do;
  %put ERROR: At least one N does not match.;
%end;


/* Compare Nexp in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(Nexp, 0.0000001) into :df_twdy_b_Nexp_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_Nexp_List = &df_twdy_b_Nexp_List; 

%if &df_twdy_b_Nexp_List. ne &Nexp. %then %do;
  %put ERROR: At least one Nexp does not match.;
%end;


*--------------------------------------------------*;
* Check Diagnostic 3, censoring, weight, scope all *;
*--------------------------------------------------*;

%lengthen(
 input=df_twdy, 
 output=df_twdy_t, 
 diagnostic=3, 
 censoring=yes, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a, 
 temporal_covariate=l m, 
 static_covariate=p,
 history=haone,
 weight_exposure=wax,
 weight_censor=wsx,
 censor=s
);


%balance(
 input=df_twdy_t, 
 output=df_twdy_b, 
 diagnostic=3, 
 approach=weight, 
 censoring=yes, 
 scope=all, 
 times_exposure=0 1 2, 
 times_covariate= 0 1 2, 
 exposure=a,
 history=haone,
 weight_exposure=wax,
 weight_censor=wsx,
 sort_order=alphabetical,
 loop=no,
 ignore_missing_metric=no,
 metric=SMD,
 sd_ref=no
);


/* Create macro variables with true values for name_cov="l" */
%LET name_list = E H name_cov time_exposure time_covariate D SMD N Nexp;
%LET E = 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1;
%LET name_cov = l l l l l l l l l l l l l l l l l;
%LET H = H H0 H0 H00 H00 H00 H01 H01 H01 H1 H1 H10 H10 H10 H11 H11 H11;
%LET time_exposure = 0 1 1 2 2 2 2 2 2 1 1 2 2 2 2 2 2;
%LET time_covariate = 0 0 1 0 1 2 0 1 2 0 1 0 1 2 0 1 2;
*%LET D = 0.013243798 0.016157784 0.051980229 -0.002844623 0.015815967 -0.068254599 0.104956374 -0.076899766 0.115652754 0.050064019 0.092905944 -0.067090916 -0.069583841 -0.170534731 -0.007140200 -0.178699307 -0.075917283;
%LET D = 0.013244 0.016158 0.05198 0.002845 0.015816 0.068255 0.104956 0.0769 0.115653 0.050064 0.092906 0.067091 0.069584 0.170535 0.00714 0.178699 0.075917;
*%LET SMD = 0.028373838 0.035459449 0.112330984 -0.006544283 0.036793102 -0.146820420 0.219116045 -0.154032969 0.250922669 0.106379786 0.195775471 -0.149630727 -0.139548490 -0.348361620 -0.014358615 -0.398632453 -0.183401291;
%LET SMD = 0.028374 0.035459 0.112331 0.006544 0.036793 0.14682 0.219116 0.154033 0.250923 0.10638 0.195775 0.149631 0.139548 0.348362 0.014359 0.398632 0.183401;
%LET N = 1000.345 488.2676 488.2676 280.6058 280.6058 280.6058 169.4771 169.4771 169.4771 358.0988 358.0988 172.7356 172.7356 172.7356 145.8214 145.8214 145.8214;
%LET Nexp = 489.1822 207.59162 207.59162 83.51905 83.51905 83.51905 100.29219 100.29219 100.29219 195.29603 195.29603 81.27641 81.27641 81.27641 102.34637 102.34637 102.34637;


** Generate list of variables in df_twdy_b, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdy_b data set */
   proc contents data=df_twdy_b out=rawVar(keep=name) noprint;
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
       from df_twdy_b;
   quit;
     
   %if &numRow1. ne 41 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   
  
/* Subset to include only records with name_cov="l" */
data df_twdy_b_name_cov_l;
   set df_twdy_b;
   if name_cov eq "l";
run;


/* Compare name_cov in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_b_name_cov_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_name_cov_List = &df_twdy_b_name_cov_List; 

%if &df_twdy_b_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_b_time_exposure_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_exposure_List = &df_twdy_b_time_exposure_List; 

%if &df_twdy_b_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_b_time_covariate_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_covariate_List = &df_twdy_b_time_covariate_List; 

%if &df_twdy_b_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare D in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(D), 0.0000001) into :df_twdy_b_D_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_D_List = &df_twdy_b_D_List; 

%if &df_twdy_b_D_List. ne &D. %then %do;
  %put ERROR: At least one D does not match.;
%end;


/* Compare SMD in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(SMD), 0.0000001) into :df_twdy_b_SMD_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_SMD_List = &df_twdy_b_SMD_List; 

%if &df_twdy_b_SMD_List. ne &SMD. %then %do;
  %put ERROR: At least one SMD does not match.;
%end;


/* Compare N in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(N, 0.0000001) into :df_twdy_b_N_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_N_List = &df_twdy_b_N_List; 

%if &df_twdy_b_N_List. ne &N. %then %do;
  %put ERROR: At least one N does not match.;
%end;


/* Compare Nexp in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(Nexp, 0.0000001) into :df_twdy_b_Nexp_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_Nexp_List = &df_twdy_b_Nexp_List; 

%if &df_twdy_b_Nexp_List. ne &Nexp. %then %do;
  %put ERROR: At least one Nexp does not match.;
%end;



*-------------------------------------------------------*;
* Check Diagnostic 3, no censoring, stratify, scope all *;
*-------------------------------------------------------*;

%lengthen(
 input=df_twdy, 
 output=df_twdy_t, 
 diagnostic=3, 
 censoring=no, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a, 
 temporal_covariate=l m, 
 static_covariate=p,
 history=haone,
 strata=e5
);


%balance(
 input=df_twdy_t, 
 output=df_twdy_b, 
 diagnostic=3, 
 approach=stratify, 
 censoring=no, 
 scope=all, 
 times_exposure=0 1 2, 
 times_covariate= 0 1 2, 
 exposure=a,
 history=haone,
 strata=e5,
 loop=no
);


/* Create macro variables with true values for name_cov="l" */
%LET name_list = E S H name_cov time_exposure time_covariate D SMD N Nexp;
%LET E = 1 1 1 1 1 1 1 1 1 1 1 1 1;
%LET S = 1 1 1 1 1 1 1 1 1 1 1 1 1;
%LET name_cov = l l l l l l l l l l l l l;
%LET H = H0 H0 H00 H00 H00 H1 H1 H10 H10 H10 H11 H11 H11;
%LET time_exposure = 1 1 2 2 2 1 1 2 2 2 2 2 2;
%LET time_covariate = 0 1 0 1 2 0 1 0 1 2 0 1 2;
*%LET D = -0.08079590 0.09918601 0.02222222 0.18888889 0.21111111 -0.12615385 0.09076923 -0.03584229 -0.13261649 0.34767025 1.00000000 -0.66666667 0.00000000;
%LET D = 0.080796 0.099186 0.022222 0.188889 0.211111 0.126154 0.090769 0.035842 0.132617 0.34767 1 0.666667 0;
*%LET SMD = -0.22004338 0.25714206 0.05467434 0.50009388 0.58817876 -0.28716705 0.24566384 -0.08072658 -0.27792191 0.96505533 . . 0.00000000;
%LET SMD = 0.220043 0.257142 0.054674 0.500094 0.588179 0.287167 0.245664 0.080727 0.277922 0.965055 . . 0;
%LET N = 138 138 108 108 108 63 63 40 40 40 4 4 4;
%LET Nexp = 31 31 18 18 18 13 13 9 9 9 1 1 1;


** Generate list of variables in df_twdy_b, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdy_b data set */
   proc contents data=df_twdy_b out=rawVar(keep=name) noprint;
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
       from df_twdy_b;
   quit;
     
   %if &numRow1. ne 186 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   
  
/* Subset to include only records with name_cov="l" and S==1 */
data df_twdy_b_name_cov_l;
   set df_twdy_b;
   if name_cov eq "l" AND S eq 1;
run;


/* Compare S in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select S into :df_twdy_b_S_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_S_List = &df_twdy_b_S_List; 

%if &df_twdy_b_S_List. ne &S. %then %do;
  %put ERROR: At least one strata value does not match.;
%end;


/* Compare name_cov in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_b_name_cov_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_name_cov_List = &df_twdy_b_name_cov_List; 

%if &df_twdy_b_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_b_time_exposure_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_exposure_List = &df_twdy_b_time_exposure_List; 

%if &df_twdy_b_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_b_time_covariate_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_time_covariate_List = &df_twdy_b_time_covariate_List; 

%if &df_twdy_b_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare D in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(D), 0.0000001) into :df_twdy_b_D_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_D_List = &df_twdy_b_D_List; 

%if &df_twdy_b_D_List. ne &D. %then %do;
  %put ERROR: At least one D does not match.;
%end;


/* Compare SMD in df_twdy_b_name_cov_l and true list */
/* Use absolute value to avoid error caused by presence of negative sign */
proc sql noprint;                              
 select round(abs(SMD), 0.0000001) into :df_twdy_b_SMD_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_SMD_List = &df_twdy_b_SMD_List; 

%if &df_twdy_b_SMD_List. ne &SMD. %then %do;
  %put ERROR: At least one SMD does not match.;
%end;


/* Compare N in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(N, 0.0000001) into :df_twdy_b_N_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_N_List = &df_twdy_b_N_List; 

%if &df_twdy_b_N_List. ne &N. %then %do;
  %put ERROR: At least one N does not match.;
%end;


/* Compare Nexp in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select round(Nexp, 0.0000001) into :df_twdy_b_Nexp_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_Nexp_List = &df_twdy_b_Nexp_List; 

%if &df_twdy_b_Nexp_List. ne &Nexp. %then %do;
  %put ERROR: At least one Nexp does not match.;
%end;


** End of tests for %balance() without Apply Scope **;