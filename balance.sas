/* Erin Schnellinger */
/* Covariate Balance Project */

/* "Balance" Macro */

/* Balance successfully passed testBalanceWOApplyScope and */
/* testBalanceWApplyScope tests on 30 July 2019 */

** Start the balance macro **;

%macro balance(input, output, diagnostic, approach, censoring, scope, times_exposure, times_covariate, exposure, 
               sort_order=alphabetical, loop=no, ignore_missing_metric=no, metric=SMD, sd_ref=no, history=NULL, weight_exposure=NULL, 
               weight_censor=NULL, strata=NULL, recency=NULL, average_over=NULL, periods=NULL, list_distance=NULL);

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
       %put ERROR: 'input' is missing. Please specify the dataset created by the lengthen() macro;
	   %ABORT;
   %end;


   %if &output. eq  OR &output. eq NULL %then %do;   /* &output is missing */
       %put NOTE: 'output' dataset name is missing. By default, the name of the output datset will be identical to that of the input dataset, with the suffix '_balance_table' appended to it;
   %end;


   %if &diagnostic. eq  OR &diagnostic. eq NULL %then %do;   /* &diagnostic is missing */
       %put ERROR: 'diagnostic' is missing or misspecified. Please specify as 1, 2, or 3;
	   %ABORT;
   %end;

   %if &diagnostic. ne  AND &diagnostic. ne NULL AND NOT %eval(&diagnostic. in(1 2 3)) %then %do;   /* &diagnostic is misspecified */
       %put ERROR: 'diagnostic' is missing or misspecified. Please specify as 1, 2, or 3;
	   %ABORT;
   %end;



   %if &approach. eq  OR &approach. eq NULL %then %do;   /* &approach is missing */
       %put ERROR: 'approach' is missing or misspecified. Please specify as none, weight, or stratify;
	   %ABORT;
   %end;

   %if &approach. ne  AND &approach. ne NULL AND NOT %eval(&approach. in(none weight stratify)) %then %do;   /* &approach is misspecified */
       %put ERROR: 'approach' is missing or misspecified. Please specify as none, weight, or stratify;
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



   %if &scope. eq  OR &scope. eq NULL %then %do;   /* &scope is missing */
       %put ERROR: 'scope' is missing. Please specify either all, recent, or average;
	   %ABORT;
   %end;

   %if &scope. ne  AND &scope. ne NULL AND NOT %eval(&scope. in(all recent average)) %then %do;   /* &scope is misspecified */
       %put ERROR: 'scope' is missing. Please specify either all, recent, or average;
	   %ABORT;
   %end;


   ** Ensure that the &periods argument is specified correctly **;

   /* First check for erroneous dashes in &periods (do this before checking for null 
      values to avoid SAS prematurely terminating due to 'unexpected character') */

   %if %sysfunc(findc(&periods., '-')) ge 1 %then %do;  /* Search for dash */ 
       %put ERROR: When specifying 'periods', the list must only contain numeric or integer values, separated by spaces (e.g. 0 2:3 5:9);
	   %ABORT;
   %end;

   /* Now, check if &periods is null. If not, search for non-numeric elements and non-allowed separators */
   %if &periods. ne  AND &periods. ne NULL %then %do; 
       %if %sysfunc(findc(&periods., ':', 'DSK')) ge 1 %then %do;  /* Search for non-numeric elements and non-allowed separators */ 
           %put ERROR: When specifying 'periods', the list must only contain numeric or integer values, separated by spaces (e.g. 0 2:3 5:9);
	       %ABORT;
       %end;
   %end;


   /* Ensure that values entered are unique */
   /* Code adapted from http://stackoverflow.com/questions/35367159/count-number-of-times-a-word-appears */

   %if &periods. ne  AND &periods. ne NULL %then %do; 
       %LET periodListLength = %eval(%length(&periods.));  /* Get length of &periods argument */
	   %LET periodbuflist = %sysfunc(translate(&periods., ' ', ':'));  /* Replace colon with blank */

	   proc IML;
            %LET numPeriodNames = %sysfunc(countw(&&periodbuflist., ' '));  /* Count the total number of period values */

	        %do i=1 %to &&numPeriodNames;  
                %LET numPer&&i = %scan(&&periodbuflist.,&&i, ' ');  /* Grab the individual period names */
            %end;

	        %do i=1 %to &&numPeriodNames.;  /* Check if any individual period name appears more than once in the list */
                data _null_;
                   length sentence search_term $&&periodListLength.;
                   sentence = "&&periodbuflist.";
                   search_term = "&&numPer&i.";

                   cnt=0;  /* Initialize counter variable to track number of times period value appears */
                   do s=findw(sentence,strip(search_term),1) by 0 while(s);
                      cnt+1;  
                      s=findw(sentence,strip(search_term),s+1);
                   end;
                   put cnt= search_term=;
				   call symput('cnt',cnt);
                   stop;
				run;

				%if &&cnt. > 1 %then %do;  /* Period value appears more than once */
                    %put ERROR: When specifying 'periods', the values should be unique (e.g. 0 2:3 5:9);
                    %ABORT;
			    %end;
	        %end;
        quit;
	%end;




   /* Ensure that values are entered in sorted order */

   %if &periods. ne  AND &periods. ne NULL %then %do; 
       %LET periodListLength = %eval(%length(&periods.));  /* Get length of &periods argument */
	   %LET periodbuflist = %sysfunc(translate(&periods., ' ', ':'));  /* Replace colon with blank */

       proc IML;
            %LET numPeriodNames = %sysfunc(countw(&&periodbuflist., ' '));  /* Count the total number of period values */

	        %do i=1 %to &&numPeriodNames;  
                %LET numPer&&i = %scan(&&periodbuflist.,&&i, ' ');  /* Grab the individual period names */
            %end;

	        %do i=2 %to &&numPeriodNames.;  /* Check if subsequent period value is smaller than current value */
			    %LET j = %eval(&&i.-1);
                %if %eval(&&numPer&i < &&numPer&j) %then %do;
                    %put ERROR: When specifying 'periods', the values must be in sorted order (e.g. 0 2:3 5:9);
                    %ABORT;
			    %end;
	        %end;
        quit;
   %end;


   /* Constrain period values to times that appear in the data */

   %if &periods. ne  AND &periods. ne NULL %then %do; 
       %LET periodListLength = %eval(%length(&periods.));  /* Get length of &periods argument */
	   %LET periodbuflist = %sysfunc(translate(&periods., ' ', ':'));  /* Replace colon with blank */


       proc IML;
            %LET numPeriodNames = %sysfunc(countw(&&periodbuflist., ' '));  /* Count the total number of period values */

	        %do i=1 %to &&numPeriodNames;  
                %LET numPer&&i = %scan(&&periodbuflist.,&&i, ' ');  /* Grab the individual period names */
            %end;


	        %do i=1 %to &&numPeriodNames.;  /* Check if any individual period name appears in the times_exposure or times_covariate lists */
                %if NOT %eval(&&numPer&i in(&times_exposure.)) AND NOT %eval(&&numPer&i in(&times_covariate.)) %then %do;
                    %put ERROR: 'period' values should be constrained to times that appear in the data.;
                    %ABORT;
			    %end;
	        %end;
        quit;
   %end;

   
   
   ** Confirm that the exposure, history, strata, weight_exposure, and weight_strata variables are also present in the input data set **;

   ** First generate list of variables in raw data set **;

   proc contents data=&input. out=rawVar(keep=VARNUM NAME) varnum noprint;
   run;

   proc sort data=rawVar out=rawVarSort;
      by varnum;
   run;

   data rawVar2;
      set rawVarSort;
   run;

   proc transpose data=rawVar2 out=rawVarWide(drop=_NAME_ _LABEL_);
	  id varnum; 
	  var NAME;
   run;


   ** Create macro variable for list of variables in raw data set **;

   data _NULL_;
	  set rawVarWide;

      rawVarNames=CATX(" ",OF _:);

	  %LOCAL rawVarList;
	  CALL SYMPUT ('rawVarList',rawVarNames);  /* Create macro variable for list of variables in raw data set */
   run;


   ** Compare raw data variable list to the appropriate prefix **;

   %if &exposure. eq  OR &exposure. eq NULL %then %do;  /* &exposure is missing */
       %put ERROR: Either 'exposure' has not been specified OR the exposure root name is not present in the input dataset;
       %ABORT;
   %end;

   %if (&exposure. ne  AND &exposure. ne NULL) AND NOT %eval(&exposure. in(&&rawVarList.)) %then %do;  /* &exposure is not present in the input data set */
       %put ERROR: Either 'exposure' has not been specified OR the exposure root name is not present in the input dataset;
       %ABORT;
   %end;



   %if (&history. ne  AND &history. ne NULL) %then %do;
       %if NOT %eval(&history. in(&&rawVarList.)) %then %do;  /* &history is not present in the input data set */
           %put ERROR: the specified root name for 'history' is not present in the input dataset;
           %ABORT;
	   %end;
   %end;



   %if (&strata. ne  AND &strata. ne NULL) %then %do;
       %if NOT %eval(&strata. in(&&rawVarList.)) %then %do;  /* &strata is not present in the input data set */
           %put ERROR: the specified root name for 'strata' is not present in the input dataset;
           %ABORT;
	   %end;
   %end;


   %if (&weight_exposure. ne  AND &weight_exposure. ne NULL) %then %do;
       %if NOT %eval(&weight_exposure. in(&&rawVarList.)) %then %do;  /* &weight_exposure is not present in the input data set */
           %put ERROR: the specified root name for 'weight_exposure' is not present in the input dataset;
           %ABORT;
	   %end;
   %end;


   %if (&weight_censor. ne  AND &weight_censor. ne NULL) %then %do; 
       %if NOT %eval(&weight_censor. in(&&rawVarList.)) %then %do;  /* &weight_censor is not present in the input data set */
           %put ERROR: the specified root name for 'weight_censor' is not present in the input dataset;
           %ABORT;
	   %end;
   %end;



   %if &times_exposure. eq  OR &times_exposure. eq NULL %then %do;   /* &times_exposure is missing */
       %put ERROR: 'times_exposure' is missing. Please specify an integer for times_exposure or a numeric vector of times;
	   %ABORT;
   %end;


   %if &times_covariate. eq  OR &times_covariate. eq NULL %then %do;   /* &times_covariate is missing */
       %put ERROR: 'times_covariate' is missing. Please specify an integer for times_covariate or a numeric vector of times;
	   %ABORT;
   %end;



   %if &scope. eq recent AND (&recency. eq  OR &recency. eq NULL) %then %do;   /* &recency is missing */
       %put ERROR: 'recency' is missing. Please specify an integer between 0 and t for diagnostics 1 and 3, or 0 and t-1 for diagnostic 2;
	   %ABORT;
   %end;


   %if &scope. eq average AND (&average_over. eq  OR &average_over. eq NULL) %then %do;   /* &average_over is missing */
       %put ERROR: 'average_over' is missing. Please specify one of the following: values, strata, history, time, distance;
	   %ABORT;
   %end;


   %if &diagnostic. ne 1 AND &approach. eq none %then %do;  /* Diagnostic 2 or 3, but &approach is not specified */ 
       %put ERROR: 'diagnostic' has been specified as 2 or 3, and to implement the choice properly, approach needs to be specified as weight or stratify.;
	   %ABORT;
   %end;

   
   %if (&diagnostic. eq 1 AND (&history. eq  OR &history. eq NULL)) %then %do;   /* &diagnostic is 1, but &history is missing */
       %put ERROR: For diagnostic 1, please specify the root names for exposure history;
	   %ABORT;
   %end;

   %else %if (&diagnostic. eq 2 AND &approach. eq weight AND  /* Diagnostic 2, &approach=weight, but &history or &weight_exposure are missing */ 
       (&history. eq  OR &history. eq NULL OR &weight_exposure. eq  OR &weight_exposure. eq NULL) ) %then %do;   
       %put ERROR: For diagnostic 2 under weighting, please specify the root names for exposure history and exposure weights;
	   %ABORT;
   %end;
   
   %else %if (&diagnostic. eq 2 AND &approach. eq stratify AND  /* Diagnostic 2, &approach=stratify, but &strata is missing */ 
       (&strata. eq  OR &strata. eq NULL) ) %then %do;   
       %put ERROR: For diagnostic 2 under stratification, please specify the root names for strata;
	   %ABORT;
   %end;
   
   %else %if (&diagnostic. eq 3 AND &approach. eq weight AND  /* Diagnostic 3, &approach=weight, but &history or &weight_exposure are missing */ 
       (&history. eq  OR &history. eq NULL OR &weight_exposure. eq  OR &weight_exposure. eq NULL) ) %then %do;   
       %put ERROR: For diagnostic 3 under weighting, please specify the root names for exposure history and exposure weights;
	   %ABORT;
   %end;

   %else %if (&diagnostic. eq 3 AND &approach. eq stratify AND   /* Diagnostic 3, &approach=stratify, but &history or &strata are missing */ 
       (&history. eq  OR &history. eq NULL OR &strata. eq  OR &strata. eq NULL) ) %then %do;   
       %put ERROR: For diagnostic 3 under stratification, please specify the root names for exposure history and strata;
	   %ABORT;
   %end;



   %if &sort_order. eq  OR &sort_order. eq NULL %then %do;  /* &sort_order is missing */ 
	   %if &sort_order. ne alphabetical %then %do;
           %put ERROR: either specify sort_order as alphabetical or as a character vector of covariates;
	       %ABORT;
	   %end;
   %end;

   %if &sort_order. ne  AND &sort_order. ne NULL %then %do;  
       %LET numSO = %sysfunc(countw(&sort_order.,' '));  /* Get the length of &sort_order */
   
	   %if &&numSO eq 1 AND &sort_order. ne alphabetical %then %do;   /* Length of &sort_order equals 1 */ 
           %put ERROR: either specify sort_order as alphabetical or as a character vector of covariates;
	       %ABORT;
	   %end;
   %end;


   ** Grab the unique covariates in the "name_cov" variable **;

   %if &sort_order. ne  AND &sort_order. ne NULL AND &&numSO > 1 %then %do;

       proc sql noprint;
	      create table check_name_cov as
          select distinct(name_cov) as unique_name_cov
          from &input.
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

          covNames=CATX(" ",OF COL:);

	      %LOCAL checkCovList;
	      CALL SYMPUT ('checkCovList',covNames); 
       run;


       ** Compare the unique covariate names with those listed in &sort_order **;

       proc IML;
          %LET numNameCov = %sysfunc(countw(&&checkCovList., ' '));  /* Count the total number of unique covariates in the "name_cov" variable */

	      %do i=1 %to &&numNameCov.;  
              %LET numVar&&i = %scan(&&checkCovList.,&&i, ' ');  /* Grab the individual covariate names */
          %end;

	      %do i=1 %to &&numNameCov.;  /* Check if any individual covariate name is missing from &sort_order */
              %if NOT %eval(&&numVar&i in(&sort_order.)) %then %do;
                  %put ERROR: when specifying the character vector for sort_order, include all covariate names in the input dataset, and also ensure that their spelling match those specified in sort_order. Provided these criteria are met, the software will still run even if sort_order includes extraneous covariate names that are NOT present in the input dataset;
                  %ABORT;
              %end;
	      %end;
      quit;
  %end;



   ** Replace null optional variables with placeholder values **;

   data &input.;
      set &input.;
 
	  %if &history. eq  OR &history. eq NULL %then %do;
		  history_none = H;  /* Use 'H' as a placeholder value for history */
		  %LET history_ = history_none;  /* Create a macro variable for the placeholder value */
      %end;
 
	  %else %do;
          %LET history_ = &history.;
	  %end;

	  
	  %if &strata. eq  OR &strata. eq NULL %then %do;
          strata_none = 1;  /* Use '1' as a placeholder value for strata */
		  %LET strata_ = strata_none;  /* Create a macro variable for the placeholder value */
	  %end;

	  %else %do;
          %LET strata_ = &strata.;
	  %end;


	  %if &weight_exposure. eq  OR &weight_exposure. eq NULL %then %do;
          weight_exposure_none = 1;  /* Use '1' as a placeholder value for exposure weight */
		  %LET weight_exposure_ = weight_exposure_none;  /* Create a macro variable for the placeholder value */
	  %end;

	  %else %do;
          %LET weight_exposure_ = &weight_exposure.;
	  %end;


	  %if &weight_censor. eq  OR &weight_censor. eq NULL %then %do;
		  weight_censor_none = 1;  /* Use '1' as a placeholder value for censor weight */
		  %LET weight_censor_ = weight_censor_none;  /* Create a macro variable for the placeholder value */
      %end;
 
	  %else %do;
          %LET weight_censor_ = &weight_censor.;
	  %end;

   run;
   
   
   ** Convert time_exposure and time_covariate into numeric format **;

   data &input.;
      set &input.;
      time_exposure_num = input(time_exposure,8.);
      time_covariate_num = input(time_covariate,8.);
   run;
   
   data &input.(rename=(time_exposure_num=time_exposure time_covariate_num=time_covariate));
      set &input.(drop=time_exposure time_covariate);
   run;



