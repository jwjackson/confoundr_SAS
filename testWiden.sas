/* Erin Schnellinger */
/* 28 September 2018 */

/* Program to test the %widen() SAS Macro */

** Clear contents in the output and log windows **;
   dm 'out;clear;log;clear;';

** Clear titles and footnotes **;
   title;
   footnote;

** Clear temporary data sets in the work library **;
   proc datasets nolist lib=work memtype=data kill;run;quit;
   
   
** Macro options **;
   options minoperator /*mprint mlogic symbolgen*/;

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
  
  
*-------------------------*;
* Test the %widen() macro *;
*-------------------------*;

** Import the relevant toy data sets **;

proc import datafile="/folders/myfolders/confoundr_SAS-master/data/toy_wide_dropoutN.csv"
   out=df_twdn dbms=csv replace;
   getnames=yes;
run;

proc import datafile="/folders/myfolders/confoundr_SAS-master/data/toy_wide_dropoutY.csv"
   out=df_twdy dbms=csv replace;
   getnames=yes;
run;

proc import datafile="/folders/myfolders/confoundr_SAS-master/data/toy_long_dropoutN.csv"
   out=df_tldn dbms=csv replace;
   getnames=yes;
run;

proc import datafile="/folders/myfolders/confoundr_SAS-master/data/toy_long_dropoutY.csv"
   out=df_tldy dbms=csv replace;
   getnames=yes;
run;


** Check Formats and Names under No Dropout **;

%widen(
 output=df_tldn_w,
 input=df_tldn,
 id=uid,
 time=time,
 exposure=s,
 history=h,
 covariate=a l m n o p, 
 weight_exposure=wa wax,
 weight_censor=wsx,
 strata=e5,
 censor=s
);


/* Drop the history variables */
data df_tldn_w;
   set df_tldn_w(drop=h_0 h_1 h_2);  
run;


/* Check numeric format preservation */

/* Flag numeric values. Adapted from: */
/* https://communities.sas.com/t5/SAS-Procedures/Check-numeric-values-in-alphanumeric-variables/td-p/19247 */

data fmttest;
   set df_tldn_w;
   len=lengthn(a_0);
   newval=compress(a_0, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=1 */
   proc sql noprint;
       select count(flag) into :numFlag1  /* Macro variable for # of numeric flags */
       from fmttest(where=(flag=:1));
   quit;

/* Count the number of rows in df_tldn_w */
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_tldn_w */
       from df_tldn_w;
   quit;
   
   %if &numFlag1. ne &numRow2. %then %do;
       %put ERROR: The exposure is not in numeric format.;
   %end;


/* Check Number of Columns */

proc contents data=df_twdn out=cont1;
run;

proc contents data=df_tldn_w out=cont2;
run;


   proc sql noprint;
       select count(*) into :numCol1  /* Macro variable for # of columns in df_twdn */
       from cont1;
   quit;
   
   
   proc sql noprint;
       select count(*) into :numCol2  /* Macro variable for # of columns in df_tldn_w */
       from cont2;
   quit;
   
   %if (%eval(&numCol1.)-18) ne &numCol2. %then %do;
       %put ERROR: The number of columns do not match.;
   %end;
   

/* Check Number of Rows */
   proc sql noprint;
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdn */
       from df_twdn;
   quit;
   
   
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_tldn_w */
       from df_tldn_w;
   quit;
   
   %if &numRow1. ne &numRow2. %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   
   
/* Check Expected Names */

   /* Get common variable names across the df_tldn_w and df_twdn data sets */
   /* See: http://support.sas.com/kb/38/059.html */
  
   proc contents data=df_tldn_w noprint out=out1(keep=name);
   run;

   proc contents data=df_twdn noprint out=out2(keep=name);
   run;

   data common_vars;
     merge out1(in=a) out2(in=b);
     by name;
     if a and b then output;
    run;
    
    /* Compare number of rows in common_vars to number of columns in df_tldn_w */
    proc sql noprint;
       select count(*) into :numCommon  /* Macro variable for # rows in common_vars */
       from common_vars;
    quit;
    
   %if &numCommon. ne &numCol2. %then %do;
       %put ERROR: Some variables are misspelled, or are missing from the input dataset.;
   %end;


** Check Formats and Names under Dropout **;

%widen(
 output=df_tldy_w,
 input=df_tldy,
 id=uid,
 time=time,
 exposure=s,
 history=h,
 covariate=a l m n o p, 
 weight_exposure=wa wax,
 weight_censor=wsx,
 strata=e5,
 censor=s
);


/* Drop the history variables */
data df_tldy_w;
   set df_tldy_w(drop=h_0 h_1 h_2);  
run;


/* Check numeric format preservation */

/* Flag numeric values. Adapted from: */
/* https://communities.sas.com/t5/SAS-Procedures/Check-numeric-values-in-alphanumeric-variables/td-p/19247 */

data fmttest;
   set df_tldy_w;
   len=lengthn(a_0);
   newval=compress(a_0, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=1 */
   proc sql noprint;
       select count(flag) into :numFlag1  /* Macro variable for # of numeric flags */
       from fmttest(where=(flag=:1));
   quit;

/* Count the number of rows in df_tldy_w */
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_tldy_w */
       from df_tldy_w;
   quit;
   
   %if &numFlag1. ne &numRow2. %then %do;
       %put ERROR: The exposure is not in numeric format.;
   %end;


/* Check Number of Columns */

proc contents data=df_twdy out=cont1;
run;

proc contents data=df_tldy_w out=cont2;
run;


   proc sql noprint;
       select count(*) into :numCol1  /* Macro variable for # of columns in df_twdy */
       from cont1;
   quit;
   
   
   proc sql noprint;
       select count(*) into :numCol2  /* Macro variable for # of columns in df_tldy_w */
       from cont2;
   quit;
   
   %if (%eval(&numCol1.)-18) ne &numCol2. %then %do;
       %put ERROR: The number of columns do not match.;
   %end;
   

/* Check Number of Rows */
   proc sql noprint;
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdy */
       from df_twdy;
   quit;
   
   
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_tldy_w */
       from df_tldy_w;
   quit;
   
   %if &numRow1. ne &numRow2. %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   
   
/* Check Expected Names */

   /* Get common variable names across the df_tldy_w and df_twdy data sets */
   /* See: http://support.sas.com/kb/38/059.html */
  
   proc contents data=df_tldy_w noprint out=out1(keep=name);
   run;

   proc contents data=df_twdy noprint out=out2(keep=name);
   run;

   data common_vars;
     merge out1(in=a) out2(in=b);
     by name;
     if a and b then output;
    run;
    
    /* Compare number of rows in common_vars to number of columns in df_tldy_w */
    proc sql noprint;
       select count(*) into :numCommon  /* Macro variable for # rows in common_vars */
       from common_vars;
    quit;
    
   %if &numCommon. ne &numCol2. %then %do;
       %put ERROR: Some variables are misspelled, or are missing from the input dataset.;
   %end;
   
   
** End of tests for %widen() **;






   



