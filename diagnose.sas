/* Erin Schnellinger */
/* Covariate Balance Project */

/* "Diagnose" Macro */

/* Successfully passed testDiagnose tests on 10 July 2019 */


** Start the diagnose macro **;

%macro diagnose(input, output, diagnostic, scope, censoring, id, times_exposure, times_covariate,
                exposure, temporal_covariate, approach=none, sort_order=alphabetical, loop=no, 
                ignore_missing_metric=no, metric=SMD, static_covariate=NULL, history=NULL, 
				weight_exposure=NULL, censor=NULL, weight_censor=NULL, strata=NULL, recency=NULL,
				average_over=NULL, periods=NULL, list_distance=NULL);



*-------------------------*;
* Apply the loop argument *;
*-------------------------*;

%if &loop. eq no %then %do; 

	/* Call the lengthen macro */
    %lengthen(input=&input., output=output_lengthen,  
              diagnostic=&diagnostic., censoring=&censoring.,
              id=&id., times_exposure=&times_exposure., times_covariate=&times_covariate.,
			  exposure=&exposure., temporal_covariate=&temporal_covariate., 
              static_covariate=&static_covariate., history=&history., weight_exposure=&weight_exposure., 
              censor=&censor., weight_censor=&weight_censor., strata=&strata.);

     /* Call the balance macro */
     %balance(input=output_lengthen, output=output_balance, 
              diagnostic=&diagnostic., approach=&approach.,
              censoring=&censoring., scope=&scope., times_exposure=&times_exposure., 
              times_covariate=&times_covariate., exposure=&exposure., history=&history., 
			  weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
              recency=&recency., average_over=&average_over., periods=&periods., list_distance=&list_distance.,
              sort_order=&sort_order., loop=&loop., ignore_missing_metric=&ignore_missing_metric., metric=&metric.); 


    /* Store the output from the loop_fxn macro */
	/*data output;
	   set output_balance;
	run;*/
	
    %if &output. ne  AND &output. ne NULL %then %do;
        data &output.;  /* Label the output data set with the user-defined name */ 
           set output_balance;
        run;
    %end;

    %else %do;
        data &input._diagnose;  /* Label the output data set with the default name */
           set output_balance;
        run;
    %end;

%end;



%else %if &loop. eq yes %then %do; 

   /* %if &loop_type. eq  OR &loop_type. eq NULL %then %do; */  /* &loop_type is missing  */
   /*     %put Please specify the type of loop: 1 to loop over covariates, 2 to loop over covariates and exposure times, 3 to loop over covariates and exposure/covariate measurement time pairs;
	    %ABORT;
    %end; */

