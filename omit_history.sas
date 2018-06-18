/* Erin Schnellinger */
/* Covariate Balance Project */

/* "Omit History" Macro */


** Start the omit_history macro **;

%macro omit_history(input, output, omission, covariate_name, distance=NULL, times=NULL);


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
       %put ERROR: 'input' is missing or misspecified;
	   %ABORT;
   %end;


   %if &output. eq  OR &output. eq NULL %then %do;   /* &output is missing */
       %put NOTE: 'output' dataset name is missing. By default, the name of the output datset will be identical to that of the input dataset, with the suffix '_longOmit' appended to it;
   %end;


   %if &omission. eq  OR &omission. eq NULL %then %do;   /* &omission is missing */
       %put ERROR: 'omission' needs to be specified;
	   %ABORT;
   %end;



   %if &omission. eq fixed AND (&times. eq  OR &times. eq NULL) %then %do;   /* &omission is fixed, but &times is missing */
       %put ERROR: 'times' needs to be specified;
	   %ABORT;
   %end;

   %else %if &omission. eq fixed AND (&times. ne  AND &times. ne NULL) %then %do;  /* Make sure that the times listed in &times are present in the time_covariate variable in the input data set */

       ** First generate list of covariate times in input data set **;

       proc sql noprint;
	      create table covariate_times as
          select distinct(time_covariate) as unique_cov_times
          from &input.
       quit;

	   proc transpose data=covariate_times out=covTimesWide(drop=_NAME_);
	      var unique_cov_times;
       run;


       ** Create macro variable for list of unique covariate times **;

       data _NULL_;
	      set covTimesWide;
          length covTimes $32767.;
          covTimes=CATX(" ",OF COL:);

	      %LOCAL covTimesList;
	      CALL SYMPUT ('covTimesList',covTimes);  /* Create macro variable for list of unique covariate times */
       run;


       ** Compare &times to covTimesList **;

       proc IML;
          %LET numTimes = %sysfunc(countw(&times., ' '));  /* Count the total number of times specified in &times */

	      %do i=1 %to &&numTimes;  
              %LET numT&&i = %scan(&times.,&&i, ' ');  /* Grab the individual times */
          %end;

	      %do i=1 %to &&numTimes.;  /* Check if any individual time is missing from the times_covariate variable in the input data set */
              %if NOT %eval(&&numT&i in(&&covTimesList.)) %then %do;
                  %put ERROR: one or more values in the 'times' vector are not covariate measurement times in the dataset;
                  %ABORT;
              %end;
	      %end;
       quit;
   %end;



   %if &omission. eq relative AND (&distance. eq  OR &distance. eq NULL) %then %do;   /* &omission is relative, but &distance is missing */
       %put ERROR: 'distance' needs to be specified;
	   %ABORT;
   %end;

   %else %if &omission. eq relative AND (&distance. ne  AND &distance. ne NULL) %then %do;  /* Make sure that the distances in &distance equal at least one difference between exposure time and covariate time in the data set */

      ** First calculate time differences in input data set **;

      data diff;
	     set &input.;

		 texp_num = input(time_exposure,8.);   /* Convert exposure time into a numeric variable */
	     tcov_num = input(time_covariate,8.);  /* Convert covariate time into a numeric variable */

	     exp_cov_diff = texp_num - tcov_num;   /* Calculate the difference between exposure time and covariate time */
	   run;


	   ** Generate list of unique time differences **;

       proc sql noprint;
	      create table diff2 as
          select distinct(exp_cov_diff) as unique_diffs
          from diff
       quit;


	   ** Separate positive differences and negative differences so that comparisons can be conducted via the IN operator **;

	   data pos_diff;
	      set diff2;
		  where unique_diffs >= 0;
	   run;

	   /*
       data neg_diff;
	      set diff2;
		  where unique_diffs < 0;
	   run;

	   data neg_diff_abs;
	      set neg_diff;
		  unique_diffs = abs(unique_diffs);  /* Calculate the absolute value of the negative differences */
	   run;
	   */

	   ** Put the pos_diff and neg_diff data sets into wide format **;

	   proc transpose data=pos_diff out=posDiffWide(drop=_NAME_);
	      var unique_diffs;
       run;

	   /*
	   proc transpose data=neg_diff_abs out=negDiffWide(drop=_NAME_);
	      var unique_diffs;
       run;
	   */

	    ** Create macro variable for lists of unique positive and negative time differences **;

       data _NULL_;
	      set posDiffWide;
          length pos_differences $32767.;
		  pos_differences=CATX(" ",OF COL:);

	      %LOCAL posDiffList;
	      CALL SYMPUT ('posDiffList',pos_differences);  /* Create macro variable for list of unique positive time differences */
       run;

	   /*
	   data _NULL_;
	      set negDiffWide;
          length neg_differences $32767.;
		  neg_differences=CATX(" ",OF COL:);

	      %LOCAL negDiffList;
	      CALL SYMPUT ('negDiffList',neg_differences);  --- recomment if active --- Create macro variable for list of unique negative time differences --- recomment if active ---
       run;
	   */

	   /*************************************
	   ONLY RUN CHECK IF POSITIVE DIFFERENCES
	   *************************************/
	   
	   /*NOTE: code adapted from: http://www.sascommunity.org/wiki/Determining_the_number_of_observations_in_a_SAS_data_set_efficiently */
	   
		data _null_;
			%LOCAL Anyobs;
			call symput('AnyObs','0'); /* set to 0 for No */
			set posDiffWide(obs=1);
			call symput('AnyObs','1'); /* if got here there are obs so set to 1 for Yes */
		run;
	   
	   %IF &ANYOBS EQ '1' %THEN %DO;
	   
       ** Compare &distance to the appropriate diffList **;

       proc IML;
          %LET numDist = %sysfunc(countw(&distance., ' '));  /* Count the total number of distances specified in &distance */

	      %do i=1 %to &&numDist;  
              %LET numD&&i = %scan(&distance.,&&i, ' ');  /* Grab the individual distances */
          %end;

	      %do i=1 %to &&numDist.;  /* Check if any individual distance is missing from the list of differences in the input data set */

		      %if &&numD&i >= 0 %then %do;   /* &distance is positive, compare to positive difference list */
                  %if NOT %eval(&&numD&i in(&&posDiffList.)) %then %do;
                      %put ERROR: 'distance' does not equal any difference between time_exposure minus time_covariate in the dataset.;
                      %ABORT;
                  %end; 
			  %end;
              /*
			  %if &&numD&i < 0 %then %do;  -- recomment if active -- &distance is negative, compare to negative difference list -- recomment if active --
			      
			      %LET numDabs&&i = %sysfunc(abs(&&numD&i));  --- recomment if active --- Take absolute value of &distance --- recomment if active

                  %if NOT %eval(&&numDabs&i in(&&negDiffList.)) %then %do;
                      %put ERROR: 'distance' does not equal any difference between time_exposure minus time_covariate in the dataset.;
                      %ABORT;
                  %end; 
			  %end;
			  */
	      %end;
       quit;
	   
	   %END;
	   
   %end;

	


   ** Get the number of covariates inputted into "covariate" **;

   data covCount;
      set &input.;

	  %LET numC = %sysfunc(countw(&covariate_name., ' '));  /* Count the total number of covariates */

	  %do i=1 %to &&numC;  
	     %LET cov&&i = %scan(&covariate_name.,&&i, ' ');  /* Grab the individual covariates */
      %end;
   run;




