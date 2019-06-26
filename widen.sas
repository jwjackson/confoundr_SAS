/* Erin Schnellinger */
/* Covariate Balance Project */

/* "Widen" Macro */

/* Successfully passed testWiden tests on 26 June 2019 */


** Start the widen macro **;

%macro widen(input, output, id, time, exposure, covariate,
             history=NULL, weight_exposure=NULL, 
             censor=NULL, weight_censor=NULL, strata=NULL);

** Obtain a list of the datasets in the workspace to save **;

   ods output Members=Members;
      proc datasets library=work memtype=data;
      run;
      quit;
   
   proc transpose data=Members out=MembersWide(drop=_NAME_);
	  id Num; 
	  var Name;
   run;


   ** Create macro variable for list of datasets in the workspace **;

   data _NULL_;
	  set MembersWide;

      datasetNames=CATX(" ",OF _:);

	  %LOCAL save;
	  CALL SYMPUT ('save',datasetNames);  /* Create macro variable for list of datasets in workspace */
   run;




*---------------------------------------------------*;
* Check for missing input variables, and display    *;
* error messages, warnings, or notes as appropriate *;
*---------------------------------------------------*;

   %if &input. eq  OR &input. eq NULL %then %do;   /* &input is missing */
       %put ERROR: 'input' is missing or misspecified. Please specify a dataset in 'long' i.e. person-time format;
	   %ABORT;
   %end;


   %if &output. eq  OR &output. eq NULL %then %do;   /* &output is missing */
       %put NOTE: 'output' dataset name is missing. By default, the name of the output datset will be identical to that of the input dataset, with the suffix '_wide' appended to it;
   %end;


   %if &id. eq  OR &id. eq NULL %then %do;   /* &id is missing */
       %put ERROR: 'id' is missing or misspecified. Please specify a unique identifier for each observation;
	   %ABORT;
   %end;


   %if &exposure. eq  OR &exposure. eq NULL %then %do;   /* &exposure is missing */
       %put ERROR: 'exposure' is missing. Please specify the root name for exposure;
	   %ABORT;
   %end;


   %if &covariate. eq  OR &covariate. eq NULL %then %do;  /* &covariate is missing */
       %put ERROR: 'covariate' is missing. Please specify a vector of covariates;
	   %ABORT;
   %end;


   %if &time. eq  OR &time. eq NULL %then %do;   /* &time is missing */
       %put ERROR: 'time' is missing or misspecified. Please specify a variable for the timing of each observation.;
	   %ABORT;
   %end;


   ** Count the number of unique ID-time combinations **;
   data &input;
      set &input;
      id_time = cats(&id., &time.);
   run;

   proc sql noprint;
	   create table check_idtime as
       select count(distinct(id_time)) as unique_idtime, count(*) as totalRows
       from &input.
   quit;


   data _NULL_;
	  set check_idtime;

	  %LOCAL uniqueIDtime;
	  CALL SYMPUT ('uniqueIDtime',unique_idtime);  /* Create macro variable for count of unique ID-times */

	  %LOCAL numRows;
	  CALL SYMPUT ('numRows',totalRows);  /* Create macro variable for total number of rows */
   run;


   ** Issue an error if ID-time combination does not uniquely identify each observation **;

   %if &&uniqueIDtime. ne &&numRows. %then %do;
       %put ERROR: id and time do not uniquely identify each observation (i.e. each row). Please specify an identifier and time variable that uniquely identify observations.;
       %ABORT;
   %end;



   ** Issue a warning if delimiter is contained in variable names **;

   /* For exposure */
   %if &exposure. ne  AND &exposure. ne NULL %then %do;
       %if %sysfunc(findc(&exposure., '_')) ge 1 %then %do;  /* At least one underscore is present in exposure name */ 
           %put ERROR: Please ensure that exposure name does not contain an underscore i.e. '_';
	       %ABORT;
       %end;
   %end;

   /* For covariates */
   %if &covariate. ne  AND &covariate. ne NULL %then %do;
       %if %sysfunc(findc(&covariate., '_')) ge 1 %then %do;  /* At least one underscore is present in covariate names */ 
           %put ERROR: Please ensure that covariate names do not contain an underscore i.e. '_';
	       %ABORT;
       %end;
   %end;
      
   /* For history */
   %if &history. ne  AND &history. ne NULL %then %do;
       %if %sysfunc(findc(&history., '_')) ge 1 %then %do;  /* At least one underscore is present in history name */ 
           %put ERROR: Please ensure that history name does not contain an underscore i.e. '_';
	       %ABORT;
       %end;
   %end;
     
   /* For censor */
   %if &censor. ne  AND &censor. ne NULL %then %do;
       %if %sysfunc(findc(&censor., '_')) ge 1 %then %do;  /* At least one underscore is present in censor name */ 
           %put ERROR: Please ensure that censor name does not contain an underscore i.e. '_';
	       %ABORT;
       %end;
   %end;
   
   /* For weight_exposure */
   %if &weight_exposure. ne  AND &weight_exposure. ne NULL %then %do;
       %if %sysfunc(findc(&weight_exposure., '_')) ge 1 %then %do;  /* At least one underscore is present in exposure weight name */ 
           %put ERROR: Please ensure that exposure weight name does not contain an underscore i.e. '_';
	       %ABORT;
       %end;
   %end;
     
   /* For weight_censor */
   %if &weight_censor. ne  AND &weight_censor. ne NULL %then %do;
       %if %sysfunc(findc(&weight_censor., '_')) ge 1 %then %do;  /* At least one underscore is present in censor weight name */ 
           %put ERROR: Please ensure that censor weight name does not contain an underscore i.e. '_';
	       %ABORT;
       %end;
   %end;
     
   /* For strata */
   %if &strata. ne  AND &strata. ne NULL %then %do;
       %if %sysfunc(findc(&strata., '_')) ge 1 %then %do;  /* At least one underscore is present in strata name */ 
           %put ERROR: Please ensure that strata name does not contain an underscore i.e. '_';
	       %ABORT;
       %end;
   %end;




   ** Generate list of variables in raw data set, and store in a macro variable **;
   ** Code adapted from http://support.sas.com/resources/papers/proceedings13/319-2013.pdf **;

   /* Grab the column names in the input data set */
   proc contents data=&input. out=rawVar(keep=name) noprint;
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



   ** Confirm that the variables in exposure, covariate, history, censor, weight_exposure, weight_censor, and strata are also in rawVarList **;

      ** Compare raw data variable list to our exposure list **;

      %if &exposure. ne  AND &exposure. ne NULL %then %do;
          proc IML;
             %if NOT %eval(&exposure. in(&&rawVarList.)) %then %do;
                 %put ERROR: The exposure variable is misspelled.;
                 %ABORT;
             %end;
          quit;
	  %end;
	  
	  
	  ** Compare raw data variable list to our covariate list **;

      %if &covariate. ne  AND &covariate. ne NULL %then %do;
          proc IML;
             %LET numCovNames = %sysfunc(countw(&covariate., ' '));  /* Count the total number of covariate names */

	         %do i=1 %to &&numCovNames;  
                 %LET numVar&&i = %scan(&covariate.,&&i, ' ');  /* Grab the individual covariate names */
             %end;

	         %do i=1 %to &&numCovNames.;  /* Check if any individual covariate name is missing from the raw list */
                 %if NOT %eval(&&numVar&i in(&&rawVarList.)) %then %do;
                     %put ERROR: One or more covariates are misspelled, or some covariates are missing from the input dataset.;
                     %ABORT;
                 %end;
	         %end;
          quit;
	  %end;


	  ** Compare raw data variable list to our history list **;

	  %if &history. ne  AND &history. ne NULL %then %do;
          proc IML;
             %if NOT %eval(&history. in(&&rawVarList.)) %then %do;
                 %put ERROR: The history root name is misspelled.;
                 %ABORT;
             %end;
          quit;
	  %end;


	  ** Compare raw data variable list to our censor list **;

	  %if &censor. ne  AND &censor. ne NULL %then %do;
          proc IML;
             %if NOT %eval(&censor. in(&&rawVarList.)) %then %do;
                 %put ERROR: The censor name is misspelled.;
                 %ABORT;
             %end;
          quit;
	  %end;


	  ** Compare raw data variable list to our censor weight list **;

	  %if &weight_censor. ne  AND &weight_censor. ne NULL %then %do;
          proc IML;
             %if NOT %eval(&weight_censor. in(&&rawVarList.)) %then %do;
                 %put ERROR: The weight_censor variable is misspelled.;
                 %ABORT;
             %end;
          quit;
	  %end;


	  ** Compare raw data variable list to our exposure weight list **;
	  %if &weight_exposure. ne  AND &weight_exposure. ne NULL %then %do;
          proc IML;
             %LET numWtExpNames = %sysfunc(countw(&weight_exposure., ' '));  /* Count the total number of exposure weights */

	         %do i=1 %to &&numWtExpNames;  
                 %LET numVar&&i = %scan(&weight_exposure.,&&i, ' ');  /* Grab the individual exposure weights */
             %end;

	         %do i=1 %to &&numWtExpNames.;  /* Check if any individual exposure weight is missing from the raw list */
                 %if NOT %eval(&&numVar&i in(&&rawVarList.)) %then %do;
                     %put ERROR: The weight_exposure variable is misspelled.;
                     %ABORT;
                 %end;
	         %end;
          quit;
	  %end;
	  
	  
	  ** Compare raw data variable list to our strata list **;

	  %if &strata. ne  AND &strata. ne NULL %then %do;
          proc IML;
             %if NOT %eval(&strata. in(&&rawVarList.)) %then %do;
                 %put ERROR: The strata variable is misspelled.;
                 %ABORT;
             %end;
          quit;
	  %end;
	  
	  
   ** Replace null optional variables with blanks **;

   data _NULL_;
      set &input.;
 
	  %if &history. eq  OR &history. eq NULL %then %do;
          %LET history_ = ;
      %end;
 
	  %else %do;
          %LET history_ = &history.;
	  %end;


	  %if &weight_exposure. eq  OR &weight_exposure. eq NULL %then %do;
          %LET weight_exposure_ = ; 
	  %end;

	  %else %do;
          %LET weight_exposure_ = &weight_exposure.;
	  %end;


	  %if &censor. eq  OR &censor. eq NULL %then %do;
          %LET censor_ = ;  
	  %end;

	  %else %do;
          %LET censor_ = &censor.;
	  %end;


	  %if &weight_censor. eq  OR &weight_censor. eq NULL %then %do;
          %LET weight_censor_ = ;
      %end;
 
	  %else %do;
          %LET weight_censor_ = &weight_censor.;
	  %end;


	  %if &strata. eq  OR &strata. eq NULL %then %do;
          %LET strata_ = ;  
	  %end;

	  %else %do;
          %LET strata_ = &strata.;
	  %end;

   run;



