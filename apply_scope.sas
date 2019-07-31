/* Erin Schnellinger */
/* Covariate Balance Project */

/* "Apply_scope" Macro */

/* Balance successfully passed testBalanceWApplyScope tests on 30 July 2019 */


** Start the apply_scope macro **;

%macro apply_scope(input, output, diagnostic, approach, scope=all,
                   sort_order=alphabetical, ignore_missing_metric=no, metric=SMD, 
                   average_over=NULL, periods=NULL, list_distance=NULL, recency=NULL);

		   
*------------------------------------------*;
* Apply the ignore_missing_metric argument *;
*------------------------------------------*;

%if &ignore_missing_metric. eq yes %then %do;

    %if &metric. eq SMD %then %do;
	    data &input.;
		   set &input.;
		   where SMD ne . ;  /* Remove observations with missing SMD values */
		run;
	%end;

	%if &metric. eq D %then %do;
	    data &input.;
		   set &input.;
		   where D ne . ;   /* Remove observations with missing D values */
		run;
	%end;

%end;




			   
*---------------------------*;
* Scope = all               *;
*---------------------------*;

%if &scope. eq all %then %do;

    data final_table;  /* final_table = sub_table */
	   set &input.;
	run;

%end;






*---------------------------*;
* Scope = average           *;
*---------------------------*;