*---------------------------*;
* For Diagnostic 1          *;
*---------------------------*;

%if &diagnostic. eq 1 AND (&approach. eq weight OR &approach. eq none) %then %do;

    ** Keep the exposure value, exposure time, covariate value, covariate time, and history variables **;

    data d1(drop=&&weight_exposure_. &&weight_censor_. &&strata_.);
	   set &input.;
	   W = 1;  /* Set the total weight equal to one */
	run;

	** Sort the data by covariate name, exposure time, covariate time, history, and exposure **;

	proc sort data=d1 out=d1sort;
	   by name_cov time_exposure time_covariate &&history_. &exposure.;
	run;


	** Calculate the mean covariate value at time t-k given exposure value at time t and history at time t-1 **;

	proc means data=d1sort MEAN STD noprint;
	   where (time_exposure in(&times_exposure.)) AND (time_covariate in(&times_covariate.));  /* Subset the data to include only the exposure and covariate times specified by the user */
	   class name_cov time_exposure time_covariate &&history_. &exposure.;
	   var value_cov;
	   weight W;
	   output out=d1_Btemp MEAN=mean_cov_b STD=sd_cov_b;
	run;



	** Check for exposure variation **;

	proc sort data=d1_Btemp out=check_table;
	   by &&history_. time_exposure;  /* Sort the data by history and exposure time */
	run;

    proc sql noprint;
	   create table check_table2 as
       select count(distinct(&exposure.)) as nexpval  /* Count the number of unique exposure values */
       from check_table
	   group by &&history_., time_exposure;
    quit;

	proc sql noprint;
	   create table check_table3 as
       select nexpval, count(distinct(nexpval)) as nexpval_all  /* Count the number of unique nexpvals to determine if there is no exposure variation whatsoever */
       from check_table2;
    quit;


	** Issue a warning if there is no exposure variation **;

	data _NULL_;
	   set check_table3;

	   if nexpval eq 1 AND nexpval_all ne 1 then do;  /* Some exposure times have no exposure variation */
	      PUTLOG 'WARNING: Some exposure times have no exposure variation within levels of exposure history. Estimates for these times will not appear in the results.';
       end;

	   if nexpval eq 1 AND nexpval_all eq 1 then do;  /* ALL exposure times have no exposure variation */
	      PUTLOG 'ERROR: None of the exposure times have exposure variation within levels of exposure history. The program has terminated because the resulting balance table is empty.';
		  ABORT;
       end;
	run;


	** Calculate the sum of the weights **;

	proc means data=d1sort SUM noprint;
	   where (time_exposure in(&times_exposure.)) AND (time_covariate in(&times_covariate.));  /* Subset the data to include only the exposure and covariate times specified by the user */
	   class name_cov time_exposure time_covariate &&history_. &exposure.;
	   var W;
	   output out=d1_Btemp2 SUM=n_cov_b;
	run;


	** Merge the two temp data sets together **;

	proc sort data=d1_Btemp;
	   by name_cov time_exposure time_covariate &&history_. &exposure. _TYPE_ _FREQ_;
	run;

	proc sort data=d1_Btemp2;
	   by name_cov time_exposure time_covariate &&history_. &exposure. _TYPE_ _FREQ_;
	run;

	data d1_Btemp3;
	   merge d1_Btemp d1_Btemp2;
	   by name_cov time_exposure time_covariate &&history_. &exposure. _TYPE_ _FREQ_;
    run; 
	

	
	** Remove missing observations that were created by PROC MEANS from the output data set **;
	
	data d1_B(drop=_TYPE_ _FREQ_);
	   set d1_Btemp3;

       if missing(name_cov) OR missing(time_exposure) OR missing(time_covariate) OR  
          missing(&&history_.) OR missing(&exposure.) then delete;
	run;



	** Select the first exposure observation within each level of history **;

	proc sort data=d1_B;
	   by name_cov time_exposure time_covariate &&history_. &exposure.;
	run;

	data first_exp;
	   set d1_B;
	   by name_cov time_exposure time_covariate &&history_. &exposure.;

	   if not first.&&history_. then delete;  
	run;



	** Generate mean_cov_a, sd_cov_a, and n_cov_a **;

	data d1_A(drop=&exposure. mean_cov_b sd_cov_b n_cov_b);
	   set first_exp;

       mean_cov_a = mean_cov_b;
	   sd_cov_a = sd_cov_b;
	   n_cov_a = n_cov_b; 
	   
	   if missing(mean_cov_a) OR missing(sd_cov_a) OR missing(n_cov_a) then delete;  /* Remove missing observations */
	run;


	
	** Merge the d1_B and d1_A data sets together **;

	proc sort data=d1_A out=d1_Asort;
	   by name_cov time_exposure time_covariate &&history_.;
	run;

    proc sort data=d1_B out=d1_Bsort;
	   by name_cov time_exposure time_covariate &&history_.;
	run;

	data d1combined;
	   merge d1_Asort d1_Bsort;
	   by name_cov time_exposure time_covariate &&history_.;

       if missing(mean_cov_a) OR missing(sd_cov_a) OR missing(n_cov_a) then delete;  /* Remove missing observations */
	run;



	** Remove observations where exposure equals its minimum value **;

	data temp_table;
	   set d1combined;
	   by name_cov time_exposure time_covariate &&history_. &exposure.;
	   if first.&&history_. then delete;
	run;


	** Retain variables in proper order **;

	data temp_table;
	   retain &exposure. &&history_. name_cov time_exposure time_covariate mean_cov_b sd_cov_b n_cov_b mean_cov_a sd_cov_a n_cov_a;
       set temp_table;
    run;



	** Calculate D, SMD, N, Nexp **;
    %if &sd_ref. eq no %then %do;  /* Default SMD calculation */
	    data temp_table2(rename=(n_cov_b=Nexp));
	       set temp_table;

	       D = mean_cov_b - mean_cov_a;


	       if D eq 0 then SMD=0;

	       if D ne 0 and (sd_cov_a eq 0 OR sd_cov_b eq 0) then do;
              SMD = . ;  /* Set SMD to missing */
              PUTLOG "WARNING: SMD values have been set to missing where there is no covariate variation within some level of time-exposure, time-covariate, exposure history, and exposure value; in this case averages for SMD estimates will also appear as missing";  /* Display warning in log */
           end;

           if D ne 0 and (sd_cov_a ne 0 AND sd_cov_b ne 0) then SMD = (mean_cov_b-mean_cov_a) / sqrt(((sd_cov_a**2)*(n_cov_a-1) + (sd_cov_b**2)*(n_cov_b-1))/(n_cov_a+n_cov_b-2));


           N = n_cov_a + n_cov_b;
	    run;
	%end;
	 
	 %else %if &sd_ref. eq yes %then %do;  /* Use standard deviation of reference group for SMD calculation */
	    data temp_table2(rename=(n_cov_b=Nexp));
	       set temp_table;

	       D = mean_cov_b - mean_cov_a;


	       if D eq 0 then SMD=0;

	       if D ne 0 and (sd_cov_a eq 0 OR sd_cov_b eq 0) then do;
              SMD = . ;  /* Set SMD to missing */
              PUTLOG "WARNING: SMD values have been set to missing where there is no covariate variation within some level of time-exposure, time-covariate, exposure history, and exposure value; in this case averages for SMD estimates will also appear as missing";  /* Display warning in log */
           end;

           if D ne 0 and (sd_cov_a ne 0 AND sd_cov_b ne 0) then SMD = (mean_cov_b-mean_cov_a) / sd_cov_a;


           N = n_cov_a + n_cov_b;
	    run;
	%end;


	data full_table(keep=&exposure. &&history_. name_cov time_exposure time_covariate D SMD N Nexp);
	   set temp_table2;
	run;


	** Issue a warning if there is no covariate variation whatsoever (i.e., all metric values equal zero) **;

	proc sql noprint;
	   create table metric_checkD as
       select count(D) as nonzero_D
       from full_table
	   where D ne 0;  /* Count the number of nonzero D values */
    quit;

	proc sql noprint;
	   create table metric_checkSMD as
       select count(SMD) as nonzero_SMD
       from full_table
	   where SMD ne 0;  /* Count the number of nonzero SMD values */
    quit;

	data metric_check;
	   merge metric_checkD metric_checkSMD;
	run;


	data _NULL_;
	   set metric_check;

	   if nonzero_D eq 0 AND nonzero_SMD eq 0 then do;  /* All metric values equal 0 */
	      PUTLOG 'WARNING: There may be no covariate variation within any level of time-exposure, time-covariate, exposure history and/or strata, and exposure value; please ensure that the temporal covariates are specified correctly.';
       end;
	run;


	** Only keep observations where D is not missing and where time_exposure >= time_covariate **;

	data sub_table; 
	   set full_table;
	   where D ne . AND time_exposure >= time_covariate;
	run;


	** Sort sub_table by exposure and index variables **;

	proc sort data=sub_table;
       by &exposure. &&history_. name_cov time_exposure time_covariate D SMD N Nexp;
	run;

	
	** Retain variables in proper order **;

	data sub_table;
	   retain &exposure. &&history_. name_cov time_exposure time_covariate D SMD N Nexp;
       set sub_table;
    run;

