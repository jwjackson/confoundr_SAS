/* Erin Schnellinger */
/* 28 September 2018 */
/* Last updated: 12 April 2019 */

/* Program to test the %makehistory_one() SAS Macro */

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
  
  
*-----------------------------------*;
* Test the %makehistory_one() macro *;
*-----------------------------------*;

** Import the relevant toy data sets **;

proc import datafile="/folders/myfolders/confoundr_SAS-master/data/toy_wide_dropoutN.csv"
   out=df_twdn dbms=csv replace;
   getnames=yes;
run;

proc import datafile="/folders/myfolders/confoundr_SAS-master/data/toy_wide_dropoutY.csv"
   out=df_twdy dbms=csv replace;
   getnames=yes;
run;



** Check Formats and Names under No Dropout **;

%makehistory_one(
 output=df_twdn_h,
 input=df_twdn,
 id=uid,
 times=0 1 2,
 exposure=a,
 name_history=ha
);

%makehistory_one(
 output=df_twdn_hg,
 input=df_twdn,
 id=uid,
 times=0 1 2,
 exposure=a,
 name_history=hag,
 group=p_0
);


/* Check Number of Columns */

proc contents data=df_twdn out=cont1;
run;

proc contents data=df_twdn_h out=cont2;
run;


   proc sql noprint;
       select count(*) into :numCol1  /* Macro variable for # of columns in df_twdn */
       from cont1;
   quit;
   
   
   proc sql noprint;
       select count(*) into :numCol2  /* Macro variable for # of columns in df_twdn_h */
       from cont2;
   quit;
   
   %if (%eval(&numCol1.)+3) ne &numCol2. %then %do;
       %put ERROR: The number of columns do not match.;
   %end;
   
   

/* Check Number of Rows */
   proc sql noprint;
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdn */
       from df_twdn;
   quit;
   
   
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_twdn_h */
       from df_twdn_h;
   quit;
   
   %if &numRow1. ne &numRow2. %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   

/* Compare ID numbers in df_twdn_h and df_twdn */
data df_twdn_h_ID;
   set df_twdn_h(keep=uid);
run;

data df_twdn_ID;
   set df_twdn(keep=uid);
run;

proc compare base=df_twdn_ID compare=df_twdn_h_ID out=compID;
run;


/* Count the number of times difference in uid=0 */
   proc sql noprint;
       select count(uid) into :numID  /* Macro variable for # of identical IDs */
       from compID(where=(uid=:0));
   quit;
   
   %if &numID. ne &numRow1. %then %do;
       %put ERROR: At least one ID number does not match.;
   %end;
   
   

/* Check character format preservation for history variables */

/* Flag numeric values. Adapted from: */
/* https://communities.sas.com/t5/SAS-Procedures/Check-numeric-values-in-alphanumeric-variables/td-p/19247 */

