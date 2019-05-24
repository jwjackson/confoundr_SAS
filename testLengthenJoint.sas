/* Erin Schnellinger */
/* 13 April 2019 */

/* Program to test the %lengthen() SAS Macro under joint exposure */

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
  
  
*-------------------------------------------------*;
* Test the %lengthen() macro under joint exposure *;
*-------------------------------------------------*;

** Import the relevant toy data sets **;

proc import datafile="/folders/myfolders/confoundr_SAS-master/data/toy_wide_dropoutY.csv"
   out=df_twdy dbms=csv replace;
   getnames=yes;
run;

*---------------------------------*;
* Check Diagnostic 1, Exposure #1 *;
*---------------------------------*;

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
 history=hatwo
);



/* Create macro variables with true values for ID=1 */
%LET name_list = uid name_cov time_exposure time_covariate hatwo a value_cov;
%LET uid = 1 1 1 1 1 1 1 1;
%LET name_cov = l l l m m m p p;
%LET time_exposure = 0 1 1 0 1 1 0 1;
%LET time_covariate = 0 0 1 0 0 1 0 0;
%LET hatwo = H H10 H10 H H10 H10 H H10;
%LET a = 1 0 0 1 0 0 1 0;
%LET value_cov = 1 1 1 1 1 0 0 0;


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
   
   
/* Compare ID numbers in df_twdy_t and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdy_t_ID1;
   set df_twdy_t;
   if uid eq 1;
run;

proc sql noprint;                              
 select uid into :df_twdy_t_ID_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_ID_List = &df_twdy_t_ID_List; 

%if &df_twdy_t_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdy_t and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_t_name_cov_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_name_cov_List = &df_twdy_t_name_cov_List; 

%if &df_twdy_t_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_t and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_t_time_exposure_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_time_exposure_List = &df_twdy_t_time_exposure_List; 

%if &df_twdy_t_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_t and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_t_time_covariate_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_time_covariate_List = &df_twdy_t_time_covariate_List; 

%if &df_twdy_t_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare hatwo in df_twdy_t and true list */
proc sql noprint;                              
 select hatwo into :df_twdy_t_hatwo_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_hatwo_List = &df_twdy_t_hatwo_List; 

%if &df_twdy_t_hatwo_List. ne &hatwo. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdy_t and true list */
proc sql noprint;                              
 select a into :df_twdy_t_a_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_a_List = &df_twdy_t_a_List; 

%if &df_twdy_t_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdy_t and true list */
proc sql noprint;                              
 select value_cov into :df_twdy_t_value_cov_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_value_cov_List = &df_twdy_t_value_cov_List; 

%if &df_twdy_t_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;



*---------------------------------*;
* Check Diagnostic 1, Exposure #2 *;
*---------------------------------*;

%lengthen(
 input=df_twdy, 
 output=df_twdy_t, 
 diagnostic=1, 
 censoring=no, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=s, 
 temporal_covariate=l m, 
 static_covariate=p, 
 history=hstwo
);



/* Create macro variables with true values for ID=1 */
%LET name_list = uid name_cov time_exposure time_covariate hstwo s value_cov;
%LET uid = 1 1 1 1 1 1 1 1;
%LET name_cov = l l l m m m p p;
%LET time_exposure = 0 1 1 0 1 1 0 1;
%LET time_covariate = 0 0 1 0 0 1 0 0;
%LET hstwo = H1 H100 H100 H1 H100 H100 H1 H100;
%LET s = 0 1 1 0 1 1 0 1;
%LET value_cov = 1 1 1 1 1 0 0 0;


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
   
   
/* Compare ID numbers in df_twdy_t and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdy_t_ID1;
   set df_twdy_t;
   if uid eq 1;
run;

proc sql noprint;                              
 select uid into :df_twdy_t_ID_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_ID_List = &df_twdy_t_ID_List; 

%if &df_twdy_t_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdy_t and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_t_name_cov_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_name_cov_List = &df_twdy_t_name_cov_List; 

%if &df_twdy_t_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_t and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_t_time_exposure_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_time_exposure_List = &df_twdy_t_time_exposure_List; 

%if &df_twdy_t_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_t and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_t_time_covariate_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_time_covariate_List = &df_twdy_t_time_covariate_List; 

%if &df_twdy_t_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare hstwo in df_twdy_t and true list */
proc sql noprint;                              
 select hstwo into :df_twdy_t_hstwo_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_hstwo_List = &df_twdy_t_hstwo_List; 

