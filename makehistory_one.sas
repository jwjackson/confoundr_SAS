/* Erin Schnellinger */
/* Covariate Balance Project */

/* "Make History One" Macro */


** Start the makehistory_one macro **;

%macro makehistory_one(input, output, id, exposure, times, group=NULL, name_history=h);

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




   ** Check for missing input variables, and display error messages, warnings, or notes as appropriate **;

   %if &input. eq  OR &input. eq NULL %then %do;   /* &input is missing */
      %put ERROR: 'input' dataset is missing;
	  %ABORT;
   %end;

   %if &output. eq  OR &output. eq NULL %then %do;   /* &output is missing */
       %put NOTE: 'output' dataset name is missing. By default, the name of the output datset will be identical to that of the input dataset, with the suffix '_with_History' appended to it;
   %end;


   %if &id. eq  OR &id. eq NULL %then %do;   /* &id is missing */
       %put ERROR: 'id' is missing or misspecified. Please specify a unique identifier for each observation;
	   %ABORT;
   %end;

   %if &exposure. eq  OR &exposure. eq NULL %then %do;   /* &exposure is missing */
       %put ERROR: root name for exposure is missing;
	   %ABORT;
   %end;

   %if &times. eq  OR &times. eq NULL %then %do;   /* &times is missing */
       %put ERROR: indices for exposure measurement times is missing. Please specify a numeric vector of times;
	   %ABORT;
   %end;
    


   ** Get the number of times inputted into "times" **;

   data timeCount;
      set &input;

	  %LET numT = %sysfunc(countw(&times., ' '));  /* Count the total number of occasions */

	  %do i=1 %to &&numT;  
	     %LET num&&i = %scan(&times.,&&i, ' ');  /* Grab the individual times */
      %end;
   run;


   ** Create exposure names data set **;

   proc IML;
      times = {&times.};  /* Use the times specified in the "times" macro variable */
      times_c = CHAR(times);

      exposure = J(1,&&numT.,"&exposure.");  /* Set up a 1 x numT matrix that repeats the exposure name */ 
      exposure_names = CATX("_",exposure,times_c);  /* Attach times to exposure prefix */

      CREATE exposure_names_dataset FROM exposure_names;  /* Create exposure names data set */
      APPEND FROM exposure_names;
      CLOSE exposure_names_dataset;
   quit;

 /* proc print data=exposure_names_dataset;
    run; */


   data _NULL_;
      set exposure_names_dataset;
	  length exposureNames $32767.;
      exposureNames=CATX(" ",OF COL1-COL&&numT.);

	  %LOCAL exposureList;
	  CALL SYMPUT ('exposureList',exposureNames);  /* Create macro variable for list of exposure names */
   run;


   ** Make sure that the variables listed in exposureList are present in the input data set **;

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

	  length rawVarNames $32767.;
      rawVarNames=CATX(" ",OF _:);

	  %LOCAL rawVarList;
	  CALL SYMPUT ('rawVarList',rawVarNames);  /* Create macro variable for list of variables in raw data set */
   run;


   ** Compare raw data variable list to our exposure list **;

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



   ** Put the sample data into "long" format **;

   data long(keep=&id. &exposure &exposure.name time timeN time_actual);
      set timeCount;

      array exp[&&numT] &&exposureList;  /* Set up the exposure array */


      do i=1 to dim(exp);
	     &exposure = exp[i]; 

	     &exposure.name=VNAME(exp[i]);  /* Get the column names for the first exposure */

	     time=scan(&exposure.name,-1,'_');  /* Extract digits after underscore and set these equal to "time" */ 
	     timeN=input(time,8.);  /* Convert the character time variable into a numeric variable */
	     time_actual = i;  /* Create variable to indicate "occasion number" */
	     output;
      end;

   run;



   ** Sort the long data set **;

   proc sort data=long out=long2;
      by &id. time_actual;
   run;


   ** Get length of history variable **;

   data expCount;
      set long2;
	  by &id.;

	  exposure_length = countw(&exposure);  /* Get the length the exposure variable */

	  if first.&id. then cum_exp_length=0;  /* Reset the cumulative sum to 0 for each subject's first exposure */
      cum_exp_length + exposure_length;  /* Cumulative sum of exposure_length */

   run;


   proc means data=expCount max noprint;
      var cum_exp_length;  /* Use maximum of the cumulative sum for the length of the history variable */
      output out=cumSumData max=maxCumSum;
   run;


   data histLength;
      set cumSumData;
      call symput("hLength",maxCumSum+2);  /* Add 1 for the 'H' character and 1 for the group variable */
   run;


   ** Get maximum exposure length **;

   proc means data=expCount max noprint;
      var exposure_length;
      output out=expData max=maxExp;
   run;

   data exposureLength;
      set expData;
      call symput("expLength",maxExp);
   run;


   ** Generate the within-subject lagged exposure variables **;

   /* For the first exposure */

   data long3;
      set long2;
	  by &id.;

	  retain &exposure.lag1; /* Retain the lagged exposure variables for each subject */ 
	  if first.&id. then &exposure.lag1= . ; /* Set the lag1 variable equal to missing for each subject's first observation*/
      output;

      &exposure.lag1 = &exposure.;  /* Set the lag1 variable equal to the preceding exposure */
	  if last.&id.;  /* Reset the lagged exposure variable for each new subject */
   run;


   /* For subsequent exposures */

   %if &&numT > 1 %then %do;
       %do i=2 %to &&numT-1;  /* From 2 to number of occasions minus 1 */ 
           data long3;
              set long3;
	          by &id.;

		      %LET j = %eval(&&i - 1);  /* Get the index of the previous lagged exposure */

	          retain &exposure.lag&&i.; /* Retain the lagged exposure variables for each subject */ 
	          if first.&id. then &exposure.lag&&i.= . ; /* Set the lagi variable equal to missing for each subject's first observation*/
              output;

	          &exposure.lag&&i. = &exposure.lag&&j.;  /* Set the lagi variable equal to the preceding value of lag(i-1) */
	          if last.&id.;  /* Reset the lagged exposure variable for each new subject */
           run;
        %end;
	%end;




   ** Convert the within-subject exposures into character variables **;
   proc sort data=long3;
      by &id. time_actual;
   run;

   data long4;
      set long3;
      by &id. time_actual;

	  %do i=1 %to &&numT-1;  /* To number of occasions minus 1 */
	      if &exposure. ne . then &exposure.char = put(&exposure.,&&expLength..);  /* Convert the (current) exposure into a character variable */ 
          if &exposure.lag&&i ne . then &exposure.lagc&&i=put(&exposure.lag&&i,&&expLength..);  /* Convert the i-unit lagged exposure into a character variable */

          *if &exposure. eq . then PUTLOG 'WARNING: An exposure is missing: ' &id.= timeN= &exposure.=;  /* Display WARNING in log if an exposure is missing */
          
          /* Replace missing exposures with '.' */
          if &exposure. eq . then &exposure.char = put('.',$1.);  
          if &exposure.lag&&i eq . then &exposure.lagc&&i = put('.',$1.);
      %end;   
   run;



   ** Create the history variable **;

   %if &group. ne  AND &group. ne NULL %then %do;
       data longgrp(keep=&id. &group.);
	      set &input.;
	   run;

	   proc sort data=longgrp;
	      by &id.;
	   run;

	   proc sort data=long4;
	      by &id.;
	   run;

	   data longgrp2;
	      merge long4 longgrp;
		  by &id.;
	   run;
	   
	   proc sort data=longgrp2;
	      by &id. time_actual;
	   run;

       data longHist;
          set longgrp2;
          by &id. time_actual;

          retain &name_history.;
          length &name_history. $ &&hLength;  /* Set the length of h equal to "hLength" */

	      %do i=1 %to &&numT-1;  /* To number of occasions minus 1 */
	          if first.&id. then &name_history. = 'H'||strip(&group.);   /* First exposure time */
	         
	          /* Remaining exposure times, concatenated in reverse order */
              %LET j = %eval(&&i - 1);  /* Get lag variables from previous times only */
             
	          %if &&i>1 %then %do;
	             if time_actual=&&i then &name_history. = 'H'||strip(&group.)||CATT(OF &exposure.lagc&&j-&exposure.lagc1);
	          %end;
	      %end;
	   run;
	%end;


	%if &group. eq  OR &group. eq NULL %then %do;
	   proc sort data=long4;
	      by &id. time_actual;
	   run;
	   
       data longHist;
          set long4;
          by &id. time_actual;

          retain &name_history.;
          length &name_history. $ &&hLength;  /* Set the length of h equal to "hLength" */

	      %do i=1 %to &&numT-1;  /* To number of occasions minus 1 */ 
	          if first.&id. then &name_history. = 'H';   /* First exposure time */
              
              /* Remaining exposure times, concatenated in reverse order */
              %LET j = %eval(&&i - 1);  /* Get lag variables from previous times only */
             
	          %if &&i>1 %then %do;
	             if time_actual=&&i then &name_history. = 'H'||CATT(OF &exposure.lagc&&j-&exposure.lagc1);
	          %end;
	      %end;
	   run;
	%end;



   ** Create the column names for the history variable **;

   data longHist2;
      set longHist;
	  histName = "&name_history._"||time;
   run;



   ** Convert the longHist data set back into a wide data set **;

   proc sort data=longHist2 out=longHist3;
      by &id. time_actual;
   run;


   ** Transpose exposure **;

   proc transpose data=longHist3 out=wideExp;
      by &id.;
      id &exposure.name;
      var &exposure.;
   run;


   ** Transpose history **;

   proc transpose data=longHist3 out=wideHist;
      by &id.;
      id histName;
      var &name_history.;
   run;


   ** Merge the two wide datasets together **;

   data wideFull;
      merge wideExp(drop=_name_) wideHist(drop=_name_);
      by &id.;
   run;



   ** Merge the wideFull data set back with the original data set to obtain the l,m,n,o,p variables **;

   %if &output. ne  AND &output. ne NULL %then %do;
       data &output.;  /* Label the output data set with the user-defined name */
          merge &input. wideFull;
          by &id.;
       run;
   %end;

   %else %do;
       data &input._with_History;  /* Label the output data set with the default name */
          merge &input. wideFull;
          by &id.;
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
	          save &input. &input._with_History &&save.;
	       run;
	       quit;
       %end; 




%mend makehistory_one;  /* End the makehistory_one macro */




** End of Program **;