*---------------------------*;
* For "fixed" omission      *;
*---------------------------*;

%if &omission. eq fixed %then %do;

    data longOmit;
	   set &input.;
 
	   %do i=1 %to &&numC.;
	       if name_cov eq "&&cov&i." AND time_covariate in(&times.) then delete;  /* Remove observations for covariates at fixed times */
       %end;
    run;

%end;




*---------------------------*;
* For "relative" omission   *;
*---------------------------*;

%if &omission. eq relative %then %do;

    data longOmit;
	   set &input.;
       timediff = time_exposure - time_covariate;  /* Calculate the difference between exposure time and covariate time */
 
	   %do i=1 %to &&numC.;
	       if name_cov eq "&&cov&i." AND timediff>=&distance. then delete;  /* Remove observations for covariates farther away than maximum distance */
       %end;
    run;

%end;




*---------------------------*;
* For "same_time" omission  *;
*---------------------------*;

%if &omission. eq same_time %then %do;

    data longOmit;
	   set &input.;
       timediff = time_exposure - time_covariate;  /* Calculate the difference between exposure time and covariate time */
 
	   %do i=1 %to &&numC.;
	       if name_cov eq "&&cov&i." AND timediff=0 then delete;  /* Remove observations for covariates measured at same time as exposure */
       %end;
    run;

%end;



** Rename the output data set with the user-defined or default name, as appropriate **;

%if &output. ne  AND &output. ne NULL %then %do;
    data &output.;  /* Label the output data set with the user-defined name */
       set longOmit;
    run;
%end;

%else %do;
    data &input._longOmit;  /* Label the output data set with the default name */
       set longOmit;
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
	       save &input. &input._longOmit &&save.;
        run;
	    quit;
    %end;




%mend omit_history;  /* End the omit_history macro */





** End of Program **;