** Create a macro variable to store the input exposure, covariates,  **;
** history, censor, weight_exposure, weight_censor, and strata names **;

data inputvar(keep=&exposure. &covariate. &&history_. &&weight_exposure_.  
                   &&censor_. &&weight_censor_. &&strata_.);
   retain &exposure. &covariate. &&history_. &&weight_exposure_. 
          &&censor_. &&weight_censor_. &&strata_.;
   set &input.;
run;

/* Grab the column names in the inputvar data set */
proc contents data=inputvar out=inVar(keep=name) noprint;
run;

/* Create a macro variable, inVarList, which contains a list of all of the column names */
   data _null_;
      set inVar;
      retain inVarList;
      length inVarList $7500.;
      if _n_ = 1 then inVarList = name;
      else inVarList = catx(' ', inVarList, name);
      call symput('inVarList', inVarList);
   run;


** Count the number of variables to be transposed **;
%LET c=1; 

%do %while(%scan(&inVarList,&c) NE); 
	%LET c=%EVAL(&c+1);
%end;

%LET nvars=%EVAL(&c-1);


*-----------------------------------------------*;
* Transpose the input data set into wide format *;
*-----------------------------------------------*;

** Sort the input dataset **;

	proc sort data=&input;
	by &id. &time.;
	run;

/* Note: this portion of the code is modified from */
/* http://www.sascommunity.org/mwiki/images/3/37/Transpose_Macros_MAKEWIDE_and_MAKELONG.sas */

%do i = 1 %to &nvars;
    proc transpose data=&input out=wide_tmp_&i.(drop=_NAME_) prefix=%scan(&inVarList,&i)_; 
       by &id.;
       id &time;
       var %scan(&inVarList,&i);
    run;
%end;


/* Merge the wide_tmp datasets together */

%if &output. ne  AND &output. ne NULL %then %do;
   data &output.;
      merge %do i = 1 %to &nvars; wide_tmp_&i. %end; ;
      by &id;
   run;
%end;

%else %do; 
   data &input._wide;
      merge %do i = 1 %to &nvars; wide_tmp_&i. %end; ;
      by &id;
   run;
%end;



** Remove all intermediate data sets from the WORK library **;

%if &output. ne  AND &output. ne NULL %then %do;
   proc datasets library=work nolist;
	  save &input. &output. &&save.;
	  run;
   quit;
%end;

%else %do;
    proc datasets library=work nolist;
	   save &input. &input._wide &&save.;
	   run;
	quit;
%end;



%mend widen;  /* End the widen macro */


** End of Program **;