%if &scope. eq average %then %do;
    
    %if &average_over. eq values OR &average_over. eq strata OR &average_over. eq history OR
        &average_over. eq time OR &average_over. eq distance OR &average_over. eq NULL %then %do;
	    
	    ** Count the number of unique exposure values **;

		proc sql noprint;
		   create table expCount as
              select count(unique(&exposure.)) as unique_exposure 
              from sub_table;
        quit;

		data _NULL_;
		   set expCount;
		   %LET uniqueExp_length = unique_exposure;  /* Create a macro variable for the count of unique exposure values */
        run;


		** Create final table based on the unique exposure count **;

		%if &&uniqueExp_length. eq 1 %then %do;
		    data final_table;  /* Final table = sub table */
	           set sub_table;
		    run;
		%end;


		%if &&uniqueExp_length. ne 1 %then %do;
		    
		    ** Sort the sub_table based on the approach and diagnostic chosen **;

		    %if &approach. ne stratify %then %do;
			    proc sort data=sub_table out=grouped_table;
                   by &&history_. time_exposure time_covariate name_cov; 
				run;
			%end;

			%if &approach. eq stratify AND &diagnostic. eq 2 %then %do;
			    proc sort data=sub_table out=grouped_table;
                   by &&strata_. time_exposure time_covariate name_cov; 
				run;
			%end;

			%if &approach. eq stratify AND &diagnostic. eq 3 %then %do;
			    proc sort data=sub_table out=grouped_table;
                   by &&strata_. &&history_. time_exposure time_covariate name_cov; 
				run;
			%end;

			
			** Calculate the product of D and Nexp and of SMD and Nexp **;

			data grouped_table2;
			   set grouped_table;
               D_x_Nexp = D*Nexp;
			   SMD_x_Nexp = SMD*Nexp;
			run;


			** Find the sums of the product variables, Nexp, and N **;

			%if &approach. ne stratify %then %do;
			    proc means data=grouped_table2 SUM noprint;
	               class &&history_. time_exposure time_covariate name_cov; 
	               var D_x_Nexp SMD_x_Nexp Nexp N;
	               output out=grouped_table3 SUM=sumDxNexp sumSMDxNexp sumNexp sumN;
	            run;
			%end;

            %if &approach. eq stratify AND &diagnostic. eq 2 %then %do;
			    proc means data=grouped_table2 SUM noprint;
	               class &&strata_. time_exposure time_covariate name_cov;
	               var D_x_Nexp SMD_x_Nexp Nexp N;
	               output out=grouped_table3 SUM=sumDxNexp sumSMDxNexp sumNexp sumN;
	            run;
			%end;

			%if &approach. eq stratify AND &diagnostic. eq 3 %then %do;
			    proc means data=grouped_table2 SUM noprint;
	               class &&strata_. &&history_. time_exposure time_covariate name_cov; 
	               var D_x_Nexp SMD_x_Nexp Nexp N;
	               output out=grouped_table3 SUM=sumDxNexp sumSMDxNexp sumNexp sumN;
	            run;
			%end;


			** Update the summary statistics and create the final table **;

			data final_table(drop=_TYPE_ _FREQ_ sumDxNexp sumSMDxNexp sumNexp sumN);
			   set grouped_table3;

			   D = sumDxNexp/sumNexp;
			   SMD = sumSMDxNexp/sumNexp;
			   Nexp = sumNexp;
			   N = sumN;

			   ** Remove missing observations that were created by PROC MEANS from the output data set **;

			   %if &approach. ne stratify %then %do;
			       if missing(&&history_.) OR missing(time_exposure) OR missing(time_covariate) OR missing(name_cov) then delete;  
			   %end;

			   %if &approach. eq stratify and &diagnostic. eq 2 %then %do;
			       if missing(&&strata_.) OR missing(time_exposure) OR missing(time_covariate) OR missing(name_cov) then delete;  
			   %end;

			    %if &approach. eq stratify and &diagnostic. eq 3 %then %do;
			       if missing(&&strata_.) OR missing(&&history_.) OR missing(time_exposure) OR missing(time_covariate) OR missing(name_cov) then delete;  
			   %end;
			run;
		%end;
    %end;



	%if &average_over. eq strata OR &average_over. eq history OR &average_over. eq time OR 
        &average_over. eq distance OR &average_over. eq NULL %then %do;


		** Generate list of variables in final_table data set **;

        proc contents data=final_table out=finalTableVar(keep=VARNUM NAME) varnum noprint;
        run;

        proc sort data=finalTableVar out=finalTableVarSort;
           by varnum;
        run;

        data finalTableVar2;
           set finalTableVarSort;
        run;

        proc transpose data=finalTableVar2 out=finalTableVarWide(drop=_NAME_ _LABEL_);
	       id varnum; 
	       var NAME;
        run;


		** Create macro variable for list of variables in final_table **;

        data _NULL_;
	       set finalTableVarWide;

           finalTableVarNames=CATX(" ",OF _:);

	       %LOCAL finalTableVarList;
	       CALL SYMPUT ('finalTableVarList',finalTableVarNames);
        run;


        ** Check if strata variable is in the final table variable list **;

		%if &&strata_. in(&&finalTableVarList.) %then %do;
		   
		   %if &diagnostic. eq 2 %then %do;  /* For diagnostic 2, group by exposure time, covariate time, covariate name */
		       proc sort data=final_table out=grouped_table;
			      by time_exposure time_covariate name_cov;  
			   run;
		   %end;

		   %if &diagnostic. eq 3 %then %do;  /* For diagnostic 3, group by history, exposure time, covariate time, covariate name */
		       proc sort data=final_table out=grouped_table;
			      by &&history_. time_exposure time_covariate name_cov;
			   run;
		   %end;


		   ** Calculate the product of D and N and of SMD and N **;

			data grouped_table2;
			   set grouped_table;
               D_x_N = D*N;
			   SMD_x_N = SMD*N;
			run;


			** Find the sums of the product variables, Nexp, and N **;

            %if &diagnostic. eq 2 %then %do;
			    proc means data=grouped_table2 SUM noprint;
	               class time_exposure time_covariate name_cov;
	               var D_x_N SMD_x_N Nexp N;
	               output out=grouped_table3 SUM=sumDxN sumSMDxN sumNexp sumN;
	            run;
			%end;

			%if &diagnostic. eq 3 %then %do;
			    proc means data=grouped_table2 SUM noprint;
	               class &&history_. time_exposure time_covariate name_cov; 
	               var D_x_N SMD_x_N Nexp N;
	               output out=grouped_table3 SUM=sumDxN sumSMDxN sumNexp sumN;
	            run;
			%end;


			** Update the summary statistics and create the final table **;

			data final_table(drop=_TYPE_ _FREQ_ sumDxN sumSMDxN sumNexp sumN);
			   set grouped_table3;

			   D = sumDxN/sumN;
			   SMD = sumSMDxN/sumN;
			   Nexp = sumNexp;
			   N = sumN;

			   ** Remove missing observations that were created by PROC MEANS from the output data set **;

			   %if &diagnostic. eq 2 %then %do;
			       if missing(time_exposure) OR missing(time_covariate) OR missing(name_cov) then delete;  
			   %end;

			    %if &diagnostic. eq 3 %then %do;
			       if missing(&&history_.) OR missing(time_exposure) OR missing(time_covariate) OR missing(name_cov) then delete;  
			   %end;
			run;
		%end;
	%end;




	%if &average_over. eq history OR &average_over. eq time OR 
        &average_over. eq distance OR &average_over. eq NULL %then %do;


		 ** Check if history variable is in the final table variable list **;

		%if &&history_. in(&&finalTableVarList.) %then %do;

		   proc sort data=final_table out=grouped_table4;  /* Group by exposure time, covariate time, covariate name */
			  by time_exposure time_covariate name_cov;  
		   run;


		   ** Calculate the product of D and N and of SMD and N **;

			data grouped_table5;
			   set grouped_table4;
               D_x_N = D*N;
			   SMD_x_N = SMD*N;
			run;


		   ** Find the sums of the product variables and N **;

		   proc means data=grouped_table5 SUM noprint;
	          class time_exposure time_covariate name_cov;
	          var D_x_N SMD_x_N N;
	          output out=grouped_table6 SUM=sumDxN sumSMDxN sumN;
	       run;


		   ** Update the summary statistics and create the final table **;

			data final_table(drop=_TYPE_ _FREQ_ sumDxN sumSMDxN sumN);
			   set grouped_table6;

			   D = sumDxN/sumN;
			   SMD = sumSMDxN/sumN;
			   N = sumN;

			   ** Remove missing observations that were created by PROC MEANS from the output data set **;

			   if missing(time_exposure) OR missing(time_covariate) OR missing(name_cov) then delete;  
	
			run;
		%end;
	%end;



	%if &average_over. eq time OR &average_over. eq distance OR &average_over. eq NULL %then %do;

	    ** Calculate the distance and time variables **;

	    %if &diagnostic. eq 1 OR &diagnostic. eq 3 %then %do;
		    data final_dt;
			   set final_table;
			   distance = time_exposure-time_covariate;  /* Exposure time minus covariate time */
			   time = time_covariate;  /* Covariate time (numeric) */
			run;
		%end;

		%if &diagnostic. eq 2 %then %do;
		    data final_dt;
			   set final_table;
			   distance = time_covariate-time_exposure;  /* Covariate time minus exposure time */
			   time = time_exposure;  /* Exposure time (numeric) */
			run;
		%end;


		** Sort the final_dt data by distance and covariate name **;

		proc sort data=final_dt out=final_dt2;
		   by distance name_cov;
		run;


		** Calculate the product of D and N and of SMD and N **;

		data final_dt3;
		   set final_dt2;
           D_x_N = D*N;
		   SMD_x_N = SMD*N;
		run;


		** Find the sums of the product variables and N **;

		proc means data=final_dt3 SUM noprint;
	       class distance name_cov;
	       var D_x_N SMD_x_N N;
	       output out=final_dt4 SUM=sumDxN sumSMDxN sumN;
	    run;


		** Update the summary statistics and create the final table **;

	    data final_table(drop=_TYPE_ _FREQ_ sumDxN sumSMDxN sumN);
		   set final_dt4;

		   D = sumDxN/sumN;
		   SMD = sumSMDxN/sumN;
		   N = sumN;

		   ** Remove missing observations that were created by PROC MEANS from the output data set **;

		   if missing(distance) OR missing(name_cov) then delete;  
	
		run;


		** Filter by list_distance, if applicable **;

		%if &list_distance. ne NULL %then %do;
		    data final_table;
			   set final_table;
			   where distance in(&list_distance.);
			run;
		%end;

	%end;



	%if &average_over. eq distance %then %do;

	    ** Create the period table **;

	    %if &periods. ne NULL %then %do;

            ** Get the number of period segments inputted into "periods" **;

            data _NULL_;
               set final_table;

	           %LET periodSeg = %sysfunc(countw(&periods., ' '));  /* Count the total number of period segments */

	           %do i=1 %to &&periodSeg;  
	               %LET periodSeg&&i = %scan(&periods., &&i, ' ');  /* Grab the individual period segments */
               %end;
		    run;


            ** Obtain the minimum and maximum of each segment, if appropriate **;

		    data make_period;
		       set final_table;

		       %do i=1 %to &&periodSeg;
                   period_id = &&i.;  /* Establish period id for reference */
 
                   %if %sysfunc(countw(&&periodSeg&i, ':'))>1 %then %do;  /* Colon is present --> A range has been specified */ 
                       period_start = %scan(&&periodSeg&i, 1, ':');  /* Minimum segment value */
				       period_end = %scan(&&periodSeg&i, -1, ':');  /* Maximum segment value */
				       output;
	               %end;

			       %else %do;  /* No colon is present --> No range was specified */
			           period_start = &&periodSeg&i;  /* Constant segment value */
				       period_end = &&periodSeg&i;  /* Constant segment value */
				       output;
	               %end;
			    %end;
		     run;


		    ** Keep observations from final_table with distance values between period_start and period_end **;

		    data period_table;
		       set make_period;
               where distance>=period_start AND distance <=period_end;
            run;
		%end;


		%if &periods. eq NULL %then %do;

		    ** Select unique distance values from final_table **;

		    proc sql noprint;
		      create table uniqueDist as
                 select unique(distance) as distance, min(distance) as minDist, max(distance) as maxDist
                 from final_table;
            quit;


			** Initialize the period_id, period_start, and period_end variables **;

			data make_period;
			   set uniqueDist;
               period_id = 1;   
               period_start = minDist;
			   period_end = maxDist;
			run;


			** Merge the make_period data set with final_table **;

			data make_period2;
			   merge final_table make_period;
			   by distance;
			run;


			** Keep observations from final_table with distance values between period_start and period_end **;

		    data period_table;
		       set make_period2;
               where distance>=period_start AND distance <=period_end;
            run;
		%end;


		** Sort the period table by period id, period start, period end, and covariate name **;

		proc sort data=period_table out=period_table2;
		   by period_id period_start period_end name_cov;
		run;


		** Calculate the product of D and N and of SMD and N **;

		data period_table3;
		   set period_table2;
           D_x_N = D*N;
		   SMD_x_N = SMD*N;
		run;


		** Find the sums of the product variables and N **;

		proc means data=period_table3 SUM noprint;
	       class period_id period_start period_end name_cov;
	       var D_x_N SMD_x_N N;
	       output out=period_table4 SUM=sumDxN sumSMDxN sumN;
	    run;


		** Update the summary statistics and create the final table **;

	    data final_table(drop=_TYPE_ _FREQ_ sumDxN sumSMDxN sumN);
		   set period_table4;

		   D = sumDxN/sumN;
		   SMD = sumSMDxN/sumN;
		   N = sumN;

		   ** Remove missing observations that were created by PROC MEANS from the output data set **;

		   if missing(period_id) OR missing(period_start) OR missing(period_end) OR missing(name_cov) then delete;  
	
		run;

	%end;

