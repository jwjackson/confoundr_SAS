/* Erin Schnellinger */
/* 12 April 2019 */

/* Program to test the %makehistory_two() SAS Macro */

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
* Test the %makehistory_two() macro *;
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

%makehistory_two(
 output=df_twdn_h,
 input=df_twdn,
 id=uid,
 times=0 1 2,
 exposure_a=a,
 exposure_b=s,
 name_history_a=ha,
 name_history_b=hs
);

%makehistory_two(
 output=df_twdn_hg,
 input=df_twdn,
 id=uid,
 times=0 1 2,
 exposure_a=a,
 exposure_b=s,
 name_history_a=hag,
 name_history_b=hsg,
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
   
   %if (%eval(&numCol1.)+6) ne &numCol2. %then %do;
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

/* Comparing ha_0 to hatwo_0 */
data df_twdn_h_ha_0;
   set df_twdn_h(keep=ha_0);
run;

data df_twdn_hatwo_0(rename=(hatwo_0=ha_0));
   set df_twdn(keep=hatwo_0);
run;

proc compare base=df_twdn_hatwo_0 compare=df_twdn_h_ha_0 out=comp_ha_0;
run;

/* Count the number of times difference in ha_0=. */
   proc sql noprint;
       select count(ha_0) into :num_ha_0  /* Macro variable for # of identical ha_0 values */
       from comp_ha_0(where=(ha_0=:'.'));
   quit;
   
   %if &num_ha_0. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   

/* Comparing ha_1 to hatwo_1 */
data df_twdn_h_ha_1;
   set df_twdn_h(keep=ha_1);
run;

data df_twdn_hatwo_1(rename=(hatwo_1=ha_1));
   set df_twdn(keep=hatwo_1);
run;

proc compare base=df_twdn_hatwo_1 compare=df_twdn_h_ha_1 out=comp_ha_1;
run;

/* Count the number of times difference in ha_1=.. */
   proc sql noprint;
       select count(ha_1) into :num_ha_1  /* Macro variable for # of identical ha_1 values */
       from comp_ha_1(where=(ha_1=:'..'));
   quit;
   
   %if &num_ha_1. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;


/* Comparing ha_2 to hatwo_2 */
data df_twdn_h_ha_2;
   set df_twdn_h(keep=ha_2);
run;

data df_twdn_hatwo_2(rename=(hatwo_2=ha_2));
   set df_twdn(keep=hatwo_2);
run;

proc compare base=df_twdn_hatwo_2 compare=df_twdn_h_ha_2 out=comp_ha_2;
run;


/* Count the number of times difference in ha_2=... */
   proc sql noprint;
       select count(ha_2) into :num_ha_2  /* Macro variable for # of identical ha_2 values */
       from comp_ha_2(where=(ha_2=:'...'));
   quit;
   
   %if &num_ha_2. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   


/* Check character format preservation for history variables - second exposure */

/* Flag numeric values. Adapted from: */
/* https://communities.sas.com/t5/SAS-Procedures/Check-numeric-values-in-alphanumeric-variables/td-p/19247 */

/* For hs_0 */
data hs0test;
   set df_twdn_h;
   len=lengthn(hs_0);
   newval=compress(hs_0, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hs0test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdn_h */
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_twdn_h */
       from df_twdn_h;
   quit;
   
   %if &numFlag0. ne &numRow2. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;


/* For hs_1 */
data hs1test;
   set df_twdn_h;
   len=lengthn(hs_1);
   newval=compress(hs_1, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hs1test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdn_h */
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_twdn_h */
       from df_twdn_h;
   quit;
   
   %if &numFlag0. ne &numRow2. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;
   

/* For hs_2 */
data hs2test;
   set df_twdn_h;
   len=lengthn(hs_2);
   newval=compress(hs_2, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hs2test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdn_h */
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_twdn_h */
       from df_twdn_h;
   quit;
   
   %if &numFlag0. ne &numRow2. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;



/* Compare history values in df_twdn_h and df_twdn - second exposure */

/* Comparing hs_0 to hstwo_0 */
data df_twdn_h_hs_0;
   set df_twdn_h(keep=hs_0);
run;

data df_twdn_hstwo_0(rename=(hstwo_0=hs_0));
   set df_twdn(keep=hstwo_0);
run;

proc compare base=df_twdn_hstwo_0 compare=df_twdn_h_hs_0 out=comp_hs_0;
run;

/* Count the number of times difference in hs_0=. */
   proc sql noprint;
       select count(hs_0) into :num_hs_0  /* Macro variable for # of identical hs_0 values */
       from comp_hs_0(where=(hs_0=:'.'));
   quit;
   
   %if &num_hs_0. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   

/* Comparing hs_1 to hstwo_1 */
data df_twdn_h_hs_1;
   set df_twdn_h(keep=hs_1);
run;

data df_twdn_hstwo_1(rename=(hstwo_1=hs_1));
   set df_twdn(keep=hstwo_1);
run;

proc compare base=df_twdn_hstwo_1 compare=df_twdn_h_hs_1 out=comp_hs_1;
run;

/* Count the number of times difference in hs_1=.. */
   proc sql noprint;
       select count(hs_1) into :num_hs_1  /* Macro variable for # of identical hs_1 values */
       from comp_hs_1(where=(hs_1=:'..'));
   quit;
   
   %if &num_hs_1. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;


/* Comparing hs_2 to hstwo_2 */
data df_twdn_h_hs_2;
   set df_twdn_h(keep=hs_2);
run;

data df_twdn_hstwo_2(rename=(hstwo_2=hs_2));
   set df_twdn(keep=hstwo_2);
run;

proc compare base=df_twdn_hstwo_2 compare=df_twdn_h_hs_2 out=comp_hs_2;
run;


/* Count the number of times difference in hs_2=... */
   proc sql noprint;
       select count(hs_2) into :num_hs_2  /* Macro variable for # of identical hs_2 values */
       from comp_hs_2(where=(hs_2=:'...'));
   quit;
   
   %if &num_hs_2. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   
   
   
   
 /* Check formats for grouped (g) results */  

/* Check Number of Columns */

proc contents data=df_twdn out=cont1;
run;

proc contents data=df_twdn_hg out=cont2;
run;


   proc sql noprint;
       select count(*) into :numCol1  /* Macro variable for # of columns in df_twdn */
       from cont1;
   quit;
   
   
   proc sql noprint;
       select count(*) into :numCol2  /* Macro variable for # of columns in df_twdn_hg */
       from cont2;
   quit;
   
   %if (%eval(&numCol1.)+6) ne &numCol2. %then %do;
       %put ERROR: The number of columns do not match.;
   %end;
   
   

/* Check Number of Rows */
   proc sql noprint;
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdn */
       from df_twdn;
   quit;
   
   
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_twdn_hg */
       from df_twdn_hg;
   quit;
   
   %if &numRow1. ne &numRow2. %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   

/* Compare ID numbers in df_twdn_hg and df_twdn */
data df_twdn_hg_ID;
   set df_twdn_hg(keep=uid);
run;

data df_twdn_ID;
   set df_twdn(keep=uid);
run;

proc compare base=df_twdn_ID compare=df_twdn_hg_ID out=compID;
run;


/* Count the number of times difference in uid=0 */
   proc sql noprint;
       select count(uid) into :numID  /* Macro variable for # of identical IDs */
       from compID(where=(uid=:0));
   quit;
   
   %if &numID. ne &numRow1. %then %do;
       %put ERROR: At least one ID number does not match.;
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

/* Comparing hag_0 to hatwog_0 */
data df_twdn_h_hag_0;
   set df_twdn_hg(keep=hag_0);
run;

data df_twdn_hatwog_0(rename=(hatwog_0=hag_0));
   set df_twdn(keep=hatwog_0);
run;

proc compare base=df_twdn_hatwog_0 compare=df_twdn_h_hag_0 out=comp_hag_0;
run;

/* Count the number of times difference in hag_0=. */
   proc sql noprint;
       select count(hag_0) into :num_hag_0  /* Macro variable for # of identical hag_0 values */
       from comp_hag_0(where=(hag_0=:'.'));
   quit;
   
   %if &num_hag_0. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   

/* Comparing hag_1 to hatwog_1 */
data df_twdn_h_hag_1;
   set df_twdn_hg(keep=hag_1);
run;

data df_twdn_hatwog_1(rename=(hatwog_1=hag_1));
   set df_twdn(keep=hatwog_1);
run;

proc compare base=df_twdn_hatwog_1 compare=df_twdn_h_hag_1 out=comp_hag_1;
run;

/* Count the number of times difference in hag_1=.. */
   proc sql noprint;
       select count(hag_1) into :num_hag_1  /* Macro variable for # of identical hag_1 values */
       from comp_hag_1(where=(hag_1=:'..'));
   quit;
   
   %if &num_hag_1. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;


/* Comparing hag_2 to hatwog_2 */
data df_twdn_h_hag_2;
   set df_twdn_hg(keep=hag_2);
run;

data df_twdn_hatwog_2(rename=(hatwog_2=hag_2));
   set df_twdn(keep=hatwog_2);
run;

proc compare base=df_twdn_hatwog_2 compare=df_twdn_h_hag_2 out=comp_hag_2;
run;


/* Count the number of times difference in hag_2=... */
   proc sql noprint;
       select count(hag_2) into :num_hag_2  /* Macro variable for # of identical hag_2 values */
       from comp_hag_2(where=(hag_2=:'...'));
   quit;
   
   %if &num_hag_2. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   

/* Repeat for second exposure */

/* For hsg_0 */
data hsg0test;
   set df_twdn_hg;
   len=lengthn(hsg_0);
   newval=compress(hsg_0, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hsg0test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdn_hg */
   proc sql noprint;
       select count(*) into :numRow3  /* Macro variable for # of rows in df_twdn_hg */
       from df_twdn_hg;
   quit;
   
   %if &numFlag0. ne &numRow3. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;


/* For hsg_1 */
data hsg1test;
   set df_twdn_hg;
   len=lengthn(hsg_1);
   newval=compress(hsg_1, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hsg1test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdn_hg */
   proc sql noprint;
       select count(*) into :numRow3  /* Macro variable for # of rows in df_twdn_hg */
       from df_twdn_hg;
   quit;
   
   %if &numFlag0. ne &numRow3. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;
   

/* For hsg_2 */
data hsg2test;
   set df_twdn_hg;
   len=lengthn(hsg_2);
   newval=compress(hsg_2, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hsg2test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdn_hg */
   proc sql noprint;
       select count(*) into :numRow3  /* Macro variable for # of rows in df_twdn_hg */
       from df_twdn_hg;
   quit;
   
   %if &numFlag0. ne &numRow3. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;



/* Compare history values in df_twdn_hg and df_twdn - second exposure */

/* Comparing hsg_0 to hstwog_0 */
data df_twdn_h_hsg_0;
   set df_twdn_hg(keep=hsg_0);
run;

data df_twdn_hstwog_0(rename=(hstwog_0=hsg_0));
   set df_twdn(keep=hstwog_0);
run;

proc compare base=df_twdn_hstwog_0 compare=df_twdn_h_hsg_0 out=comp_hsg_0;
run;

/* Count the number of times difference in hsg_0=. */
   proc sql noprint;
       select count(hsg_0) into :num_hsg_0  /* Macro variable for # of identical hsg_0 values */
       from comp_hsg_0(where=(hsg_0=:'.'));
   quit;
   
   %if &num_hsg_0. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   

/* Comparing hsg_1 to hstwog_1 */
data df_twdn_h_hsg_1;
   set df_twdn_hg(keep=hsg_1);
run;

data df_twdn_hatwog_1(rename=(hstwog_1=hsg_1));
   set df_twdn(keep=hstwog_1);
run;

proc compare base=df_twdn_hstwog_1 compare=df_twdn_h_hsg_1 out=comp_hsg_1;
run;

/* Count the number of times difference in hsg_1=.. */
   proc sql noprint;
       select count(hsg_1) into :num_hsg_1  /* Macro variable for # of identical hsg_1 values */
       from comp_hsg_1(where=(hsg_1=:'..'));
   quit;
   
   %if &num_hsg_1. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;


/* Comparing hsg_2 to hstwog_2 */
data df_twdn_h_hsg_2;
   set df_twdn_hg(keep=hsg_2);
run;

data df_twdn_hstwog_2(rename=(hstwog_2=hsg_2));
   set df_twdn(keep=hstwog_2);
run;

proc compare base=df_twdn_hstwog_2 compare=df_twdn_h_hsg_2 out=comp_hsg_2;
run;


/* Count the number of times difference in hsg_2=... */
   proc sql noprint;
       select count(hsg_2) into :num_hsg_2  /* Macro variable for # of identical hsg_2 values */
       from comp_hsg_2(where=(hsg_2=:'...'));
   quit;
   
   %if &num_hsg_2. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   
   
   


** Check Formats and Names under Dropout **;

%makehistory_two(
 output=df_twdy_h,
 input=df_twdy,
 id=uid,
 times=0 1 2,
 exposure_a=a,
 exposure_b=s,
 name_history_a=ha,
 name_history_b=hs
);

%makehistory_two(
 output=df_twdy_hg,
 input=df_twdy,
 id=uid,
 times=0 1 2,
 exposure_a=a,
 exposure_b=s,
 name_history_a=hag,
 name_history_b=hsg,
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
   
   %if (%eval(&numCol1.)+6) ne &numCol2. %then %do;
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

/* Comparing ha_0 to hatwo_0 */
data df_twdy_h_ha_0;
   set df_twdy_h(keep=ha_0);
run;

data df_twdy_hatwo_0(rename=(hatwo_0=ha_0));
   set df_twdy(keep=hatwo_0);
run;

proc compare base=df_twdy_hatwo_0 compare=df_twdy_h_ha_0 out=comp_ha_0;
run;

/* Count the number of times difference in ha_0=. */
   proc sql noprint;
       select count(ha_0) into :num_ha_0  /* Macro variable for # of identical ha_0 values */
       from comp_ha_0(where=(ha_0=:'.'));
   quit;
   
   %if &num_ha_0. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   

/* Comparing ha_1 to hatwo_1 */
data df_twdy_h_ha_1;
   set df_twdy_h(keep=ha_1);
run;

data df_twdy_hatwo_1(rename=(hatwo_1=ha_1));
   set df_twdy(keep=hatwo_1);
run;

proc compare base=df_twdy_hatwo_1 compare=df_twdy_h_ha_1 out=comp_ha_1;
run;

/* Count the number of times difference in ha_1=.. */
   proc sql noprint;
       select count(ha_1) into :num_ha_1  /* Macro variable for # of identical ha_1 values */
       from comp_ha_1(where=(ha_1=:'..'));
   quit;
   
   %if &num_ha_1. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;


/* Comparing ha_2 to hatwo_2 */
data df_twdy_h_ha_2;
   set df_twdy_h(keep=ha_2);
run;

data df_twdy_hatwo_2(rename=(hatwo_2=ha_2));
   set df_twdy(keep=hatwo_2);
run;

proc compare base=df_twdy_hatwo_2 compare=df_twdy_h_ha_2 out=comp_ha_2;
run;


/* Count the number of times difference in ha_2=... */
   proc sql noprint;
       select count(ha_2) into :num_ha_2  /* Macro variable for # of identical ha_2 values */
       from comp_ha_2(where=(ha_2=:'...'));
   quit;
   
   %if &num_ha_2. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;



/* Check character format preservation for history variables - second exposure */

/* Flag numeric values. Adapted from: */
/* https://communities.sas.com/t5/SAS-Procedures/Check-numeric-values-in-alphanumeric-variables/td-p/19247 */

/* For hs_0 */
data hs0test;
   set df_twdy_h;
   len=lengthn(hs_0);
   newval=compress(hs_0, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hs0test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdy_h */
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_twdy_h */
       from df_twdy_h;
   quit;
   
   %if &numFlag0. ne &numRow2. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;


/* For hs_1 */
data hs1test;
   set df_twdy_h;
   len=lengthn(hs_1);
   newval=compress(hs_1, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hs1test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdy_h */
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_twdy_h */
       from df_twdy_h;
   quit;
   
   %if &numFlag0. ne &numRow2. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;
   

/* For hs_2 */
data hs2test;
   set df_twdy_h;
   len=lengthn(hs_2);
   newval=compress(hs_2, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hs2test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdy_h */
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_twdy_h */
       from df_twdy_h;
   quit;
   
   %if &numFlag0. ne &numRow2. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;



/* Compare history values in df_twdy_h and df_twdy - second exposure */

/* Comparing hs_0 to hstwo_0 */
data df_twdy_h_hs_0;
   set df_twdy_h(keep=hs_0);
run;

data df_twdy_hstwo_0(rename=(hstwo_0=hs_0));
   set df_twdy(keep=hstwo_0);
run;

proc compare base=df_twdy_hstwo_0 compare=df_twdy_h_hs_0 out=comp_hs_0;
run;

/* Count the number of times difference in ha_0=. */
   proc sql noprint;
       select count(hs_0) into :num_hs_0  /* Macro variable for # of identical hs_0 values */
       from comp_hs_0(where=(hs_0=:'.'));
   quit;
   
   %if &num_hs_0. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   

/* Comparing hs_1 to hstwo_1 */
data df_twdy_h_hs_1;
   set df_twdy_h(keep=hs_1);
run;

data df_twdy_hstwo_1(rename=(hstwo_1=hs_1));
   set df_twdy(keep=hstwo_1);
run;

proc compare base=df_twdy_hstwo_1 compare=df_twdy_h_hs_1 out=comp_hs_1;
run;

/* Count the number of times difference in hs_1=.. */
   proc sql noprint;
       select count(hs_1) into :num_hs_1  /* Macro variable for # of identical hs_1 values */
       from comp_hs_1(where=(hs_1=:'..'));
   quit;
   
   %if &num_hs_1. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;


/* Comparing hs_2 to hstwo_2 */
data df_twdy_h_hs_2;
   set df_twdy_h(keep=hs_2);
run;

data df_twdy_hstwo_2(rename=(hstwo_2=hs_2));
   set df_twdy(keep=hstwo_2);
run;

proc compare base=df_twdy_hstwo_2 compare=df_twdy_h_hs_2 out=comp_hs_2;
run;


/* Count the number of times difference in hs_2=... */
   proc sql noprint;
       select count(hs_2) into :num_hs_2  /* Macro variable for # of identical hs_2 values */
       from comp_hs_2(where=(hs_2=:'...'));
   quit;
   
   %if &num_hs_2. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;


/* Repeat for  grouped (g) results */

/* Check Number of Columns */
proc contents data=df_twdy out=cont1;
run;

proc contents data=df_twdy_hg out=cont2;
run;

   proc sql noprint;
       select count(*) into :numCol1  /* Macro variable for # of columns in df_twdy */
       from cont1;
   quit;
     
   proc sql noprint;
       select count(*) into :numCol2  /* Macro variable for # of columns in df_twdy_hg */
       from cont2;
   quit;
   
   %if (%eval(&numCol1.)+6) ne &numCol2. %then %do;
       %put ERROR: The number of columns do not match.;
   %end;



/* Check Number of Rows */
   proc sql noprint;
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdy */
       from df_twdy;
   quit;
   
   
   proc sql noprint;
       select count(*) into :numRow2  /* Macro variable for # of rows in df_twdy_hg */
       from df_twdy_hg;
   quit;
   
   %if &numRow1. ne &numRow2. %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   

/* Compare ID numbers in df_twdy_hg and df_twdy */
data df_twdy_hg_ID;
   set df_twdy_hg(keep=uid);
run;

data df_twdy_ID;
   set df_twdy(keep=uid);
run;

proc compare base=df_twdy_ID compare=df_twdy_hg_ID out=compID;
run;


/* Count the number of times difference in uid=0 */
   proc sql noprint;
       select count(uid) into :numID  /* Macro variable for # of identical IDs */
       from compID(where=(uid=:0));
   quit;
   
   %if &numID. ne &numRow1. %then %do;
       %put ERROR: At least one ID number does not match.;
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

/* Comparing hag_0 to hatwog_0 */
data df_twdy_h_hag_0;
   set df_twdy_hg(keep=hag_0);
run;

data df_twdy_hatwog_0(rename=(hatwog_0=hag_0));
   set df_twdy(keep=hatwog_0);
run;

proc compare base=df_twdy_hatwog_0 compare=df_twdy_h_hag_0 out=comp_hag_0;
run;

/* Count the number of times difference in hag_0=. */
   proc sql noprint;
       select count(hag_0) into :num_hag_0  /* Macro variable for # of identical hag_0 values */
       from comp_hag_0(where=(hag_0=:'.'));
   quit;
   
   %if &num_hag_0. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   

/* Comparing hag_1 to hatwog_1 */
data df_twdy_h_hag_1;
   set df_twdy_hg(keep=hag_1);
run;

data df_twdy_hatwog_1(rename=(hatwog_1=hag_1));
   set df_twdy(keep=hatwog_1);
run;

proc compare base=df_twdy_hatwog_1 compare=df_twdy_h_hag_1 out=comp_hag_1;
run;

/* Count the number of times difference in hag_1=.. */
   proc sql noprint;
       select count(hag_1) into :num_hag_1  /* Macro variable for # of identical hag_1 values */
       from comp_hag_1(where=(hag_1=:'..'));
   quit;
   
   %if &num_hag_1. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;


/* Comparing hag_2 to hatwog_2 */
data df_twdy_h_hag_2;
   set df_twdy_hg(keep=hag_2);
run;

data df_twdy_hatwog_2(rename=(hatwog_2=hag_2));
   set df_twdy(keep=hatwog_2);
run;

proc compare base=df_twdy_hatwog_2 compare=df_twdy_h_hag_2 out=comp_hag_2;
run;


/* Count the number of times difference in hag_2=... */
   proc sql noprint;
       select count(hag_2) into :num_hag_2  /* Macro variable for # of identical hag_2 values */
       from comp_hag_2(where=(hag_2=:'...'));
   quit;
   
   %if &num_hag_2. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;



/* Repeat for second exposure */

/* Check character format preservation for history g variables */

/* Flag numeric values. Adapted from: */
/* https://communities.sas.com/t5/SAS-Procedures/Check-numeric-values-in-alphanumeric-variables/td-p/19247 */

/* For hsg_0 */
data hsg0test;
   set df_twdy_hg;
   len=lengthn(hsg_0);
   newval=compress(hsg_0, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hsg0test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdy_hg */
   proc sql noprint;
       select count(*) into :numRow3  /* Macro variable for # of rows in df_twdy_hg */
       from df_twdy_hg;
   quit;
   
   %if &numFlag0. ne &numRow3. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;


/* For hsg_1 */
data hsg1test;
   set df_twdy_hg;
   len=lengthn(hsg_1);
   newval=compress(hsg_1, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hsg1test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdn_hg */
   proc sql noprint;
       select count(*) into :numRow3  /* Macro variable for # of rows in df_twdy_hg */
       from df_twdy_hg;
   quit;
   
   %if &numFlag0. ne &numRow3. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;
   

/* For hsg_2 */
data hsg2test;
   set df_twdy_hg;
   len=lengthn(hsg_2);
   newval=compress(hsg_2, ".", 'd');
   len2=lengthn(newval);
   
   if len2 ne 0 then flag=0;
     else flag=1;
run;

/* Count the number of times flag=0 (character) */
   proc sql noprint;
       select count(flag) into :numFlag0  /* Macro variable for # of character flags */
       from hsg2test(where=(flag=:0));
   quit;

/* Count the number of rows in df_twdn_hg */
   proc sql noprint;
       select count(*) into :numRow3  /* Macro variable for # of rows in df_twdy_hg */
       from df_twdy_hg;
   quit;
   
   %if &numFlag0. ne &numRow3. %then %do;
       %put ERROR: The history variable is not in character format.;
   %end;



/* Compare history values in df_twdn_hg and df_twdn - second exposure */

/* Comparing hsg_0 to hstwog_0 */
data df_twdy_h_hsg_0;
   set df_twdy_hg(keep=hsg_0);
run;

data df_twdy_hstwog_0(rename=(hstwog_0=hsg_0));
   set df_twdy(keep=hstwog_0);
run;

proc compare base=df_twdy_hstwog_0 compare=df_twdy_h_hsg_0 out=comp_hsg_0;
run;

/* Count the number of times difference in hsg_0=. */
   proc sql noprint;
       select count(hsg_0) into :num_hsg_0  /* Macro variable for # of identical hsg_0 values */
       from comp_hsg_0(where=(hsg_0=:'.'));
   quit;
   
   %if &num_hsg_0. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   

/* Comparing hsg_1 to hstwog_1 */
data df_twdy_h_hsg_1;
   set df_twdy_hg(keep=hsg_1);
run;

data df_twdy_hstwog_1(rename=(hstwog_1=hsg_1));
   set df_twdy(keep=hstwog_1);
run;

proc compare base=df_twdy_hstwog_1 compare=df_twdy_h_hsg_1 out=comp_hsg_1;
run;

/* Count the number of times difference in hsg_1=.. */
   proc sql noprint;
       select count(hsg_1) into :num_hsg_1  /* Macro variable for # of identical hsg_1 values */
       from comp_hsg_1(where=(hsg_1=:'..'));
   quit;
   
   %if &num_hsg_1. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;


/* Comparing hsg_2 to hstwog_2 */
data df_twdy_h_hsg_2;
   set df_twdy_hg(keep=hsg_2);
run;

data df_twdy_hstwog_2(rename=(hstwog_2=hsg_2));
   set df_twdy(keep=hstwog_2);
run;

proc compare base=df_twdy_hstwog_2 compare=df_twdy_h_hsg_2 out=comp_hsg_2;
run;


/* Count the number of times difference in hsg_2=... */
   proc sql noprint;
       select count(hsg_2) into :num_hsg_2  /* Macro variable for # of identical hsg_2 values */
       from comp_hsg_2(where=(hsg_2=:'...'));
   quit;
   
   %if &num_hsg_2. ne &numRow1. %then %do;
       %put ERROR: At least one history value does not match.;
   %end;
   
   
** End of tests for %makehistory_two() **;