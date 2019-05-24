/* Erin Schnellinger */
/* 14 April 2019 */

/* Program to test the %omit_history() SAS Macro */

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
  
  
*--------------------------------*;
* Test the %omit_history() macro *;
*--------------------------------*;

** Import the relevant toy data sets **;

proc import datafile="/folders/myfolders/confoundr_SAS-master/data/toy_wide_dropoutY.csv"
   out=df_twdy dbms=csv replace;
   getnames=yes;
run;


*------------------------------*;
* Check Relative Time Omission *;
*------------------------------*;

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

%omit_history(
 input=df_twdy_t, 
 output=df_twdy_o, 
 omission=relative, 
 covariate_name=l, 
 distance=1
);


/* Create macro variables with true values for ID=1 */
%LET name_list = uid name_cov time_exposure time_covariate haone a value_cov;
%LET uid = 1 1 1 1 1 1 1;
%LET name_cov = l l m m m p p;
%LET time_exposure = 0 1 0 1 1 0 1;
%LET time_covariate = 0 1 0 0 1 0 0;
%LET haone = H H1 H H1 H1 H H1;
%LET a = 1 0 1 0 0 1 0;
%LET value_cov = 1 1 1 1 0 0 0;


** Generate list of variables in df_twdy_t, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdy_t data set */
   proc contents data=df_twdy_t out=rawVar(keep=name) noprint;
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
       from df_twdy_t;
   quit;
     
   %if &numRow1. ne 13929 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;


/* Compare ID numbers in df_twdy_o and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdy_o_ID1;
   set df_twdy_o;
   if uid eq 1;
run;

proc sql noprint;                              
 select uid into :df_twdy_o_ID_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_ID_List = &df_twdy_o_ID_List; 

%if &df_twdy_o_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdy_o and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_o_name_cov_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_name_cov_List = &df_twdy_o_name_cov_List; 

%if &df_twdy_o_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_o and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_o_time_exposure_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_time_exposure_List = &df_twdy_o_time_exposure_List; 

%if &df_twdy_o_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_o and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_o_time_covariate_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_time_covariate_List = &df_twdy_o_time_covariate_List; 

%if &df_twdy_o_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare haone in df_twdy_o and true list */
proc sql noprint;                              
 select haone into :df_twdy_o_haone_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_haone_List = &df_twdy_o_haone_List; 

%if &df_twdy_o_haone_List. ne &haone. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdy_o and true list */
proc sql noprint;                              
 select a into :df_twdy_o_a_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_a_List = &df_twdy_o_a_List; 

%if &df_twdy_o_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdy_o and true list */
proc sql noprint;                              
 select value_cov into :df_twdy_o_value_cov_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_value_cov_List = &df_twdy_o_value_cov_List; 

%if &df_twdy_o_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;



*---------------------------*;
* Check Fixed Time Omission *;
*---------------------------*;

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

%omit_history(
 input=df_twdy_t, 
 output=df_twdy_o, 
 omission=fixed, 
 covariate_name=l, 
 times=1
);


/* Create macro variables with true values for ID=1 */
%LET name_list = uid name_cov time_exposure time_covariate haone a value_cov;
%LET uid = 1 1 1 1 1 1 1;
%LET name_cov = l l m m m p p;
%LET time_exposure = 0 1 0 1 1 0 1;
%LET time_covariate = 0 0 0 0 1 0 0;
%LET haone = H H1 H H1 H1 H H1;
%LET a = 1 0 1 0 0 1 0;
%LET value_cov = 1 1 1 1 0 0 0;


** Generate list of variables in df_twdy_t, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdy_t data set */
   proc contents data=df_twdy_t out=rawVar(keep=name) noprint;
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
       from df_twdy_t;
   quit;
     
   %if &numRow1. ne 13929 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;