%end;



%if &diagnostic. eq 1 AND &approach. eq stratify %then %do;

    ** Keep the exposure value, exposure time, covariate value, covariate time, and history variables **;

    data d1(drop=&&weight_exposure_. &&weight_censor_. &&strata_.);
	   set &input.;
	   W = 1;  /* Set the total weight equal to one */
	run;

	** Sort the data by covariate name, exposure time, covariate time, history, and exposure **;

	proc sort data=d1 out=d1sort;
	   by name_cov time_exposure time_covariate &&history_. &exposure.;
	run;


	** Calculate the mean covariate value at time t-k given exposure value at time t and history at time t-1 **;

	proc means data=d1sort MEAN STD noprint;
	   where (time_exposure in(&times_exposure.)) AND (time_covariate in(&times_covariate.));  /* Subset the data to include only the exposure and covariate times specified by the user */
	   class name_cov time_exposure time_covariate &&history_. &exposure.;
	   var value_cov;
	   weight W;
	   output out=d1_Btemp MEAN=mean_cov_b STD=sd_cov_b;
	run;



	** Check for exposure variation **;

	proc sort data=d1_Btemp out=check_table;
	   by &&history_. time_exposure;  /* Sort the data by history and exposure time */
	run;

    proc sql noprint;
	   create table check_table2 as
       select count(distinct(&exposure.)) as nexpval  /* Count the number of unique exposure values */
       from check_table
	   group by &&history_., time_exposure;
    quit;

	proc sql noprint;
	   create table check_table3 as
       select nexpval, count(distinct(nexpval)) as nexpval_all  /* Count the number of unique nexpvals to determine if there is no exposure variation whatsoever */
       from check_table2;
    quit;


	** Issue a warning if there is no exposure variation **;

	data _NULL_;
	   set check_table3;

	   if nexpval eq 1 AND nexpval_all ne 1 then do;  /* Some exposure times have no exposure variation */
	      PUTLOG 'WARNING: Some exposure times have no exposure variation within levels of exposure history. Estimates for these times will not appear in the results.';
       end;

	   if nexpval eq 1 AND nexpval_all eq 1 then do;  /* ALL exposure times have no exposure variation */
	      PUTLOG 'ERROR: None of the exposure times have exposure variation within levels of exposure history. The program has terminated because the resulting balance table is empty.';
		  ABORT;
       end;
	run;



	** Calculate the sum of the weights **;

	proc means data=d1sort SUM noprint;
	   where (time_exposure in(&times_exposure.)) AND (time_covariate in(&times_covariate.));  /* Subset the data to include only the exposure and covariate times specified by the user */
	   class name_cov time_exposure time_covariate &&history_. &exposure.;
	   var W;
	   output out=d1_Btemp2 SUM=n_cov_b;
	run;


	** Merge the two temp data sets together **;

	proc sort data=d1_Btemp;
	   by name_cov time_exposure time_covariate &&history_. &exposure. _TYPE_ _FREQ_;
	run;

	proc sort data=d1_Btemp2;
	   by name_cov time_exposure time_covariate &&history_. &exposure. _TYPE_ _FREQ_;
	run;

	data d1_Btemp3;
	   merge d1_Btemp d1_Btemp2;
	   by name_cov time_exposure time_covariate &&history_. &exposure. _TYPE_ _FREQ_;
    run; 
	

	
	** Remove missing observations that were created by PROC MEANS from the output data set **;
	
	data d1_B(drop=_TYPE_ _FREQ_);
	   set d1_Btemp3;

       if missing(name_cov) OR missing(time_exposure) OR missing(time_covariate) OR  
          missing(&&history_.) OR missing(&exposure.) then delete;
	run;



	** Select the first exposure observation within each level of history **;

	proc sort data=d1_B;
	   by name_cov time_exposure time_covariate &&history_. &exposure.;
	run;

	data first_exp;
	   set d1_B;
	   by name_cov time_exposure time_covariate &&history_. &exposure.;

	   if not first.&&history_. then delete;  
	run;



	** Generate mean_cov_a, sd_cov_a, and n_cov_a **;

	data d1_A(drop=&exposure. mean_cov_b sd_cov_b n_cov_b);
	   set first_exp;

       mean_cov_a = mean_cov_b;
	   sd_cov_a = sd_cov_b;
	   n_cov_a = n_cov_b; 
	   
	   if missing(mean_cov_a) OR missing(sd_cov_a) OR missing(n_cov_a) then delete;  /* Remove missing observations */
	run;


	
	** Merge the d1_B and d1_A data sets together **;

	proc sort data=d1_A out=d1_Asort;
	   by name_cov time_exposure time_covariate &&history_.;
	run;

    proc sort data=d1_B out=d1_Bsort;
	   by name_cov time_exposure time_covariate &&history_.;
	run;

	data d1combined;
	   merge d1_Asort d1_Bsort;
	   by name_cov time_exposure time_covariate &&history_.;

       if missing(mean_cov_a) OR missing(sd_cov_a) OR missing(n_cov_a) then delete;  /* Remove missing observations */
	run;



	** Remove observations where exposure equals its minimum value **;

	data temp_table;
	   set d1combined;
	   by name_cov time_exposure time_covariate &&history_. &exposure.;
	   if first.&&history_. then delete;
	run;


	** Retain variables in proper order **;

	data temp_table;
	   retain &exposure. &&history_. name_cov time_exposure time_covariate mean_cov_b sd_cov_b n_cov_b mean_cov_a sd_cov_a n_cov_a;
       set temp_table;
    run;



	** Calculate D, SMD, N, Nexp **;
    %if &sd_ref. eq no %then %do;  /* Default SMD calculation */
	    data temp_table2(rename=(n_cov_b=Nexp));
	       set temp_table;

	       D = mean_cov_b - mean_cov_a;


	       if D eq 0 then SMD=0;

	       if D ne 0 and (sd_cov_a eq 0 OR sd_cov_b eq 0) then do;
              SMD = . ;  /* Set SMD to missing */
              PUTLOG "WARNING: SMD values have been set to missing where there is no covariate variation within some level of time-exposure, time-covariate, exposure history, and exposure value; in this case averages for SMD estimates will also appear as missing";  /* Display warning in log */
           end;

           if D ne 0 and (sd_cov_a ne 0 AND sd_cov_b ne 0) then SMD = (mean_cov_b-mean_cov_a) / sqrt(((sd_cov_a**2)*(n_cov_a-1) + (sd_cov_b**2)*(n_cov_b-1))/(n_cov_a+n_cov_b-2));


           N = n_cov_a + n_cov_b;
	    run;
	%end;
	
	%else %if &sd_ref. eq yes %then %do;  /* Use standard deviation of reference group for SMD calculation */
	    data temp_table2(rename=(n_cov_b=Nexp));
	       set temp_table;

	       D = mean_cov_b - mean_cov_a;


	       if D eq 0 then SMD=0;

	       if D ne 0 and (sd_cov_a eq 0 OR sd_cov_b eq 0) then do;
              SMD = . ;  /* Set SMD to missing */
              PUTLOG "WARNING: SMD values have been set to missing where there is no covariate variation within some level of time-exposure, time-covariate, exposure history, and exposure value; in this case averages for SMD estimates will also appear as missing";  /* Display warning in log */
           end;

           if D ne 0 and (sd_cov_a ne 0 AND sd_cov_b ne 0) then SMD = (mean_cov_b-mean_cov_a) / sd_cov_a;


           N = n_cov_a + n_cov_b;
	    run;
	%end;


	data full_table(keep=&exposure. &&history_. name_cov time_exposure time_covariate D SMD N Nexp);
	   set temp_table2;
	run;


	** Issue a warning if there is no covariate variation whatsoever (i.e., all metric values equal zero) **;

	proc sql noprint;
	   create table metric_checkD as
       select count(D) as nonzero_D
       from full_table
	   where D ne 0;  /* Count the number of nonzero D values */
    quit;

	proc sql noprint;
	   create table metric_checkSMD as
       select count(SMD) as nonzero_SMD
       from full_table
	   where SMD ne 0;  /* Count the number of nonzero SMD values */
    quit;

	data metric_check;
	   merge metric_checkD metric_checkSMD;
	run;


	data _NULL_;
	   set metric_check;

	   if nonzero_D eq 0 AND nonzero_SMD eq 0 then do;  /* All metric values equal 0 */
	      PUTLOG "WARNING: There may be no covariate variation within any level of time-exposure, time-covariate, exposure history and/or strata, and exposure value; please ensure that the temporal covariates are specified correctly.";
       end;
	run;



	** Only keep observations where D is not missing and where time_exposure >= time_covariate **;

	data sub_table; 
	   set full_table;
	   where D ne . AND time_exposure >= time_covariate;
	run;


	** Sort sub_table by exposure and index variables **;

	proc sort data=sub_table;
       by &exposure. &&history_. name_cov time_exposure time_covariate D SMD N Nexp;
	run;

	
	** Retain variables in proper order **;

	data sub_table;
	   retain &exposure. &&history_. name_cov time_exposure time_covariate D SMD N Nexp;
       set sub_table;
    run;