%end;







*---------------------------*;
* Scope = recent            *;
*---------------------------*;

%if &scope. eq recent %then %do;

    ** Set the value of k **;

    data sub_table2;
	   set sub_table;

       %if &recency. eq 0 %then %do;
           if &diagnostic. ne 2 then k = 0;  /* For diagnostics 1 and 3 */
		   if &diagnostic. eq 2 then k = 1;  /* For diagnostic 2 */
	   %end;

	   %if &recency. ne 0 %then %do;
	       k = &recency.; 
	   %end;
	run;


	** Calculate exposure time minus k and covariate time minus k **;

	data sub_table3;
	   set sub_table2;
	   texp_minus_k = time_exposure - k;
	   tcov_minus_k = time_covariate - k;
	run;


	** Select the appropriate observations from sub_table **;

	%if &diagnostic. ne 2 %then %do;  /* For diagnostics 1 and 3 */
	    data final_table(drop=k texp_minus_k tcov_minus_k);
           set sub_table3;
           where texp_minus_k eq time_covariate;  /* Where (exposure time - k) == covariate time */
        run;
    %end;

	%if &diagnostic. eq 2 %then %do;  /* For diagnostic 2 */
	    data final_table(drop=k texp_minus_k tcov_minus_k);
           set sub_table3;
           where time_exposure eq tcov_minus_k;  /* Where exposure time == (covariate time - k) */
        run;
    %end;