%if &df_twdy_t_hstwo_List. ne &hstwo. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare s in df_twdy_t and true list */
proc sql noprint;                              
 select s into :df_twdy_t_s_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_s_List = &df_twdy_t_s_List; 

%if &df_twdy_t_s_List. ne &s. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdy_t and true list */
proc sql noprint;                              
 select value_cov into :df_twdy_t_value_cov_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_value_cov_List = &df_twdy_t_value_cov_List; 

%if &df_twdy_t_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;


*-----------------------------------------*;
* Check Diagnostic 2, Exposure #1, weight *;
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
 history=hatwo,
 weight_exposure=wax
);



/* Create macro variables with true values for ID=1 */
%LET name_list = uid name_cov time_exposure time_covariate hatwo a value_cov wax;
%LET uid = 1 1;
%LET name_cov = l m;
%LET time_exposure = 0 0;
%LET time_covariate = 1 1;
%LET hatwo = H H;
%LET a = 1 1;
%LET value_cov = 1 0;
%LET wax = 0.946306 0.946306;


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
     
   %if &numRow1. ne 5388 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   
   
/* Compare ID numbers in df_twdy_t and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdy_t_ID1;
   set df_twdy_t;
   if uid eq 1;
run;

proc sql noprint;                              
 select uid into :df_twdy_t_ID_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_ID_List = &df_twdy_t_ID_List; 

%if &df_twdy_t_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdy_t and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_t_name_cov_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_name_cov_List = &df_twdy_t_name_cov_List; 

%if &df_twdy_t_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_t and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_t_time_exposure_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_time_exposure_List = &df_twdy_t_time_exposure_List; 

%if &df_twdy_t_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_t and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_t_time_covariate_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_time_covariate_List = &df_twdy_t_time_covariate_List; 

%if &df_twdy_t_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare hatwo in df_twdy_t and true list */
proc sql noprint;                              
 select hatwo into :df_twdy_t_hatwo_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_hatwo_List = &df_twdy_t_hatwo_List; 

%if &df_twdy_t_hatwo_List. ne &hatwo. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdy_t and true list */
proc sql noprint;                              
 select a into :df_twdy_t_a_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_a_List = &df_twdy_t_a_List; 

%if &df_twdy_t_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdy_t and true list */
proc sql noprint;                              
 select value_cov into :df_twdy_t_value_cov_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_value_cov_List = &df_twdy_t_value_cov_List; 

%if &df_twdy_t_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;


/* Compare wax in df_twdy_t and true list */
proc sql noprint;                              
 select round(input(wax,12.), 0.000001) into :df_twdy_t_wax_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_wax_List = &df_twdy_t_wax_List; 

%if &df_twdy_t_wax_List. ne &wax. %then %do;
  %put ERROR: At least one exposure weight does not match.;
%end;


*-------------------------------------------------*;
* Check Diagnostic 2, Exposure #1, stratification *;
*-------------------------------------------------*;

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
 history=hatwo,
 strata=e5
);



/* Create macro variables with true values for ID=1 */
%LET name_list = uid name_cov time_exposure time_covariate hatwo a value_cov e5;
%LET uid = 1 1;
%LET name_cov = l m;
%LET time_exposure = 0 0;
%LET time_covariate = 1 1;
%LET hatwo = H H;
%LET a = 1 1;
%LET value_cov = 1 0;
%LET e5 =3 3;


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
     
   %if &numRow1. ne 5388 %then %do;
       %put ERROR: The number of rows do not match.;
   %end;
   
   