%end;




*---------------------------*;
* For Diagnostic 2          *;
*---------------------------*;

%if &diagnostic. eq 2 AND (&approach. eq weight OR &approach. eq none) %then %do;

 ** Get length of exposure weight variable, to be used when converting W into numeric format **;

    data _NULL_;
       set &input.;
	   length_WE = lengthc(&&weight_exposure_.);
       call symput("WELength",length_WE); 
    run;



 ** Keep the exposure value, exposure time, covariate value, covariate time, and history variables **;

    data d2(drop=&&weight_exposure_. &&weight_censor_. &&strata_.);
	   set &input.;

	   %if &censoring. eq no %then %do;
           W = input(&&weight_exposure_.,&&WELength..);  /* Total weight equals exposure weight (numeric) */   
       %end;

	   %if &censoring. eq yes %then %do;
           W = &&weight_exposure_.*&&weight_censor_.;  /* Total weight equals the product of the exposure weight and the censor weight (numeric) */
	   %end;

	run;


	** Sort the data by covariate name, exposure time, covariate time, history, and exposure **;

	proc sort data=d2 out=d2sort;
	   by name_cov time_exposure time_covariate &&history_. &exposure.;
	run;



	** Calculate the mean covariate value at time t-k given exposure value at time t and history at time t-1 **;

	proc means data=d2sort MEAN STD noprint;
	   where (time_exposure in(&times_exposure.)) AND (time_covariate in(&times_covariate.));  /* Subset the data to include only the exposure and covariate times specified by the user */
	   class name_cov time_exposure time_covariate &&history_. &exposure.;
	   var value_cov;
	   weight W;
	   output out=d2_Btemp MEAN=mean_cov_b STD=sd_cov_b;
	run;


	** Check for exposure variation **;

	proc sort data=d2_Btemp out=check_table;
	   by &&history_. time_exposure;  /* Sort the data by history and exposure time */
	run;

    proc sql noprint;
	   create table check_table2 as
       select count(distinct(&exposure.)) as nexpval  /* Count the number of unique exposure values */
       from check_table
	   group by &&history_., time_exposure;
    quit;

	proc sql noprint;
	   create table check_table3 as
       select nexpval, count(distinct(nexpval)) as nexpval_all  /* Count the number of unique nexpvals to determine if there is no exposure variation whatsoever */
       from check_table2;
    quit;


	** Issue a warning if there is no exposure variation **;

	data _NULL_;
	   set check_table3;

	   if nexpval eq 1 AND nexpval_all ne 1 then do;  /* Some exposure times have no exposure variation */
	      PUTLOG 'WARNING: Some exposure times have no exposure variation within levels of exposure history. Estimates for these times will not appear in the results.';
       end;

	   if nexpval eq 1 AND nexpval_all eq 1 then do;  /* ALL exposure times have no exposure variation */
	      PUTLOG 'ERROR: None of the exposure times have exposure variation within levels of exposure history. The program has terminated because the resulting balance table is empty.';
		  ABORT;
       end;
	run;



	** Calculate the sum of the weights **;

	proc means data=d2sort SUM noprint;
	   where (time_exposure in(&times_exposure.)) AND (time_covariate in(&times_covariate.));  /* Subset the data to include only the exposure and covariate times specified by the user */
	   class name_cov time_exposure time_covariate &&history_. &exposure.;
	   var W;
	   output out=d2_Btemp2 SUM=n_cov_b;
	run;


	** Merge the two temp data sets together **;

	proc sort data=d2_Btemp;
	   by name_cov time_exposure time_covariate &&history_. &exposure. _TYPE_ _FREQ_;
	run;

	proc sort data=d2_Btemp2;
	   by name_cov time_exposure time_covariate &&history_. &exposure. _TYPE_ _FREQ_;
	run;

	data d2_Btemp3;
	   merge d2_Btemp d2_Btemp2;
	   by name_cov time_exposure time_covariate &&history_. &exposure. _TYPE_ _FREQ_;
    run; 
	

	
	** Remove missing observations that were created by PROC MEANS from the output data set **;
	
	data d2_B(drop=_TYPE_ _FREQ_);
	   set d2_Btemp3;

       if missing(name_cov) OR missing(time_exposure) OR missing(time_covariate) OR 
          missing(&&history_.) OR missing(&exposure.) then delete;
	run;



	** Select the first exposure observation within each level of history **;

	proc sort data=d2_B;
	   by name_cov time_exposure time_covariate &&history_. &exposure.;
	run;

	data first_exp;
	   set d2_B;
	   by name_cov time_exposure time_covariate &&history_. &exposure.;

	   if not first.&&history_. then delete;  
	run;



	** Generate mean_cov_a, sd_cov_a, and n_cov_a **;

	data d2_A(drop=&exposure. mean_cov_b sd_cov_b n_cov_b);
	   set first_exp;

       mean_cov_a = mean_cov_b;
	   sd_cov_a = sd_cov_b;
	   n_cov_a = n_cov_b; 
	   
	   if missing(mean_cov_a) OR missing(sd_cov_a) OR missing(n_cov_a) then delete;  /* Remove missing observations */
	run;


	
	** Merge the d2_B and d2_A data sets together **;

	proc sort data=d2_A out=d2_Asort;
	   by name_cov time_exposure time_covariate &&history_.;
	run;

    proc sort data=d2_B out=d2_Bsort;
	   by name_cov time_exposure time_covariate &&history_.;
	run;

	data d2combined;
	   merge d2_Asort d2_Bsort;
	   by name_cov time_exposure time_covariate &&history_.;

       if missing(mean_cov_a) OR missing(sd_cov_a) OR missing(n_cov_a) then delete;  /* Remove missing observations */
	run;



	** Remove observations where exposure equals its minimum value **;

	data temp_table;
	   set d2combined;
	   by name_cov time_exposure time_covariate &&history_. &exposure.;
	   if first.&&history_. then delete;
	run;


	** Retain variables in proper order **;

	data temp_table;
	   retain &exposure. &&history_. name_cov time_exposure time_covariate mean_cov_b sd_cov_b n_cov_b mean_cov_a sd_cov_a n_cov_a;
       set temp_table;
    run;



	** Calculate D, SMD, N, Nexp **;
    %if &sd_ref. eq no %then %do;  /* Default SMD calculation */
	    data temp_table2(rename=(n_cov_b=Nexp));
	       set temp_table;

	       D = mean_cov_b - mean_cov_a;


	       if D eq 0 then SMD=0;

	       if D ne 0 and (sd_cov_a eq 0 OR sd_cov_b eq 0) then do;
              SMD = . ;  /* Set SMD to missing */
              PUTLOG "WARNING: SMD values have been set to missing where there is no covariate variation within some level of time-exposure, time-covariate, exposure history, and exposure value; in this case averages for SMD estimates will also appear as missing";  /* Display warning in log */
           end;

           if D ne 0 and (sd_cov_a ne 0 AND sd_cov_b ne 0) then SMD = (mean_cov_b-mean_cov_a) / sqrt(((sd_cov_a**2)*(n_cov_a-1) + (sd_cov_b**2)*(n_cov_b-1))/(n_cov_a+n_cov_b-2));


           N = n_cov_a + n_cov_b;
	    run;
	%end;
	
	%else %if &sd_ref. eq yes %then %do;  /*Use standard deviation of reference group for SMD calculation */
	    data temp_table2(rename=(n_cov_b=Nexp));
	       set temp_table;

	       D = mean_cov_b - mean_cov_a;


	       if D eq 0 then SMD=0;

	       if D ne 0 and (sd_cov_a eq 0 OR sd_cov_b eq 0) then do;
              SMD = . ;  /* Set SMD to missing */
              PUTLOG "WARNING: SMD values have been set to missing where there is no covariate variation within some level of time-exposure, time-covariate, exposure history, and exposure value; in this case averages for SMD estimates will also appear as missing";  /* Display warning in log */
           end;

           if D ne 0 and (sd_cov_a ne 0 AND sd_cov_b ne 0) then SMD = (mean_cov_b-mean_cov_a) / sd_cov_a;


           N = n_cov_a + n_cov_b;
	    run;
	%end;


	data full_table(keep=&exposure. &&history_. name_cov time_exposure time_covariate D SMD N Nexp);
	   set temp_table2;
	run;


	** Issue a warning if there is no covariate variation whatsoever (i.e., all metric values equal zero) **;

	proc sql noprint;
	   create table metric_checkD as
       select count(D) as nonzero_D
       from full_table
	   where D ne 0;  /* Count the number of nonzero D values */
    quit;

	proc sql noprint;
	   create table metric_checkSMD as
       select count(SMD) as nonzero_SMD
       from full_table
	   where SMD ne 0;  /* Count the number of nonzero SMD values */
    quit;

	data metric_check;
	   merge metric_checkD metric_checkSMD;
	run;


	data _NULL_;
	   set metric_check;

	   if nonzero_D eq 0 AND nonzero_SMD eq 0 then do;  /* All metric values equal 0 */
	      PUTLOG "WARNING: There may be no covariate variation within any level of time-exposure, time-covariate, exposure history and/or strata, and exposure value; please ensure that the temporal covariates are specified correctly.";
       end;
	run;



	** Only keep observations where D is not missing and where time_exposure < time_covariate **;

	data sub_table; 
	   set full_table;
	   where D ne . AND time_exposure < time_covariate;
	run;


	** Sort sub_table by exposure and index variables **;

	proc sort data=sub_table;
       by &exposure. &&history_. name_cov time_exposure time_covariate D SMD N Nexp;
	run;

	
	** Retain variables in proper order **;

	data sub_table;
	   retain &exposure. &&history_. name_cov time_exposure time_covariate D SMD N Nexp;
       set sub_table;
    run;

