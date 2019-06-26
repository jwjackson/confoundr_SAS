/* Erin Schnellinger */
/* Covariate Balance Project */

/* "Make History Two" Macro */

/* Last Updated: 26 June 2019 */
/* Fixed concatenation issue with history variable */


/* Macro successfully passed testMakeHistoryTwo tests on 26 June 2019 */


** Start the makehistory_two macro **;

%macro makehistory_two(input, output, id, exposure_a, exposure_b, times, group=NULL, name_history_a=ha, name_history_b=hb);

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

   %if &exposure_a. eq  OR &exposure_a. eq NULL %then %do;   /* &exposure_a is missing */
       %put ERROR: root name for the first exposure is missing;
	   %ABORT;
   %end;

   %if &exposure_b. eq  OR &exposure_b. eq NULL %then %do;   /* &exposure_b is missing */
       %put ERROR: root name for the second exposure is missing;
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


   ** Create exposure names data set for first exposure **;

   proc IML;
      times = {&times.};  /* Use the times specified in the "times" macro variable */
      times_c = CHAR(times);

      exposure_a = J(1,&&numT.,"&exposure_a.");  /* Set up a 1 x numT matrix that repeats the first exposure name */ 
      exposure_a_names = CATX("_",exposure_a,times_c);  /* Attach times to first exposure prefix */

      CREATE exposure_a_names_dataset FROM exposure_a_names;  /* Create exposure names data set for first exposure */
      APPEND FROM exposure_a_names;
      CLOSE exposure_a_names_dataset;
   quit;

 /* proc print data=exposure_a_names_dataset;
    run; */ 


   data _NULL_;
      set exposure_a_names_dataset;
	  length exposure_a_Names $32767.;
      exposure_a_Names=CATX(" ",OF COL1-COL&&numT.);

	  %LOCAL exposure_a_List;
	  CALL SYMPUT ('exposure_a_List',exposure_a_Names);  /* Create macro variable for list of first exposure names */
   run;


    ** Create exposure names data set for second exposure **;

   proc IML;
      times = {&times.};  /* Use the times specified in the "times" macro variable */
      times_c = CHAR(times);

      exposure_b = J(1,&&numT.,"&exposure_b.");  /* Set up a 1 x numT matrix that repeats the second exposure name */ 
      exposure_b_names = CATX("_",exposure_b,times_c);  /* Attach times to second exposure prefix */

      CREATE exposure_b_names_dataset FROM exposure_b_names;  /* Create exposure names data set for second exposure */
      APPEND FROM exposure_b_names;
      CLOSE exposure_b_names_dataset;
   quit;

 /* proc print data=exposure_b_names_dataset;
    run; */ 


   data _NULL_;
      set exposure_b_names_dataset;
	  length exposure_b_Names $32767.;
      exposure_b_Names=CATX(" ",OF COL1-COL&&numT.);

	  %LOCAL exposure_b_List;
	  CALL SYMPUT ('exposure_b_List',exposure_b_Names);  /* Create macro variable for list of second exposure names */
   run;


   ** Make sure that the variables listed in exposure_a_List and exposure_b_List are present in the input data set **;

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


   ** Compare raw data variable list to our exposure lists **;

   proc IML;
      %LET numExpANames = %sysfunc(countw(&&exposure_a_List., ' '));  /* Count the total number of exposure names for the first exposure */

	  %do i=1 %to &&numExpANames;  
          %LET numAVar&&i = %scan(&&exposure_a_List.,&&i, ' ');  /* Grab the individual exposure names */
      %end;

	  %do i=1 %to &&numExpANames.;  /* Check if any individual exposure name is missing from the raw list */
          %if NOT %eval(&&numAVar&i in(&&rawVarList.)) %then %do;
             %put ERROR: The exposure root name is misspelled, or some exposure measurements are missing from the input dataset, or incorrect measurement times have been specified;
             %ABORT;
          %end;
	  %end;
   quit;

   proc IML;
      %LET numExpBNames = %sysfunc(countw(&&exposure_b_List., ' '));  /* Count the total number of exposure names for the second exposure */

	  %do i=1 %to &&numExpBNames;  
          %LET numBVar&&i = %scan(&&exposure_b_List.,&&i, ' ');  /* Grab the individual exposure names */
      %end;

	  %do i=1 %to &&numExpBNames.;  /* Check if any individual exposure name is missing from the raw list */
          %if NOT %eval(&&numBVar&i in(&&rawVarList.)) %then %do;
             %put ERROR: The exposure root name is misspelled, or some exposure measurements are missing from the input dataset, or incorrect measurement times have been specified;
             %ABORT;
          %end;
	  %end;
   quit;



   ** Put the sample data into "long" format **;

   data long (keep=&id. &exposure_a &exposure_a.name &exposure_b &exposure_b.name time timeN time_actual);
      set timeCount;

      array exp[&&numT] &&exposure_a_List;  /* Set up the first exposure array */
      array exp2[&&numT] &&exposure_b_List;  /* Set up the second exposure array */


      do i=1 to dim(exp);
	     &exposure_a = exp[i];  /* First exposure */
	     &exposure_b = exp2[i]; /* Second exposure */

	     &exposure_a.name=VNAME(exp[i]);  /* Get the column names for the first exposure */
	     &exposure_b.name=VNAME(exp2[i]); /* Get the column names for the second exposure */

	     time=scan(&exposure_a.name,-1,'_');  /* Extract digits after underscore and set these equal to "time" */ 
	     timeN=input(time,8.);  /* Convert the character time variable into a numeric variable */
	     time_actual = i;  /* Create variable to indicate "occasion number" */
	     output;
      end;

   run;


   ** Sort the long data set **;

   proc sort data=long;
      by &id. time_actual;
   run;

   ** Get maximum exposure length **;

   data expLength;
      set long;
	  by &id.;

	  exposure_length_a = countw(&exposure_a);  /* Get the length of the first exposure variable */
	  exposure_length_b = countw(&exposure_b);  /* Get the length of the second exposure variable */
   run;

   proc means data=expLength max noprint;
      var exposure_length_a exposure_length_b;
      output out=expData max=maxExpA maxExpB;
   run;

   data expData2;
      set expData;
      call symput("expLengthA",maxExpA);  /* Maximum exposure length for the first exposure */
	  call symput("expLengthB",maxExpB);  /* Maximum exposure length for the second exposure */
	  call symput("expLengthJoint",maxExpA+maxExpB);  /* Maximum exposure length for the joint exposure */
   run;


   ** Create the joint exposure column **;

   data long2;
      set long;

      &exposure_a.&exposure_b.char = trim(put(&exposure_a.,&&expLengthA..))||trim(put(&exposure_b.,&&expLengthB..));  /* Joint exposure */
      &exposure_a.&exposure_b.name = "&exposure_a.&exposure_b._"||time;  /* Column names for joint exposure */
   run;


   ** Sort the long data set **;

   proc sort data=long2 out=long3;
      by &id. time_actual;
   run;


   ** Get length of history variable **;

   data expCount;
      set long3;
	  by &id.;

	  exposure_length_a = countw(&exposure_a);  /* Get the length of the first exposure variable */
	  exposure_length_b = countw(&exposure_b);  /* Get the length of the second exposure variable */

	  if first.&id. then cum_exp_length=0;  /* Reset the cumulative sum to 0 for each subject's first exposure */
      cum_exp_length + exposure_length_a + exposure_length_b;  /* Cumulative sum of the two exposure lengths */

   run;


   proc means data=expCount max noprint;
      var cum_exp_length;  /* Use maximum of the cumulative sum for the length of the history variable */
      output out=cumSumData max=maxCumSum;
   run;


   data histLength;
      set cumSumData;
      call symput("hLength", maxCumSum+2);  /* Add 1 for the 'H' character and 1 for group variable */
   run;



   ** Generate the within-subject lagged exposure variables **;

   /* For the first exposures */

   data long4;
      set long3;
	  by &id.;

	  retain &exposure_a.lag1 &exposure_b.lag1; /* Retain the lagged exposure variables for each subject */ 
	  if first.&id. then &exposure_a.lag1= . ; /* Set the lag1 variable equal to missing for each subject's first observation*/
	  if first.&id. then &exposure_b.lag1= . ; /* Set the lag1 variable equal to missing for each subject's first observation*/
      output;

      &exposure_a.lag1 = &exposure_a.;  /* Set the lag1 variable equal to the preceding exposure */
	  &exposure_b.lag1 = &exposure_b.;  /* Set the lag1 variable equal to the preceding exposure */
	  if last.&id.;  /* Reset the lagged exposure variable for each new subject */
   run;


   /* For subsequent exposures */

   %if &&numT > 1 %then %do;
       %do i=2 %to &&numT-1;  /* From 2 to number of occasions minus 1 */ 
           data long4;
              set long4;
	          by &id.;

		      %LET j = %eval(&&i - 1);

	          retain &exposure_a.lag&&i. &exposure_b.lag&&i.; /* Retain the lagged exposure variables for each subject */ 
	          if first.&id. then &exposure_a.lag&&i.= . ; /* Set the lagi variable equal to missing for each subject's first observation*/
			  if first.&id. then &exposure_b.lag&&i.= . ; /* Set the lagi variable equal to missing for each subject's first observation*/
              output;

	          &exposure_a.lag&&i. = &exposure_a.lag&&j.;  /* Set the lagi variable equal to the preceding value of lag(i-1) */
			  &exposure_b.lag&&i. = &exposure_b.lag&&j.;  /* Set the lagi variable equal to the preceding value of lag(i-1) */
	          if last.&id.;  /* Reset the lagged exposure variable for each new subject */
           run;
        %end;
	%end;




	** Lag the within-subject joint exposure variable **;

	data long4;
	   set long4;

	   %do i=1 %to &&numT-1;  /* To number of occasions minus 1 **/
	       &exposure_a.&exposure_b.lagc&&i = put(catt(&exposure_a.lag&&i, &exposure_b.lag&&i),&&expLengthJoint..);  /* Within-subject joint exposure lagged i units */
	   %end;
    run;


   ** Convert the within-subject exposures into character variables **;

   data long5;
      set long4;
      by &id. time_actual;

	  %do i=1 %to &&numT-1;  /* To number of occasions minus 1 */
	      if &exposure_a ne . then &exposure_a.char = put(&exposure_a.,&&expLengthA..);  /* Convert the (current) exposure 1 into a character variable */ 
          if &exposure_a.lag&&i ne . then &exposure_a.lagc&&i=put(&exposure_a.lag&&i,&&expLengthA..);  /* Convert the i-unit lagged exposure 1 into a character variable */

		  if &exposure_b ne . then &exposure_b.char = put(&exposure_b.,&&expLengthB..);  /* Convert the (current) exposure 2 into a character variable */ 
          if &exposure_b.lag&&i ne . then &exposure_b.lagc&&i=put(&exposure_b.lag&&i,&&expLengthB..);  /* Convert the i-unit lagged exposure 2 into a character variable */

		  *if &exposure_a.&exposure_b.lagc&&i eq '..' then &exposure_a.&exposure_b.lagc&&i = '';  /* Remove the periods from the joint exposure */  


          *if &exposure_a eq . OR &exposure_b eq . then PUTLOG 'WARNING: An exposure is missing: ' &id.= timeN= &exposure_a.= &exposure_b.= ;  /* Display WARNING in log if an exposure is missing */
         
          /* Replace missing exposures with '.' */
          if &exposure_a eq . then &exposure_a.char = put('.',$1.);  
          if &exposure_a.lag&&i eq . then &exposure_a.lagc&&i = put('.',$1.);
          
          if &exposure_b eq . then &exposure_b.char = put('.',$1.);  
          if &exposure_b.lag&&i eq . then &exposure_b.lagc&&i = put('.',$1.);
          
          if &exposure_a.&exposure_b.lagc&&i eq '..' then &exposure_a.&exposure_b.lagc&&i = put('..',$2.);
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

	   proc sort data=long5;
	      by &id.;
	   run;

	   data longgrp2;
	      merge long5 longgrp;
		  by &id.;
	   run;


       data longHist;
          set longgrp2;
          by &id. time_actual;

          retain &name_history_a &name_history_b;
          length &name_history_a &name_history_b $ &&hLength;  /* Set the length of h_a, and h_z equal to "hLength" */


	      %do i=1 %to &&numT;  /* To number of occasions */
	          if first.&id. then do;  /* First exposure time */
                 &name_history_a = strip(&group.)||'H'; 
                 &name_history_b = strip(&group.)||'H'||&exposure_a.char;
              end;
		      
		      /* Remaining exposure times, concatenated in reverse order */
              %LET j = %eval(&&i - 1);  /* Get lag variables from previous times only */
             
	          %if &&i>1 %then %do;
	              if time_actual=&&i then &name_history_a = strip(&group.)||'H'||CATT(OF &exposure_a.&exposure_b.lagc&&j-&exposure_a.&exposure_b.lagc1);
			      if time_actual=&&i then &name_history_b = strip(&group.)||'H'||CATT(OF &exposure_a.&exposure_b.lagc&&j-&exposure_a.&exposure_b.lagc1, &exposure_a.char);
	          %end;	          
	      %end;
       run;
   %end;


   %if &group. eq  OR &group. eq NULL %then %do;      
       data longHist;
          set long5;
          by &id. time_actual;

          retain &name_history_a &name_history_b;
          length &name_history_a &name_history_b $ &&hLength;  /* Set the length of h_a, and h_z equal to "hLength" */


	      %do i=1 %to &&numT;  /* To number of occasions minus 1 */
	          if first.&id. then do;  /* First exposure time */
                 &name_history_a = 'H'; 
                 &name_history_b = 'H'||&exposure_a.char;
              end;

		      /* Remaining exposure times, concatenated in reverse order */
              %LET j = %eval(&&i - 1);  /* Get lag variables from previous times only */
             
	          %if &&i>1 %then %do;
	              if time_actual=&&i then &name_history_a = 'H'||CATT(OF &exposure_a.&exposure_b.lagc&&j-&exposure_a.&exposure_b.lagc1);
			      if time_actual=&&i then &name_history_b = 'H'||CATT(OF &exposure_a.&exposure_b.lagc&&j-&exposure_a.&exposure_b.lagc1, &exposure_a.char);
	          %end;
	      %end;
       run;
   %end;




   ** Create the column names for the history variable **;

   data longHist2;
      set longHist;

	  histName&exposure_a. = "&name_history_a._"||time;  /* Column names for history of exposure A */
	  histName&exposure_b. = "&name_history_b._"||time;  /* Column names for history of exposure B */
   run;



   ** Convert the longHist data set back into a wide data set **;

   proc sort data=longHist2 out=longHist3;
      by &id. time_actual;
   run;


   ** Transpose exposure A **;

   proc transpose data=longHist3 out=wideExpA;
      by &id.;
      id &exposure_a.name;
      var &exposure_a.;
   run;


   ** Transpose exposure B **;

   proc transpose data=longHist3 out=wideExpB;
      by &id.;
      id &exposure_b.name;
      var &exposure_b.;
   run;



   ** Transpose history A **;

   proc transpose data=longHist3 out=wideHistA;
      by &id.;
      id histName&exposure_a.;
      var &name_history_a.;
   run;


   ** Transpose history B **;

   proc transpose data=longHist3 out=wideHistB;
      by &id.;
      id histName&exposure_b.;
      var &name_history_b.;
   run;



   ** Merge the four wide datasets together **;

   data wideFull;
      merge wideExpA(drop=_name_) wideExpB(drop=_name_) wideHistA(drop=_name_) wideHistB(drop=_name_);
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





%mend makehistory_two;  /* End the makehistory_two macro */




** End of Program **;


