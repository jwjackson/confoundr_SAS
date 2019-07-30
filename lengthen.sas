/* Erin Schnellinger */
/* Covariate Balance Project */

/* "Lengthen" Macro */

/* Updated: 26 June 2019 */
/* Fixed length issue for history variable (length now based on longest instead of shortest value) */

/* Updated: 1 July 2019 */
/* For Diagnostic 2 without censoring, used the same subsetting logic as in */
/* Diagnostic 2 with censoring (i.e., where covariate time > exposure time) */

/* Diagnostics 1 and 3 successfully passed testMakeHistoryTwo tests on 26 June 2019 */
/* Diagnostic 2 - no censoring successfully passed testMakeHistoryTwo tests on 1 July 2019 */



** Start the lengthen macro **;

%macro lengthen(input, output, diagnostic, censoring, id, times_exposure, times_covariate, exposure, 
                temporal_covariate=NULL, static_covariate=NULL, history=NULL, weight_exposure=NULL, 
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
       %put ERROR: 'input' is missing or misspecified. Please specify a dataset in 'wide' format;
	   %ABORT;
   %end;


   %if &output. eq  OR &output. eq NULL %then %do;   /* &output is missing */
       %put NOTE: 'output' dataset name is missing. By default, the name of the output datset will be identical to that of the input dataset, with the suffix '_long' appended to it;
   %end;


   %if &id. eq  OR &id. eq NULL %then %do;   /* &id is missing */
       %put ERROR: 'id' is missing or misspecified. Please specify a unique identifier for each observation;
	   %ABORT;
   %end;


   ** Count the number of unique IDs **;

   proc sql noprint;
	   create table check_id as
       select count(distinct(&id.)) as unique_id, count(*) as totalRows
       from &input.
   quit;


   data _NULL_;
	  set check_id;

	  %LOCAL uniqueID;
	  CALL SYMPUT ('uniqueID',unique_id);  /* Create macro variable for count of unique IDs */

	  %LOCAL numRows;
	  CALL SYMPUT ('numRows',totalRows);  /* Create macro variable for total number of rows */
   run;


   ** Issue an error if ID does not uniquely identify each observation **;

   %if &&uniqueID. ne &&numRows. %then %do;
       %put ERROR: id does not uniquely identify each observation (i.e. each row). Please specify a unique identifier.;
       %ABORT;
   %end;



   %if &diagnostic. eq  OR &diagnostic. eq NULL %then %do;   /* &diagnostic is missing */
       %put ERROR: 'diagnostic' is missing or misspecified. Please specify as 1, 2, or 3;
	   %ABORT;
   %end;

   %if &diagnostic. ne  AND &diagnostic. ne NULL AND NOT %eval(&diagnostic. in(1 2 3)) %then %do;   /* &diagnostic is misspecified */
       %put ERROR: 'diagnostic' is missing or misspecified. Please specify as 1, 2, or 3;
	   %ABORT;
   %end;


   
   %if &censoring. eq  OR &censoring. eq NULL %then %do;   /* &censoring is missing  */
       %put ERROR: 'censoring' is missing. Please specify it as yes or no;
	   %ABORT;
   %end;

   %if &censoring. ne  AND &censoring. ne NULL AND NOT %eval(&censoring. in(no yes)) %then %do;   /* &censoring is misspecified */
       %put ERROR: 'censoring' is missing. Please specify it as yes or no;
	   %ABORT;
   %end;




   %if &exposure. eq  OR &exposure. eq NULL %then %do;   /* &exposure is missing */
       %put ERROR: 'exposure' is missing. Please specify the root name for exposure;
	   %ABORT;
   %end;


   %if &times_exposure. eq  OR &times_exposure. eq NULL OR &times_covariate. eq  OR &times_covariate. eq NULL %then %do;   /* Either &times_exposure or &times_covariate is missing */
       %put ERROR: either 'times_exposure' or 'times_covariate' is missing. Please specify an integer or a numeric vector of times;
	   %ABORT;
   %end;


   %if (&temporal_covariate. eq  OR &temporal_covariate. eq NULL) AND (&static_covariate. eq  OR &static_covariate. eq NULL) %then %do;   /* Both &temporal_covariate and &static_covariate are missing */
       %put ERROR: both 'temporal_covariate' and 'static_covariate' are missing. Please specify a character vector of root names for temporal_covariates or static_covariates;
	   %ABORT;
   %end;


   %if &censoring. eq yes AND (&censor. eq  OR &censor. eq NULL) %then %do;   /* &censor is missing */
       %put ERROR: 'censor' is missing. Please specify a root name for censoring indicators;
	   %ABORT;
   %end;


   %if (&diagnostic. eq 1 AND (&history. eq  OR &history. eq NULL)) %then %do;   /* Diagnostic 1, but &history is missing */
       %put ERROR: For diagnostic 1, please specify the root names for exposure history;
	   %ABORT;
   %end;

   %else %if (&diagnostic. eq 2 AND  /* Diagnostic 2, but some required variables are missing */ 
       (&history. eq  OR &history. eq NULL OR &weight_exposure. eq  OR &weight_exposure. eq NULL) AND
       (&strata. eq  OR &strata. eq NULL) ) %then %do;   
       %put WARNING: For diagnostic 2, unless exposure is randomized, specify the root names for (i) exposure history and exposure weights or (ii) strata;
   %end;
   
   %else %if (&diagnostic. eq 3 AND  /* Diagnostic 3, but some required variables are missing */ 
       (&history. eq  OR &history. eq NULL OR &weight_exposure. eq  OR &weight_exposure. eq NULL) AND
       (&history. eq  OR &history. eq NULL OR &strata. eq  OR &strata. eq NULL) ) %then %do;   
       %put ERROR: For diagnostic 3, please specify the root names for (i) exposure history and exposure weights or (ii) exposure history and strata;
	   %ABORT;
   %end;






*---------------------------------------------------*;
* Pre-processing: Create the Names data sets        *;
*---------------------------------------------------*;
 
   ** Get the number of times inputted into "times_exposure" **;

   data timeCountExp;
      set &input;

	  %LET numTE = %sysfunc(countw(&times_exposure.,' '));  /* Count the total number of exposure times */

	  %do i=1 %to &&numTE;  
	     %LET numTE&&i = %scan(&times_exposure.,&&i, ' ');  /* Grab the individual times */
      %end;
   run;


   ** Get the number of times inputted into "times_covariate" **;

   data timeCountCov;
      set &input;

	  %LET numTC = %sysfunc(countw(&times_covariate., ' '));  /* Count the total number of covariate times */

	  %do i=1 %to &&numTC;  
	     %LET numTC&&i = %scan(&times_covariate.,&&i, ' ');  /* Grab the individual times */
      %end;
   run;



   ** Create exposure names data set **;

   proc IML;
      times = {&times_exposure.};  /* Use the times specified in the "times_exposure" macro variable */
      times_c = CHAR(times);

      exposure = J(1,&&numTE.,"&exposure.");  /* Set up a 1 x numTE matrix that repeats the exposure name */ 
      exposure_names = CATX("_",exposure,times_c);  /* Attach times to exposure prefix */

      CREATE exposure_names_dataset FROM exposure_names;  /* Create exposure names data set */
      APPEND FROM exposure_names;
      CLOSE exposure_names_dataset;
   quit;

 /* proc print data=exposure_names_dataset;
    run; */ 


   data _NULL_;
      set exposure_names_dataset;
      exposureNames=CATX(" ",OF COL1-COL&&numTE.);

	  %LOCAL exposureList;
	  CALL SYMPUT ('exposureList',exposureNames);  /* Create macro variable for list of exposure names */
   run;



   ** Create history names data set **;

   %if &history. ne  AND &history. ne NULL %then %do;

   proc IML;
      times = {&times_exposure.};  /* Use the times specified in the "times_exposure" macro variable */
      times_c = CHAR(times);

      history = J(1,&&numTE.,"&history.");  /* Set up a 1 x numTE matrix that repeats the history name */ 
      history_names = CATX("_",history,times_c);  /* Attach times to history prefix */

      CREATE history_names_dataset FROM history_names;  /* Create history names data set */
      APPEND FROM history_names;
      CLOSE history_names_dataset;
   quit;

  /*proc print data=history_names_dataset;
    run; */


   data _NULL_;
      set history_names_dataset;
      historyNames=CATX(" ",OF COL1-COL&&numTE.);

	  %LOCAL historyList;
	  CALL SYMPUT ('historyList',historyNames);  /* Create macro variable for list of history names */
   run;

   %end;



** Create exposure weight names data set **;

   %if &weight_exposure. ne  AND &weight_exposure. ne NULL %then %do;

   proc IML;
      times = {&times_exposure.};  /* Use the times specified in the "times_exposure" macro variable */
      times_c = CHAR(times);

      expWt = J(1,&&numTE.,"&weight_exposure.");  /* Set up a 1 x numTE matrix that repeats the exposure weight name */ 
      expWt_names = CATX("_",expWt,times_c);  /* Attach times to exposure weight prefix */

      CREATE expWt_names_dataset FROM expWt_names;  /* Create exposure weight names data set */
      APPEND FROM expWt_names;
      CLOSE expWt_names_dataset;
   quit;

 /* proc print data=expWt_names_dataset;
    run; */ 


   data _NULL_;
      set expWt_names_dataset;
      expWtNames=CATX(" ",OF COL1-COL&&numTE.);

	  %LOCAL expWtList;
	  CALL SYMPUT ('expWtList',expWtNames);  /* Create macro variable for list of exposure weight names */
   run;

   %end;




   ** Create censor names data set **;

   %if &censor. ne  AND &censor. ne NULL %then %do;

       %if &diagnostic. eq 1 OR &diagnostic. eq 3 %then %do;
           proc IML;
              times = {&times_exposure.};  /* Use the times specified in the "times_exposure" macro variable */
              times_c = CHAR(times);

              censor = J(1,&&numTE.,"&censor.");  /* Set up a 1 x numTE matrix that repeats the censor name */ 
              censor_names = CATX("_",censor,times_c);  /* Attach times to censor prefix */

              CREATE censor_names_dataset FROM censor_names;  /* Create censor names data set */
              APPEND FROM censor_names;
              CLOSE censor_names_dataset;
           quit;

         /* proc print data=censor_names_dataset;
            run; */ 

           data _NULL_;
              set censor_names_dataset;
              censorNames=CATX(" ",OF COL1-COL&&numTE.);
    
	          %LOCAL censorList;
	          CALL SYMPUT ('censorList',censorNames);  /* Create macro variable for list of censor names */
           run;
       %end;


	   %if &diagnostic. eq 2 %then %do;
           proc IML;
              times = {&times_covariate.};  /* Use the times specified in the "times_covariate" macro variable */
              times_c = CHAR(times);

              censor = J(1,&&numTC.,"&censor.");  /* Set up a 1 x numTC matrix that repeats the censor name */ 
              censor_names = CATX("_",censor,times_c);  /* Attach times to censor prefix */

              CREATE censor_names_dataset FROM censor_names;  /* Create censor names data set */
              APPEND FROM censor_names;
              CLOSE censor_names_dataset;
           quit;

         /* proc print data=censor_names_dataset;
            run; */ 

           data _NULL_;
              set censor_names_dataset;
              censorNames=CATX(" ",OF COL1-COL&&numTC.);
    
	          %LOCAL censorList;
	          CALL SYMPUT ('censorList',censorNames);  /* Create macro variable for list of censor names */
           run;
       %end;
   %end;
	  



   ** Create censor weight names data set **;

   %if &weight_censor. ne  AND &weight_censor. ne NULL %then %do;

       %if &diagnostic. eq 1 OR &diagnostic. eq 3 %then %do;
           proc IML;
              times = {&times_exposure.};  /* Use the times specified in the "times_exposure" macro variable */
              times_c = CHAR(times);

              censWt = J(1,&&numTE.,"&weight_censor.");  /* Set up a 1 x numTE matrix that repeats the censor weight name */ 
              censWt_names = CATX("_",censWt,times_c);  /* Attach times to censor weight prefix */

              CREATE censWt_names_dataset FROM censWt_names;  /* Create censor weight names data set */
              APPEND FROM censWt_names;
              CLOSE censWt_names_dataset;
           quit;

         /* proc print data=censWt_names_dataset;
            run; */

           data _NULL_;
              set censWt_names_dataset;
              censWtNames=CATX(" ",OF COL1-COL&&numTE.);

	          %LOCAL censWtList;
	          CALL SYMPUT ('censWtList',censWtNames);  /* Create macro variable for list of censor weight names */
           run;
	   %end;


	   %if &diagnostic. eq 2 %then %do;
           proc IML;
              times = {&times_covariate.};  /* Use the times specified in the "times_covariate" macro variable */
              times_c = CHAR(times);

              censWt = J(1,&&numTC.,"&weight_censor.");  /* Set up a 1 x numTC matrix that repeats the censor weight name */ 
              censWt_names = CATX("_",censWt,times_c);  /* Attach times to censor weight prefix */

              CREATE censWt_names_dataset FROM censWt_names;  /* Create censor weight names data set */
              APPEND FROM censWt_names;
              CLOSE censWt_names_dataset;
           quit;

         /* proc print data=censWt_names_dataset;
            run; */

           data _NULL_;
              set censWt_names_dataset;
              censWtNames=CATX(" ",OF COL1-COL&&numTC.);

	          %LOCAL censWtList;
	          CALL SYMPUT ('censWtList',censWtNames);  /* Create macro variable for list of censor weight names */
           run;
	   %end;
   %end;



   ** Create strata names data set **;

   %if &strata. ne  AND &strata. ne NULL %then %do;

   proc IML;
      times = {&times_exposure.};  /* Use the times specified in the "times_exposure" macro variable */
      times_c = CHAR(times);

      strata = J(1,&&numTE.,"&strata.");  /* Set up a 1 x numTE matrix that repeats the strata name */ 
      strata_names = CATX("_",strata,times_c);  /* Attach times to strata prefix */

      CREATE strata_names_dataset FROM strata_names;  /* Create strata names data set */
      APPEND FROM strata_names;
      CLOSE strata_names_dataset;
   quit;

 /* proc print data=strata_names_dataset;
    run; */


   data _NULL_;
      set strata_names_dataset;
      strataNames=CATX(" ",OF COL1-COL&&numTE.);

	  %LOCAL strataList;
	  CALL SYMPUT ('strataList',strataNames);  /* Create macro variable for list of strata names */
   run;

   %end;


   ** Issue a warning if delimiter is contained in root names **;

   /* For temporal covariates */
   %if &temporal_covariate. ne  AND &temporal_covariate. ne NULL %then %do;
       %if %sysfunc(findc(&temporal_covariate., '_')) ge 1 %then %do;  /* At least one underscore is present in temporal_covariate root names */ 
           %put ERROR: Please ensure that covariate root names do not contain an underscore i.e. '_';
	       %ABORT;
       %end;
   %end;

   /* For static covariates covariates */
   %if &static_covariate. ne  AND &static_covariate. ne NULL %then %do;
       %if %sysfunc(findc(&static_covariate., '_')) ge 1 %then %do;  /* At least one underscore is present in static_covariate root names */ 
           %put ERROR: Please ensure that covariate root names do not contain an underscore i.e. '_';
	       %ABORT;
       %end;
   %end;



   ** Issue a warning if covariate name list is too long, and direct user to the DIAGNOSE macro **;

   /* For temporal covariates only */
   %if &temporal_covariate. ne  AND &temporal_covariate. ne NULL AND (&static_covariate. eq  OR &static_covariate. eq NULL) %then %do;
       %LET covListLength = %eval(%length(&temporal_covariate.));

	   %if &covListLength. > 7500 %then %do;  /* Covariate name list is too long */
           %put ERROR: the temporal_covariate list and/or static_covariate list is too long. Please use the DIAGNOSE macro instead.;
           %ABORT;
       %end;
   %end;


   /* For static covariates only */
   %if (&temporal_covariate. eq  OR &temporal_covariate. eq NULL) AND &static_covariate. ne  AND &static_covariate. ne NULL %then %do;
       %LET covListLength = %eval(%length(&static_covariate.));

	   %if &covListLength. > 7500 %then %do;  /* Covariate name list is too long */
           %put ERROR: the temporal_covariate list and/or static_covariate list is too long. Please use the DIAGNOSE macro instead.;
           %ABORT;
       %end;
   %end;


   /* For both temporal and static covariates */
   %if &temporal_covariate. ne  AND &temporal_covariate. ne NULL AND &static_covariate. ne  AND &static_covariate. ne NULL %then %do;
       %LET covListLength = %eval(%length(&temporal_covariate.) + %length(&static_covariate.) + 1);  /* Add one to account for space between the two covariate lists */

	   %if &covListLength. > 15000 %then %do;  /* Covariate name list is too long */
           %put ERROR: the temporal_covariate list and/or static_covariate list is too long. Please use the DIAGNOSE macro instead.;
           %ABORT;
       %end;
   %end;








   ** Get the number of temporal covariates inputted into "temporal_covariate" **;

   %if &temporal_covariate. ne  AND &temporal_covariate. ne NULL %then %do;

   data covCount;
      set &input;

	  %LET numC = %sysfunc(countw(&temporal_covariate., ' '));  /* Count the total number of temporal covariates */

	  %do i=1 %to &&numC;  
	     %LET cov&&i = %scan(&temporal_covariate.,&&i, ' ');  /* Grab the individual temporal covariates */
      %end;
   run;


  ** Create temporal covariate names data set **;

   proc IML;
      times = {&times_covariate.};  /* Use the times specified in the "times_covariate" macro variable */
      times_c = CHAR(times);

	  cov = {&temporal_covariate.};

	  %do i=1 %to &&numC.;
          covar&&i. = J(1,&&numTC.,"&&cov&i.");  /* Set up separate 1 x numTC matrices for each covariate name */ 
          covar_names&&i. = CATX("_",covar&&i.,times_c);  /* Attach times to covariate prefix */
      
		  %LET colStart = %eval(1 + &&numTC.*(&&i.-1));  /* Starting column number */
		  %LET colEnd = %eval(&&numTC.*&&i.);  /* Ending column number */

		  column_names = "COL&&colStart.":"COL&&colEnd.";  /* Create list of column names */

          CREATE covariate_names_dataset&&i. FROM covar_names&&i. [COLNAME=column_names];  /* Create covariate names data sets */
          APPEND FROM covar_names&&i.;
          CLOSE covariate_names_dataset&&i.;
	  %end;
   quit;

 /* proc print data=covariate_names_dataset;
    run; */ 


   ** Merge the temporal covariate names datasets together **;

   data cov_names_all;
      merge covariate_names_dataset1-covariate_names_dataset&&numC.;
   run;


   ** Create list of temporal covariate names **;

   data _NULL_;
      set cov_names_all;
      length temporalCovNames $7500.;

	  %LET colMax = %eval(&&numTC.*&&numC.);  /* Calculate the maximum column number */
      temporalCovNames=CATX(" ",OF COL1-COL&&colMax.);

	  %LOCAL temporalCovList;
	  CALL SYMPUT ('temporalCovList',temporalCovNames);  /* Create macro variable for list of temporal covariate names */
   run;

   %end;



   ** Get the number of static covariates inputted into "static_covariate" **;

   %if &static_covariate. ne  AND &static_covariate. ne NULL %then %do;

   data statCovCount;
      set &input;

	  %LET numSC = %sysfunc(countw(&static_covariate., ' '));  /* Count the total number of static covariates */

	  %do i=1 %to &&numSC;  
	     %LET cov&&i = %scan(&static_covariate.,&&i, ' ');  /* Grab the individual static covariates */
      %end;
   run;


  ** Create static covariate names data set **;

  proc IML;
	 cov = {&static_covariate.};

	 %do i=1 %to &&numSC.;
         covar&&i. = J(1,1,"&&cov&i.");  /* Set up separate 1 x 1 matrices for each covariate name */ 
         covar_names&&i. = CATX("_",covar&&i.,&&numTC1.);  /* Attach the first covariate time to covariate prefix */

		 column_names = "COL&&i.";  /* Create list of column names */

         CREATE static_cov_names_dataset&&i. FROM covar_names&&i. [COLNAME=column_names];  /* Create static covariate names data sets */
         APPEND FROM covar_names&&i.;
         CLOSE static_cov_names_dataset&&i.;
	 %end;
  quit;

 /* proc print data=static_cov_names_dataset;
    run; */ 


   ** Merge the static covariate names datasets together **;

   data static_cov_names_all;
      merge static_cov_names_dataset1-static_cov_names_dataset&&numSC.;
   run;


   ** Create list of static covariate names **;

   data _NULL_;
      set static_cov_names_all;
	  length staticCovNames $7500.;

	  %LET colMax = %eval(1*&&numSC.);  /* Calculate the maximum column number */
      staticCovNames=CATX(" ",OF COL1-COL&&colMax.);

	  %LOCAL staticCovList;
	  CALL SYMPUT ('staticCovList',staticCovNames);  /* Create macro variable for list of static covariate names */
   run;

   %end;



  ** Replace null optional variables with blanks **;

   data _NULL_;
      set &input.;
 
	  %if &history. eq  OR &history. eq NULL %then %do;
          %LET history_ = ;
          %LET historyList_ = ;
      %end;
 
	  %else %do;
          %LET history_ = &history.;
		  %LET historyList_ = &&historyList.;
	  %end;


	  %if &weight_exposure. eq  OR &weight_exposure. eq NULL %then %do;
          %LET weight_exposure_ = ; 
          %LET expWtList_ = ; 
	  %end;

	  %else %do;
          %LET weight_exposure_ = &weight_exposure.;
		  %LET expWtList_ = &&expWtList.;
	  %end;


	  %if &censor. eq  OR &censor. eq NULL %then %do;
          %LET censor_ = ;  
		  %LET censorList_ = ;
	  %end;

	  %else %do;
          %LET censor_ = &censor.;
		  %LET censorList_ = &&censorList.;
	  %end;


	  %if &weight_censor. eq  OR &weight_censor. eq NULL %then %do;
          %LET weight_censor_ = ;
          %LET censWtList_ = ;
      %end;
 
	  %else %do;
          %LET weight_censor_ = &weight_censor.;
		  %LET censWtList_ = &&censWtList.;
	  %end;


	  %if &strata. eq  OR &strata. eq NULL %then %do;
          %LET strata_ = ;  
		  %LET strataList_ = ;
	  %end;

	  %else %do;
          %LET strata_ = &strata.;
		  %LET strataList_ = &&strataList.;
	  %end;

   run;


   ** Check the format of exposure and covariates and issue an error if these variables are not numeric **;

   data covFormat_check;
      set &input;

      /* For temporal covariates only */
      %if &temporal_covariate. ne  AND &temporal_covariate. ne NULL AND (&static_covariate. eq  OR &static_covariate. eq NULL) %then %do; 
          keep &&exposureList. &&temporalCovList.;
      %end;

      /* For static covariates only */
      %if (&temporal_covariate. eq  OR &temporal_covariate. eq NULL) AND &static_covariate. ne  AND &static_covariate. ne NULL %then %do;
          keep &&exposureList. &&staticCovList.;
      %end;

      /* For both temporal and static covariates */
      %if &temporal_covariate. ne  AND &temporal_covariate. ne NULL AND &static_covariate. ne  AND &static_covariate. ne NULL %then %do;
          keep &&exposureList. &&temporalCovList. &&staticCovList.;
      %end;
   run;


   %let dsid=%sysfunc(open(covFormat_check,i));  /* Obtain the data set ID for covFormat_check */

   %do i=1 %to %sysfunc(attrn(&dsid,nvars));
       %if (%sysfunc(vartype(&dsid,&i)) = C) %then %do;  /* At least one exposure or covariate is not numeric */
           %put ERROR: At least one exposure or covariate is not formatted properly. Please ensure that these variables are in numeric format.;
	       %ABORT;
	   %end;
   %end;

   %let rc=%sysfunc(close(&dsid));  /* Close the covFormat_check data set (see http://www2.sas.com/proceedings/sugi23/Advtutor/p44.pdf) */
   %if &rc NE 0 %then %put %sysfunc(SYSMSG());  /* If an error occurred when opening data set, print message in log */


*---------------------------------------------------*;
* MAIN: Diagnostics 1 or 3, or 2 without censoring  *;
*---------------------------------------------------*;

   %if &diagnostic. eq 1 OR &diagnostic. eq 3 OR (&diagnostic. eq 2 AND &censoring. eq no) %then %do;

   ** STEP 1 **;

   ** Subset the input data so that it contains only the ID, exposure, **;
   ** history, weights, strata, and censoring variables at the appropriate times **;

   data step1(keep=&id. &&exposureList &&historyList_ &&expWtList_ &&censWtList_ &&strataList_ &&censorList_);
      retain &id. &&exposureList &&historyList_ &&expWtList_ &&censWtList_ &&strataList_ &&censorList_;
      set &input.;
   run;




   ** STEP 2 **;

   ** Transform the step1 data set from wide to long (stacked) with respect to **;
   ** exposure, history, weights, censoring indicators, and strata variables   **;


   ** First get length of longest variable, to be used when defining value_exp **;

   %if &history. ne  AND &history. ne NULL %then %do;  /* History or exposure weight is longest variable */
       data _NULL_;
          set step1;
	      length_hist = lengthc(&history._&&numTE.);
          call symput("histLength",length_hist); 
       run;

	   %if &weight_exposure. eq  OR &weight_exposure. eq NULL %then %do;
	       %LET hLength = &&histLength.;  /* Exposure weight is missing, use the length of the history variable */
	   %end;

	   %else %do;  /* Compare lengths of history and exposure weight, use whichever variable is longer */
	       data _NULL_;
              set step1;
	          length_wte = lengthc(&weight_exposure._&&numTE.);
              call symput("wteLength",length_wte); 
           run;

		   %if &&histLength >= &&wteLength %then %do;
		       %LET hLength = &&histLength.;  /* Use the length of the history variable */
	       %end;

		   %if &&histLength < &&wteLength %then %do;
		       %LET hLength = &&wteLength.;  /* Use the length of the exposure weight variable */
	       %end;
		%end;
   %end;


   %if &history. eq  OR &history. eq NULL %then %do;  /* Exposure or exposure weight is longest (required) variable */
       data _NULL_;
          set step1;
	      length_exp = lengthc(&exposure._&&numTE.);
          call symput("expLength",length_exp); 
       run;

	    %if &weight_exposure. eq  OR &weight_exposure. eq NULL %then %do;  
	       %LET hLength = &&expLength.;  /* Exposure weight is missing, use the length of the exposure variable */
	   %end;

	   %else %do;   /* Compare lengths of exposure and exposure weight, use whichever variable is longer */
	       data _NULL_;
              set step1;
	          length_wte = lengthc(&weight_exposure._&&numTE.);
              call symput("wteLength",length_wte); 
           run;

		   %if &&expLength >= &&wteLength %then %do;
		       %LET hLength = &&expLength.;  /* Use the length of the exposure variable */
	       %end;

		   %if &&expLength < &&wteLength %then %do;
		       %LET hLength = &&wteLength.;  /* Use the length of the exposure weight variable */
	       %end;
		%end;
   %end;


   ** Transform data from wide to long by creating separate arrays for each variable **;

   data step2(keep=&id. wideName_exp value_exp);
      retain &id. wideName_exp value_exp;  /* Retain proper order of variables */
      set step1;
	  
	  array exp[&&numTE] &&exposureList;  /* Set up the exposure array */

      do i=1 to dim(exp);
	     value_exp = left(put(exp[i],&&hLength..));  /* Ensure that value_exp is a left-aligned character variable */
	     wideName_exp=VNAME(exp[i]);  /* Get the column names for the exposure */
	     output;
      end;


	  %if &history. ne  AND &history. ne NULL %then %do;
	      array hist[&&numTE] &&historyList;  /* Set up the history array */

          do i=1 to dim(hist);
	         value_exp = hist[i]; 
	         wideName_exp=VNAME(hist[i]);  /* Get the column names for the history */
	         output;
          end;
	  %end;
	  

	  %if &weight_exposure. ne  AND &weight_exposure. ne NULL %then %do;
	      array expWt[&&numTE] &&expWtList;  /* Set up the exposure weight array */

          do i=1 to dim(expWt);
	         value_exp = expWt[i];  
	         wideName_exp=VNAME(expWt[i]);  /* Get the column names for the exposure weights */
	         output;
          end;
	  %end;
	

	  %if &weight_censor. ne  AND &weight_censor. ne NULL %then %do;
          %if &diagnostic. eq 1 OR &diagnostic. eq 3 %then %do;
	          array censWt[&&numTE] &&censWtList;  /* Set up the censor weight array */

              do i=1 to dim(censWt);
	             value_exp = censWt[i];  
	             wideName_exp=VNAME(censWt[i]);  /* Get the column names for the exposure weights */
	             output;
              end;
	      %end;

		  %if &diagnostic. eq 2 %then %do;
	          array censWt[&&numTC] &&censWtList;  /* Set up the censor weight array */

              do i=1 to dim(censWt);
	             value_exp = censWt[i];  
	             wideName_exp=VNAME(censWt[i]);  /* Get the column names for the exposure weights */
	             output;
              end;
	      %end;
	  %end;


	  %if &strata. ne  AND &strata. ne NULL %then %do;
	      array strat[&&numTE] &&strataList;  /* Set up the strata array */

          do i=1 to dim(strat);
	         value_exp = left(put(strat[i],&&hLength..));  /* Ensure that value_exp is a left-aligned character variable */
	         wideName_exp=VNAME(strat[i]);  /* Get the column names for the strata variables */
	         output;
          end;
	  %end;


	  %if &censor. ne  AND &censor. ne NULL %then %do;
	      %if &diagnostic. eq 1 OR &diagnostic. eq 3 %then %do;
	          array cens[&&numTE] &&censorList;  /* Set up the censoring indicator array */

              do i=1 to dim(cens);
	             value_exp = left(put(cens[i],&&hLength..));  /* Ensure that value_exp is a left-aligned character variable */ 
    	         wideName_exp=VNAME(cens[i]);  /* Get the column names for the censoring indicators */
	             output;
              end;
	      %end;

		  %if &diagnostic. eq 2 %then %do;
	          array cens[&&numTC] &&censorList;  /* Set up the censoring indicator array */

              do i=1 to dim(cens);
	             value_exp = left(put(cens[i],&&hLength..));  /* Ensure that value_exp is a left-aligned character variable */ 
    	         wideName_exp=VNAME(cens[i]);  /* Get the column names for the censoring indicators */
	             output;
              end;
	      %end;
	  %end;

   run;


   ** Remove missing covariates **;

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



   ** Confirm that the variables in exposureList, historyList, censorList, censWtList, and expWtList are also in rawVarList **;

      ** Compare raw data variable list to our exposure list **;

      %if &exposure. ne  AND &exposure. ne NULL %then %do;
          proc IML;
             %LET numExpNames = %sysfunc(countw(&&exposureList., ' '));  /* Count the total number of exposure names in our list */

	         %do i=1 %to &&numExpNames;  
                 %LET numVar&&i = %scan(&&exposureList.,&&i, ' ');  /* Grab the individual exposure names */
             %end;

	         %do i=1 %to &&numExpNames.;  /* Check if any individual exposure name is missing from the raw list */
                 %if NOT %eval(&&numVar&i in(&&rawVarList.)) %then %do;
                     %put ERROR: The exposure root name is misspelled, or some exposure measurements are missing from the input dataset, or incorrect measurement times have been specified;
                     %ABORT;
                 %end;
	         %end;
          quit;
	  %end;


	  ** Compare raw data variable list to our history list **;

	  %if &history. ne  AND &history. ne NULL %then %do;
          proc IML;
             %LET numHistNames = %sysfunc(countw(&&historyList., ' '));  /* Count the total number of history names in our list */

	         %do i=1 %to &&numHistNames;  
                 %LET numVar&&i = %scan(&&historyList.,&&i, ' ');  /* Grab the individual history names */
             %end;

	         %do i=1 %to &&numHistNames.;  /* Check if any individual history name is missing from the raw list */
                 %if (&history. ne  AND &history. ne NULL) AND (NOT %eval(&&numVar&i in(&&rawVarList.))) %then %do;
                     %put ERROR: Either the history root name is misspelled or some history measurements are missing from the input dataset.;
                     %ABORT;
                 %end;
	         %end;
          quit;
	  %end;


	  ** Compare raw data variable list to our censor list **;

	  %if &censor. ne  AND &censor. ne NULL %then %do;
          proc IML;
             %LET numCensNames = %sysfunc(countw(&&censorList., ' '));  /* Count the total number of censor names in our list */

	         %do i=1 %to &&numCensNames;  
                 %LET numVar&&i = %scan(&&censorList.,&&i, ' ');  /* Grab the individual censor names */
             %end;

	         %do i=1 %to &&numCensNames.;  /* Check if any individual censor name is missing from the raw list */
                 %if (&censor. ne  AND &censor. ne NULL) AND (NOT %eval(&&numVar&i in(&&rawVarList.))) %then %do;
                     %put ERROR: Either the censor root name is misspelled or some censor measurements are missing from the input dataset.;
                     %ABORT;
                 %end;
	         %end;
          quit;
	  %end;


	  ** Compare raw data variable list to our censor weight list **;

	  %if &weight_censor. ne  AND &weight_censor. ne NULL %then %do;
          proc IML;
             %LET numCWtNames = %sysfunc(countw(&&censWtList., ' '));  /* Count the total number of censor weight names in our list */

	         %do i=1 %to &&numCWtNames;  
                 %LET numVar&&i = %scan(&&censWtList.,&&i, ' ');  /* Grab the individual censor weight names */
             %end;

	         %do i=1 %to &&numCWtNames.;  /* Check if any individual censor weight name is missing from the raw list */
                 %if (&weight_censor. ne  AND &weight_censor. ne NULL) AND (NOT %eval(&&numVar&i in(&&rawVarList.))) %then %do;
                     %put ERROR: Either the weight_censor root name is misspelled or some weight_censor measurements are missing from the input dataset.;
                     %ABORT;
                 %end;
	         %end;
          quit;
	  %end;


	  ** Compare raw data variable list to our exposure weight list **;

	  %if &weight_exposure. ne  AND &weight_exposure. ne NULL %then %do;
          proc IML;
             %LET numEWtNames = %sysfunc(countw(&&expWtList., ' '));  /* Count the total number of exposure weight names in our list */

	         %do i=1 %to &&numEWtNames;  
                 %LET numVar&&i = %scan(&&expWtList.,&&i, ' ');  /* Grab the individual exposure weight names */
             %end;

	         %do i=1 %to &&numEWtNames.;  /* Check if any individual exposure weight name is missing from the raw list */
                 %if (&weight_exposure. ne  AND &weight_exposure. ne NULL) AND (NOT %eval(&&numVar&i in(&&rawVarList.))) %then %do;
                     %put ERROR: Either the weight_exposure root name is misspelled or some weight_exposure measurements are missing from the input dataset.;
                     %ABORT;
                 %end;
	         %end;
          quit;
	  %end;




   ** Compare raw data variable list to our covariate list to obtain WANTED list **;

   proc sort data=step2 out=step2sort;
      by &id.;
   run;

   proc transpose data=step2sort out=step2wide(drop=_NAME_);
      by &id.;
      id wideName_exp;
      var value_exp;
   run;


   proc IML;
      %LET numNames = %sysfunc(countw(&&rawVarList., ' '));  /* Count the total number of raw variable names */

	  %do i=1 %to &&numNames;  
          %LET numVar&&i = %scan(&&rawVarList.,&&i, ' ');  /* Grab the individual raw variable names */
      %end;

	  %do i=1 %to &&numNames.;  /* Check if each individual variable name is in both the raw list and our list */
	      /* If only temporal covariates are present */
          %if &&temporal_covariate. ne  AND &&temporal_covariate. ne NULL AND (&&static_covariate. eq  OR &&static_covariate. eq NULL) %then %do;
              if %eval(&&numVar&i in(&&rawVarList.) AND &&numVar&i in(&&temporalCovList.)) then do;
                 wantCov&&i. = J(1,1,"&&numVar&i.");  /* Set up separate 1 x 1 matrices for each wanted covariate name */ 
                 column_names = "COL&&i.";  /* Create list of column names */

                 CREATE wanted_names_dataset&&i. FROM wantCov&&i. [COLNAME=column_names];  /* Create wanted names data sets */
                 APPEND FROM wantCov&&i.;
                 CLOSE wanted_names_dataset&&i.;
 	   	      end;
		  %end;

		  /* If only static covariates are present */
          %if (&&temporal_covariate. eq  OR &&temporal_covariate. eq NULL) AND &&static_covariate. ne  AND &&static_covariate. ne NULL %then %do;
              if %eval(&&numVar&i in(&&rawVarList.) AND &&numVar&i in(&&staticCovList.)) then do;
                 wantCov&&i. = J(1,1,"&&numVar&i.");  /* Set up separate 1 x 1 matrices for each wanted covariate name */ 
                 column_names = "COL&&i.";  /* Create list of column names */

                 CREATE wanted_names_dataset&&i. FROM wantCov&&i. [COLNAME=column_names];  /* Create wanted names data sets */
                 APPEND FROM wantCov&&i.;
                 CLOSE wanted_names_dataset&&i.;
 	   	      end;
		  %end;

		  /* If both temporal and static covariates are present */
	      %if &&temporal_covariate. ne  AND &&temporal_covariate. ne NULL AND &&static_covariate. ne  AND &&static_covariate. ne NULL %then %do;
              if %eval(&&numVar&i in(&&rawVarList.) AND &&numVar&i in(&&temporalCovList. &&staticCovList.)) then do;
                 wantCov&&i. = J(1,1,"&&numVar&i.");  /* Set up separate 1 x 1 matrices for each wanted covariate name */ 
                 column_names = "COL&&i.";  /* Create list of column names */

                 CREATE wanted_names_dataset&&i. FROM wantCov&&i. [COLNAME=column_names];  /* Create wanted names data sets */
                 APPEND FROM wantCov&&i.;
                 CLOSE wanted_names_dataset&&i.;
 	   	      end;
		  %end;
	  %end;
  quit;


  ** Merge the wanted covariate names datasets together **;

   data wanted_covariates;
      merge wanted_names_dataset:;
   run;


   ** Create list of wanted covariate names **;

   data _NULL_;
      set wanted_covariates;
	  length wantedCovNames $7500.;

      wantedCovNames=CATX(" ",OF COL:);

	  %LOCAL wantedCovList;
	  CALL SYMPUT ('wantedCovList',wantedCovNames);  /* Create macro variable for list of wanted covariate names */
   run;


   ** Issue a warning if the exposure and/or covariates contain missing data **;

   ** For missing exposures **;

   data _NULL_;
      set &input;

	  %LET numExp = %sysfunc(countw(&&exposureList., ' '));  /* Count the total number of exposure names */

	  %do i=1 %to &&numExp;  
          %LET numVar&&i = %scan(&&exposureList.,&&i, ' ');  /* Grab the individual exposure names */
      %end;

	  %do i=1 %to &&numExp.;  /* Check if any of the exposures contain missing values */
          proc sql noprint;
	         create table expMissCheck&&i. as
             select nmiss(&&numVar&i.) as nmissExp&&i.  /* Count the number of missing exposure values */
             from &input.;
          quit;
	  %end;
   run;


   ** Merge the expMissCheck datasets together **;

   data expMissCheckAll;
      merge expMissCheck:;
   run;

   ** Calculate the sum of the nmissExp columns **;

   data expMissCheckSum;
      set expMissCheckAll;
	  expMissTotal = sum(of nmissExp:);
   run;

   ** Issue warning if expMissTotal > 0 **;

   data _NULL_;
      set expMissCheckSum;

	  if expMissTotal > 0 then do;
	     PUTLOG "WARNING: The exposure and/or some covariates contain missing data. Subsequent calculations are not guaranteed to be unbiased in the presence of partially missing data.";
      end;
   run;



   ** For missing covariates **;

   data _NULL_;
      set &input;

	  %LET numCov = %sysfunc(countw(&&wantedCovList., ' '));  /* Count the total number of covariate names */

	  %do i=1 %to &&numExp;  
          %LET numVar&&i = %scan(&&exposureList.,&&i, ' ');  /* Grab the individual covariate names */
      %end;

	  %do i=1 %to &&numCov.;  /* Check if any of the covariates contain missing values */
          proc sql noprint;
	         create table covMissCheck&&i. as
             select nmiss(&&numVar&i.) as nmissCov&&i.  /* Count the number of missing covariate values */
             from &input.;
          quit;
	  %end;
   run;


  ** Merge the covMissCheck datasets together **;

   data covMissCheckAll;
      merge covMissCheck:;
   run;

   ** Calculate the sum of the nmissCov columns **;

   data covMissCheckSum;
      set covMissCheckAll;
	  covMissTotal = sum(of nmissCov:);
   run;

   ** Issue warning if covMissTotal > 0 **;

   data _NULL_;
      set covMissCheckSum;

	  if covMissTotal > 0 then do;
	     PUTLOG "WARNING: The exposure and/or some covariates contain missing data. Subsequent calculations are not guaranteed to be unbiased in the presence of partially missing data.";
      end;
   run;



   ** STEP 3 **;

   ** Separate variable names into ROOT and TIME variables **;

   data step3(keep=&id. name_exp time_exposure value_exp);
      retain &id. name_exp time_exposure value_exp;  /* Retain proper order of variables */
      set step2;

	  name_exp=scan(wideName_exp,1,'_');  /* Extract characters before underscore and set equal to "name" */
	  time_exposure=scan(wideName_exp,-1,'_');  /* Extract digits after underscore and set equal to "time" */
   run;
	  
   
   ** Widen the data set with respect to time **;

   proc sort data=step3 out=step3sort;
      by &id. time_exposure;
   run;

   proc transpose data=step3sort out=step3wide(drop=_NAME_);
      by &id. time_exposure;
      id name_exp;
      var value_exp;
   run;


   ** Merge the step3wide data set back with the wanted covariates **;

   data step3full;
      merge step3wide &input.(keep=&id. &&wantedCovList.);  /* Include only wanted covariates */
      by &id.;
   run;




** STEP 4 **;

** Transform the step3full data set with respect to the covariates, yielding an even longer data set **;

   data step4(keep=&id. time_exposure &&exposure &&history_ &&weight_exposure_ &&weight_censor_ &&strata_ &&censor_ wideName_cov value_cov);
      retain &id. time_exposure &&exposure &&history_ &&weight_exposure_ &&weight_censor_ &&strata_ &&censor_ wideName_cov value_cov;  /* Retain proper order of variables */
      set step3full;
	     
      %LET totCov = %sysfunc(countw(&&wantedCovList., ' '));  /* Count the total number of wanted covariates */

	  array cov[&&totCov.] &&wantedCovList.;  /* Set up the full covariate array */

      do i=1 to dim(cov);
	     value_cov = cov[i]; 
	     wideName_cov=VNAME(cov[i]);  /* Get the column names for the covariates */
	     output;
      end;
   run;


   ** Sort the step4data by wideName_cov **;

   proc sort data=step4 out=step4sort;
      by &id. wideName_cov;
   run;


   ** Separate covariate names into ROOT and TIME variables **;

   data step4split(keep=&id. time_exposure &&exposure &&history_ &&weight_exposure_ &&weight_censor_ &&strata_ &&censor_ name_cov time_covariate value_cov);
      retain &id. time_exposure &&exposure &&history_ &&weight_exposure_ &&weight_censor_ &&strata_ &&censor_ name_cov time_covariate value_cov;  /* Retain proper order of variables */
      set step4sort;

	  name_cov=scan(wideName_cov,1,'_');  /* Extract characters before underscore and set equal to "name" */
	  time_covariate=scan(wideName_cov,-1,'_');  /* Extract digits after underscore and set equal to "time" */
   run;

   data step4out;
      set step4split;
   run;



   ** Step 5 **;

   ** Retain only the uncensored observations, and omit records with missing data **;

   data step5;
      set step4split;

	  %if &&censor_ ne  %then %do;
	     if strip(&&censor_.) eq '1' then delete;  /* Remove censored observations */
	  %end;

	  if missing(&id.) OR missing(time_exposure) OR missing(&&exposure) OR missing(name_cov) OR 
         missing(time_covariate) OR missing(value_cov) then delete;  /* Remove records with missing data */

		 if &id. eq '.' OR time_exposure eq '.' OR &&exposure eq '.' OR name_cov eq '.' OR
		 time_covariate eq '.' then delete;
		 
	  %if &&history_ ne  %then %do;
          if missing(&&history_) then delete;  /* Remove records with missing history, if applicable */
		  if &&history_ eq '.' then delete;
	  %end;

	  %if &&weight_exposure_ ne  %then %do;
          if missing(&&weight_exposure_) then delete;  /* Remove records with missing exposure weights, if applicable */
		  if &&weight_exposure_ eq '.' then delete;
	  %end;

	  %if &&weight_censor_ ne  %then %do;
          if missing(&&weight_censor_) then delete;  /* Remove records with missing censor weights, if applicable */
		  if &&weight_censor_ eq '.' then delete;
	  %end;
	 
	  %if &&strata_ ne  %then %do;
         if missing(&&strata_) then delete;  /* Remove records with missing strata, if applicable */
		 if &&strata_ eq '.' then delete;
	  %end;

	   %if &&censor_ ne  %then %do;
         if missing(&&censor_) then delete;  /* Remove records with missing censor indicators, if applicable */
		 if &&censor_ eq '.' then delete;
	  %end;

	run;


	** Check to see if any covariates are completely missing **;

	** First grab the unique covariates in the "name_cov" variable **;

    proc sql noprint;
       create table check_name_cov as
       select distinct(name_cov) as unique_name_cov
       from step5
    quit;

    proc sort data=check_name_cov out=check_name_cov_sort;
       by unique_name_cov;
    run;

    data check_name_cov2;
       set check_name_cov_sort;
    run;

    proc transpose data=check_name_cov2 out=check_name_cov_wide(drop=_NAME_);
       var unique_name_cov;
    run;

	** Create macro variable for list of covariates in "name_cov" **;

    data _NULL_;
	   set check_name_cov_wide;
	   length CovNames $7500.;

       covNames=CATX(" ",OF COL:);

	   %LOCAL finalCovList;
       CALL SYMPUT ('finalCovList',covNames); 
    run;


	** Create another macro variable for list of temporal and/or static covariates inputted into lengthen **;

	/* If only temporal covariates are present */
	%if &static_covariate. eq  OR &static_covariate. eq NULL %then %do;
        %LET inputCovList = %sysfunc(CATX(%str(),&temporal_covariate.));
	%end;

	/* If only static covariates are present */
	%if &temporal_covariate. eq  OR &temporal_covariate. eq NULL %then %do;
        %LET inputCovList = %sysfunc(CATX(%str(),&static_covariate.));
	%end;

	/* If both temporal and static covariates are present */
	%if &temporal_covariate. ne  AND &temporal_covariate. ne NULL AND &static_covariate. ne  AND &static_covariate. ne NULL %then %do;
        %LET inputCovList = %sysfunc(CATX(%str( ), &temporal_covariate., &static_covariate.));
	%end;





    ** Compare the unique covariate names with those listed in &&inputCovList**;

    proc IML;
       %LET numNameCov = %sysfunc(countw(&&inputCovList., ' '));  /* Count the total number of inputted covariates */

	   %do i=1 %to &&numNameCov.;  
           %LET numVar&&i = %scan(&&inputCovList.,&&i, ' ');  /* Grab the individual covariate names */
       %end;

	   %do i=1 %to &&numNameCov.;  /* Check if any individual covariate name is missing from &&finalCovList */
           %if NOT %eval(&&numVar&i in(&&finalCovList.)) %then %do;
               %put WARNING: Some covariates listed in temporal_covariate and/or static_covariate have missing values at all timepoints. These covariates will not be included in the balance table or plot.;
           %end;
       %end;
    quit;
    
    
    
    ** STEP 6, if Diagnostic 1 or 3: **;
    ** Subset to observations with time_exposure >= time_covariate **;
    %if &diagnostic. eq 1 OR &diagnostic. eq 3 %then %do;
       data step6a;
          set step5;
          time_exposure_num = input(time_exposure, 8.);   
          time_covariate_num = input(time_covariate, 8.);
       run;  
    
       data step6b;
          set step6a;
          if time_exposure_num>=time_covariate_num;  /* Use numeric times for this step */
       run;
    %end;
    
    
    ** STEP 6, if Diagnostic 2: **;
    ** Subset to observations with time_covariate > time_exposure **;
    %if &diagnostic. eq 2 %then %do;
       data step6a;
          set step5;
          time_exposure_num = input(time_exposure, 8.);
          time_covariate_num = input(time_covariate, 8.);
       run;
       
       data step6b;
          set step6a;
          if time_covariate_num>time_exposure_num;  /* Use numeric times for this step */ 
       run;
    %end;
    
    
    
    
    ** STEP 7: Sort the STEP6b data set by name_cov, &id., time_exposure_num, time_covariate_num, &&history_ **;

    proc sort data=step6b out=step6c;
       by name_cov &id. time_exposure_num time_covariate_num &&history_;
    run;
    
    data step7;
       set step6c(drop=time_exposure_num time_covariate_num);
    run;



    ** Rename the STEP7 data set to match the user-defined or default name, as appropriate **;

    %if &output. ne  AND &output. ne NULL %then %do;
        data &output.;  /* Label the output data set with the user-defined name */
           retain &id. &&history_ name_cov time_exposure time_covariate value_cov;  /* Retain variables in proper order */
           set step7;
        run;
    %end;

    %else %do;
        data &input._long;  /* Label the output data set with the default name */
           retain &id. &&history_ name_cov time_exposure time_covariate value_cov;  /* Retain variables in proper order */
           set step7;
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
	            save &input. &input._long &&save.;
	         run;
	         quit;
         %end;


%end;








*---------------------------------------------------*;
* Alternative: Diagnostic 2 with censoring          *;
*---------------------------------------------------*;

%if &diagnostic. eq 2 AND &censoring. eq yes %then %do;
 
   ** STEP 1 **;

   ** Subset the input data so that it contains only the ID, exposure, history **;
   ** exposure weights, strata, and censoring variables at the appropriate times        **;

   data step1(keep=&id. &&exposureList &&historyList_ &&expWtList_ &&strataList_ &&censorList_);
      retain &id. &&exposureList &&historyList_ &&expWtList_ &&strataList_ &&censorList_;
      set &input.;
   run;




   ** STEP 2 **;

   ** Transform the step1 data set from wide to long (stacked) with respect to **;
   ** exposure, history, weights, censoring indicators, and strata variables   **;


   ** First get length of longest variable, to be used when defining value_exp **;

   %if &history. ne  AND &history. ne NULL %then %do;  /* History or exposure weight is longest variable */
       data _NULL_;
          set step1;
	      length_hist = lengthc(&history._&&numTE.);
          call symput("histLength",length_hist); 
       run;

	   %if &weight_exposure. eq  OR &weight_exposure. eq NULL %then %do;
	       %LET hLength = &&histLength.;  /* Exposure weight is missing, use the length of the history variable */
	   %end;

	   %else %do;   /* Compare lengths of history and exposure weight, use whichever variable is longer */
	       data _NULL_;
              set step1;
	          length_wte = lengthc(&weight_exposure._&&numTE.);
              call symput("wteLength",length_wte); 
           run;

		   %if &&histLength >= &&wteLength %then %do;
		       %LET hLength = &&histLength.;  /* Use the length of the history variable */
	       %end;

		   %if &&histLength < &&wteLength %then %do;
		       %LET hLength = &&wteLength.;  /* Use the length of the exposure weight variable */
	       %end;
		%end;
   %end;


   %if &history. eq  OR &history. eq NULL %then %do;  /* Exposure or exposure weight is longest (required) variable */
       data _NULL_;
          set step1;
	      length_exp = lengthc(&exposure._&&numTE.);
          call symput("expLength",length_exp); 
       run;

	    %if &weight_exposure. eq  OR &weight_exposure. eq NULL %then %do;
	       %LET hLength = &&expLength.;  /* Exposure weight is missing, use the length of the exposure variable */
	   %end;

	   %else %do;   /* Compare lengths of exposure and exposure weight, use whichever variable is longer */
	       data _NULL_;
              set step1;
	          length_wte = lengthc(&weight_exposure._&&numTE.);
              call symput("wteLength",length_wte); 
           run;

		   %if &&expLength >= &&wteLength %then %do;
		       %LET hLength = &&expLength.;  /* Use the length of the exposure variable */
	       %end;

		   %if &&expLength < &&wteLength %then %do;
		       %LET hLength = &&wteLength.;  /* Use the length of the exposure weight variable */
	       %end;
		%end;
   %end;




   ** Transform data from wide to long by creating separate arrays for each variable **;

   data step2(keep=&id. wideName_exp value_exp);
      retain &id. wideName_exp value_exp;  /* Retain proper order of variables */
      set step1;

	  array exp[&&numTE] &&exposureList;  /* Set up the exposure array */

      do i=1 to dim(exp);
	     value_exp = left(put(exp[i],&&hLength..));  /* Ensure that value_exp is a left-aligned character variable */
	     wideName_exp=VNAME(exp[i]);  /* Get the column names for the exposure */
	     output;
      end;


	  %if &history. ne  AND &history. ne NULL %then %do;
	      array hist[&&numTE] &&historyList;  /* Set up the history array */

          do i=1 to dim(hist);
	         value_exp = hist[i]; 
	         wideName_exp=VNAME(hist[i]);  /* Get the column names for the history */
	         output;
          end;
	  %end;


	  %if &weight_exposure. ne  AND &weight_exposure. ne NULL %then %do;
	      array expWt[&&numTE] &&expWtList;  /* Set up the exposure weight array */

          do i=1 to dim(expWt);
	         value_exp = expWt[i];  
	         wideName_exp=VNAME(expWt[i]);  /* Get the column names for the exposure weights */
	         output;
          end;
	  %end;


	  %if &strata. ne  AND &strata. ne NULL %then %do;
	      array strat[&&numTE] &&strataList;  /* Set up the strata array */

          do i=1 to dim(strat);
	         value_exp = left(put(strat[i],&&hLength..));  /* Ensure that value_exp is a left-aligned character variable */
	         wideName_exp=VNAME(strat[i]);  /* Get the column names for the strata variables */
	         output;
          end;
	  %end;


	  %if &censor. ne  AND &censor. ne NULL %then %do;
	      %if &diagnostic. eq 1 OR &diagnostic. eq 3 %then %do;
	          array cens[&&numTE] &&censorList;  /* Set up the censoring indicator array */

              do i=1 to dim(cens);
	             value_exp = left(put(cens[i],&&hLength..));  /* Ensure that value_exp is a left-aligned character variable */ 
	             wideName_exp=VNAME(cens[i]);  /* Get the column names for the censoring indicators */
	             output;
              end;
	      %end;

		  %if &diagnostic. eq 2 %then %do;
	          array cens[&&numTC] &&censorList;  /* Set up the censoring indicator array */

              do i=1 to dim(cens);
	             value_exp = left(put(cens[i],&&hLength..));  /* Ensure that value_exp is a left-aligned character variable */ 
	             wideName_exp=VNAME(cens[i]);  /* Get the column names for the censoring indicators */
	             output;
              end;
	      %end;
      %end;

   run;



   ** Remove missing covariates **;

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



   ** Confirm that the variables in exposureList, historyList, censorList, censWtList, and expWtList are also in rawVarList **;

      ** Compare raw data variable list to our exposure list **;

      %if &exposure. ne  AND &exposure. ne NULL %then %do;
          proc IML;
             %LET numExpNames = %sysfunc(countw(&&exposureList., ' '));  /* Count the total number of exposure names in our list */

	         %do i=1 %to &&numExpNames;  
                 %LET numVar&&i = %scan(&&exposureList.,&&i, ' ');  /* Grab the individual exposure names */
             %end;

	         %do i=1 %to &&numExpNames.;  /* Check if any individual exposure name is missing from the raw list */
                 %if NOT %eval(&&numVar&i in(&&rawVarList.)) %then %do;
                     %put ERROR: The exposure root name is misspelled, or some exposure measurements are missing from the input dataset, or incorrect measurement times have been specified;
                     %ABORT;
                 %end;
	         %end;
          quit;
	  %end;


	  ** Compare raw data variable list to our history list **;

	  %if &history. ne  AND &history. ne NULL %then %do;
          proc IML;
             %LET numHistNames = %sysfunc(countw(&&historyList., ' '));  /* Count the total number of history names in our list */

	         %do i=1 %to &&numHistNames;  
                 %LET numVar&&i = %scan(&&historyList.,&&i, ' ');  /* Grab the individual history names */
             %end;

	         %do i=1 %to &&numHistNames.;  /* Check if any individual history name is missing from the raw list */
                 %if (&history. ne  AND &history. ne NULL) AND (NOT %eval(&&numVar&i in(&&rawVarList.))) %then %do;
                     %put ERROR: Either the history root name is misspelled or some history measurements are missing from the input dataset.;
                     %ABORT;
                 %end;
	         %end;
          quit;
	  %end;


	  ** Compare raw data variable list to our censor list **;

	  %if &censor. ne  AND &censor. ne NULL %then %do;
          proc IML;
             %LET numCensNames = %sysfunc(countw(&&censorList., ' '));  /* Count the total number of censor names in our list */

	         %do i=1 %to &&numCensNames;  
                 %LET numVar&&i = %scan(&&censorList.,&&i, ' ');  /* Grab the individual censor names */
             %end;

	         %do i=1 %to &&numCensNames.;  /* Check if any individual censor name is missing from the raw list */
                 %if (&censor. ne  AND &censor. ne NULL) AND (NOT %eval(&&numVar&i in(&&rawVarList.))) %then %do;
                     %put ERROR: Either the censor root name is misspelled or some censor measurements are missing from the input dataset.;
                     %ABORT;
                 %end;
	         %end;
          quit;
	  %end;


	  ** Compare raw data variable list to our censor weight list **;

	  %if &weight_censor. ne  AND &weight_censor. ne NULL %then %do;
          proc IML;
             %LET numCWtNames = %sysfunc(countw(&&censWtList., ' '));  /* Count the total number of censor weight names in our list */
 
	         %do i=1 %to &&numCWtNames;  
                 %LET numVar&&i = %scan(&&censWtList.,&&i, ' ');  /* Grab the individual censor weight names */
             %end;

	         %do i=1 %to &&numCWtNames.;  /* Check if any individual censor weight name is missing from the raw list */
                 %if (&weight_censor. ne  AND &weight_censor. ne NULL) AND (NOT %eval(&&numVar&i in(&&rawVarList.))) %then %do;
                     %put ERROR: Either the weight_censor root name is misspelled or some weight_censor measurements are missing from the input dataset.;
                     %ABORT;
                 %end;
	         %end;
          quit;
	  %end;


	  ** Compare raw data variable list to our exposure weight list **;

	  %if &weight_exposure. ne  AND &weight_exposure. ne NULL %then %do;
          proc IML;
             %LET numEWtNames = %sysfunc(countw(&&expWtList., ' '));  /* Count the total number of exposure weight names in our list */

	         %do i=1 %to &&numEWtNames;  
                 %LET numVar&&i = %scan(&&expWtList.,&&i, ' ');  /* Grab the individual exposure weight names */
             %end;

	         %do i=1 %to &&numEWtNames.;  /* Check if any individual exposure weight name is missing from the raw list */
                 %if (&weight_exposure. ne  AND &weight_exposure. ne NULL) AND (NOT %eval(&&numVar&i in(&&rawVarList.))) %then %do;
                     %put ERROR: Either the weight_exposure root name is misspelled or some weight_exposure measurements are missing from the input dataset.;
                     %ABORT;
                 %end;
	         %end;
          quit;
	  %end;




   ** Compare raw data variable list to our covariate list to obtain WANTED list **;

   proc sort data=step2 out=step2sort;
      by &id.;
   run;

   proc transpose data=step2sort out=step2wide(drop=_NAME_);
      by &id.;
      id wideName_exp;
      var value_exp;
   run;


   proc IML;
      %LET numNames = %sysfunc(countw(&&rawVarList., ' '));  /* Count the total number of raw variable names */

	  %do i=1 %to &&numNames;  
          %LET numVar&&i = %scan(&&rawVarList.,&&i, ' ');  /* Grab the individual raw variable names */
      %end;

	  %do i=1 %to &&numNames.;  /* Check if each individual variable name is in both the raw list and our list */
		  
		 /* If there are no censoring weights */
		 %if &weight_censor. eq  OR &weight_censor. eq NULL %then %do;
		 
		   /* If only temporal covariates are present */
           %if &&temporal_covariate. ne  AND &&temporal_covariate. ne NULL AND (&&static_covariate. eq  OR &&static_covariate. eq NULL) %then %do;
              if %eval(&&numVar&i in(&&rawVarList.) AND &&numVar&i in(&&temporalCovList.)) then do;
                 wantCov&&i. = J(1,1,"&&numVar&i.");  /* Set up separate 1 x 1 matrices for each wanted covariate name */ 
                 column_names = "COL&&i.";  /* Create list of column names */

                 CREATE wanted_names_dataset&&i. FROM wantCov&&i. [COLNAME=column_names];  /* Create wanted names data sets */
                 APPEND FROM wantCov&&i.;
                 CLOSE wanted_names_dataset&&i.;
 	   	      end;
		   %end;

		   /* If only static covariates are present */
           %if (&&temporal_covariate. eq  OR &&temporal_covariate. eq NULL) AND &&static_covariate. ne  AND &&static_covariate. ne NULL %then %do;
              if %eval(&&numVar&i in(&&rawVarList.) AND &&numVar&i in(&&staticCovList.)) then do;
                 wantCov&&i. = J(1,1,"&&numVar&i.");  /* Set up separate 1 x 1 matrices for each wanted covariate name */ 
                 column_names = "COL&&i.";  /* Create list of column names */

                 CREATE wanted_names_dataset&&i. FROM wantCov&&i. [COLNAME=column_names];  /* Create wanted names data sets */
                 APPEND FROM wantCov&&i.;
                 CLOSE wanted_names_dataset&&i.;
 	   	      end;
		   %end;

		   /* If both temporal and static covariates are present */
	       %if &&temporal_covariate. ne  AND &&temporal_covariate. ne NULL AND &&static_covariate. ne  AND &&static_covariate. ne NULL %then %do;
              if %eval(&&numVar&i in(&&rawVarList.) AND &&numVar&i in(&&temporalCovList. &&staticCovList.)) then do;
                 wantCov&&i. = J(1,1,"&&numVar&i.");  /* Set up separate 1 x 1 matrices for each wanted covariate name */ 
                 column_names = "COL&&i.";  /* Create list of column names */

                 CREATE wanted_names_dataset&&i. FROM wantCov&&i. [COLNAME=column_names];  /* Create wanted names data sets */
                 APPEND FROM wantCov&&i.;
                 CLOSE wanted_names_dataset&&i.;
 	   	      end;
		  %end;
		  
	    %end;
		
		
		/* If censoring weights are present */
		%if &weight_censor. ne  AND &weight_censor. ne NULL %then %do;
		 
		   /* If only temporal covariates are present */
           %if &&temporal_covariate. ne  AND &&temporal_covariate. ne NULL AND (&&static_covariate. eq  OR &&static_covariate. eq NULL) %then %do;
              if %eval(&&numVar&i in(&&rawVarList.) AND &&numVar&i in(&&temporalCovList. &&censWtList.)) then do;
                 wantCov&&i. = J(1,1,"&&numVar&i.");  /* Set up separate 1 x 1 matrices for each wanted covariate name and censoring weight name */ 
                 column_names = "COL&&i.";  /* Create list of column names */

                 CREATE wanted_names_dataset&&i. FROM wantCov&&i. [COLNAME=column_names];  /* Create wanted names data sets */
                 APPEND FROM wantCov&&i.;
                 CLOSE wanted_names_dataset&&i.;
 	   	      end;
		   %end;

		   /* If only static covariates are present */
           %if (&&temporal_covariate. eq  OR &&temporal_covariate. eq NULL) AND &&static_covariate. ne  AND &&static_covariate. ne NULL %then %do;
              if %eval(&&numVar&i in(&&rawVarList.) AND &&numVar&i in(&&staticCovList. &&censWtList.)) then do;
                 wantCov&&i. = J(1,1,"&&numVar&i.");  /* Set up separate 1 x 1 matrices for each wanted covariate name and censoring weight name */ 
                 column_names = "COL&&i.";  /* Create list of column names */

                 CREATE wanted_names_dataset&&i. FROM wantCov&&i. [COLNAME=column_names];  /* Create wanted names data sets */
                 APPEND FROM wantCov&&i.;
                 CLOSE wanted_names_dataset&&i.;
 	   	      end;
		   %end;

		   /* If both temporal and static covariates are present */
	       %if &&temporal_covariate. ne  AND &&temporal_covariate. ne NULL AND &&static_covariate. ne  AND &&static_covariate. ne NULL %then %do;
              if %eval(&&numVar&i in(&&rawVarList.) AND &&numVar&i in(&&temporalCovList. &&staticCovList. &&censWtList.)) then do;
                 wantCov&&i. = J(1,1,"&&numVar&i.");  /* Set up separate 1 x 1 matrices for each wanted covariate name and censoring weight name */ 
                 column_names = "COL&&i.";  /* Create list of column names */

                 CREATE wanted_names_dataset&&i. FROM wantCov&&i. [COLNAME=column_names];  /* Create wanted names data sets */
                 APPEND FROM wantCov&&i.;
                 CLOSE wanted_names_dataset&&i.;
 	   	      end;
		   %end;
		  
	    %end;
		
	 %end;
  quit;


  ** Merge the wanted covariate names datasets together **;

   data wanted_covariates;
      merge wanted_names_dataset:;
   run;


   ** Create list of wanted covariate names **;

   data _NULL_;
      set wanted_covariates;
	  length wantedCovNames $7500.;

      wantedCovNames=CATX(" ",OF COL:);

	  %LOCAL wantedCovList;
	  CALL SYMPUT ('wantedCovList',wantedCovNames);  /* Create macro variable for list of wanted covariate names */
   run;



   ** Issue a warning if the exposure and/or covariates contain missing data **;

   ** For missing exposures **;

   data _NULL_;
      set &input;

	  %LET numExp = %sysfunc(countw(&&exposureList., ' '));  /* Count the total number of exposure names */

	  %do i=1 %to &&numExp;  
          %LET numVar&&i = %scan(&&exposureList.,&&i, ' ');  /* Grab the individual exposure names */
      %end;

	  %do i=1 %to &&numExp.;  /* Check if any of the exposures contain missing values */
          proc sql noprint;
	         create table expMissCheck&&i. as
             select nmiss(&&numVar&i.) as nmissExp&&i.  /* Count the number of missing exposure values */
             from &input.;
          quit;
	  %end;
   run;


   ** Merge the expMissCheck datasets together **;

   data expMissCheckAll;
      merge expMissCheck:;
   run;

   ** Calculate the sum of the nmissExp columns **;

   data expMissCheckSum;
      set expMissCheckAll;
	  expMissTotal = sum(of nmissExp:);
   run;

   ** Issue warning if expMissTotal > 0 **;

   data _NULL_;
      set expMissCheckSum;

	  if expMissTotal > 0 then do;
	     PUTLOG "WARNING: The exposure and/or some covariates contain missing data. Subsequent calculations are not guaranteed to be unbiased in the presence of partially missing data.";
      end;
   run;



   ** For missing covariates **;

   data _NULL_;
      set &input;

	  %LET numCov = %sysfunc(countw(&&wantedCovList., ' '));  /* Count the total number of covariate names */

	  %do i=1 %to &&numExp;  
          %LET numVar&&i = %scan(&&exposureList.,&&i, ' ');  /* Grab the individual covariate names */
      %end;

	  %do i=1 %to &&numCov.;  /* Check if any of the covariates contain missing values */
          proc sql noprint;
	         create table covMissCheck&&i. as
             select nmiss(&&numVar&i.) as nmissCov&&i.  /* Count the number of missing covariate values */
             from &input.;
          quit;
	  %end;
   run;


  ** Merge the covMissCheck datasets together **;

   data covMissCheckAll;
      merge covMissCheck:;
   run;

   ** Calculate the sum of the nmissCov columns **;

   data covMissCheckSum;
      set covMissCheckAll;
	  covMissTotal = sum(of nmissCov:);
   run;

   ** Issue warning if covMissTotal > 0 **;

   data _NULL_;
      set covMissCheckSum;

	  if covMissTotal > 0 then do;
	     PUTLOG "WARNING: The exposure and/or some covariates contain missing data. Subsequent calculations are not guaranteed to be unbiased in the presence of partially missing data.";
      end;
   run;




   ** STEP 3 **;

   ** Separate variable names into ROOT and TIME variables **;

   data step3(keep=&id. name_exp time_exposure value_exp);
      retain &id. name_exp time_exposure value_exp;  /* Retain proper order of variables */
      set step2;

	  name_exp=scan(wideName_exp,1,'_');  /* Extract characters before underscore and set equal to "name" */
	  time_exposure=scan(wideName_exp,-1,'_');  /* Extract digits after underscore and set equal to "time" */
   run;
	  
   
   ** Widen the data set with respect to time **;

   proc sort data=step3 out=step3sort;
      by &id. time_exposure;
   run;

   proc transpose data=step3sort out=step3wide(drop=_NAME_);
      by &id. time_exposure;
      id name_exp;
      var value_exp;
   run;


   ** Merge the step3wide data set back with the censor weights and the wanted covariates **;

   data step3full;
      merge step3wide &input.(keep=&id. &&wantedCovList.);  /* Include wanted covariates plus censor weights (if present) */
      by &id.;
   run;





** STEP 4 **;

** Transform the step3full data set with respect to the covariates **;
** and the censor weights, yielding an even longer data set        **;

   data step4(keep=&id. time_exposure &&exposure &&history_ &&weight_exposure_ &&strata_ &&censor_ wideName_cov value_cov);
      retain &id. time_exposure &&exposure &&history_ &&weight_exposure_ &&strata_ &&censor_ wideName_cov value_cov;  /* Retain proper order of variables */
      set step3full;

      %LET totCov = %sysfunc(countw(&&wantedCovList., ' '));  /* Count the total number of wanted covariates and censor weights */

	  array cov[&&totCov.] &&wantedCovList.;  /* Set up the full covariate and censor weight array */

	  do i=1 to dim(cov);                                                 
	     value_cov = cov[i]; 
	     wideName_cov=VNAME(cov[i]);  /* Get the column names for the covariates */
         output; 
      end;   

   run;




   ** Sort the step4data by wideName_cov **;

   proc sort data=step4 out=step4sort;
      by &id. wideName_cov;
   run;



   ** Separate covariate names into ROOT and TIME variables **;

   data step4split(keep=&id. time_exposure &&exposure &&history_ &&weight_exposure_ &&strata_ &&censor_ name_cov time_covariate value_cov);
      retain &id. time_exposure &&exposure &&history_ &&weight_exposure_ &&strata_ &&censor_ name_cov time_covariate value_cov;  /* Retain proper order of variables */
      set step4sort;

	  name_cov=scan(wideName_cov,1,'_');  /* Extract characters before underscore and set equal to "name" */
	  time_covariate=scan(wideName_cov,-1,'_');  /* Extract digits after underscore and set equal to "time" */
   run;


   ** Create separate data sets for covariates and censor weights **;

   data longCov;  /* Covariate data */
      set step4split;
	  if name_cov eq "&&weight_censor." then delete;
   run;

   data longCensWt;  /* Censor weight data */
      set step4split;
	  if name_cov ne "&&weight_censor." then delete;
   run;



   ** Widen the longCensWt data set to line up the censoring weights with the covariate times **;

   proc sort data=longCensWt out=longCensWtSort;
      by &id. time_exposure &&exposure &&history_ &&weight_exposure_ &&strata_ &&censor_ time_covariate;
   run;

   proc transpose data=longCensWtSort out=censWtWide(drop=_NAME_);
      by &id. time_exposure &&exposure &&history_ &&weight_exposure_ &&strata_ &&censor_ time_covariate;
      id name_cov;
      var value_cov;
   run;



   ** Merge the censWtWide data set back with the longCov data set **;

   proc sort data=censWtWide out=censWideSort;
      by &id. time_covariate time_exposure;
   run;

   proc sort data=longCov;
      by &id. time_covariate time_exposure;
   run;

   data step4full;
      retain &id. time_exposure &&exposure &&history_ &&weight_exposure_ &&weight_censor_ &&strata_ &&censor_ name_cov time_covariate value_cov;
      merge censWideSort longCov;
	  by &id. time_covariate time_exposure /*&&exposure &&history &&weight_exposure &&strata &&censor*/;
   run;


   ** Sort the step4full data set **;

   proc sort data=step4full out=step4out;
      by &id. name_cov time_covariate time_exposure;
   run;

   

   ** Step 5 **;

   ** Retain only the uncensored observations, and omit records with missing data **;

   data step5;
      set step4out;

	  %if &&censor_ ne  %then %do;
	     if strip(&&censor_.) eq '1' then delete;  /* Remove censored observations */
	  %end;

	  if missing(&id.) OR missing(time_exposure) OR missing(&&exposure) OR missing(name_cov) OR 
         missing(time_covariate) OR missing(value_cov) then delete;  /* Remove records with missing data */

	  if &id. eq '.' OR time_exposure eq '.' OR &&exposure eq '.' OR name_cov eq '.' OR 
         time_covariate eq '.' then delete;
		 
	  %if &&history_ ne  %then %do;
          if missing(&&history_) then delete;  /* Remove records with missing history, if applicable */
		  if &&history_ eq '.' then delete;
	  %end;

	  %if &&weight_exposure_ ne  %then %do;
          if missing(&&weight_exposure_) then delete;  /* Remove records with missing exposure weights, if applicable */
		  if &&weight_exposure_ eq '.' then delete;
	  %end;

	  %if &&weight_censor_ ne  %then %do;
          if missing(&&weight_censor_) then delete;  /* Remove records with missing censor weights, if applicable */
		  if &&weight_censor_ eq '.' then delete;
	  %end;
	 
	  %if &&strata_ ne  %then %do;
         if missing(&&strata_) then delete;  /* Remove records with missing strata, if applicable */
		 if &&strata_ eq '.' then delete;
	  %end;

	   %if &&censor_ ne  %then %do;
         if missing(&&censor_) then delete;  /* Remove records with missing censor indicators, if applicable */
		 if &&censor_ eq "." then delete;
	  %end;

	  
	run;


	** Check to see if any covariates are completely missing **;

	** First grab the unique covariates in the "name_cov" variable **;

    proc sql noprint;
       create table check_name_cov as
       select distinct(name_cov) as unique_name_cov
       from step5
    quit;

    proc sort data=check_name_cov out=check_name_cov_sort;
       by unique_name_cov;
    run;

    data check_name_cov2;
       set check_name_cov_sort;
    run;

    proc transpose data=check_name_cov2 out=check_name_cov_wide(drop=_NAME_);
       var unique_name_cov;
    run;

	** Create macro variable for list of covariates in "name_cov" **;

    data _NULL_;
	   set check_name_cov_wide;
	   length covNames $7500.;

       covNames=CATX(" ",OF COL:);

	   %LOCAL finalCovList;
       CALL SYMPUT ('finalCovList',covNames); 
    run;


	** Create another macro variable for list of temporal and/or static covariates inputted into lengthen **;

	/* If only temporal covariates are present */
	%if &static_covariate. eq  OR &static_covariate. eq NULL %then %do;
        %LET inputCovList = %sysfunc(CATX(%str(),&temporal_covariate));
	%end;

	/* If only static covariates are present */
	%if &temporal_covariate. eq  OR &temporal_covariate. eq NULL %then %do;
        %LET inputCovList = %sysfunc(CATX(%str(),&static_covariate));
	%end;

	/* If both temporal and static covariates are present */
	%if &temporal_covariate. ne  AND &temporal_covariate. ne NULL AND &static_covariate. ne  AND &static_covariate. ne NULL %then %do;
        %LET inputCovList = %sysfunc(CATX(%str( ), &temporal_covariate., &static_covariate.));
	%end;





    ** Compare the unique covariate names with those listed in &&inputCovList**;

    proc IML;
       %LET numNameCov = %sysfunc(countw(&&inputCovList., ' '));  /* Count the total number of inputted covariates */

	   %do i=1 %to &&numNameCov.;  
           %LET numVar&&i = %scan(&&inputCovList.,&&i, ' ');  /* Grab the individual covariate names */
       %end;

	   %do i=1 %to &&numNameCov.;  /* Check if any individual covariate name is missing from &&finalCovList */
           %if NOT %eval(&&numVar&i in(&&finalCovList.)) %then %do;
               %put WARNING: Some covariates listed in temporal_covariate and/or static_covariate have missing values at all timepoints. These covariates will not be included in the balance table or plot.;
           %end;
       %end;
    quit;
    
    
    
    ** STEP 6: Subset to observations with time_covariate > time_exposure **;

    data step6a;
       set step5;
       time_exposure_num = input(time_exposure, 8.);
       time_covariate_num = input(time_covariate, 8.);
    run;
       
    data step6b;
       set step6a;
       if time_covariate_num>time_exposure_num;  /* Use numeric times for this step */ 
    run;
    
    
    
    ** STEP 7: Sort the STEP6b data set by name_cov, &id., time_exposure_num, time_covariate_num, &&history_ **;

    proc sort data=step6b out=step6c;
       by name_cov &id. time_exposure_num time_covariate_num &&history_;
    run;
    
    data step7;
       set step6c(drop=time_exposure_num time_covariate_num);
    run;
    
    



	** Rename the STEP7 data set to match the user-defined or default name, as appropriate **;

    %if &output. ne  AND &output. ne NULL %then %do;
        data &output.;  /* Label the output data set with the user-defined name */
           retain &id. &&history_ name_cov time_exposure time_covariate value_cov;  /* Retain variables in proper order */
           set step7;
        run;
    %end;

    %else %do;
        data &input._long;  /* Label the output data set with the default name */
           retain &id. &&history_ name_cov time_exposure time_covariate value_cov;  /* Retain variables in proper order */
           set step7;
        run;
    %end;



    ** Remove all intermediate data sets from the WORK library **;

       %if &output. ne  AND &output. ne NULL %then %do;
            proc datasets library=work nolist;
	           save &input. &output. &&save. step4out step5 step6a step6b step6c step6ctest step6ctest2 step7;
	        run;
	        quit;
        %end;

        %else %do;
            proc datasets library=work nolist;
	           save &input. &input._long &&save.;
	        run;
	        quit;
        %end; 


%end;



%mend lengthen;  /* End the lengthen macro */




** End of Program **;