%end;



%if &diagnostic. eq 2 AND &approach. eq stratify %then %do;

    ** Get length of censor weight variable, to be used when converting W into numeric format **;

    data _NULL_;
       set &input.;
       length_WC = lengthc(&&weight_censor_.);
       call symput("WCLength",length_WC); 
    run;



    ** Keep the exposure value, exposure time, covariate value, covariate time, and strata variables **;

    data d2(drop=&&weight_exposure_. &&weight_censor_. &&history_.);
	   set &input.;

	   %if &censoring. eq no %then %do;
           W = 1;  /* Total weight equals 1 */   
       %end;

	   %if &censoring. eq yes %then %do;
           W = input(&&weight_censor_.,&&WCLength..);  /* Total weight equals censor weight (numeric) */  
	   %end;
	run;


	** Sort the data by covariate name, exposure time, and covariate time, strata, and exposure **;

	proc sort data=d2 out=d2sort;
	   by name_cov time_exposure time_covariate &&strata_. &exposure.;
	run;



	** Calculate the mean covariate value at time t-k given exposure value at time t and strata at time t-1 **;

	proc means data=d2sort MEAN STD noprint;
	   where (time_exposure in(&times_exposure.)) AND (time_covariate in(&times_covariate.));  /* Subset the data to include only the exposure and covariate times specified by the user */
	   class name_cov time_exposure time_covariate &&strata_. &exposure.;
	   var value_cov;
	   weight W;
	   output out=d2_Btemp MEAN=mean_cov_b STD=sd_cov_b;
	run;


	** Check for exposure variation **;

	proc sort data=d2_Btemp out=check_table;
	   by &&strata_. time_exposure;  /* Sort the data by strata and exposure time */
	run;

    proc sql noprint;
	   create table check_table2 as
       select count(distinct(&exposure.)) as nexpval  /* Count the number of unique exposure values */
       from check_table
	   group by &&strata_., time_exposure;
    quit;

	proc sql noprint;
	   create table check_table3 as
       select nexpval, count(distinct(nexpval)) as nexpval_all  /* Count the number of unique nexpvals to determine if there is no exposure variation whatsoever */
       from check_table2;
    quit;


	** Issue a warning if there is no exposure variation **;

	data _NULL_;
	   set check_table3;

	   if nexpval eq 1 AND nexpval_all ne 1 then do;  /* Some exposure times have no exposure variation */
	      PUTLOG 'WARNING: Some exposure times have no exposure variation within levels of exposure history. Estimates for these times will not appear in the results.';
       end;

	   if nexpval eq 1 AND nexpval_all eq 1 then do;  /* ALL exposure times have no exposure variation */
	      PUTLOG 'ERROR: None of the exposure times have exposure variation within levels of exposure history. The program has terminated because the resulting balance table is empty.';
		  ABORT;
       end;
	run;



	** Calculate the sum of the weights **;

	proc means data=d2sort SUM noprint;
	   where (time_exposure in(&times_exposure.)) AND (time_covariate in(&times_covariate.));  /* Subset the data to include only the exposure and covariate times specified by the user */
	   class name_cov time_exposure time_covariate &&strata_. &exposure.;
	   var W;
	   output out=d2_Btemp2 SUM=n_cov_b;
	run;


	** Merge the two temp data sets together **;

	proc sort data=d2_Btemp;
	   by name_cov time_exposure time_covariate &&strata_. &exposure. _TYPE_ _FREQ_;
	run;

	proc sort data=d2_Btemp2;
	   by name_cov time_exposure time_covariate &&strata_. &exposure. _TYPE_ _FREQ_;
	run;

	data d2_Btemp3;
	   merge d2_Btemp d2_Btemp2;
	   by name_cov time_exposure time_covariate &&strata_. &exposure. _TYPE_ _FREQ_;
    run; 
	

	
	** Remove missing observations that were created by PROC MEANS from the output data set **;
	
	data d2_B(drop=_TYPE_ _FREQ_);
	   set d2_Btemp3;

       if missing(name_cov) OR missing(time_exposure) OR missing(time_covariate) OR 
          missing(&&strata_.) OR missing(&exposure.) then delete;
	run;



	** Select the first exposure observation within each level of strata **;

	proc sort data=d2_B;
	   by name_cov time_exposure time_covariate &&strata_. &exposure.;
	run;

	data first_exp;
	   set d2_B;
	   by name_cov time_exposure time_covariate &&strata_. &exposure.;

	   if not first.&&strata_. then delete;  
	run;



	** Generate mean_cov_a, sd_cov_a, and n_cov_a **;

	data d2_A(drop=&exposure. mean_cov_b sd_cov_b n_cov_b);
	   set first_exp;

       mean_cov_a = mean_cov_b;
	   sd_cov_a = sd_cov_b;
	   n_cov_a = n_cov_b; 
	   
	   if missing(mean_cov_a) OR missing(sd_cov_a) OR missing(n_cov_a) then delete;  /* Remove missing observations */
	run;


	
	** Merge the d2_B and d2_A data sets together **;

	proc sort data=d2_A out=d2_Asort;
	   by name_cov time_exposure time_covariate &&strata_.;
	run;

    proc sort data=d2_B out=d2_Bsort;
	   by name_cov time_exposure time_covariate &&strata_.;
	run;

	data d2combined;
	   merge d2_Asort d2_Bsort;
	   by name_cov time_exposure time_covariate &&strata_.;

       if missing(mean_cov_a) OR missing(sd_cov_a) OR missing(n_cov_a) then delete;  /* Remove missing observations */
	run;



	** Remove observations where exposure equals its minimum value **;

	data temp_table;
	   set d2combined;
	   by name_cov time_exposure time_covariate &&strata_. &exposure.;
	   if first.&&strata_. then delete;
	run;


	** Retain variables in proper order **;

	data temp_table;
	   retain &exposure. &&strata_. name_cov time_exposure time_covariate mean_cov_b sd_cov_b n_cov_b mean_cov_a sd_cov_a n_cov_a;
       set temp_table;
    run;



	** Calculate D, SMD, N, Nexp **;
    %if &sd_ref. eq no %then %do;  /* Default SMD calculation */
	    data temp_table2(rename=(n_cov_b=Nexp));
	       set temp_table;

	       D = mean_cov_b - mean_cov_a;


	       if D eq 0 then SMD=0;

	       if D ne 0 and (sd_cov_a eq 0 OR sd_cov_b eq 0) then do;
              SMD = . ;  /* Set SMD to missing */
              PUTLOG "WARNING: SMD values have been set to missing where there is no covariate variation within some level of time-exposure, time-covariate, exposure history, and exposure value; in this case averages for SMD estimates will also appear as missing";  /* Display warning in log */
           end;

           if D ne 0 and (sd_cov_a ne 0 AND sd_cov_b ne 0) then SMD = (mean_cov_b-mean_cov_a) / sqrt(((sd_cov_a**2)*(n_cov_a-1) + (sd_cov_b**2)*(n_cov_b-1))/(n_cov_a+n_cov_b-2));


           N = n_cov_a + n_cov_b;
	    run;
	%end;
	
	%else %if &sd_ref. eq yes %then %do;  /* Use standard deviation of reference group for SMD calculation */
	    data temp_table2(rename=(n_cov_b=Nexp));
	       set temp_table;

	       D = mean_cov_b - mean_cov_a;


	       if D eq 0 then SMD=0;

	       if D ne 0 and (sd_cov_a eq 0 OR sd_cov_b eq 0) then do;
              SMD = . ;  /* Set SMD to missing */
              PUTLOG "WARNING: SMD values have been set to missing where there is no covariate variation within some level of time-exposure, time-covariate, exposure history, and exposure value; in this case averages for SMD estimates will also appear as missing";  /* Display warning in log */
           end;

           if D ne 0 and (sd_cov_a ne 0 AND sd_cov_b ne 0) then SMD = (mean_cov_b-mean_cov_a) / sd_cov_a;


           N = n_cov_a + n_cov_b;
	    run;
	%end;


	data full_table(keep=&exposure. &&strata_. name_cov time_exposure time_covariate D SMD N Nexp);
	   set temp_table2;
	run;



    ** Issue a warning if there is no covariate variation whatsoever (i.e., all metric values equal zero) **;

	proc sql noprint;
	   create table metric_checkD as
       select count(D) as nonzero_D
       from full_table
	   where D ne 0;  /* Count the number of nonzero D values */
    quit;

	proc sql noprint;
	   create table metric_checkSMD as
       select count(SMD) as nonzero_SMD
       from full_table
	   where SMD ne 0;  /* Count the number of nonzero SMD values */
    quit;

	data metric_check;
	   merge metric_checkD metric_checkSMD;
	run;


	data _NULL_;
	   set metric_check;

	   if nonzero_D eq 0 AND nonzero_SMD eq 0 then do;  /* All metric values equal 0 */
	      PUTLOG "WARNING: There may be no covariate variation within any level of time-exposure, time-covariate, exposure history and/or strata, and exposure value; please ensure that the temporal covariates are specified correctly.";
       end;
	run;



	** Only keep observations where D is not missing and where time_exposure < time_covariate **;

	data sub_table; 
	   set full_table;
	   where D ne . AND time_exposure < time_covariate;
	run;


	** Sort sub_table by exposure and index variables **;

	proc sort data=sub_table;
       by &exposure. &&strata_. name_cov time_exposure time_covariate D SMD N Nexp;
	run;

	
	** Retain variables in proper order **;

	data sub_table;
	   retain &exposure. &&strata_. name_cov time_exposure time_covariate D SMD N Nexp;
       set sub_table;
    run;