%end;



*---------------------------*;
* Final Output              *;
*---------------------------*;

   ** Obtain a list of the variables in the final_table data set **;

   proc contents data=final_table out=finalVar(keep=VARNUM NAME) varnum noprint;
   run;

   proc sort data=finalVar out=finalVarSort;
      by varnum;
   run;

   data finalVar2;
      set finalVarSort;
   run;

   proc transpose data=finalVar2 out=finalVarWide(drop=_NAME_ _LABEL_);
	  id varnum; 
	  var NAME;
   run;


   ** Create macro variable for list of variables in final_table data set **;

   data _NULL_;
	  set finalVarWide;

      finalVarNames=CATX(" ",OF _:);

	  %LOCAL finalVarList;
	  CALL SYMPUT ('finalVarList',finalVarNames);  /* Create macro variable for list of variables in final data set */
   run;


   ** Compare final data variable list to the appropriate prefix, and replace with generic names if appropriate **;

   proc datasets lib=work nolist;
      modify final_table;

      %if &exposure. ne  AND &exposure. ne NULL %then %do;  
          %if %eval(&exposure. in(&&finalVarList.)) %then %do;  /* Exposure is present in the final data set */
              rename &exposure.=E;
	      %end;	  
      %end;

      %if &&history_. ne  AND &&history_. ne NULL %then %do;  
          %if %eval(&&history_. in(&&finalVarList.)) %then %do;  /* History is present in the final data set */
              rename &&history_.=H;
	      %end;	  
      %end;

      %if &&strata_. ne  AND &&strata_. ne NULL %then %do;  
          %if %eval(&&strata_. in(&&finalVarList.)) %then %do;  /* Strata is present in the final data set */
              rename &&strata_.=S;
	      %end;	  
      %end;

      %if &&weight_exposure_. ne  AND &&weight_exposure_. ne NULL %then %do;  
          %if %eval(&&weight_exposure_. in(&&finalVarList.)) %then %do;  /* Exposure weight is present in the final data set */
              rename &&weight_exposure_.=W_a;
	      %end;	  
      %end;

      %if &&weight_censor_. ne  AND &&weight_censor_. ne NULL %then %do;  
          %if %eval(&&weight_censor_. in(&&finalVarList.)) %then %do;  /* Censor weight is present in the final data set */
              rename &&weight_censor_.=W_s;
	      %end;	  
      %end;

   run;
   quit;