/* Compare ID numbers in df_twdy_t and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdy_t_ID1;
   set df_twdy_t;
   if uid eq 1;
run;

proc sql noprint;                              
 select uid into :df_twdy_t_ID_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_ID_List = &df_twdy_t_ID_List; 

%if &df_twdy_t_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdy_t and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_t_name_cov_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_name_cov_List = &df_twdy_t_name_cov_List; 

%if &df_twdy_t_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_t and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_t_time_exposure_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_time_exposure_List = &df_twdy_t_time_exposure_List; 

%if &df_twdy_t_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_t and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_t_time_covariate_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_time_covariate_List = &df_twdy_t_time_covariate_List; 

%if &df_twdy_t_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare hatwo in df_twdy_t and true list */
proc sql noprint;                              
 select hatwo into :df_twdy_t_hatwo_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_hatwo_List = &df_twdy_t_hatwo_List; 

%if &df_twdy_t_hatwo_List. ne &hatwo. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdy_t and true list */
proc sql noprint;                              
 select a into :df_twdy_t_a_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_a_List = &df_twdy_t_a_List; 

%if &df_twdy_t_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdy_t and true list */
proc sql noprint;                              
 select value_cov into :df_twdy_t_value_cov_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_value_cov_List = &df_twdy_t_value_cov_List; 

%if &df_twdy_t_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;


/* Compare strata (e5) in df_twdy_t and true list */
proc sql noprint;                              
 select e5 into :df_twdy_t_e5_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_e5_List = &df_twdy_t_e5_List; 

%if &df_twdy_t_e5_List. ne &e5. %then %do;
  %put ERROR: At least one strata value does not match.;
%end;


*-----------------------------------------*;
* Check Diagnostic 3, Exposure #1, weight *;
*-----------------------------------------*;

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
 history=hatwo,
 weight_exposure=wax
);



/* Create macro variables with true values for ID=1 */
%LET name_list = uid name_cov time_exposure time_covariate hatwo a value_cov wax;
%LET uid = 1 1 1 1 1 1 1 1;
%LET name_cov = l l l m m m p p;
%LET time_exposure = 0 1 1 0 1 1 0 1;
%LET time_covariate = 0 0 1 0 0 1 0 0;
%LET hatwo = H H10 H10 H H10 H10 H H10;
%LET a = 1 0 0 1 0 0 1 0;
%LET value_cov = 1 1 1 1 1 0 0 0;
%LET wax = 0.946306 1.083579 1.083579 0.946306 1.083579 1.083579 0.946306 1.083579;


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
   
   
/* Compare ID numbers in df_twdy_t and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdy_t_ID1;
   set df_twdy_t;
   if uid eq 1;
run;

proc sql noprint;                              
 select uid into :df_twdy_t_ID_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_ID_List = &df_twdy_t_ID_List; 

%if &df_twdy_t_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdy_t and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_t_name_cov_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_name_cov_List = &df_twdy_t_name_cov_List; 

%if &df_twdy_t_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_t and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_t_time_exposure_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_time_exposure_List = &df_twdy_t_time_exposure_List; 

%if &df_twdy_t_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_t and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_t_time_covariate_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_time_covariate_List = &df_twdy_t_time_covariate_List; 

%if &df_twdy_t_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare hatwo in df_twdy_t and true list */
proc sql noprint;                              
 select hatwo into :df_twdy_t_hatwo_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_hatwo_List = &df_twdy_t_hatwo_List; 

%if &df_twdy_t_hatwo_List. ne &hatwo. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare a in df_twdy_t and true list */
proc sql noprint;                              
 select a into :df_twdy_t_a_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_a_List = &df_twdy_t_a_List; 

%if &df_twdy_t_a_List. ne &a. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdy_t and true list */
proc sql noprint;                              
 select value_cov into :df_twdy_t_value_cov_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_value_cov_List = &df_twdy_t_value_cov_List; 

%if &df_twdy_t_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;


/* Compare wax in df_twdy_t and true list */
proc sql noprint;                              
 select round(input(wax,12.), 0.000001) into :df_twdy_t_wax_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_wax_List = &df_twdy_t_wax_List; 

%if &df_twdy_t_wax_List. ne &wax. %then %do;
  %put ERROR: At least one exposure weight does not match.;
%end;


*-------------------------------------------------*;
* Check Diagnostic 3, Exposure #2, stratification *;
*-------------------------------------------------*;