%end;




*---------------------------*;
* For Diagnostic 3          *;
*---------------------------*;

%if &diagnostic. eq 3 AND (&approach. eq weight OR &approach. eq none) %then %do;

    ** Get length of exposure weight variable, to be used when converting W into numeric format **;

    data _NULL_;
       set &input.;
	   length_WE = lengthc(&&weight_exposure_.);
       call symput("WELength",length_WE); 
    run;



    ** Keep the exposure value, exposure time, covariate value, covariate time, and history variables **;

    data d3(drop=&&weight_exposure_. &&weight_censor_. &&strata_.);
	   set &input.;

	   %if &censoring. eq no %then %do;
           W = input(&&weight_exposure_.,&&WELength..);  /* Total weight equals exposure weight (numeric) */   
       %end;

	   %if &censoring. eq yes %then %do;
           W = &&weight_exposure_.*&&weight_censor_.;  /* Total weight equals the product of the exposure weight and the censor weight (numeric) */
	   %end;
	run;



	** Sort the data by covariate name, exposure time, covariate time, history, and exposure **;

	proc sort data=d3 out=d3sort;
	   by name_cov time_exposure time_covariate &&history_. &exposure.;
	run;


	** Calculate the mean covariate value at time t-k given exposure value at time t and history at time t-1 **;

	proc means data=d3sort MEAN STD noprint;
	   where (time_exposure in(&times_exposure.)) AND (time_covariate in(&times_covariate.));  /* Subset the data to include only the exposure and covariate times specified by the user */
	   class name_cov time_exposure time_covariate &&history_. &exposure.;
	   var value_cov;
	   weight W;
	   output out=d3_Btemp MEAN=mean_cov_b STD=sd_cov_b;
	run;


	** Check for exposure variation **;

	proc sort data=d3_Btemp out=check_table;
	   by &&history_. time_exposure;  /* Sort the data by history and exposure time */
	run;

    proc sql noprint;
	   create table check_table2 as
       select count(distinct(&exposure.)) as nexpval  /* Count the number of unique exposure values */
       from check_table
	   group by &&history_., time_exposure;
    quit;

	proc sql noprint;
	   create table check_table3 as
       select nexpval, count(distinct(nexpval)) as nexpval_all  /* Count the number of unique nexpvals to determine if there is no exposure variation whatsoever */
       from check_table2;
    quit;


	** Issue a warning if there is no exposure variation **;

	data _NULL_;
	   set check_table3;

	   if nexpval eq 1 AND nexpval_all ne 1 then do;  /* Some exposure times have no exposure variation */
	      PUTLOG 'WARNING: Some exposure times have no exposure variation within levels of exposure history. Estimates for these times will not appear in the results.';
       end;

	   if nexpval eq 1 AND nexpval_all eq 1 then do;  /* ALL exposure times have no exposure variation */
	      PUTLOG 'ERROR: None of the exposure times have exposure variation within levels of exposure history. The program has terminated because the resulting balance table is empty.';
		  ABORT;
       end;
	run;



	** Calculate the sum of the weights **;

	proc means data=d3sort SUM noprint;
	   where (time_exposure in(&times_exposure.)) AND (time_covariate in(&times_covariate.));  /* Subset the data to include only the exposure and covariate times specified by the user */
	   class name_cov time_exposure time_covariate &&history_. &exposure.;
	   var W;
	   output out=d3_Btemp2 SUM=n_cov_b;
	run;


	** Merge the two temp data sets together **;

	proc sort data=d3_Btemp;
	   by name_cov time_exposure time_covariate &&history_. &exposure. _TYPE_ _FREQ_;
	run;

	proc sort data=d3_Btemp2;
	   by name_cov time_exposure time_covariate &&history_. &exposure. _TYPE_ _FREQ_;
	run;

	data d3_Btemp3;
	   merge d3_Btemp d3_Btemp2;
	   by name_cov time_exposure time_covariate &&history_. &exposure. _TYPE_ _FREQ_;
    run; 
	

	** Remove missing observations that were created by PROC MEANS from the output data set **;
	
	data d3_B(drop=_TYPE_ _FREQ_);
	   set d3_Btemp3;

       if missing(name_cov) OR missing(time_exposure) OR missing(time_covariate) OR 
          missing(&&history_.) OR missing(&exposure.) then delete;
	run;



	** Select the first exposure observation within each level of history **;

	proc sort data=d3_B;
	   by name_cov time_exposure time_covariate &&history_. &exposure.;
	run;

	data first_exp;
	   set d3_B;
	   by name_cov time_exposure time_covariate &&history_. &exposure.;

	   if not first.&&history_. then delete;  
	run;



	** Generate mean_cov_a, sd_cov_a, and n_cov_a **;

	data d3_A(drop=&exposure. mean_cov_b sd_cov_b n_cov_b);
	   set first_exp;

       mean_cov_a = mean_cov_b;
	   sd_cov_a = sd_cov_b;
	   n_cov_a = n_cov_b; 
	   
	   if missing(mean_cov_a) OR missing(sd_cov_a) OR missing(n_cov_a) then delete;  /* Remove missing observations */
	run;


	
	** Merge the d3_B and d3_A data sets together **;

	proc sort data=d3_A out=d3_Asort;
	   by name_cov time_exposure time_covariate &&history_.;
	run;

    proc sort data=d3_B out=d3_Bsort;
	   by name_cov time_exposure time_covariate &&history_.;
	run;

	data d3combined;
	   merge d3_Asort d3_Bsort;
	   by name_cov time_exposure time_covariate &&history_.;

       if missing(mean_cov_a) OR missing(sd_cov_a) OR missing(n_cov_a) then delete;  /* Remove missing observations */
	run;



	** Remove observations where exposure equals its minimum value **;

	data temp_table;
	   set d3combined;
	   by name_cov time_exposure time_covariate &&history_. &exposure.;
	   if first.&&history_. then delete;
	run;


	** Retain variables in proper order **;

	data temp_table;
	   retain &exposure. &&history_. name_cov time_exposure time_covariate mean_cov_b sd_cov_b n_cov_b mean_cov_a sd_cov_a n_cov_a;
       set temp_table;
    run;



	** Calculate D, SMD, N, Nexp **;
    %if &sd_ref. eq no %then %do;  /* Default SMD calculation */
	    data temp_table2(rename=(n_cov_b=Nexp));
	       set temp_table;

	       D = mean_cov_b - mean_cov_a;


	       if D eq 0 then SMD=0;

	       if D ne 0 and (sd_cov_a eq 0 OR sd_cov_b eq 0) then do;
              SMD = . ;  /* Set SMD to missing */
              PUTLOG "WARNING: SMD values have been set to missing where there is no covariate variation within some level of time-exposure, time-covariate, exposure history, and exposure value; in this case averages for SMD estimates will also appear as missing";  /* Display warning in log */
           end;

           if D ne 0 and (sd_cov_a ne 0 AND sd_cov_b ne 0) then SMD = (mean_cov_b-mean_cov_a) / sqrt(((sd_cov_a**2)*(n_cov_a-1) + (sd_cov_b**2)*(n_cov_b-1))/(n_cov_a+n_cov_b-2));


           N = n_cov_a + n_cov_b;
	    run;
	%end;
	
	%if &sd_ref. eq yes %then %do;  /* Use standard deviation of reference group for SMD calculation */
	    data temp_table2(rename=(n_cov_b=Nexp));
	       set temp_table;

	       D = mean_cov_b - mean_cov_a;


	       if D eq 0 then SMD=0;

	       if D ne 0 and (sd_cov_a eq 0 OR sd_cov_b eq 0) then do;
              SMD = . ;  /* Set SMD to missing */
              PUTLOG "WARNING: SMD values have been set to missing where there is no covariate variation within some level of time-exposure, time-covariate, exposure history, and exposure value; in this case averages for SMD estimates will also appear as missing";  /* Display warning in log */
           end;

           if D ne 0 and (sd_cov_a ne 0 AND sd_cov_b ne 0) then SMD = (mean_cov_b-mean_cov_a) / sd_cov_a;


           N = n_cov_a + n_cov_b;
	    run;
	%end;


	data full_table(keep=&exposure. &&history_. name_cov time_exposure time_covariate D SMD N Nexp);
	   set temp_table2;
	run;


	** Issue a warning if there is no covariate variation whatsoever (i.e., all metric values equal zero) **;

	proc sql noprint;
	   create table metric_checkD as
       select count(D) as nonzero_D
       from full_table
	   where D ne 0;  /* Count the number of nonzero D values */
    quit;

	proc sql noprint;
	   create table metric_checkSMD as
       select count(SMD) as nonzero_SMD
       from full_table
	   where SMD ne 0;  /* Count the number of nonzero SMD values */
    quit;

	data metric_check;
	   merge metric_checkD metric_checkSMD;
	run;


	data _NULL_;
	   set metric_check;

	   if nonzero_D eq 0 AND nonzero_SMD eq 0 then do;  /* All metric values equal 0 */
	      PUTLOG "WARNING: There may be no covariate variation within any level of time-exposure, time-covariate, exposure history and/or strata, and exposure value; please ensure that the temporal covariates are specified correctly.";
       end;
	run;



	** Only keep observations where D is not missing and where time_exposure >= time_covariate **;

	data sub_table; 
	   set full_table;
	   where D ne . AND time_exposure >= time_covariate;
	run;


	** Sort sub_table by exposure and index variables **;

	proc sort data=sub_table;
       by &exposure. &&history_. name_cov time_exposure time_covariate D SMD N Nexp;
	run;

	
	** Retain variables in proper order **;

	data sub_table;
	   retain &exposure. &&history_. name_cov time_exposure time_covariate D SMD N Nexp;
       set sub_table;
    run;

