/* Erin Schnellinger */
/* 12 April 2019 */

/* Program to test the %lengthen() SAS Macro under single exposure */

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
  
  
*--------------------------------------------------*;
* Test the %lengthen() macro under single exposure *;
*--------------------------------------------------*;

** Import the relevant toy data sets **;

proc import datafile="/folders/myfolders/confoundr_SAS-master/data/toy_wide_dropoutN.csv"
   out=df_twdn dbms=csv replace;
   getnames=yes;
run;

*---------------------------------------*;
* Check Diagnostic 1 under no censoring *;
*---------------------------------------*;

%lengthen(
 input=df_twdn, 
 output=df_twdn_t, 
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



/* Create macro variables with true values for ID=1 */
%LET name_list = uid name_cov time_exposure time_covariate haone a value_cov;
%LET uid = 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1;
%LET name_cov = l l l l l l m m m m m m p p p;
%LET time_exposure = 0 1 1 2 2 2 0 1 1 2 2 2 0 1 2;
%LET time_covariate = 0 0 1 0 1 2 0 0 1 0 1 2 0 0 0;
%LET haone = H H1 H1 H10 H10 H10 H H1 H1 H10 H10 H10 H H1 H10;
%LET a = 1 0 0 0 0 0 1 0 0 0 0 0 1 0 0;
%LET value_cov = 1 1 1 1 1 1 1 1 0 1 0 0 0 0 0;



** Generate list of variables in df_twdn_t, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdn_t data set */
   proc contents data=df_twdn_t out=rawVar(keep=name) noprint;
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
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdn_t */
       from df_twdn_t;
   quit;
     
   %if &numRow1. ne 15000 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   

/* Compare ID numbers in df_twdn_t and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdn_t_ID1;
   set df_twdn_t;
   if uid eq 1;
run;

proc sql noprint;                              
 select uid into :df_twdn_t_ID_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_ID_List = &df_twdn_t_ID_List; 

%if &df_twdn_t_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdn_t and true list */
proc sql noprint;                              
 select name_cov into :df_twdn_t_name_cov_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_name_cov_List = &df_twdn_t_name_cov_List; 

%if &df_twdn_t_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdn_t and true list */
proc sql noprint;                              
 select time_exposure into :df_twdn_t_time_exposure_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_time_exposure_List = &df_twdn_t_time_exposure_List; 

%if &df_twdn_t_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;



/* Compare time_covariate in df_twdn_t and true list */
proc sql noprint;                              
 select time_covariate into :df_twdn_t_time_covariate_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_time_covariate_List = &df_twdn_t_time_covariate_List; 

%if &df_twdn_t_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare haone in df_twdn_t and true list */
proc sql noprint;                              
 select haone into :df_twdn_t_haone_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_haone_List = &df_twdn_t_haone_List; 

%if &df_twdn_t_haone_List. ne &haone. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdn_t and true list */
proc sql noprint;                              
 select a into :df_twdn_t_a_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_a_List = &df_twdn_t_a_List; 

%if &df_twdn_t_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdn_t and true list */
proc sql noprint;                              
 select value_cov into :df_twdn_t_value_cov_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_value_cov_List = &df_twdn_t_value_cov_List; 

%if &df_twdn_t_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;



*------------------------------------*;
* Check Diagnostic 1 under censoring *;
*------------------------------------*;

%lengthen(
 input=df_twdn, 
 output=df_twdn_t, 
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


/* Create macro variables with true values for ID=31 */
%LET name_list = uid name_cov time_exposure time_covariate haone a value_cov s;
%LET uid = 31 31 31 31 31 31 31 31;
%LET name_cov = l l l m m m p p;
%LET time_exposure = 0 1 1 0 1 1 0 1;
%LET time_covariate = 0 0 1 0 0 1 0 0;
%LET haone = H H1 H1 H H1 H1 H H1;
%LET a = 1 0 0 1 0 0 1 0;
%LET value_cov = 0 0 0 0 0 0 0 0;
%LET s = 0 0 0 0 0 0 0 0;



** Generate list of variables in df_twdn_t, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdn_t data set */
   proc contents data=df_twdn_t out=rawVar(keep=name) noprint;
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
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdn_t */
       from df_twdn_t;
   quit;
     
   %if &numRow1. ne 12478 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   


/* Compare ID numbers in df_twdn_t and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdn_t_ID31;
   set df_twdn_t;
   if uid eq 31;
run;

proc sql noprint;                              
 select uid into :df_twdn_t_ID_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_ID_List = &df_twdn_t_ID_List; 

%if &df_twdn_t_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdn_t and true list */
proc sql noprint;                              
 select name_cov into :df_twdn_t_name_cov_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_name_cov_List = &df_twdn_t_name_cov_List; 

%if &df_twdn_t_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdn_t and true list */
proc sql noprint;                              
 select time_exposure into :df_twdn_t_time_exposure_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_time_exposure_List = &df_twdn_t_time_exposure_List; 

%if &df_twdn_t_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;



/* Compare time_covariate in df_twdn_t and true list */
proc sql noprint;                              
 select time_covariate into :df_twdn_t_time_covariate_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_time_covariate_List = &df_twdn_t_time_covariate_List; 

%if &df_twdn_t_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare haone in df_twdn_t and true list */
proc sql noprint;                              
 select haone into :df_twdn_t_haone_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_haone_List = &df_twdn_t_haone_List; 

%if &df_twdn_t_haone_List. ne &haone. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdn_t and true list */
proc sql noprint;                              
 select a into :df_twdn_t_a_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_a_List = &df_twdn_t_a_List; 

%if &df_twdn_t_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdn_t and true list */
proc sql noprint;                              
 select value_cov into :df_twdn_t_value_cov_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_value_cov_List = &df_twdn_t_value_cov_List; 

%if &df_twdn_t_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;


/* Compare censor (s) in df_twdn_t and true list */
proc sql noprint;                              
 select s into :df_twdn_t_s_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_s_List = &df_twdn_t_s_List; 

%if &df_twdn_t_s_List. ne &s. %then %do;
  %put ERROR: At least one censor value does not match.;
%end;



*------------------------------------------*;
* Check Diagnostic 2, no censoring, weight *;
*------------------------------------------*;

%lengthen(
 input=df_twdn, 
 output=df_twdn_t, 
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


/* Create macro variables with true values for ID=31 */
%LET name_list = uid name_cov time_exposure time_covariate haone a value_cov wax;
%LET uid = 1 1 1 1 1 1;
%LET name_cov = l l l m m m;
%LET time_exposure = 0 0 1 0 0 1;
%LET time_covariate = 1 2 2 1 2 2;
%LET haone = H H H1 H H H1;
%LET a = 1 1 0 1 1 0;
%LET value_cov = 1 1 1 0 0 0;
%LET wax = 0.946306 0.946306 1.083579 0.946306 0.946306 1.083579;



** Generate list of variables in df_twdn_t, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdn_t data set */
   proc contents data=df_twdn_t out=rawVar(keep=name) noprint;
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
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdn_t */
       from df_twdn_t;
   quit;
     
   %if &numRow1. ne 6000 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   


/* Compare ID numbers in df_twdn_t and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdn_t_ID1;
   set df_twdn_t;
   if uid eq 1;
run;

proc sql noprint;                              
 select uid into :df_twdn_t_ID_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_ID_List = &df_twdn_t_ID_List; 

%if &df_twdn_t_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdn_t and true list */
proc sql noprint;                              
 select name_cov into :df_twdn_t_name_cov_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_name_cov_List = &df_twdn_t_name_cov_List; 

%if &df_twdn_t_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdn_t and true list */
proc sql noprint;                              
 select time_exposure into :df_twdn_t_time_exposure_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_time_exposure_List = &df_twdn_t_time_exposure_List; 

%if &df_twdn_t_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;



/* Compare time_covariate in df_twdn_t and true list */
proc sql noprint;                              
 select time_covariate into :df_twdn_t_time_covariate_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_time_covariate_List = &df_twdn_t_time_covariate_List; 

%if &df_twdn_t_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare haone in df_twdn_t and true list */
proc sql noprint;                              
 select haone into :df_twdn_t_haone_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_haone_List = &df_twdn_t_haone_List; 

%if &df_twdn_t_haone_List. ne &haone. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdn_t and true list */
proc sql noprint;                              
 select a into :df_twdn_t_a_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_a_List = &df_twdn_t_a_List; 

%if &df_twdn_t_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdn_t and true list */
proc sql noprint;                              
 select value_cov into :df_twdn_t_value_cov_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_value_cov_List = &df_twdn_t_value_cov_List; 

%if &df_twdn_t_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;


/* Compare exposure weight (wax) in df_twdn_t and true list */
proc sql noprint;                              
 select round(input(wax,12.), 0.000001) into :df_twdn_t_wax_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_wax_List = &df_twdn_t_wax_List; 

%if &df_twdn_t_wax_List. ne &wax. %then %do;
  %put ERROR: At least one exposure weight value does not match.;
%end;




*---------------------------------------*;
* Check Diagnostic 2, censoring, weight *;
*---------------------------------------*;

%lengthen(
 input=df_twdn, 
 output=df_twdn_t, 
 diagnostic=2, 
 censoring=yes, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a, 
 temporal_covariate=l m, 
 static_covariate=p, 
 history=haone,
 censor=s,
 weight_exposure=wax,
 weight_censor=wsx
);


/* Create macro variables with true values for ID=31 */
%LET name_list = uid name_cov time_exposure time_covariate haone a value_cov s wax wsx;
%LET uid = 31 31;
%LET name_cov = l m;
%LET time_exposure = 0 0;
%LET time_covariate = 1 1;
%LET haone = H H;
%LET a = 1 1;
%LET value_cov = 0 0;
%LET s = 0 0;
%LET wax = 1.0144498 1.0144498;
%LET wsx = 0.9751602 0.9751602;



** Generate list of variables in df_twdn_t, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdn_t data set */
   proc contents data=df_twdn_t out=rawVar(keep=name) noprint;
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
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdn_t */
       from df_twdn_t;
   quit;
     
   %if &numRow1. ne 4690 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   


/* Compare ID numbers in df_twdn_t and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdn_t_ID31;
   set df_twdn_t;
   if uid eq 31;
run;

proc sql noprint;                              
 select uid into :df_twdn_t_ID_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_ID_List = &df_twdn_t_ID_List; 

%if &df_twdn_t_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdn_t and true list */
proc sql noprint;                              
 select name_cov into :df_twdn_t_name_cov_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_name_cov_List = &df_twdn_t_name_cov_List; 

%if &df_twdn_t_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdn_t and true list */
proc sql noprint;                              
 select time_exposure into :df_twdn_t_time_exposure_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_time_exposure_List = &df_twdn_t_time_exposure_List; 

%if &df_twdn_t_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;



/* Compare time_covariate in df_twdn_t and true list */
proc sql noprint;                              
 select time_covariate into :df_twdn_t_time_covariate_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_time_covariate_List = &df_twdn_t_time_covariate_List; 

%if &df_twdn_t_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare haone in df_twdn_t and true list */
proc sql noprint;                              
 select haone into :df_twdn_t_haone_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_haone_List = &df_twdn_t_haone_List; 

%if &df_twdn_t_haone_List. ne &haone. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdn_t and true list */
proc sql noprint;                              
 select a into :df_twdn_t_a_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_a_List = &df_twdn_t_a_List; 

%if &df_twdn_t_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdn_t and true list */
proc sql noprint;                              
 select value_cov into :df_twdn_t_value_cov_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_value_cov_List = &df_twdn_t_value_cov_List; 

%if &df_twdn_t_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;


/* Compare censor (s) in df_twdn_t and true list */
proc sql noprint;                              
 select s into :df_twdn_t_s_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_s_List = &df_twdn_t_s_List; 

%if &df_twdn_t_s_List. ne &s. %then %do;
  %put ERROR: At least one censor value does not match.;
%end;


/* Compare exposure weight (wax) in df_twdn_t and true list */
proc sql noprint;                              
 select round(input(wax,12.), 0.0000001) into :df_twdn_t_wax_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_wax_List = &df_twdn_t_wax_List; 

%if &df_twdn_t_wax_List. ne &wax. %then %do;
  %put ERROR: At least one exposure weight value does not match.;
%end;


/* Compare censor weight (wsx) in df_twdn_t and true list */
proc sql noprint;                              
 select round(input(wsx,12.), 0.0000001) into :df_twdn_t_wsx_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_wsx_List = &df_twdn_t_wsx_List; 

%if &df_twdn_t_wsx_List. ne &wsx. %then %do;
  %put ERROR: At least one censor weight value does not match.;
%end;




*--------------------------------------------------*;
* Check Diagnostic 2, no censoring, stratification *;
*--------------------------------------------------*;

%lengthen(
 input=df_twdn, 
 output=df_twdn_t, 
 diagnostic=2, 
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


/* Create macro variables with true values for ID=1 */
%LET name_list = uid name_cov time_exposure time_covariate haone a value_cov e5;
%LET uid = 1 1 1 1 1 1;
%LET name_cov = l l l m m m;
%LET time_exposure = 0 0 1 0 0 1;
%LET time_covariate = 1 2 2 1 2 2;
%LET haone = H H H1 H H H1;
%LET a = 1 1 0 1 1 0;
%LET value_cov = 1 1 1 0 0 0;
%LET e5 = 3 3 4 3 3 4;



** Generate list of variables in df_twdn_t, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdn_t data set */
   proc contents data=df_twdn_t out=rawVar(keep=name) noprint;
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
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdn_t */
       from df_twdn_t;
   quit;
     
   %if &numRow1. ne 6000 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   


/* Compare ID numbers in df_twdn_t and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdn_t_ID1;
   set df_twdn_t;
   if uid eq 1;
run;

proc sql noprint;                              
 select uid into :df_twdn_t_ID_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_ID_List = &df_twdn_t_ID_List; 

%if &df_twdn_t_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdn_t and true list */
proc sql noprint;                              
 select name_cov into :df_twdn_t_name_cov_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_name_cov_List = &df_twdn_t_name_cov_List; 

%if &df_twdn_t_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdn_t and true list */
proc sql noprint;                              
 select time_exposure into :df_twdn_t_time_exposure_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_time_exposure_List = &df_twdn_t_time_exposure_List; 

%if &df_twdn_t_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;



/* Compare time_covariate in df_twdn_t and true list */
proc sql noprint;                              
 select time_covariate into :df_twdn_t_time_covariate_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_time_covariate_List = &df_twdn_t_time_covariate_List; 

%if &df_twdn_t_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare haone in df_twdn_t and true list */
proc sql noprint;                              
 select haone into :df_twdn_t_haone_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_haone_List = &df_twdn_t_haone_List; 

%if &df_twdn_t_haone_List. ne &haone. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdn_t and true list */
proc sql noprint;                              
 select a into :df_twdn_t_a_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_a_List = &df_twdn_t_a_List; 

%if &df_twdn_t_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdn_t and true list */
proc sql noprint;                              
 select value_cov into :df_twdn_t_value_cov_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_value_cov_List = &df_twdn_t_value_cov_List; 

%if &df_twdn_t_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;


/* Compare strata (e5) in df_twdn_t and true list */
proc sql noprint;                              
 select e5 into :df_twdn_t_e5_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_e5_List = &df_twdn_t_e5_List; 

%if &df_twdn_t_e5_List. ne &e5. %then %do;
  %put ERROR: At least one strata value does not match.;
%end;



*-----------------------------------------------*;
* Check Diagnostic 2, censoring, stratification *;
*-----------------------------------------------*;

%lengthen(
 input=df_twdn, 
 output=df_twdn_t, 
 diagnostic=2, 
 censoring=yes, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a, 
 temporal_covariate=l m, 
 static_covariate=p, 
 history=haone,
 censor=s,
 weight_censor=wsx,
 strata=e5
);


/* Create macro variables with true values for ID=31 */
%LET name_list = uid name_cov time_exposure time_covariate haone a value_cov s wsx e5;
%LET uid = 31 31;
%LET name_cov = l m;
%LET time_exposure = 0 0;
%LET time_covariate = 1 1;
%LET haone = H H;
%LET a = 1 1;
%LET value_cov = 0 0;
%LET s = 0 0;
%LET wsx = 0.9751602 0.9751602;
%LET e5 = 3 3;



** Generate list of variables in df_twdn_t, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdn_t data set */
   proc contents data=df_twdn_t out=rawVar(keep=name) noprint;
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
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdn_t */
       from df_twdn_t;
   quit;
     
   %if &numRow1. ne 4690 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   


/* Compare ID numbers in df_twdn_t and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdn_t_ID31;
   set df_twdn_t;
   if uid eq 31;
run;

proc sql noprint;                              
 select uid into :df_twdn_t_ID_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_ID_List = &df_twdn_t_ID_List; 

%if &df_twdn_t_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdn_t and true list */
proc sql noprint;                              
 select name_cov into :df_twdn_t_name_cov_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_name_cov_List = &df_twdn_t_name_cov_List; 

%if &df_twdn_t_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdn_t and true list */
proc sql noprint;                              
 select time_exposure into :df_twdn_t_time_exposure_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_time_exposure_List = &df_twdn_t_time_exposure_List; 

%if &df_twdn_t_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;



/* Compare time_covariate in df_twdn_t and true list */
proc sql noprint;                              
 select time_covariate into :df_twdn_t_time_covariate_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_time_covariate_List = &df_twdn_t_time_covariate_List; 

%if &df_twdn_t_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare haone in df_twdn_t and true list */
proc sql noprint;                              
 select haone into :df_twdn_t_haone_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_haone_List = &df_twdn_t_haone_List; 

%if &df_twdn_t_haone_List. ne &haone. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdn_t and true list */
proc sql noprint;                              
 select a into :df_twdn_t_a_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_a_List = &df_twdn_t_a_List; 

%if &df_twdn_t_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdn_t and true list */
proc sql noprint;                              
 select value_cov into :df_twdn_t_value_cov_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_value_cov_List = &df_twdn_t_value_cov_List; 

%if &df_twdn_t_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;


/* Compare censor (s) in df_twdn_t and true list */
proc sql noprint;                              
 select s into :df_twdn_t_s_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_s_List = &df_twdn_t_s_List; 

%if &df_twdn_t_s_List. ne &s. %then %do;
  %put ERROR: At least one censor value does not match.;
%end;


/* Compare censor weight (wsx) in df_twdn_t and true list */
proc sql noprint;                              
 select round(input(wsx,12.), 0.0000001) into :df_twdn_t_wsx_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_wsx_List = &df_twdn_t_wsx_List; 

%if &df_twdn_t_wsx_List. ne &wsx. %then %do;
  %put ERROR: At least one censor weight value does not match.;
%end;


/* Compare strata (e5) in df_twdn_t and true list */
proc sql noprint;                              
 select e5 into :df_twdn_t_e5_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_e5_List = &df_twdn_t_e5_List; 

%if &df_twdn_t_e5_List. ne &e5. %then %do;
  %put ERROR: At least one strata value does not match.;
%end;




*------------------------------------------*;
* Check Diagnostic 3, no censoring, weight *;
*------------------------------------------*;

%lengthen(
 input=df_twdn, 
 output=df_twdn_t, 
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


/* Create macro variables with true values for ID=31 */
%LET name_list = uid name_cov time_exposure time_covariate haone a value_cov wax;
%LET uid = 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1;
%LET name_cov = l l l l l l m m m m m m p p p;
%LET time_exposure = 0 1 1 2 2 2 0 1 1 2 2 2 0 1 2;
%LET time_covariate = 0 0 1 0 1 2 0 0 1 0 1 2 0 0 0;
%LET haone = H H1 H1 H10 H10 H10 H H1 H1 H10 H10 H10 H H1 H10;
%LET a = 1 0 0 0 0 0 1 0 0 0 0 0 1 0 0;
%LET value_cov = 1 1 1 1 1 1 1 1 0 1 0 0 0 0 0;
%LET wax = 0.946306 1.083579 1.083579 1.593498 1.593498 1.593498 0.946306 1.083579 1.083579 1.593498 1.593498 1.593498 0.946306 1.083579 1.593498;



** Generate list of variables in df_twdn_t, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdn_t data set */
   proc contents data=df_twdn_t out=rawVar(keep=name) noprint;
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
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdn_t */
       from df_twdn_t;
   quit;
     
   %if &numRow1. ne 15000 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   


/* Compare ID numbers in df_twdn_t and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdn_t_ID1;
   set df_twdn_t;
   if uid eq 1;
run;

proc sql noprint;                              
 select uid into :df_twdn_t_ID_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_ID_List = &df_twdn_t_ID_List; 

%if &df_twdn_t_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdn_t and true list */
proc sql noprint;                              
 select name_cov into :df_twdn_t_name_cov_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_name_cov_List = &df_twdn_t_name_cov_List; 

%if &df_twdn_t_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdn_t and true list */
proc sql noprint;                              
 select time_exposure into :df_twdn_t_time_exposure_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_time_exposure_List = &df_twdn_t_time_exposure_List; 

%if &df_twdn_t_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;



/* Compare time_covariate in df_twdn_t and true list */
proc sql noprint;                              
 select time_covariate into :df_twdn_t_time_covariate_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_time_covariate_List = &df_twdn_t_time_covariate_List; 

%if &df_twdn_t_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare haone in df_twdn_t and true list */
proc sql noprint;                              
 select haone into :df_twdn_t_haone_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_haone_List = &df_twdn_t_haone_List; 

%if &df_twdn_t_haone_List. ne &haone. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdn_t and true list */
proc sql noprint;                              
 select a into :df_twdn_t_a_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_a_List = &df_twdn_t_a_List; 

%if &df_twdn_t_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdn_t and true list */
proc sql noprint;                              
 select value_cov into :df_twdn_t_value_cov_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_value_cov_List = &df_twdn_t_value_cov_List; 

%if &df_twdn_t_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;


/* Compare exposure weight (wax) in df_twdn_t and true list */
proc sql noprint;                              
 select round(input(wax,12.), 0.000001) into :df_twdn_t_wax_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_wax_List = &df_twdn_t_wax_List; 

%if &df_twdn_t_wax_List. ne &wax. %then %do;
  %put ERROR: At least one exposure weight value does not match.;
%end;

 

*---------------------------------------*;
* Check Diagnostic 3, censoring, weight *;
*---------------------------------------*;

%lengthen(
 input=df_twdn, 
 output=df_twdn_t, 
 diagnostic=3, 
 censoring=yes, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a, 
 temporal_covariate=l m, 
 static_covariate=p, 
 history=haone,
 censor=s,
 weight_exposure=wax,
 weight_censor=wsx
);


/* Create macro variables with true values for ID=31 */
%LET name_list = uid name_cov time_exposure time_covariate haone a value_cov s wax wsx;
%LET uid = 31 31 31 31 31 31 31 31;
%LET name_cov = l l l m m m p p;
%LET time_exposure = 0 1 1 0 1 1 0 1;
%LET time_covariate = 0 0 1 0 0 1 0 0;
%LET haone = H H1 H1 H H1 H1 H H1;
%LET a = 1 0 0 1 0 0 1 0;
%LET value_cov = 0 0 0 0 0 0 0 0;
%LET s = 0 0 0 0 0 0 0 0;
%LET wax = 1.01445 0.786882 0.786882 1.01445 0.786882 0.786882 1.01445 0.786882;
%LET wsx = 1 0.97516 0.97516 1 0.97516 0.97516 1 0.97516;



** Generate list of variables in df_twdn_t, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdn_t data set */
   proc contents data=df_twdn_t out=rawVar(keep=name) noprint;
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
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdn_t */
       from df_twdn_t;
   quit;
     
   %if &numRow1. ne 12478 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   


/* Compare ID numbers in df_twdn_t and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdn_t_ID31;
   set df_twdn_t;
   if uid eq 31;
run;

proc sql noprint;                              
 select uid into :df_twdn_t_ID_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_ID_List = &df_twdn_t_ID_List; 

%if &df_twdn_t_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdn_t and true list */
proc sql noprint;                              
 select name_cov into :df_twdn_t_name_cov_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_name_cov_List = &df_twdn_t_name_cov_List; 

%if &df_twdn_t_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdn_t and true list */
proc sql noprint;                              
 select time_exposure into :df_twdn_t_time_exposure_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_time_exposure_List = &df_twdn_t_time_exposure_List; 

%if &df_twdn_t_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;



/* Compare time_covariate in df_twdn_t and true list */
proc sql noprint;                              
 select time_covariate into :df_twdn_t_time_covariate_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_time_covariate_List = &df_twdn_t_time_covariate_List; 

%if &df_twdn_t_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare haone in df_twdn_t and true list */
proc sql noprint;                              
 select haone into :df_twdn_t_haone_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_haone_List = &df_twdn_t_haone_List; 

%if &df_twdn_t_haone_List. ne &haone. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdn_t and true list */
proc sql noprint;                              
 select a into :df_twdn_t_a_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_a_List = &df_twdn_t_a_List; 

%if &df_twdn_t_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdn_t and true list */
proc sql noprint;                              
 select value_cov into :df_twdn_t_value_cov_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_value_cov_List = &df_twdn_t_value_cov_List; 

%if &df_twdn_t_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;


/* Compare censor (s) in df_twdn_t and true list */
proc sql noprint;                              
 select s into :df_twdn_t_s_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_s_List = &df_twdn_t_s_List; 

%if &df_twdn_t_s_List. ne &s. %then %do;
  %put ERROR: At least one censor value does not match.;
%end;


/* Compare exposure weight (wax) in df_twdn_t and true list */
proc sql noprint;                              
 select round(input(wax,12.), 0.000000001) into :df_twdn_t_wax_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_wax_List = &df_twdn_t_wax_List; 

%if &df_twdn_t_wax_List. ne &wax. %then %do;
  %put ERROR: At least one exposure weight value does not match.;
%end;


/* Compare censor weight (wsx) in df_twdn_t and true list */
proc sql noprint;                              
 select round(input(wsx,12.), 0.000000001) into :df_twdn_t_wsx_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_wsx_List = &df_twdn_t_wsx_List; 

%if &df_twdn_t_wsx_List. ne &wsx. %then %do;
  %put ERROR: At least one censor weight value does not match.;
%end;  



*--------------------------------------------------*;
* Check Diagnostic 3, no censoring, stratification *;
*--------------------------------------------------*;

%lengthen(
 input=df_twdn, 
 output=df_twdn_t, 
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


/* Create macro variables with true values for ID=31 */
%LET name_list = uid name_cov time_exposure time_covariate haone a value_cov e5;
%LET uid = 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1;
%LET name_cov = l l l l l l m m m m m m p p p;
%LET time_exposure = 0 1 1 2 2 2 0 1 1 2 2 2 0 1 2;
%LET time_covariate = 0 0 1 0 1 2 0 0 1 0 1 2 0 0 0;
%LET haone = H H1 H1 H10 H10 H10 H H1 H1 H10 H10 H10 H H1 H10;
%LET a = 1 0 0 0 0 0 1 0 0 0 0 0 1 0 0;
%LET value_cov = 1 1 1 1 1 1 1 1 0 1 0 0 0 0 0;
%LET e5 = 3 4 4 4 4 4 3 4 4 4 4 4 3 4 4;



** Generate list of variables in df_twdn_t, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdn_t data set */
   proc contents data=df_twdn_t out=rawVar(keep=name) noprint;
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
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdn_t */
       from df_twdn_t;
   quit;
     
   %if &numRow1. ne 15000 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   


/* Compare ID numbers in df_twdn_t and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdn_t_ID1;
   set df_twdn_t;
   if uid eq 1;
run;

proc sql noprint;                              
 select uid into :df_twdn_t_ID_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_ID_List = &df_twdn_t_ID_List; 

%if &df_twdn_t_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdn_t and true list */
proc sql noprint;                              
 select name_cov into :df_twdn_t_name_cov_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_name_cov_List = &df_twdn_t_name_cov_List; 

%if &df_twdn_t_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdn_t and true list */
proc sql noprint;                              
 select time_exposure into :df_twdn_t_time_exposure_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_time_exposure_List = &df_twdn_t_time_exposure_List; 

%if &df_twdn_t_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;



/* Compare time_covariate in df_twdn_t and true list */
proc sql noprint;                              
 select time_covariate into :df_twdn_t_time_covariate_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_time_covariate_List = &df_twdn_t_time_covariate_List; 

%if &df_twdn_t_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare haone in df_twdn_t and true list */
proc sql noprint;                              
 select haone into :df_twdn_t_haone_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_haone_List = &df_twdn_t_haone_List; 

%if &df_twdn_t_haone_List. ne &haone. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdn_t and true list */
proc sql noprint;                              
 select a into :df_twdn_t_a_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_a_List = &df_twdn_t_a_List; 

%if &df_twdn_t_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdn_t and true list */
proc sql noprint;                              
 select value_cov into :df_twdn_t_value_cov_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_value_cov_List = &df_twdn_t_value_cov_List; 

%if &df_twdn_t_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;


/* Compare strata (e5) in df_twdn_t and true list */
proc sql noprint;                              
 select e5 into :df_twdn_t_e5_List separated by ' '
 from df_twdn_t_ID1;
quit;
%put df_twdn_t_e5_List = &df_twdn_t_e5_List; 

%if &df_twdn_t_e5_List. ne &e5. %then %do;
  %put ERROR: At least one strata value does not match.;
%end;



*-----------------------------------------------*;
* Check Diagnostic 3, censoring, stratification *;
*-----------------------------------------------*;

%lengthen(
 input=df_twdn, 
 output=df_twdn_t, 
 diagnostic=3, 
 censoring=yes, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=a, 
 temporal_covariate=l m, 
 static_covariate=p, 
 history=haone,
 censor=s,
 weight_censor=wsx,
 strata=e5
);


/* Create macro variables with true values for ID=31 */
%LET name_list = uid name_cov time_exposure time_covariate haone a value_cov s wsx e5;
%LET uid = 31 31 31 31 31 31 31 31;
%LET name_cov = l l l m m m p p;
%LET time_exposure = 0 1 1 0 1 1 0 1;
%LET time_covariate = 0 0 1 0 0 1 0 0;
%LET haone = H H1 H1 H H1 H1 H H1;
%LET a = 1 0 0 1 0 0 1 0;
%LET value_cov = 0 0 0 0 0 0 0 0;
%LET s = 0 0 0 0 0 0 0 0;
%LET e5 = 3 2 2 3 2 2 3 2;
%LET wsx = 1 0.97516 0.97516 1 0.97516 0.97516 1 0.97516;



** Generate list of variables in df_twdn_t, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdn_t data set */
   proc contents data=df_twdn_t out=rawVar(keep=name) noprint;
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
       select count(*) into :numRow1  /* Macro variable for # of rows in df_twdn_t */
       from df_twdn_t;
   quit;
     
   %if &numRow1. ne 12478 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   


/* Compare ID numbers in df_twdn_t and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdn_t_ID31;
   set df_twdn_t;
   if uid eq 31;
run;

proc sql noprint;                              
 select uid into :df_twdn_t_ID_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_ID_List = &df_twdn_t_ID_List; 

%if &df_twdn_t_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdn_t and true list */
proc sql noprint;                              
 select name_cov into :df_twdn_t_name_cov_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_name_cov_List = &df_twdn_t_name_cov_List; 

%if &df_twdn_t_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdn_t and true list */
proc sql noprint;                              
 select time_exposure into :df_twdn_t_time_exposure_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_time_exposure_List = &df_twdn_t_time_exposure_List; 

%if &df_twdn_t_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;



/* Compare time_covariate in df_twdn_t and true list */
proc sql noprint;                              
 select time_covariate into :df_twdn_t_time_covariate_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_time_covariate_List = &df_twdn_t_time_covariate_List; 

%if &df_twdn_t_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare haone in df_twdn_t and true list */
proc sql noprint;                              
 select haone into :df_twdn_t_haone_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_haone_List = &df_twdn_t_haone_List; 

%if &df_twdn_t_haone_List. ne &haone. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdn_t and true list */
proc sql noprint;                              
 select a into :df_twdn_t_a_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_a_List = &df_twdn_t_a_List; 

%if &df_twdn_t_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdn_t and true list */
proc sql noprint;                              
 select value_cov into :df_twdn_t_value_cov_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_value_cov_List = &df_twdn_t_value_cov_List; 

%if &df_twdn_t_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;


/* Compare censor (s) in df_twdn_t and true list */
proc sql noprint;                              
 select s into :df_twdn_t_s_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_s_List = &df_twdn_t_s_List; 

%if &df_twdn_t_s_List. ne &s. %then %do;
  %put ERROR: At least one censor value does not match.;
%end;


/* Compare censor weight (wsx) in df_twdn_t and true list */
proc sql noprint;                              
 select round(input(wsx,12.), 0.000000001) into :df_twdn_t_wsx_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_wsx_List = &df_twdn_t_wsx_List; 

%if &df_twdn_t_wsx_List. ne &wsx. %then %do;
  %put ERROR: At least one censor weight value does not match.;
%end;  


/* Compare strata (e5) in df_twdn_t and true list */
proc sql noprint;                              
 select e5 into :df_twdn_t_e5_List separated by ' '
 from df_twdn_t_ID31;
quit;
%put df_twdn_t_e5_List = &df_twdn_t_e5_List; 

%if &df_twdn_t_e5_List. ne &e5. %then %do;
  %put ERROR: At least one strata value does not match.;
%end;  


** End of tests for %lengthen() under single exposure **;