%lengthen(
 input=df_twdy, 
 output=df_twdy_t, 
 diagnostic=3, 
 censoring=no, 
 id=uid, 
 times_exposure=0 1 2, 
 times_covariate=0 1 2, 
 exposure=s, 
 temporal_covariate=l m, 
 static_covariate=p, 
 history=hstwo,
 strata=e5
);



/* Create macro variables with true values for ID=1 */
%LET name_list = uid name_cov time_exposure time_covariate hstwo s value_cov e5;
%LET uid = 1 1 1 1 1 1 1 1;
%LET name_cov = l l l m m m p p;
%LET time_exposure = 0 1 1 0 1 1 0 1;
%LET time_covariate = 0 0 1 0 0 1 0 0;
%LET hstwo = H1 H100 H100 H1 H100 H100 H1 H100;
%LET s = 0 1 1 0 1 1 0 1;
%LET value_cov = 1 1 1 1 1 0 0 0;
%LET e5 =3 4 4 3 4 4 3 4;


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
   
   
/* Compare ID numbers in df_twdy_t and uid */
/* See: https://blogs.sas.com/content/iml/2016/01/18/create-macro-list-values.html */

data df_twdy_t_ID1;
   set df_twdy_t;
   if uid eq 1;
run;

proc sql noprint;                              
 select uid into :df_twdy_t_ID_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_ID_List = &df_twdy_t_ID_List; 

%if &df_twdy_t_ID_List. ne &uid. %then %do;
  %put ERROR: At least one ID number does not match.;
%end;


/* Compare name_cov in df_twdy_t and true list */
proc sql noprint;                              
 select name_cov into :df_twdy_t_name_cov_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_name_cov_List = &df_twdy_t_name_cov_List; 

%if &df_twdy_t_name_cov_List. ne &name_cov. %then %do;
  %put ERROR: At least one covariate name does not match.;
%end;


/* Compare time_exposure in df_twdy_t and true list */
proc sql noprint;                              
 select time_exposure into :df_twdy_t_time_exposure_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_time_exposure_List = &df_twdy_t_time_exposure_List; 

%if &df_twdy_t_time_exposure_List. ne &time_exposure. %then %do;
  %put ERROR: At least one exposure time does not match.;
%end;


/* Compare time_covariate in df_twdy_t and true list */
proc sql noprint;                              
 select time_covariate into :df_twdy_t_time_covariate_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_time_covariate_List = &df_twdy_t_time_covariate_List; 

%if &df_twdy_t_time_covariate_List. ne &time_covariate. %then %do;
  %put ERROR: At least one covariate time does not match.;
%end;


/* Compare hstwo in df_twdy_t and true list */
proc sql noprint;                              
 select hstwo into :df_twdy_t_hstwo_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_hstwo_List = &df_twdy_t_hstwo_List; 

%if &df_twdy_t_hstwo_List. ne &hstwo. %then %do;
  %put ERROR: At least one history value does not match.;
%end;


/* Compare s in df_twdy_t and true list */
proc sql noprint;                              
 select s into :df_twdy_t_s_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_s_List = &df_twdy_t_s_List; 

%if &df_twdy_t_s_List. ne &s. %then %do;
  %put ERROR: At least one exposure value does not match.;
%end;


/* Compare value_cov in df_twdy_t and true list */
proc sql noprint;                              
 select value_cov into :df_twdy_t_value_cov_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_value_cov_List = &df_twdy_t_value_cov_List; 

%if &df_twdy_t_value_cov_List. ne &value_cov. %then %do;
  %put ERROR: At least one covariate value does not match.;
%end;


/* Compare strata (e5) in df_twdy_t and true list */
proc sql noprint;                              
 select e5 into :df_twdy_t_e5_List separated by ' '
 from df_twdy_t_ID1;
quit;
%put df_twdy_t_e5_List = &df_twdy_t_e5_List; 

%if &df_twdy_t_e5_List. ne &e5. %then %do;
  %put ERROR: At least one strata value does not match.;
%end;


** End of tests for %lengthen() under joint exposure **;