** Sort the final_table by the user-defined sort order, if applicable **;

%if &sort_order. ne  AND &sort_order. ne NULL AND &sort_order. ne alphabetical %then %do;
    data sortCovCount;
       set &input;

	   %LET numSC = %sysfunc(countw(&sort_order., ' '));  /* Count the total number of covariates */

	   %do i=1 %to &&numSC.;  
	       %LET cov&&i = %scan(&sort_order.,&&i, ' ');  /* Grab the individual covariates */
       %end;
    run;


    ** Create sorted covariate names data set **;

    proc IML;
	   cov = {&sort_order.};

	   %do i=1 %to &&numSC.;
           covar&&i. = J(1,1,"&&cov&i.");  /* Set up separate 1 x 1 matrices for each covariate name */ 
           column_name = "name_cov";  /* Create column name */

           CREATE sort_cov_names_dataset&&i. FROM covar&&i. [COLNAME=column_name];  /* Create covariate names data sets */
           APPEND FROM covar&&i.;
           CLOSE sort_cov_names_dataset&&i.;
	   %end;
    quit;


    ** Merge the sorted covariate names datasets together **;

    data sort_cov_names_all;
       set sort_cov_names_dataset1-sort_cov_names_dataset&&numSC.;
    run;


    ** Assign an order number to each observation **;

    data orderCov;
       set sort_cov_names_all;
	   covariate_order = _N_;
    run;


	** Merge the orderCov data set with the final_table data set to ensure covariates are sorted in the proper order **;

	proc sort data=orderCov;
	   by name_cov;
	run;

	proc sort data=final_table;
	   by name_cov;
	run;

	data final_table;
	   merge final_table(in=a) orderCov(in=b);
	   by name_cov;
	   if a AND b;
	run;


	** Sort the final_table again by the index variables **;

	** Create macro variable for list of variables in new final_table data set **;

	proc contents data=final_table out=finalVar(keep=VARNUM NAME) varnum noprint;
    run;

    proc sort data=finalVar out=finalVarSort;
       by varnum;
    run;

    data finalVar2;
       set finalVarSort;
    run;

    proc transpose data=finalVar2 out=finalVarWide(drop=_NAME_ _LABEL_);
	   id varnum; 
	   var NAME;
    run;


    data _NULL_;
	   set finalVarWide;

       finalVarNames=CATX(" ",OF _:);

	   %LOCAL finalVarList2;
	   CALL SYMPUT ('finalVarList2',finalVarNames);  /* Create macro variable for list of variables in new final data set */
    run;

	
 
    %if %eval(E in(&&finalVarList2.)) AND %eval(S in(&&finalVarList2.)) AND %eval(H in(&&finalVarList2.)) %then %do;  /* Exposure, strata, and history are present in the final data set */
        proc sort data=final_table;
	       by E S H covariate_order name_cov time_exposure time_covariate;
	    run;
    %end;	

    %if %eval(E in(&&finalVarList2.)) AND %eval(S in(&&finalVarList2.)) AND NOT %eval(H in(&&finalVarList2.)) %then %do;  /* Exposure and strata are present in the final data set */
        proc sort data=final_table;
	       by E S covariate_order name_cov time_exposure time_covariate;
	    run;
    %end;	 

    %if %eval(E in(&&finalVarList2.)) AND %eval(H in(&&finalVarList2.)) AND NOT %eval(S in(&&finalVarList2.)) %then %do;  /* Exposure and history are present in the final data set */
        proc sort data=final_table;
	       by E H covariate_order name_cov time_exposure time_covariate;
	    run;
    %end;


	%if NOT %eval(E in(&&finalVarList2.)) AND %eval(S in(&&finalVarList2.)) AND NOT %eval(H in(&&finalVarList2.)) %then %do;  /* Only strata is present in the final data set */
        proc sort data=final_table;
	       by S covariate_order name_cov time_exposure time_covariate;
	    run;
    %end;

	%if NOT %eval(E in(&&finalVarList2.)) AND NOT %eval(S in(&&finalVarList2.)) AND %eval(H in(&&finalVarList2.)) %then %do;  /* Only history is present in the final data set */
        proc sort data=final_table;
	       by H covariate_order name_cov time_exposure time_covariate;
	    run;
    %end;

	%if NOT %eval(E in(&&finalVarList2.)) AND NOT %eval(S in(&&finalVarList2.)) AND NOT %eval(H in(&&finalVarList2.)) 
    AND NOT %eval(distance in(&&finalVarList2.)) AND NOT %eval(period_id in(&&finalVarList2.)) %then %do;  /* Only covariates and times are present in the final data set */
        proc sort data=final_table;
	       by covariate_order name_cov time_exposure time_covariate;
	    run;
    %end;



    %if %eval(distance in(&&finalVarList2.)) %then %do;  /* Distance is present in the final data set */
	    proc sort data=final_table;
		   by distance covariate_order name_cov;
		run;
	%end;

	%if %eval(period_id in(&&finalVarList2.)) %then %do;  /* Period is present in the final data set */
	    proc sort data=final_table;
		   by period_id period_start period_end covariate_order name_cov;
		run;
	%end;

%end;


** Numerical Precision: Round D and SMD to match the number of digits displayed in R **;

data final_table;
   set final_table;
   D = round(D, .000000001);
   SMD = round(SMD, .000000001);
run;


** If the 'output' argument is specified, then rename 'final_table' to the user-defined name **;

   %if &output. ne  AND &output. ne NULL %then %do;
       data &output.;  /* Label the output data set with the user-defined name */
          set final_table;
       run;
   %end;


%mend apply_scope;  /* End the apply_scope macro */




** End of Program **;
