/* Erin Schnellinger */
/* 24 May 2019 */

/* Program to test the %balance() SAS Macro with Apply Scope */

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
  
  
*--------------------------------------------*;
* Test the %balance() macro with Apply Scope *;
*--------------------------------------------*;

** Import the relevant toy data sets **;

proc import datafile="/folders/myfolders/confoundr_SAS-master/data/toy_wide_dropoutY.csv"
   out=df_twdy dbms=csv replace;
   getnames=yes;
run;


*---------------------------------------*;
* Check Diagnostic 1, recent, recency 1 *;
*---------------------------------------*;

%lengthen(
 input=df_twdy, 
 output=df_twdy_t, 
 diagnostic=1, 
 censoring=no, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a,
 history=haone,
 temporal_covariate=l m, 
 static_covariate=p
);


%balance(
 input=df_twdy_t, 
 output=df_twdy_b, 
 diagnostic=1, 
 approach=none, 
 censoring=no, 
 scope=recent, 
 times_exposure=0 1 2, 
 times_covariate= 0 1 2, 
 exposure=a,
 history=haone
);


/* Create macro variables with true values for name_cov="l" */
%LET name_list = E H name_cov time_exposure time_covariate D SMD N Nexp;
%LET E = 1 1 1 1 1 1;
%LET name_cov = l l l l l l;
%LET H = H0 H00 H01 H1 H10 H11;
%LET time_exposure = 1 2 2 1 2 2;
%LET time_covariate = 0 1 1 0 1 1;
%LET D = 0.15209607 0.11621380 0.08740416 0.10434636 0.03426966 0.02276367;
%LET SMD = 0.33343944 0.27013382 0.17484151 0.22225472 0.06881350 0.04989958;
%LET N = 511 282 193 489 169 203;
%LET Nexp = 209 85 110 265 80 141;


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



*-----------------------------------------*;
* Check Diagnostic 2, average over strata *;
*-----------------------------------------*;

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
 scope=average, 
 average_over=strata,
 times_exposure=0 1 2, 
 times_covariate= 0 1 2, 
 exposure=a,
 strata=e5
);


/* Create macro variables with true values for name_cov="l" */
%LET name_list = time_exposure time_covariate D SMD N Nexp;
%LET E = 1 1 1;
%LET name_cov = l l l;
%LET time_exposure = 0 0 1;
%LET time_covariate = 1 2 2;
%LET D = 0.2729881 0.1713809 0.2339781;
%LET SMD = 0.5677838 0.3476923 0.5008615;
%LET N = 489 372 396;
%LET Nexp = 1000 847 847;


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
     
   %if &numRow1. ne 6 %then %do;
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



*------------------------------------------*;
* Check Diagnostic 1, average over history *;
*------------------------------------------*;

%lengthen(
 input=df_twdy, 
 output=df_twdy_t, 
 diagnostic=1, 
 censoring=no, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a,
 history=haone,
 temporal_covariate=l m, 
 static_covariate=p
);


%balance(
 input=df_twdy_t, 
 output=df_twdy_b, 
 diagnostic=1, 
 approach=none, 
 censoring=no, 
 scope=average,
 average_over=history,
 times_exposure=0 1 2, 
 times_covariate= 0 1 2, 
 exposure=a,
 history=haone
);


/* Create macro variables with true values for name_cov="l" */
%LET name_list = time_exposure time_covariate D SMD N;
%LET E = 1 1 1 1 1 1;
%LET name_cov = l l l l l l;
%LET time_exposure = 0 1 1 2 2 2;
%LET time_covariate = 0 0 1 0 1 2;
%LET D = 0.02609263 0.12874646 0.22953811 0.07514628 0.07090188 0.21568466;
%LET SMD = 0.0559015 0.2790701 0.4907190 0.1601581 0.1554678 0.4693983;
%LET N = 1000 1000 1000 847 847 847;


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
     
   %if &numRow1. ne 15 %then %do;
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



*---------------------------------------*;
* Check Diagnostic 1, average over time *;
*---------------------------------------*;

%lengthen(
 input=df_twdy, 
 output=df_twdy_t, 
 diagnostic=1, 
 censoring=no, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a,
 history=haone,
 temporal_covariate=l m, 
 static_covariate=p
);


%balance(
 input=df_twdy_t, 
 output=df_twdy_b, 
 diagnostic=1, 
 approach=none, 
 censoring=no, 
 scope=average,
 average_over=time,
 times_exposure=0 1 2, 
 times_covariate= 0 1 2, 
 exposure=a,
 history=haone
);


/* Create macro variables with true values for name_cov="l" */
%LET name_list = distance name_cov D SMD N;
%LET E = 1 1 1;
%LET name_cov = l l l;
%LET distance = 0 1 2;
%LET D = 0.15395702 0.10222001 0.07514628;
%LET SMD = 0.3316477 0.2223884 0.1601581;
%LET N = 2847 1847 847;


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
     
   %if &numRow1. ne 9 %then %do;
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


/* Compare distance in df_twdy_b_name_cov_l and true list */
proc sql noprint;                              
 select distance into :df_twdy_b_distance_List separated by ' '
 from df_twdy_b_name_cov_l;
quit;
%put df_twdy_b_distance_List = &df_twdy_b_distance_List; 

%if &df_twdy_b_distance_List. ne &distance. %then %do;
  %put ERROR: At least one distance does not match.;
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



*--------------------------------------------------------*;
* Check Diagnostic 1, average within periods of distance *;
*--------------------------------------------------------*;

%lengthen(
 input=df_twdy, 
 output=df_twdy_t, 
 diagnostic=1, 
 censoring=no, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a,
 history=haone,
 temporal_covariate=l m, 
 static_covariate=p
);


%balance(
 input=df_twdy_t, 
 output=df_twdy_b, 
 diagnostic=1, 
 approach=none, 
 censoring=no, 
 scope=average,
 average_over=distance,
 periods=0:1 2
 times_exposure=0 1 2, 
 times_covariate= 0 1 2, 
 exposure=a,
 history=haone
);


/* Create macro variables with true values for name_cov="l" */
%LET name_list = period_id period_start period_end name_cov D SMD N;
%LET period_id = 1 2;
%LET period_start = 0 2;
%LET period_end = 1 2;
%LET name_cov = l l;
%LET D = 0.13359949 0.07514628;
%LET SMD = 0.2886562 0.1601581;
%LET N = 4694 847;


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
     
   %if &numRow1. ne 6 %then %do;
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


*-------------------------------------------*;
* Check Diagnostic 1, average over distance *;
*-------------------------------------------*;

%lengthen(
 input=df_twdy, 
 output=df_twdy_t, 
 diagnostic=1, 
 censoring=no, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a,
 history=haone,
 temporal_covariate=l m, 
 static_covariate=p
);


%balance(
 input=df_twdy_t, 
 output=df_twdy_b, 
 diagnostic=1, 
 approach=none, 
 censoring=no, 
 scope=average,
 average_over=distance,
 periods=0:1 2
 times_exposure=0 1 2, 
 times_covariate= 0 1 2, 
 exposure=a,
 history=haone
);


/* Create macro variables with true values for name_cov="l" */
%LET name_list = period_id period_start period_end name_cov D SMD N;
%LET period_id = 1;
%LET period_start = 0;
%LET period_end = 2;
%LET name_cov = l;
%LET D = 0.1246643;
%LET SMD = 0.2690139;
%LET N = 5541;


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
     
   %if &numRow1. ne 3 %then %do;
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


** End of tests for %balance() with Apply Scope **;