%end;



%if &diagnostic. eq 3 AND &approach. eq stratify %then %do;

    ** Get length of censor weight variable, to be used when converting W into numeric format **;

    data _NULL_;
       set &input.;
	   length_WC = lengthc(&&weight_censor_.);
       call symput("WCLength",length_WC); 
    run;



    ** Keep the exposure value, exposure time, covariate value, covariate time, strata, and history variables **;

    data d3(drop=&&weight_exposure_. &&weight_censor_.);
	   set &input.;

	   %if &censoring. eq no %then %do;
           W = 1;  /* Total weight equals 1 */   
       %end;

	   %if &censoring. eq yes %then %do;
           W = input(&&weight_censor_.,&&WCLength..);  /* Total weight equals censor weight (numeric) */  
	   %end;
	run;


	** Sort the data by covariate name, exposure time, covariate time, history, strata, and exposure **;

	proc sort data=d3 out=d3sort;
	   by name_cov time_exposure time_covariate &&history_. &&strata_. &exposure.;
	run;


	** Calculate the mean covariate value at time t-k given exposure value at time t and strata and history at time t-1 **;

	proc means data=d3sort MEAN STD noprint;
	   where (time_exposure in(&times_exposure.)) AND (time_covariate in(&times_covariate.));  /* Subset the data to include only the exposure and covariate times specified by the user */
	   class name_cov time_exposure time_covariate &&history_. &&strata_. &exposure.;
	   var value_cov;
	   weight W;
	   output out=d3_Btemp MEAN=mean_cov_b STD=sd_cov_b;
	run;


	** Check for exposure variation **;

	proc sort data=d3_Btemp out=check_table;
	   by &&strata_. &&history_. time_exposure;  /* Sort the data by strata, history, and exposure time */
	run;

    proc sql noprint;
	   create table check_table2 as
       select count(distinct(&exposure.)) as nexpval  /* Count the number of unique exposure values */
       from check_table
	   group by &&strata_., &&history_., time_exposure;
    quit;

	proc sql noprint;
	   create table check_table3 as
       select nexpval, count(distinct(nexpval)) as nexpval_all  /* Count the number of unique nexpvals to determine if there is no exposure variation whatsoever */
       from check_table2;
    quit;


	** Issue a warning if there is no exposure variation **;

	data _NULL_;
	   set check_table3;

	   if nexpval eq 1 AND nexpval_all ne 1 then do;  /* Some exposure times have no exposure variation */
	      PUTLOG 'WARNING: Some exposure times have no exposure variation within levels of exposure history. Estimates for these times will not appear in the results.';
       end;

	   if nexpval eq 1 AND nexpval_all eq 1 then do;  /* ALL exposure times have no exposure variation */
	      PUTLOG 'ERROR: None of the exposure times have exposure variation within levels of exposure history. The program has terminated because the resulting balance table is empty.';
		  ABORT;
       end;
	run;



	** Calculate the sum of the weights **;

	proc means data=d3sort SUM noprint;
	   where (time_exposure in(&times_exposure.)) AND (time_covariate in(&times_covariate.));  /* Subset the data to include only the exposure and covariate times specified by the user */
	   class name_cov time_exposure time_covariate &&history_. &&strata_. &exposure.;
	   var W;
	   output out=d3_Btemp2 SUM=n_cov_b;
	run;


	** Merge the two temp data sets together **;

	proc sort data=d3_Btemp;
	   by name_cov time_exposure time_covariate &&history_. &&strata_. &exposure. _TYPE_ _FREQ_;
	run;

	proc sort data=d3_Btemp2;
	   by name_cov time_exposure time_covariate &&history_. &&strata_. &exposure. _TYPE_ _FREQ_;
	run;

	data d3_Btemp3;
	   merge d3_Btemp d3_Btemp2;
	   by name_cov time_exposure time_covariate &&history_. &&strata_. &exposure. _TYPE_ _FREQ_;
    run; 
	

	
	** Remove missing observations that were created by PROC MEANS from the output data set **;
	
	data d3_B(drop=_TYPE_ _FREQ_);
	   set d3_Btemp3;

       if missing(name_cov) OR missing(time_exposure) OR missing(time_covariate) OR 
          missing(&&history_.) OR missing(&&strata_.) OR missing(&exposure.) then delete;
	run;


	** Select the first exposure observation within each level of strata and history **;

	proc sort data=d3_B;
	   by name_cov time_exposure time_covariate &&strata_. &&history_. &exposure.;
	run;

	data first_exp;
	   set d3_B;
	   by name_cov time_exposure time_covariate &&strata_. &&history_. &exposure.;

	   if not first.&&history_. then delete;  
	run;



	** Generate mean_cov_a, sd_cov_a, and n_cov_a **;

	data d3_A(drop=&exposure. mean_cov_b sd_cov_b n_cov_b);
	   set first_exp;

       mean_cov_a = mean_cov_b;
	   sd_cov_a = sd_cov_b;
	   n_cov_a = n_cov_b; 
	   
	   if missing(mean_cov_a) OR missing(sd_cov_a) OR missing(n_cov_a) then delete;  /* Remove missing observations */
	run;


	
	** Merge the d3_B and d3_A data sets together **;

	proc sort data=d3_A out=d3_Asort;
	   by name_cov time_exposure time_covariate &&strata_. &&history_.;
	run;

    proc sort data=d3_B out=d3_Bsort;
	   by name_cov time_exposure time_covariate &&strata_. &&history_.;
	run;

	data d3combined;
	   merge d3_Asort d3_Bsort;
	   by name_cov time_exposure time_covariate &&strata_. &history_.;

       if missing(mean_cov_a) OR missing(sd_cov_a) OR missing(n_cov_a) then delete;  /* Remove missing observations */
	run;



	** Remove observations where exposure equals its minimum value **;

	data temp_table;
	   set d3combined;
	   by name_cov time_exposure time_covariate &&strata_. &&history_. &exposure.;
	   if first.&&history_. then delete;
	run;


	** Retain variables in proper order **;

	data temp_table;
	   retain &exposure. &&strata_. &&history_. name_cov time_exposure time_covariate mean_cov_b sd_cov_b n_cov_b mean_cov_a sd_cov_a n_cov_a;
       set temp_table;
    run;



	** Calculate D, SMD, N, Nexp **;
    %if &sd_ref. eq no %then %do;  /* Default SMD calculation */
	    data temp_table2(rename=(n_cov_b=Nexp));
	       set temp_table;

	       D = mean_cov_b - mean_cov_a;


	       if D eq 0 then SMD=0;

	       if D ne 0 and (sd_cov_a eq 0 OR sd_cov_b eq 0) then do;
              SMD = . ;  /* Set SMD to missing */
              PUTLOG "WARNING: SMD values have been set to missing where there is no covariate variation within some level of time-exposure, time-covariate, exposure history, and exposure value; in this case averages for SMD estimates will also appear as missing";  /* Display warning in log */
           end;

           if D ne 0 and (sd_cov_a ne 0 AND sd_cov_b ne 0) then SMD = (mean_cov_b-mean_cov_a) / sqrt(((sd_cov_a**2)*(n_cov_a-1) + (sd_cov_b**2)*(n_cov_b-1))/(n_cov_a+n_cov_b-2));


           N = n_cov_a + n_cov_b;
	    run;
	%end;
	
	%else %if &sd_ref. eq no %then %do;  /* Use standard deviation of reference group for SMD calculation */
	    data temp_table2(rename=(n_cov_b=Nexp));
	       set temp_table;

	       D = mean_cov_b - mean_cov_a;


	       if D eq 0 then SMD=0;

	       if D ne 0 and (sd_cov_a eq 0 OR sd_cov_b eq 0) then do;
              SMD = . ;  /* Set SMD to missing */
              PUTLOG "WARNING: SMD values have been set to missing where there is no covariate variation within some level of time-exposure, time-covariate, exposure history, and exposure value; in this case averages for SMD estimates will also appear as missing";  /* Display warning in log */
           end;

           if D ne 0 and (sd_cov_a ne 0 AND sd_cov_b ne 0) then SMD = (mean_cov_b-mean_cov_a) / sd_cov_a;


           N = n_cov_a + n_cov_b;
	    run;
	%end;


	data full_table(keep=&exposure. &&strata_. &&history_. name_cov time_exposure time_covariate D SMD N Nexp);
	   set temp_table2;
	run;



	** Issue a warning if there is no covariate variation whatsoever (i.e., all metric values equal zero) **;

	proc sql noprint;
	   create table metric_checkD as
       select count(D) as nonzero_D
       from full_table
	   where D ne 0;  /* Count the number of nonzero D values */
    quit;

	proc sql noprint;
	   create table metric_checkSMD as
       select count(SMD) as nonzero_SMD
       from full_table
	   where SMD ne 0;  /* Count the number of nonzero SMD values */
    quit;

	data metric_check;
	   merge metric_checkD metric_checkSMD;
	run;


	data _NULL_;
	   set metric_check;

	   if nonzero_D eq 0 AND nonzero_SMD eq 0 then do;  /* All metric values equal 0 */
	      PUTLOG "WARNING: There may be no covariate variation within any level of time-exposure, time-covariate, exposure history and/or strata, and exposure value; please ensure that the temporal covariates are specified correctly.";
       end;
	run;



	** Only keep observations where D is not missing and where time_exposure >= time_covariate **;

	data sub_table; 
	   set full_table;
	   where D ne . AND time_exposure >= time_covariate;
	run;


	** Sort sub_table by exposure and index variables **;

	proc sort data=sub_table;
       by &exposure. &&strata_. &&history_. name_cov time_exposure time_covariate D SMD N Nexp;
	run;

	
	** Retain variables in proper order **;

	data sub_table;
	   retain &exposure. &&strata_. &&history_. name_cov time_exposure time_covariate D SMD N Nexp;
       set sub_table;
    run;

%end;




*----------------------------*;
* Call the apply_scope macro *;
*----------------------------*;

%if &loop. eq no %then %do;  /* Call the apply_scope macro */
    %apply_scope(input=sub_table, diagnostic=&diagnostic., approach=&approach., scope=&scope.,
                   sort_order=&sort_order., ignore_missing_metric=&ignore_missing_metric., 
                   metric=&metric., average_over=&average_over., periods=&periods., 
                   list_distance=&list_distance., recency=&recency.);

	data final_table;  /* Store the output of the apply_scope macro as "final_table" */
	   set final_table;
	run;
%end;

%if &loop. eq yes %then %do;  /* Do not call apply_scope. Final_table = sub_table */
    data final_table;
	   set sub_table;
	run;
%end;




** Rename the final_table data set to match the user-defined or default name, as appropriate **;

%if &output. ne  AND &output. ne NULL %then %do;
    data &output.;  /* Label the output data set with the user-defined name */
       set final_table;
    run;
%end;

%else %do;
    data &input._balance_table;  /* Label the output data set with the default name */
       set final_table;
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
	       save &input. &input._balance_table &&save.;
	    run;
	    quit;
    %end;




%mend balance;  /* End the balance macro */




** End of Program **;