/* For ha_0 */
data ha0test;
   set df_twdn_h;
   len=lengthn(ha_0);
   newval=compress(ha_0, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from ha0test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdn_h */
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_twdn_h */
       from df_twdn_h;
   quit;
   
   %if &numFlag0. ne &numRow2. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;


/* For ha_1 */
data ha1test;
   set df_twdn_h;
   len=lengthn(ha_1);
   newval=compress(ha_1, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from ha1test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdn_h */
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_twdn_h */
       from df_twdn_h;
   quit;
   
   %if &numFlag0. ne &numRow2. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;
   

/* For ha_2 */
data ha2test;
   set df_twdn_h;
   len=lengthn(ha_2);
   newval=compress(ha_2, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from ha2test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdn_h */
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_twdn_h */
       from df_twdn_h;
   quit;
   
   %if &numFlag0. ne &numRow2. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;



/* Compare history values in df_twdn_h and df_twdn */

/* Comparing ha_0 to haone_0 */
data df_twdn_h_ha_0;
   set df_twdn_h(keep=ha_0);
run;

data df_twdn_haone_0(rename=(haone_0=ha_0));
   set df_twdn(keep=haone_0);
run;

proc compare base=df_twdn_haone_0 compare=df_twdn_h_ha_0 out=comp_ha_0;
run;

/* Count the number of times difference in ha_0=. */
   proc sql noprint;
       select count(ha_0) into :num_ha_0  /* Macro variable for # of identical ha_0 values */
       from comp_ha_0(where=(ha_0=:'.'));
   quit;
   
   %if &num_ha_0. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   

/* Comparing ha_1 to haone_1 */
data df_twdn_h_ha_1;
   set df_twdn_h(keep=ha_1);
run;

data df_twdn_haone_1(rename=(haone_1=ha_1));
   set df_twdn(keep=haone_1);
run;

proc compare base=df_twdn_haone_1 compare=df_twdn_h_ha_1 out=comp_ha_1;
run;

/* Count the number of times difference in ha_1=.. */
   proc sql noprint;
       select count(ha_1) into :num_ha_1  /* Macro variable for # of identical ha_1 values */
       from comp_ha_1(where=(ha_1=:'..'));
   quit;
   
   %if &num_ha_1. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;


/* Comparing ha_2 to haone_2 */
data df_twdn_h_ha_2;
   set df_twdn_h(keep=ha_2);
run;

data df_twdn_haone_2(rename=(haone_2=ha_2));
   set df_twdn(keep=haone_2);
run;

proc compare base=df_twdn_haone_2 compare=df_twdn_h_ha_2 out=comp_ha_2;
run;


/* Count the number of times difference in ha_2=... */
   proc sql noprint;
       select count(ha_2) into :num_ha_2  /* Macro variable for # of identical ha_2 values */
       from comp_ha_2(where=(ha_2=:'...'));
   quit;
   
   %if &num_ha_2. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;



/* Check character format preservation for history g variables */

/* Flag numeric values. Adapted from: */
/* https://communities.sas.com/t5/SAS-Procedures/Check-numeric-values-in-alphanumeric-variables/td-p/19247 */

/* For hag_0 */
data hag0test;
   set df_twdn_hg;
   len=lengthn(hag_0);
   newval=compress(hag_0, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hag0test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdn_hg */
   proc sql noprint;
       select count(*) into :numRow3  /* Macro variable for # of rows in df_twdn_hg */
       from df_twdn_hg;
   quit;
   
   %if &numFlag0. ne &numRow3. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;


/* For hag_1 */
data hag1test;
   set df_twdn_hg;
   len=lengthn(hag_1);
   newval=compress(hag_1, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hag1test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdn_hg */
   proc sql noprint;
       select count(*) into :numRow3  /* Macro variable for # of rows in df_twdn_hg */
       from df_twdn_hg;
   quit;
   
   %if &numFlag0. ne &numRow3. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;
   

/* For hag_2 */
data hag2test;
   set df_twdn_hg;
   len=lengthn(hag_2);
   newval=compress(hag_2, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hag2test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdn_hg */
   proc sql noprint;
       select count(*) into :numRow3  /* Macro variable for # of rows in df_twdn_hg */
       from df_twdn_hg;
   quit;
   
   %if &numFlag0. ne &numRow3. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;



/* Compare history values in df_twdn_hg and df_twdn */

/* Comparing hag_0 to haoneg_0 */
data df_twdn_h_hag_0;
   set df_twdn_hg(keep=hag_0);
run;

data df_twdn_haoneg_0(rename=(haoneg_0=hag_0));
   set df_twdn(keep=haoneg_0);
run;

proc compare base=df_twdn_haoneg_0 compare=df_twdn_h_hag_0 out=comp_hag_0;
run;

/* Count the number of times difference in hag_0=. */
   proc sql noprint;
       select count(hag_0) into :num_hag_0  /* Macro variable for # of identical hag_0 values */
       from comp_hag_0(where=(hag_0=:'.'));
   quit;
   
   %if &num_hag_0. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   

/* Comparing hag_1 to haoneg_1 */
data df_twdn_h_hag_1;
   set df_twdn_hg(keep=hag_1);
run;

data df_twdn_haoneg_1(rename=(haoneg_1=hag_1));
   set df_twdn(keep=haoneg_1);
run;

proc compare base=df_twdn_haoneg_1 compare=df_twdn_h_hag_1 out=comp_hag_1;
run;

/* Count the number of times difference in hag_1=.. */
   proc sql noprint;
       select count(hag_1) into :num_hag_1  /* Macro variable for # of identical hag_1 values */
       from comp_hag_1(where=(hag_1=:'..'));
   quit;
   
   %if &num_hag_1. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;


/* Comparing hag_2 to haoneg_2 */
data df_twdn_h_hag_2;
   set df_twdn_hg(keep=hag_2);
run;

data df_twdn_haoneg_2(rename=(haoneg_2=hag_2));
   set df_twdn(keep=haoneg_2);
run;

proc compare base=df_twdn_haoneg_2 compare=df_twdn_h_hag_2 out=comp_hag_2;
run;


/* Count the number of times difference in hag_2=... */
   proc sql noprint;
       select count(hag_2) into :num_hag_2  /* Macro variable for # of identical hag_2 values */
       from comp_hag_2(where=(hag_2=:'...'));
   quit;
   
   %if &num_hag_2. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   


** Check Formats and Names under Dropout **;

%makehistory_one(
 output=df_twdy_h,
 input=df_twdy,
 id=uid,
 times=0 1 2,
 exposure=a,
 name_history=ha
);

%makehistory_one(
 output=df_twdy_hg,
 input=df_twdy,
 id=uid,
 times=0 1 2,
 exposure=a,
 name_history=hag,
 group=p_0
);

/* Check Number of Columns */
proc contents data=df_twdy out=cont1;
run;

proc contents data=df_twdy_h out=cont2;
run;

   proc sql noprint;
       select count(*) into :numCol1  /* Macro variable for # of columns in df_twdy */
       from cont1;
   quit;
     
   proc sql noprint;
       select count(*) into :numCol2  /* Macro variable for # of columns in df_twdy_h */
       from cont2;
   quit;
   
   %if (%eval(&numCol1.)+3) ne &numCol2. %then %do;
       %put ERROR: The number of columns do not match.;
   %end;



/* Check Number of Rows */
   proc sql noprint;
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdy */
       from df_twdy;
   quit;
   
   
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_twdy_h */
       from df_twdy_h;
   quit;
   
   %if &numRow1. ne &numRow2. %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   

/* Compare ID numbers in df_twdy_h and df_twdy */
data df_twdy_h_ID;
   set df_twdy_h(keep=uid);
run;

data df_twdy_ID;
   set df_twdy(keep=uid);
run;

proc compare base=df_twdy_ID compare=df_twdy_h_ID out=compID;
run;


/* Count the number of times difference in uid=0 */
   proc sql noprint;
       select count(uid) into :numID  /* Macro variable for # of identical IDs */
       from compID(where=(uid=:0));
   quit;
   
   %if &numID. ne &numRow1. %then %do;
       %put ERROR: At least one ID number does not match.;
   %end;
   
   

/* Check character format preservation for history variables */

/* Flag numeric values. Adapted from: */
/* https://communities.sas.com/t5/SAS-Procedures/Check-numeric-values-in-alphanumeric-variables/td-p/19247 */

/* For ha_0 */
data ha0test;
   set df_twdy_h;
   len=lengthn(ha_0);
   newval=compress(ha_0, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from ha0test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdy_h */
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_twdy_h */
       from df_twdy_h;
   quit;
   
   %if &numFlag0. ne &numRow2. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;


/* For ha_1 */
data ha1test;
   set df_twdy_h;
   len=lengthn(ha_1);
   newval=compress(ha_1, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from ha1test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdy_h */
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_twdy_h */
       from df_twdy_h;
   quit;
   
   %if &numFlag0. ne &numRow2. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;
   

/* For ha_2 */
data ha2test;
   set df_twdy_h;
   len=lengthn(ha_2);
   newval=compress(ha_2, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from ha2test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdy_h */
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_twdy_h */
       from df_twdy_h;
   quit;
   
   %if &numFlag0. ne &numRow2. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;



/* Compare history values in df_twdy_h and df_twdy */

/* Comparing ha_0 to haone_0 */
data df_twdy_h_ha_0;
   set df_twdy_h(keep=ha_0);
run;

data df_twdy_haone_0(rename=(haone_0=ha_0));
   set df_twdy(keep=haone_0);
run;

proc compare base=df_twdy_haone_0 compare=df_twdy_h_ha_0 out=comp_ha_0;
run;

/* Count the number of times difference in ha_0=. */
   proc sql noprint;
       select count(ha_0) into :num_ha_0  /* Macro variable for # of identical ha_0 values */
       from comp_ha_0(where=(ha_0=:'.'));
   quit;
   
   %if &num_ha_0. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   

/* Comparing ha_1 to haone_1 */
data df_twdy_h_ha_1;
   set df_twdy_h(keep=ha_1);
run;

data df_twdy_haone_1(rename=(haone_1=ha_1));
   set df_twdy(keep=haone_1);
run;

proc compare base=df_twdy_haone_1 compare=df_twdy_h_ha_1 out=comp_ha_1;
run;

/* Count the number of times difference in ha_1=.. */
   proc sql noprint;
       select count(ha_1) into :num_ha_1  /* Macro variable for # of identical ha_1 values */
       from comp_ha_1(where=(ha_1=:'..'));
   quit;
   
   %if &num_ha_1. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;


/* Comparing ha_2 to haone_2 */
data df_twdy_h_ha_2;
   set df_twdy_h(keep=ha_2);
run;

data df_twdy_haone_2(rename=(haone_2=ha_2));
   set df_twdy(keep=haone_2);
run;

proc compare base=df_twdy_haone_2 compare=df_twdy_h_ha_2 out=comp_ha_2;
run;


/* Count the number of times difference in ha_2=... */
   proc sql noprint;
       select count(ha_2) into :num_ha_2  /* Macro variable for # of identical ha_2 values */
       from comp_ha_2(where=(ha_2=:'...'));
   quit;
   
   %if &num_ha_2. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;



/* Check character format preservation for history g variables */

/* Flag numeric values. Adapted from: */
/* https://communities.sas.com/t5/SAS-Procedures/Check-numeric-values-in-alphanumeric-variables/td-p/19247 */

/* For hag_0 */
data hag0test;
   set df_twdy_hg;
   len=lengthn(hag_0);
   newval=compress(hag_0, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hag0test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdy_hg */
   proc sql noprint;
       select count(*) into :numRow3  /* Macro variable for # of rows in df_twdy_hg */
       from df_twdy_hg;
   quit;
   
   %if &numFlag0. ne &numRow3. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;


/* For hag_1 */
data hag1test;
   set df_twdy_hg;
   len=lengthn(hag_1);
   newval=compress(hag_1, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hag1test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdn_hg */
   proc sql noprint;
       select count(*) into :numRow3  /* Macro variable for # of rows in df_twdy_hg */
       from df_twdy_hg;
   quit;
   
   %if &numFlag0. ne &numRow3. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;
   

/* For hag_2 */
data hag2test;
   set df_twdy_hg;
   len=lengthn(hag_2);
   newval=compress(hag_2, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hag2test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdn_hg */
   proc sql noprint;
       select count(*) into :numRow3  /* Macro variable for # of rows in df_twdy_hg */
       from df_twdy_hg;
   quit;
   
   %if &numFlag0. ne &numRow3. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;



/* Compare history values in df_twdn_hg and df_twdn */

/* Comparing hag_0 to haoneg_0 */
data df_twdy_h_hag_0;
   set df_twdy_hg(keep=hag_0);
run;

data df_twdy_haoneg_0(rename=(haoneg_0=hag_0));
   set df_twdy(keep=haoneg_0);
run;

proc compare base=df_twdy_haoneg_0 compare=df_twdy_h_hag_0 out=comp_hag_0;
run;

/* Count the number of times difference in hag_0=. */
   proc sql noprint;
       select count(hag_0) into :num_hag_0  /* Macro variable for # of identical hag_0 values */
       from comp_hag_0(where=(hag_0=:'.'));
   quit;
   
   %if &num_hag_0. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   

/* Comparing hag_1 to haoneg_1 */
data df_twdy_h_hag_1;
   set df_twdy_hg(keep=hag_1);
run;

data df_twdy_haoneg_1(rename=(haoneg_1=hag_1));
   set df_twdy(keep=haoneg_1);
run;

proc compare base=df_twdy_haoneg_1 compare=df_twdy_h_hag_1 out=comp_hag_1;
run;

/* Count the number of times difference in hag_1=.. */
   proc sql noprint;
       select count(hag_1) into :num_hag_1  /* Macro variable for # of identical hag_1 values */
       from comp_hag_1(where=(hag_1=:'..'));
   quit;
   
   %if &num_hag_1. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;


/* Comparing hag_2 to haoneg_2 */
data df_twdy_h_hag_2;
   set df_twdy_hg(keep=hag_2);
run;

data df_twdy_haoneg_2(rename=(haoneg_2=hag_2));
   set df_twdy(keep=haoneg_2);
run;

proc compare base=df_twdy_haoneg_2 compare=df_twdy_h_hag_2 out=comp_hag_2;
run;


/* Count the number of times difference in hag_2=... */
   proc sql noprint;
       select count(hag_2) into :num_hag_2  /* Macro variable for # of identical hag_2 values */
       from comp_hag_2(where=(hag_2=:'...'));
   quit;
   
   %if &num_hag_2. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   
   
   
** End of tests for %makehistory_one() **;






   