/* Compare ID numbers in df_twdy_o and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdy_o_ID1;
   set df_twdy_o;
   if uid eq 1;
run;

proc sql noprint;                              
 select uid into :df_twdy_o_ID_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_ID_List = &df_twdy_o_ID_List; 

%if &df_twdy_o_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdy_o and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_o_name_cov_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_name_cov_List = &df_twdy_o_name_cov_List; 

%if &df_twdy_o_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_o and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_o_time_exposure_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_time_exposure_List = &df_twdy_o_time_exposure_List; 

%if &df_twdy_o_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_o and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_o_time_covariate_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_time_covariate_List = &df_twdy_o_time_covariate_List; 

%if &df_twdy_o_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare haone in df_twdy_o and true list */
proc sql noprint;                              
 select haone into :df_twdy_o_haone_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_haone_List = &df_twdy_o_haone_List; 

%if &df_twdy_o_haone_List. ne &haone. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdy_o and true list */
proc sql noprint;                              
 select a into :df_twdy_o_a_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_a_List = &df_twdy_o_a_List; 

%if &df_twdy_o_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdy_o and true list */
proc sql noprint;                              
 select value_cov into :df_twdy_o_value_cov_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_value_cov_List = &df_twdy_o_value_cov_List; 

%if &df_twdy_o_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;



*--------------------------*;
* Check Same Time Omission *;
*--------------------------*;

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

%omit_history(
 input=df_twdy_t, 
 output=df_twdy_o, 
 omission=same_time, 
 covariate_name=l
);


/* Create macro variables with true values for ID=1 */
%LET name_list = uid name_cov time_exposure time_covariate haone a value_cov;
%LET uid = 1 1 1 1 1 1;
%LET name_cov = l m m m p p;
%LET time_exposure = 1 0 1 1 0 1;
%LET time_covariate = 0 0 0 1 0 0;
%LET haone = H1 H H1 H1 H H1;
%LET a = 0 1 0 0 1 0;
%LET value_cov = 1 1 1 0 0 0;


** Generate list of variables in df_twdy_t, and store in a macro variable **;
** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the df_twdy_t data set */
   proc contents data=df_twdy_t out=rawVar(keep=name) noprint;
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
       from df_twdy_t;
   quit;
     
   %if &numRow1. ne 13929 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;


/* Compare ID numbers in df_twdy_o and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdy_o_ID1;
   set df_twdy_o;
   if uid eq 1;
run;

proc sql noprint;                              
 select uid into :df_twdy_o_ID_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_ID_List = &df_twdy_o_ID_List; 

%if &df_twdy_o_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdy_o and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_o_name_cov_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_name_cov_List = &df_twdy_o_name_cov_List; 

%if &df_twdy_o_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_o and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_o_time_exposure_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_time_exposure_List = &df_twdy_o_time_exposure_List; 

%if &df_twdy_o_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_o and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_o_time_covariate_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_time_covariate_List = &df_twdy_o_time_covariate_List; 

%if &df_twdy_o_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare haone in df_twdy_o and true list */
proc sql noprint;                              
 select haone into :df_twdy_o_haone_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_haone_List = &df_twdy_o_haone_List; 

%if &df_twdy_o_haone_List. ne &haone. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdy_o and true list */
proc sql noprint;                              
 select a into :df_twdy_o_a_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_a_List = &df_twdy_o_a_List; 

%if &df_twdy_o_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdy_o and true list */
proc sql noprint;                              
 select value_cov into :df_twdy_o_value_cov_List separated by ' '
 from df_twdy_o_ID1;
quit;
%put df_twdy_o_value_cov_List = &df_twdy_o_value_cov_List; 

%if &df_twdy_o_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;



*-------------------------------------------*;
* Confirm name_cov retains character format *;
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
 temporal_covariate=l m, 
 static_covariate=p, 
 history=haone
);

%omit_history(
 input=df_twdy_t, 
 output=df_twdy_o, 
 omission=same_time, 
 covariate_name=l
);


/* Grab the variable type information from the df_twdy_o data set */
proc contents data=df_twdy_o out=checkType(keep=name type) noprint;
run;

   
/* Confirm that name_cov is a character variable */
proc sql noprint;                              
 select type into :name_cov_type separated by ' '
 from checkType
 where name eq "name_cov";  /* only include type information for name_cov */
quit;
%put name_cov_type = &name_cov_type; 

%if &name_cov_type. ne 2 %then %do;
  %put ERROR: The format of name_cov has not been preserved.;
%end;


** End of tests for %omit_history() **;
      