%LET loop_type = 1;  /* Loop Type */

	%if &&loop_type. eq 1 %then %do;  /* Loop over covariates only */

	    ** Get the number of temporal covariates inputted into "temporal_covariate" **;

        %if &temporal_covariate. ne  AND &temporal_covariate. ne NULL %then %do;
            data covCount;
               set &input;

	           %LET numTempCov = %sysfunc(countw(&temporal_covariate., ' '));  /* Count the total number of temporal covariates */

	           %do i=1 %to &&numTempCov;  
	               %LET tempcov&&i = %scan(&temporal_covariate.,&&i, ' ');  /* Grab the individual temporal covariates */
               %end;
            run;
		%end;


		** Get the number of static covariates inputted into "static_covariate" **;

        %if &static_covariate. ne  AND &static_covariate. ne NULL %then %do;
            data covCount;
               set &input;

	           %LET numStatCov = %sysfunc(countw(&static_covariate., ' '));  /* Count the total number of static covariates */

	           %do i=1 %to &&numStatCov;  
	               %LET statcov&&i = %scan(&static_covariate.,&&i, ' ');  /* Grab the individual static covariates */
               %end;
            run;
		%end;


		** Call Lengthen and Balance using covariate [i] and all times_exposure and all times_covariate **;

		/* For temporal covariates */

		%if &temporal_covariate. ne  AND &temporal_covariate. ne NULL %then %do;

           %do iii=1 %to &&numTempCov.;

			   %if &&iii. = 1 %then %do;  /* For first covariate */

			       /* Call the lengthen macro */
                   %lengthen(input=&input., output=output_lengthen, 
                             diagnostic=&diagnostic., censoring=&censoring.,
                             id=&id., times_exposure=&times_exposure., times_covariate=&times_covariate.,
			                 exposure=&exposure., temporal_covariate=&&tempcov&iii., 
                             static_covariate=NULL, history=&history., weight_exposure=&weight_exposure., 
                             censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                   /* Call the balance macro */
                   %balance(input=output_lengthen, output=output_balance, 
                            diagnostic=&diagnostic., approach=&approach.,
                            censoring=&censoring., scope=&scope., times_exposure=&times_exposure., 
                            times_covariate=&times_covariate., exposure=&exposure., history=&history., 
			                weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                            recency=&recency., average_over=&average_over., periods=&periods., 
                            list_distance=&list_distance., sort_order=&sort_order., loop=&loop., 
                            ignore_missing_metric=&ignore_missing_metric., metric=&metric.); 


				   /* Store the output from the balance macro */
			       data temporal_baseoutput;
				      set output_balance;
			       run;
			   %end;


			   %else %if &&iii. > 1 %then %do;  /* For subsequent covariates */

			       /* Call the lengthen macro */
                   %lengthen(input=&input., output=output_lengthen,  
                             diagnostic=&diagnostic., censoring=&censoring.,
                             id=&id., times_exposure=&times_exposure., times_covariate=&times_covariate.,
			                 exposure=&exposure., temporal_covariate=&&tempcov&iii., 
                             static_covariate=NULL, history=&history., weight_exposure=&weight_exposure., 
                             censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                   /* Call the balance macro */
                   %balance(input=output_lengthen, output=output_balance,  
                            diagnostic=&diagnostic., approach=&approach.,
                            censoring=&censoring., scope=&scope., times_exposure=&times_exposure., 
                            times_covariate=&times_covariate., exposure=&exposure., history=&history., 
			                weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                            recency=&recency., average_over=&average_over., periods=&periods., 
                            list_distance=&list_distance.,
                            sort_order=&sort_order., loop=&loop., ignore_missing_metric=&ignore_missing_metric.,
                            metric=&metric.); 

				   /* Append the new balance output to the original balance output */
			       proc append base=temporal_baseoutput data=output_balance;
				   run;
			   %end;
		    %end;
		%end;



		/* For static covariates */

		%if &static_covariate. ne  AND &static_covariate. ne NULL %then %do;

		    /* Determine whether the temporal_baseoutput exists, and, if so, save it */
		    %if &temporal_covariate. ne  AND &temporal_covariate. ne NULL %then %LET save_ =temporal_baseoutput;
			%else %if &temporal_covariate. eq  OR &temporal_covariate. eq NULL %then %LET save_ = ;

           %do iii=1 %to &&numStatCov.;

			   %if &&iii. eq 1 %then %do;  /* For first covariate */

			       /* Call the lengthen macro */
                   %lengthen(input=&input., output=output_lengthen,  
                             diagnostic=&diagnostic., censoring=&censoring.,
                             id=&id., times_exposure=&times_exposure., times_covariate=&times_covariate.,
			                 exposure=&exposure., temporal_covariate=NULL, 
                             static_covariate=&&statcov&iii., history=&history., weight_exposure=&weight_exposure., 
                             censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                   /* Call the balance macro */
                   %balance(input=output_lengthen, output=output_balance,  
                            diagnostic=&diagnostic., approach=&approach.,
                            censoring=&censoring., scope=&scope., times_exposure=&times_exposure., 
                            times_covariate=&times_covariate., exposure=&exposure., history=&history., 
			                weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                            recency=&recency., average_over=&average_over., periods=&periods., 
                            list_distance=&list_distance., sort_order=&sort_order., loop=&loop., 
                            ignore_missing_metric=&ignore_missing_metric., metric=&metric.); 


				   /* Store the output from the balance macro */
			       data static_baseoutput;
				      set output_balance;
				   run;
			   %end;

			   %else %if &&iii. > 1 %then %do;  /* For subsequent covariates */

			       /* Call the lengthen macro */
                   %lengthen(input=&input., output=output_lengthen,  
                             diagnostic=&diagnostic., censoring=&censoring.,
                             id=&id., times_exposure=&times_exposure., times_covariate=&times_covariate.,
			                 exposure=&exposure., temporal_covariate=NULL, 
                             static_covariate=&&statcov&iii., history=&history., weight_exposure=&weight_exposure., 
                             censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                   /* Call the balance macro */
                   %balance(input=output_lengthen, output=output_balance,  
                            diagnostic=&diagnostic., approach=&approach.,
                            censoring=&censoring., scope=&scope., times_exposure=&times_exposure., 
                            times_covariate=&times_covariate., exposure=&exposure., history=&history., 
			                weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                            recency=&recency., average_over=&average_over., periods=&periods., 
                            list_distance=&list_distance.,
                            sort_order=&sort_order., loop=&loop., ignore_missing_metric=&ignore_missing_metric.,
                            metric=&metric.); 

				   /* Append the new balance output to the original static_baseoutput */
			       proc append base=static_baseoutput data=output_balance;
				   run;
			   %end;


            %end;
		%end;

   %end;  /* End for loop_type=1 */



   %if &&loop_type. eq 2 %then %do;  /* Loop over covariates and exposure times (Diagnostic 1|3) or covariate times (Diagnostic 2) */

	    ** Get the number of temporal covariates inputted into "temporal_covariate" **;

        %if &temporal_covariate. ne  AND &temporal_covariate. ne NULL %then %do;
            data covCount;
               set &input;

	           %LET numTempCov = %sysfunc(countw(&temporal_covariate., ' '));  /* Count the total number of temporal covariates */

	           %do i=1 %to &&numTempCov;  
	               %LET tempcov&&i = %scan(&temporal_covariate.,&&i, ' ');  /* Grab the individual temporal covariates */
               %end;
            run;
		%end;


		** Get the number of static covariates inputted into "static_covariate" **;

        %if &static_covariate. ne  AND &static_covariate. ne NULL %then %do;
            data covCount;
               set &input;

	           %LET numStatCov = %sysfunc(countw(&static_covariate., ' '));  /* Count the total number of static covariates */

	           %do i=1 %to &&numStatCov;  
	               %LET statcov&&i = %scan(&static_covariate.,&&i, ' ');  /* Grab the individual static covariates */
               %end;
            run;
		 %end;


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


		 ** Create times lists so that covariate times and exposure times can be compared **;

		 /* For exposure times */
		 proc IML;
            times = {&times_exposure.};  /* Use the times specified in the "times_exposure" macro variable */
            times_c = CHAR(times);

            CREATE exposure_times_dataset FROM times_c;  /* Create exposure times data set */
            APPEND FROM times_c;
            CLOSE exposure_times_dataset;
        quit;
	
        data _NULL_;
           set exposure_times_dataset;
           exposureTimes=CATX(", ",OF COL1-COL&&numTE.);

	       %LOCAL exposureTimeList;
	       CALL SYMPUT ('exposureTimeList',exposureTimes);  /* Create macro variable for list of exposure times */
        run;


		 /* For covariate times */
		 proc IML;
            times = {&times_covariate.};  /* Use the times specified in the "times_covariate" macro variable */
            times_c = CHAR(times);

            CREATE covariate_times_dataset FROM times_c;  /* Create exposure times data set */
            APPEND FROM times_c;
            CLOSE covariate_times_dataset;
        quit;
	
        data _NULL_;
           set covariate_times_dataset;
           covariateTimes=CATX(", ",OF COL1-COL&&numTC.);

	       %LOCAL covariateTimeList;
	       CALL SYMPUT ('covariateTimeList',covariateTimes);  /* Create macro variable for list of covariate times */
        run;

 


		 ** Call Lengthen and Balance using covariate[i] and times_exposure[j] **;
         ** and times_covariate <= times_exposure[j]                           **;

	     %if &diagnostic. eq 1 OR &diagnostic. eq 3 %then %do;

		     /* For temporal covariates */

		     %if &temporal_covariate. ne  AND &temporal_covariate. ne NULL %then %do;

                 %do iii=1 %to &&numTempCov.;  /* Loop over temporal covariates */

				     %do jjj=1 %to &&numTE.;   /* Loop over times_exposure */

					     /* Scan through covariate times and keep those <= exposure time[j] */
                         %do ccc=1 %to &&numTC; 
			                 %if &&numTC&ccc. <= &&numTE&jjj. %then %do;
							     %LET lasttime&&jjj. = &&ccc;  /* Last covariate time <= exposure time [j] */
							 %end;

							 %else %if &&numTC&ccc. > &&numTE&jjj. %then %goto leave;  /* Leave loop once condition fails */
						  %end;

						  %leave:

						  /* Create new covariate times list, only keeping times <= exposure time [j]*/
						  %if &&lasttime&jjj. eq 1 %then %do;  /* If only 1 time point meets criteria */
					          %LET shortcovTimeList&&jjj. = &&numTC1;
				          %end;

						  %else %if &&lasttime&jjj. > 0 %then %do;  /* If more than 1 time point meet criteria */
                              data _NULL_;
								 set &input.;
								 
								 %do ttt=1 %to &&lasttime&jjj.;
								     TC&&ttt. = &&numTC&ttt.;
								 %end;

								 shortcovTimes = CATX(" ",OF TC1-TC&&lasttime&jjj.);

								 %LOCAL shortcovTimesL;
	                             CALL SYMPUT ('shortcovTimesL',shortcovTimes);
							  run;

							  %LET shortcovTimeList&&jjj. = &&shortcovTimesL.;  /* Short covariate list for exposure time j */
                           %end; 


			             %if &&iii. = 1 AND &&jjj. = 1 %then %do;  /* For first covariate and first exposure time */

						     /* Call the lengthen macro */
                             %lengthen(input=&input., output=output_lengthen,  
                                       diagnostic=&diagnostic., censoring=&censoring.,
                                       id=&id., times_exposure=&&numTE&jjj., times_covariate=&&shortcovTimeList&jjj.,
			                           exposure=&exposure., temporal_covariate=&&tempcov&iii., 
                                       static_covariate=NULL, history=&history., weight_exposure=&weight_exposure., 
                                       censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                             /* Call the balance macro */
                             %balance(input=output_lengthen, output=output_balance,  
                                       diagnostic=&diagnostic., approach=&approach.,
                                       censoring=&censoring., scope=&scope., times_exposure=&&numTE&jjj., 
                                       times_covariate=&&shortcovTimeList&jjj., exposure=&exposure., history=&history., 
			                           weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                                       recency=&recency., average_over=&average_over., periods=&periods., 
                                       list_distance=&list_distance., sort_order=&sort_order., loop=&loop., 
                                       ignore_missing_metric=&ignore_missing_metric., metric=&metric.); 


				             /* Store the output from the balance macro */
			                 data temporal_baseoutput;
				                set output_balance;
				             run;
			             %end;


			             %else %if &&iii. = 1 AND &&jjj. > 1 %then %do;  /* For first covariate and subsequent exposure times */

						       /* Call the lengthen macro */
                               %lengthen(input=&input., output=output_lengthen, 
                                         diagnostic=&diagnostic., censoring=&censoring.,
                                         id=&id., times_exposure=&&numTE&jjj., times_covariate=&&shortcovTimeList&jjj.,
			                             exposure=&exposure., temporal_covariate=&&tempcov&iii., 
                                         static_covariate=NULL, history=&history., weight_exposure=&weight_exposure., 
                                         censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                               /* Call the balance macro */
                               %balance(input=output_lengthen, output=output_balance,   
                                        diagnostic=&diagnostic., approach=&approach.,
                                        censoring=&censoring., scope=&scope., times_exposure=&&numTE&jjj., 
                                        times_covariate=&&shortcovTimeList&jjj., exposure=&exposure., history=&history., 
			                            weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                                        recency=&recency., average_over=&average_over., periods=&periods., 
                                        list_distance=&list_distance.,
                                        sort_order=&sort_order., loop=&loop., ignore_missing_metric=&ignore_missing_metric.,
                                        metric=&metric.); 

				               /* Append the new balance output to the original balance output */
			                   proc append base=temporal_baseoutput data=output_balance force;  /* use FORCE option to ensure all records are appended */
				               run;
			             %end;



						  %else %if &&iii. > 1 %then %do;  /* For subsequent covariates */

						       /* Call the lengthen macro */
                               %lengthen(input=&input., output=output_lengthen,  
                                         diagnostic=&diagnostic., censoring=&censoring.,
                                         id=&id., times_exposure=&&numTE&jjj., times_covariate=&&shortcovTimeList&jjj.,
			                             exposure=&exposure., temporal_covariate=&&tempcov&iii., 
                                         static_covariate=NULL, history=&history., weight_exposure=&weight_exposure., 
                                         censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                               /* Call the balance macro */
                               %balance(input=output_lengthen, output=output_balance,  
                                        diagnostic=&diagnostic., approach=&approach.,
                                        censoring=&censoring., scope=&scope., times_exposure=&&numTE&jjj., 
                                        times_covariate=&&shortcovTimeList&jjj., exposure=&exposure., history=&history., 
			                            weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                                        recency=&recency., average_over=&average_over., periods=&periods., 
                                        list_distance=&list_distance.,
                                        sort_order=&sort_order., loop=&loop., ignore_missing_metric=&ignore_missing_metric.,
                                        metric=&metric.); 

				               /* Append the new balance output to the original balance output */
			                   proc append base=temporal_baseoutput data=output_balance force;  /* Use FORCE option to ensure all records are appended */
				               run;
			             %end;

	
				     %end;  /* End for jjj */
		         %end;  /* End for iii */
			 %end;  /* End for temporal covariates */


		   /* For static covariates */

		   %if &static_covariate. ne  AND &static_covariate. ne NULL %then %do;

		       /* Determine whether the temporal_baseoutput exists, and, if so, save it */
		       %if &temporal_covariate. ne  AND &temporal_covariate. ne NULL %then %LET save_ =temporal_baseoutput;
			   %else %if &temporal_covariate. eq  OR &temporal_covariate. eq NULL %then %LET save_ = ;


               %do iii=1 %to &&numStatCov.;  /* Loop over static covariates */

			       %do jjj=1 %to &&numTE.;   /* Loop over exposure times */

			           %if &&iii. eq 1 AND &&jjj. eq 1 %then %do;  /* For first covariate and first exposure time */

					       /* Call the lengthen macro */
                           %lengthen(input=&input., output=output_lengthen,  
                                     diagnostic=&diagnostic., censoring=&censoring.,
                                     id=&id., times_exposure=&&numTE&jjj., 
                                     times_covariate=%sysfunc(min(&&covariateTimeList.)),
			                         exposure=&exposure., temporal_covariate=NULL, 
                                     static_covariate=&&statcov&iii., history=&history., 
                                     weight_exposure=&weight_exposure., censor=&censor., 
                                     weight_censor=&weight_censor., strata=&strata.);

                           /* Call the balance macro */
                           %balance(input=output_lengthen, output=output_balance,  
                                    diagnostic=&diagnostic., approach=&approach.,
                                    censoring=&censoring., scope=&scope., times_exposure=&&numTE&jjj., 
                                    times_covariate=%sysfunc(min(&&covariateTimeList.)), 
                                    exposure=&exposure., history=&history., 
			                        weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                                    recency=&recency., average_over=&average_over., periods=&periods., 
                                    list_distance=&list_distance., sort_order=&sort_order., loop=&loop., 
                                    ignore_missing_metric=&ignore_missing_metric., metric=&metric.); 


				           /* Store the output from the balance macro */
			               data static_baseoutput;
				              set output_balance;
				           run;
			           %end;


					   %else %if &&iii. = 1 AND &&jjj. > 1 %then %do;  /* For first covariate and subsequent exposure times */

					       /* Call the lengthen macro */
                           %lengthen(input=&input., output=output_lengthen,  
                                     diagnostic=&diagnostic., censoring=&censoring.,
                                     id=&id., times_exposure=&&numTE&jjj., 
                                     times_covariate=%sysfunc(min(&&covariateTimeList.)),
			                         exposure=&exposure., temporal_covariate=NULL, 
                                     static_covariate=&&statcov&iii., history=&history., weight_exposure=&weight_exposure., 
                                     censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                           /* Call the balance macro */
                           %balance(input=output_lengthen, output=output_balance,  
                                    diagnostic=&diagnostic., approach=&approach.,
                                    censoring=&censoring., scope=&scope., times_exposure=&&numTE&jjj., 
                                    times_covariate=%sysfunc(min(&&covariateTimeList.)), 
                                    exposure=&exposure., history=&history., 
			                        weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                                    recency=&recency., average_over=&average_over., periods=&periods., 
                                    list_distance=&list_distance.,
                                    sort_order=&sort_order., loop=&loop., ignore_missing_metric=&ignore_missing_metric.,
                                    metric=&metric.); 

				           /* Append the new balance output to the original static_baseoutput */
			               proc append base=static_baseoutput data=output_balance force;  /* Use FORCE option to ensure all records are appended */
				           run;
			           %end;


			           %else %if &&iii. > 1 %then %do;  /* For subsequent covariates */

					       /* Call the lengthen macro */
                           %lengthen(input=&input., output=output_lengthen,  
                                     diagnostic=&diagnostic., censoring=&censoring.,
                                     id=&id., times_exposure=&&numTE&jjj., 
                                     times_covariate=%sysfunc(min(&&covariateTimeList.)),
			                         exposure=&exposure., temporal_covariate=NULL, 
                                     static_covariate=&&statcov&iii., history=&history., weight_exposure=&weight_exposure., 
                                     censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                           /* Call the balance macro */
                           %balance(input=output_lengthen, output=output_balance,  
                                    diagnostic=&diagnostic., approach=&approach.,
                                    censoring=&censoring., scope=&scope., times_exposure=&&numTE&jjj., 
                                    times_covariate=%sysfunc(min(&&covariateTimeList.)), 
                                    exposure=&exposure., history=&history., 
			                        weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                                    recency=&recency., average_over=&average_over., periods=&periods., 
                                    list_distance=&list_distance.,
                                    sort_order=&sort_order., loop=&loop., ignore_missing_metric=&ignore_missing_metric.,
                                    metric=&metric.); 

				           /* Append the new balance output to the original static_baseoutput */
			               proc append base=static_baseoutput data=output_balance force;  /* Use FORCE option to ensure all records are appended */
				           run;
			           %end;
				  %end;  /* End for jjj */
               %end;  /* End for iii */
		   %end;  /* End for static_covariates */

	   %end;  /* End for diagnostic 1 and 3 */



	   %if &diagnostic. eq 2 %then %do;

	       /* For temporal covariates */

		   %if &temporal_covariate. ne  AND &temporal_covariate. ne NULL %then %do;

                 %do iii=1 %to &&numTempCov.;  /* Loop over temporal covariates */

				     %do jjj=1 %to &&numTC.;   /* Loop over times_covariate */
						
						  /* Scan through exposure times and keep those < covariate time[j] */
                         %do eee=1 %to &&numTE; 
			                 %if &&numTE&eee. < &&numTC&jjj. %then %do;
							     %LET lasttime = &&eee;  /* Last exposure time < covariate time [j] */
							 %end;

							 %else %if &&numTE&eee. >= &&numTC&jjj. %then %goto leave2;  /* Exit loop when condition fails */
						  %end;

						  %leave2:

						  /* Create new exposure times list, only keeping times < covariate time [j]*/
						  %if &&lasttime. eq 1 %then %do;  /* If only 1 time point meets criteria */
					          %LET shortexpTimeList=&&numTE1;
				          %end;

						  %else %if &&lasttime. > 1 %then %do;  /* If more than 1 time point meet criteria */
                              data _NULL_;
								 set &input.;
								 
								 %do ttt=1 %to &&lasttime.;
								     TE&&ttt. = &&numTE&ttt.;
								 %end;

                                 exposureTimes=CATX(" ",OF TE1-TE&lasttime.);

	                             %LOCAL shortexpTimeList;
	                             CALL SYMPUT ('shortexpTimeList',exposureTimes); 
                              run;
                          %end;



			              %if &&iii. = 1 AND &&jjj. = 1 %then %do;  /* For first covariate and first covariate time */

						      /* Call the lengthen macro */
                              %lengthen(input=&input., output=output_lengthen,  
                                        diagnostic=&diagnostic., censoring=&censoring.,
                                        id=&id., times_exposure=&&shortexpTimeList., times_covariate=&&numTC&jjj.,
			                            exposure=&exposure., temporal_covariate=&&tempcov&iii., 
                                        static_covariate=NULL, history=&history., weight_exposure=&weight_exposure., 
                                        censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                              /* Call the balance macro */
                              %balance(input=output_lengthen, output=output_balance,  
                                       diagnostic=&diagnostic., approach=&approach.,
                                       censoring=&censoring., scope=&scope., times_exposure=&&shortexpTimeList., 
                                       times_covariate=&&numTC&jjj., exposure=&exposure., history=&history., 
			                           weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                                       recency=&recency., average_over=&average_over., periods=&periods., 
                                       list_distance=&list_distance., sort_order=&sort_order., loop=&loop., 
                                       ignore_missing_metric=&ignore_missing_metric., metric=&metric.); 


				              /* Store the output from the balance macro */
			                  data temporal_baseoutput;
				                 set output_balance;
				              run;
			               %end;

						   %else %if &&iii. = 1 AND &&jjj. > 1 %then %do;  /* For first covariate and subsequent covariate times */

						         /* Call the lengthen macro */
                                 %lengthen(input=&input., output=output_lengthen,  
                                           diagnostic=&diagnostic., censoring=&censoring.,
                                           id=&id., times_exposure=&&shortexpTimeList., times_covariate=&&numTC&jjj.,
			                               exposure=&exposure., temporal_covariate=&&tempcov&iii., 
                                           static_covariate=NULL, history=&history., weight_exposure=&weight_exposure., 
                                           censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                                 /* Call the balance macro */
                                %balance(input=output_lengthen, output=output_balance,  
                                         diagnostic=&diagnostic., approach=&approach.,
                                         censoring=&censoring., scope=&scope., times_exposure=&&shortexpTimeList., 
                                         times_covariate=&&numTC&jjj., exposure=&exposure., history=&history., 
			                             weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                                         recency=&recency., average_over=&average_over., periods=&periods., 
                                         list_distance=&list_distance.,
                                         sort_order=&sort_order., loop=&loop., ignore_missing_metric=&ignore_missing_metric.,
                                         metric=&metric.); 

				                /* Append the new balance output to the original balance output */
			                    proc append base=temporal_baseoutput data=output_balance force;  /* Use FORCE option to ensure all records are appended */
				                run;
			               %end;

			               %else %if &&iii. > 1 %then %do;  /* For subsequent covariates */

						         /* Call the lengthen macro */
                                 %lengthen(input=&input., output=output_lengthen,  
                                           diagnostic=&diagnostic., censoring=&censoring.,
                                           id=&id., times_exposure=&&shortexpTimeList., times_covariate=&&numTC&jjj.,
			                               exposure=&exposure., temporal_covariate=&&tempcov&iii., 
                                           static_covariate=NULL, history=&history., weight_exposure=&weight_exposure., 
                                           censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                                 /* Call the balance macro */
                                %balance(input=output_lengthen, output=output_balance,  
                                         diagnostic=&diagnostic., approach=&approach.,
                                         censoring=&censoring., scope=&scope., times_exposure=&&shortexpTimeList., 
                                         times_covariate=&&numTC&jjj., exposure=&exposure., history=&history., 
			                             weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                                         recency=&recency., average_over=&average_over., periods=&periods., 
                                         list_distance=&list_distance.,
                                         sort_order=&sort_order., loop=&loop., ignore_missing_metric=&ignore_missing_metric.,
                                         metric=&metric.); 

				                /* Append the new balance output to the original balance output */
			                    proc append base=temporal_baseoutput data=output_balance force;  /* Use FORCE option to ensure all records are appended */
				                run;
			               %end;

				       %end;  /* End for jjj */
		            %end;  /* End for iii */
			   %end;  /* End for temporal_covariates */

	      %end;  /* End for diagnostic 2 */

	%end;  /* End for loop_type=2 */




	%if &&loop_type. eq 3 %then %do;  /* Loop over covariates, exposure times, and covariate times */

	    ** Get the number of temporal covariates inputted into "temporal_covariate" **;

        %if &temporal_covariate. ne  AND &temporal_covariate. ne NULL %then %do;
            data covCount;
               set &input;

	           %LET numTempCov = %sysfunc(countw(&temporal_covariate., ' '));  /* Count the total number of temporal covariates */

	           %do i=1 %to &&numTempCov;  
	               %LET tempcov&&i = %scan(&temporal_covariate.,&&i, ' ');  /* Grab the individual temporal covariates */
               %end;
            run;
		%end;


		** Get the number of static covariates inputted into "static_covariate" **;

        %if &static_covariate. ne  AND &static_covariate. ne NULL %then %do;
            data covCount;
               set &input;

	           %LET numStatCov = %sysfunc(countw(&static_covariate., ' '));  /* Count the total number of static covariates */

	           %do i=1 %to &&numStatCov;  
	               %LET statcov&&i = %scan(&static_covariate.,&&i, ' ');  /* Grab the individual static covariates */
               %end;
            run;
		 %end;


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


		 ** Create times lists so that covariate times and exposure times can be compared **;

		 /* For exposure times */
		 proc IML;
            times = {&times_exposure.};  /* Use the times specified in the "times_exposure" macro variable */
            times_c = CHAR(times);

            CREATE exposure_times_dataset FROM times_c;  /* Create exposure times data set */
            APPEND FROM times_c;
            CLOSE exposure_times_dataset;
        quit;
	
        data _NULL_;
           set exposure_times_dataset;
           exposureTimes=CATX(", ",OF COL1-COL&&numTE.);

	       %LOCAL exposureTimeList;
	       CALL SYMPUT ('exposureTimeList',exposureTimes);  /* Create macro variable for list of exposure times */
        run;


		 /* For covariate times */
		 proc IML;
            times = {&times_covariate.};  /* Use the times specified in the "times_covariate" macro variable */
            times_c = CHAR(times);

            CREATE covariate_times_dataset FROM times_c;  /* Create exposure times data set */
            APPEND FROM times_c;
            CLOSE covariate_times_dataset;
        quit;
	
        data _NULL_;
           set covariate_times_dataset;
           covariateTimes=CATX(", ",OF COL1-COL&&numTC.);

	       %LOCAL covariateTimeList;
	       CALL SYMPUT ('covariateTimeList',covariateTimes);  /* Create macro variable for list of covariate times */
        run;


	     %if &diagnostic. eq 1 OR &diagnostic. eq 3 %then %do;

		     /* For temporal covariates */

		     %if &temporal_covariate. ne  AND &temporal_covariate. ne NULL %then %do;

                 %do iii=1 %to &&numTempCov.;  /* Loop over temporal covariates */

				     %do jjj=1 %to &&numTE.;   /* Loop over times_exposure */

					     %do mmm=1 %to &&numTC.;  /* Loop over times_covariate */

						     %if &&numTE&jjj. >= &&numTC&mmm. %then %do;  /* times_exposure[j] >= times_covariate[m] */				

			                     %if &&iii. = 1 AND &&jjj. = 1 AND &&mmm. = 1 %then %do;  /* For first covariate, times_exposure, and times_covariate */

								     /* Call the lengthen macro */
                                     %lengthen(input=&input., output=output_lengthen,  
                                               diagnostic=&diagnostic., censoring=&censoring.,
                                               id=&id., times_exposure=&&numTE&jjj., times_covariate=&&numTC&mmm.,
			                                   exposure=&exposure., temporal_covariate=&&tempcov&iii., 
                                               static_covariate=NULL, history=&history., weight_exposure=&weight_exposure., 
                                               censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                                     /* Call the balance macro */
                                     %balance(input=output_lengthen, output=output_balance,  
                                              diagnostic=&diagnostic., approach=&approach.,
                                              censoring=&censoring., scope=&scope., times_exposure=&&numTE&jjj., 
                                              times_covariate=&&numTC&mmm., exposure=&exposure., history=&history., 
			                                  weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                                              recency=&recency., average_over=&average_over., periods=&periods., 
                                              list_distance=&list_distance., sort_order=&sort_order., loop=&loop., 
                                              ignore_missing_metric=&ignore_missing_metric., metric=&metric.); 


				                     /* Store the output from the balance macro */
			                         data temporal_baseoutput;
				                        set output_balance;
				                     run;
			                     %end;


			                     %else /*%if &&iii. > 1 OR &&jjj. > 1 OR &&mmm. > 1 %then*/ %do;  /* For subsequent covariates */

								     /* Call the lengthen macro */
                                     %lengthen(input=&input., output=output_lengthen, 
                                               diagnostic=&diagnostic., censoring=&censoring.,
                                               id=&id., times_exposure=&&numTE&jjj., times_covariate=&&numTC&mmm.,
			                                   exposure=&exposure., temporal_covariate=&&tempcov&iii., 
                                               static_covariate=NULL, history=&history., weight_exposure=&weight_exposure., 
                                               censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                                     /* Call the balance macro */
                                     %balance(input=output_lengthen, output=output_balance,  
                                              diagnostic=&diagnostic., approach=&approach.,
                                              censoring=&censoring., scope=&scope., times_exposure=&&numTE&jjj., 
                                              times_covariate=&&numTC&mmm., exposure=&exposure., history=&history., 
			                                  weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                                              recency=&recency., average_over=&average_over., periods=&periods., 
                                              list_distance=&list_distance.,
                                              sort_order=&sort_order., loop=&loop., ignore_missing_metric=&ignore_missing_metric.,
                                              metric=&metric.); 

				                     /* Append the new balance output to the original balance output */
			                           proc append base=temporal_baseoutput data=output_balance force;  /* Use FORCE option to ensure all records are appended */
				                       run;
			                     %end;
		                     %end;
		                  %end;  /* End for mmm */
				       %end;  /* End for jjj */
		            %end;  /* End for iii */
				 %end;  /* End for temporal covariates */



		   /* For static covariates */

		   %if &static_covariate. ne  AND &static_covariate. ne NULL %then %do;

		       /* Determine whether the temporal_baseoutput exists, and, if so, save it */
		       %if &temporal_covariate. ne  AND &temporal_covariate. ne NULL %then %LET save_ =temporal_baseoutput;
			   %else %if &temporal_covariate. eq  OR &temporal_covariate. eq NULL %then %LET save_ = ;

               %do iii=1 %to &&numStatCov.;  /* Loop over static covariates */

			       %do jjj=1 %to &&numTE.;   /* Loop over exposure times */

			           %if &&iii. eq 1 AND &&jjj. eq 1 %then %do;  /* For first covariate and first exposure time */

					       /* Call the lengthen macro */
                           %lengthen(input=&input., output=output_lengthen,  
                                     diagnostic=&diagnostic., censoring=&censoring.,
                                     id=&id., times_exposure=&&numTE&jjj., 
                                     times_covariate=%sysfunc(min(&&covariateTimeList.)),
			                         exposure=&exposure., temporal_covariate=NULL, 
                                     static_covariate=&&statcov&iii., history=&history., 
                                     weight_exposure=&weight_exposure., censor=&censor., 
                                     weight_censor=&weight_censor., strata=&strata.);

                           /* Call the balance macro */
                           %balance(input=output_lengthen, output=output_balance,  
                                    diagnostic=&diagnostic., approach=&approach.,
                                    censoring=&censoring., scope=&scope., times_exposure=&&numTE&jjj., 
                                    times_covariate=%sysfunc(min(&&covariateTimeList.)), 
                                    exposure=&exposure., history=&history., 
			                        weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                                    recency=&recency., average_over=&average_over., periods=&periods., 
                                    list_distance=&list_distance., sort_order=&sort_order., loop=&loop., 
                                    ignore_missing_metric=&ignore_missing_metric., metric=&metric.); 


				           /* Store the output from the balance macro */
			               data static_baseoutput;
				              set output_balance;
				           run;
			           %end;


			           %else %do;  /* For subsequent covariates and/or exposure times */

					       /* Call the lengthen macro */
                           %lengthen(input=&input., output=output_lengthen,  
                                     diagnostic=&diagnostic., censoring=&censoring.,
                                     id=&id., times_exposure=&&numTE&jjj., 
                                     times_covariate=%sysfunc(min(&&covariateTimeList.)),
			                         exposure=&exposure., temporal_covariate=NULL, 
                                     static_covariate=&&statcov&iii., history=&history., weight_exposure=&weight_exposure., 
                                     censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                           /* Call the balance macro */
                           %balance(input=output_lengthen, output=output_balance,  
                                    diagnostic=&diagnostic., approach=&approach.,
                                    censoring=&censoring., scope=&scope., times_exposure=&&numTE&jjj., 
                                    times_covariate=%sysfunc(min(&&covariateTimeList.)), 
                                    exposure=&exposure., history=&history., 
			                        weight_exposure=&weight_exposure., weight_censor=&weight_censor., strata=&strata.,
                                    recency=&recency., average_over=&average_over., periods=&periods., 
                                    list_distance=&list_distance.,
                                    sort_order=&sort_order., loop=&loop., ignore_missing_metric=&ignore_missing_metric.,
                                    metric=&metric.); 

				           /* Append the new balance output to the original static_baseoutput */
			               proc append base=static_baseoutput data=output_balance force;  /* Use FORCE option to ensure all records are appended */
				           run;
			           %end;

				  %end;  /* End for jjj */
               %end;  /* End for iii */
		   %end;  /* End for static_covariates */

	   %end;  /* End for diagnostic 1 and 3 */



	   %if &diagnostic. eq 2 %then %do;

	       /* For temporal covariates */

		   %if &temporal_covariate. ne  AND &temporal_covariate. ne NULL %then %do;

                 %do iii=1 %to &&numTempCov.;  /* Loop over temporal covariates */

				     %do jjj=1 %to &&numTC.;   /* Loop over times_covariate */

					     %do mmm=1 %to &&numTE.;  /* Loop over times_exposure */

						     %if &&numTC&jjj. > &&numTE&mmm. %then %do;  /* times_covariate[j] > times_exposure[m] */

			                     %if &&iii. = 1 AND &&jjj. = 1 AND &&mmm. = 1 %then %do;  /* For first covariate, times_covariate, and times_exposure */

								     /* Call the lengthen macro */
                                     %lengthen(input=&input., output=output_lengthen,  
                                               diagnostic=&diagnostic., censoring=&censoring.,
                                               id=&id., times_exposure=&&numTE&mmm., times_covariate=&&numTC&jjj.,
			                                   exposure=&exposure., temporal_covariate=&&tempcov&iii., 
                                               static_covariate=NULL, history=&history., weight_exposure=&weight_exposure., 
                                               censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                                     /* Call the balance macro */
                                     %balance(input=output_lengthen, output=output_balance,  
                                              diagnostic=&diagnostic., approach=&approach.,
                                              censoring=&censoring., scope=&scope., times_exposure=&&numTE&mmm., 
                                              times_covariate=&&numTC&jjj., exposure=&exposure., history=&history., 
			                                  weight_exposure=&weight_exposure., weight_censor=&weight_censor., 
                                              strata=&strata., recency=&recency., average_over=&average_over., 
                                              periods=&periods., list_distance=&list_distance., 
                                              sort_order=&sort_order., loop=&loop., 
                                              ignore_missing_metric=&ignore_missing_metric., metric=&metric.); 


				                     /* Store the output from the balance macro */
			                         data temporal_baseoutput;
				                        set output_balance;
				                     run;
			                     %end;


			                     %else %do;  /* For subsequent covariates and/or times */

								       /* Call the lengthen macro */
                                       %lengthen(input=&input., output=output_lengthen,  
                                                 diagnostic=&diagnostic., censoring=&censoring.,
                                                 id=&id., times_exposure=&&numTE&mmm., times_covariate=&&numTC&jjj.,
			                                     exposure=&exposure., temporal_covariate=&&tempcov&iii., 
                                                 static_covariate=NULL, history=&history., 
                                                 weight_exposure=&weight_exposure., 
                                                 censor=&censor., weight_censor=&weight_censor., strata=&strata.);

                                       /* Call the balance macro */
                                       %balance(input=output_lengthen, output=output_balance,  
                                                diagnostic=&diagnostic., approach=&approach.,
                                                censoring=&censoring., scope=&scope., times_exposure=&&numTE&mmm., 
                                                times_covariate=&&numTC&jjj., exposure=&exposure., history=&history., 
			                                    weight_exposure=&weight_exposure., weight_censor=&weight_censor., 
                                                strata=&strata., recency=&recency., average_over=&average_over., 
                                                periods=&periods., list_distance=&list_distance.,
                                                sort_order=&sort_order., loop=&loop., 
                                                ignore_missing_metric=&ignore_missing_metric., metric=&metric.); 

				                       /* Append the new balance output to the original balance output */
			                           proc append base=temporal_baseoutput data=output_balance force;  /* Use FORCE option to ensure all records are appended */
				                       run;
			                     %end;

		                     %end;
		                  %end;  /* End for mmm */
				       %end;  /* End for jjj */
		            %end;  /* End for iii */
				%end;  /* End for temporal_covariates */

	      %end;  /* End for diagnostic 2 */

	%end;  /* End for loop_type=3 */



	*--------------------------------------------------*;
	* Combine the temporal and static output data sets *;
	*--------------------------------------------------*;

	%if &diagnostic. eq 2 %then %do;  /* Only look at temporal covariates */
	    data baseoutput;
		   set temporal_baseoutput;
		run;
	%end;

	%if &diagnostic. ne 2 AND &temporal_covariate. ne  AND &temporal_covariate. ne NULL AND (&static_covariate. eq  OR &static_covariate. eq NULL) %then %do;
		data baseoutput;
		   set temporal_baseoutput;
		run;
	%end;

	%if &diagnostic. ne 2 AND &static_covariate. ne  AND &static_covariate. ne NULL AND (&temporal_covariate. eq  OR &temporal_covariate. eq NULL) %then %do;
		data baseoutput;
		   set static_baseoutput;
		run;
	%end;

	%if &diagnostic. ne 2 AND &temporal_covariate. ne  AND &temporal_covariate. ne NULL AND &static_covariate. ne  AND &static_covariate. ne NULL %then %do;
		data baseoutput;
		   set temporal_baseoutput static_baseoutput;
		run;
	%end;
	   

	*----------------------------*;
	* Call the apply_scope macro *;
	*----------------------------*;

	%apply_scope(input=baseoutput, diagnostic=&diagnostic., approach=&approach., scope=&scope.,
                 sort_order=&sort_order., ignore_missing_metric=&ignore_missing_metric., 
                 metric=&metric., average_over=&average_over., periods=&periods., 
                 list_distance=&list_distance., recency=&recency.); 

	/* Store the output of the apply_scope macro as "output" */
	/*data output;  
	   set final_table;
	run;*/
	
	%if &output. ne  AND &output. ne NULL %then %do;
        data &output.;  /* Label the output data set with the user-defined name */ 
           set final_table;
        run;
    %end;

    %else %do;
        data &input._diagnose;  /* Label the output data set with the default name */
           set final_table;
        run;
    %end;


%end;  /* End for loop=yes */



%mend diagnose;  /* End the diagnose macro */




** End of Program **;
