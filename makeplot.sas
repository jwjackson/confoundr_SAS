/* Erin Schnellinger */
/* Covariate Balance Project */

/* "makeplot" Macro */


** Start the makeplot macro **;

%macro makeplot(input, output, diagnostic, approach, scope, metric=SMD, average_over=NULL, stratum=NULL, 
                label_exposure=A, label_covariate=C, lbound=-1, ubound=1, ratio=2, columns_per_page=1, rows_per_page=1,
                text_axis_title=8.5, text_axis_y=7.5, text_axis_x=7.5, text_strip_y=10, text_strip_x=10, 
                point_size=1.25, zeroline_size=.1, refline_size=.1, refline_limit_a=-.25, refline_limit_b=0.25, 
                panel_margin_size=25, axis_title=NULL);


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
       %put ERROR: 'input' is missing. Please specify the dataset created by the balance() macro;
	   %ABORT;
   %end;


   %if &output. eq  OR &output. eq NULL %then %do;   /* &output is missing */
       %put NOTE: 'output' dataset name is missing. By default, the name of the output datset will be identical to that of the input dataset, with the suffix '_final_plot' appended to it;
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



   %if &metric. eq  OR &metric. eq NULL %then %do;   /* &metric is missing */
       %put ERROR: 'metric' is missing or misspecified. Please specify as D (for the mean difference) or SMD (for the standardized mean difference);
	   %ABORT;
   %end;

   %if &metric. ne  AND &metric. ne NULL AND NOT %eval(&metric. in(D SMD)) %then %do;   /* &metric is misspecified */
       %put ERROR: 'metric' is missing or misspecified. Please specify as D (for the mean difference) or SMD (for the standardized mean difference);
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



   %if &scope. eq average AND (&average_over. eq  OR &average_over. eq NULL) %then %do;   /* &average_over is missing */
       %put ERROR: 'average_over' is missing. Please specify one of the following: values, strata, history, time, distance;
	   %ABORT;
   %end;



   %if &approach. eq stratify AND (&stratum eq  OR &stratum eq NULL) AND &scope ne average %then %do;   /* &stratum is missing (&scope is not equal to average) */
       %put ERROR: 'stratum' is missing. Please specify an integer indicating the stratum to select for plotting. Note that 'stratum' is not required when strata are averaged over e.g. scope equals average and average_over equals anything higher than values;
	   %ABORT;
   %end;

   %if &approach. eq stratify AND (&stratum eq  OR &stratum eq NULL) AND &scope eq average AND (&average_over ne  AND &average_over ne NULL AND &average_over eq values) %then %do;   /* &stratum is missing (&scope equals average) */
       %put ERROR: 'stratum' is missing. Please specify a value indicating the stratum to select for plotting. Note that 'stratum' is not required when strata are averaged over e.g. scope equals average and average_over equals anything higher than values;
	   %ABORT;
   %end;


*--------------------------------*;
* Prepare the data for plotting  *;
*--------------------------------*;

   ** Select the appropriate metric **;

   %if &metric. eq D %then %do;
       data indata;
	      set &input.;
		  plot_metric = D;  /* Set the plot_metric variable equal to D */
	   run;
   %end;

   %else %if &metric. eq SMD %then %do;
       data indata;
	      set &input.;
		  plot_metric = SMD;  /* Set the plot_metric variable equal to SMD */
	   run;
   %end;


   ** Check to see if plot_metric contains at least 1 non-missing value, abort if all values are missing **;

    proc sql noprint;
	   create table metric_check as
       select count(plot_metric) as nonmiss_metric  /* Count the number of non-missing metric values */
       from indata;
    quit;

	data _NULL_;
	   set metric_check;

	   if nonmiss_metric eq 0 then do;  /* All values of plot_metric are missing */
	      PUTLOG 'ERROR: There are no non-missing values for the specified metric. The program has terminated because the resulting plot is empty';
		  ABORT;
       end;
	run;


	** Ensure that plot_metric contains at least 1 nonzero value, issue warning if all values are zero **;

	proc sql noprint;
	   create table metric_check2 as
       select count(plot_metric) as nonzero_metric
       from indata
	   where plot_metric ne 0;  /* Count the number of nonzero metric values */
    quit;

	data _NULL_;
	   set metric_check2;

	   if nonzero_metric eq 0 then do;  /* All values of plot_metric equal 0 */
	      PUTLOG 'WARNING: There are no non-zero values for the specified metric. The plot will still be produced, but it is advisable to revisit the balance macro and ensure that the temporal covariates were specified correctly.';
       end;
	run;



   ** Replace missing variables with placeholder values **;

   %if (&axis_title. eq  OR &axis_title. eq NULL) AND &metric. eq D %then %do;
	   %LET axis_title_ = Mean Difference;   /* If &axis_title variable is missing, replace with appropriate title */
   %end;
 
   %else %if (&axis_title. eq  OR &axis_title. eq NULL) AND &metric. eq SMD %then %do;
       %LET axis_title_ = Standardized Mean Difference;
   %end;

   %else %if &axis_title. ne  AND &axis_title. ne NULL %then %do;
       %LET axis_title_ = &axis_title.;
   %end;



   %if &average_over. eq  OR &average_over. eq NULL %then %do;
	   %LET average_over_ =  ;   /* If &average_over variable is missing, replace with a blank */
   %end;
 
   %else %do;
       %LET average_over_ = &average_over.;
   %end;


   data indata2;
      set indata;
 
	  %if (&stratum. eq  OR &stratum. eq NULL) AND &approach. ne stratify %then %do;
          stratum_none = 1;  /* Use '1' as a placeholder value for stratum */
		  %LET stratum_ = stratum_none;  /* Create a macro variable for the placeholder value */
	  %end;

	  %else %if &stratum. ne  AND &stratum. ne NULL %then %do;
          %LET stratum_ = &stratum.;
	  %end;
   run;



   ** Obtain a list of the variables in the input data set **;

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
	  CALL SYMPUT ('rawVarList',rawVarNames);  /* Create macro variable for list of variables in input data set */
   run;


   ** Compare raw data variable list to the appropriate prefix, and replace with '1' if appropriate **;
	
   data indata3;
      set indata2;
 
      %if NOT %eval(E in(&&rawVarList.)) %then %do;  /* Exposure is absent from the input data set */
          E = 1;   
      %end;	

      %if NOT %eval(H in(&&rawVarList.))%then %do;  /* History is absent from the input data set */
          H = 1;   
      %end;	 

      %if NOT %eval(S in(&&rawVarList.)) %then %do;  /* Strata is absent from the input data set */
          S = 1;   
      %end;	
   run;



   ** Collapse the E and H variables into a combined categorical variable that can be used for grouping the data **;

   proc sort data=indata3 out=insort;
      by H E;
   run;

   data insort2;
      set insort;
	  EHcat = CATT(OF E H);
   run;



   ** Filter the input data set if necessary **;

   %if &approach. eq weight OR &approach. eq none OR (&approach. eq stratify AND &scope. eq average AND &&average_over_. ne values) %then %do;
       data sub_input;
          set insort2;
       run;
   %end;

   %else %if &approach. eq stratify AND (&scope. eq all OR &scope. eq recent OR (&scope. eq average AND &&average_over_. eq values)) %then %do;
       data sub_input;
          set insort2;
		  if S eq &&stratum_.;  /* Keep observations where S = stratum */
       run;
   %end;



   ** Add the variable labels to the sub_input data set **;

   %if &scope. eq all OR (&scope. eq average AND &&average_over_. ne time AND &&average_over_. ne distance) %then %do;
       data labelled_input;
	      set sub_input;
		  time_exp_label = "&label_exposure."||"("||strip(time_exposure)||")";
		  time_cov_label = "&label_covariate."||"("||strip(time_covariate)||")";
	   run;
   %end;  


   %if &scope. eq recent AND &diagnostic. ne 2 %then %do;
       data labelled_input;
	      set sub_input;
		  comparison_label = "&label_exposure."||" "||strip(time_exposure);
		  *comparison_label = "&label_exposure."||"("||strip(time_exposure)||") "||"vs "||"&label_covariate."||"("||strip(time_covariate)||")";
	   run;
   %end; 

   %if &scope. eq recent AND &diagnostic. eq 2 %then %do;
       data labelled_input;
	      set sub_input;
		  comparison_label = "&label_covariate."||"("||strip(time_covariate)||") "||"vs "||"&label_exposure."||"("||strip(time_exposure)||")";
	   run;
   %end; 


   %if &scope. eq average AND &&average_over_. eq time AND &diagnostic. ne 2 %then %do;
       data labelled_input;
	      set sub_input;
		  comparison_label = "&label_covariate."||"(t-"||strip(distance)||") vs "||"&label_exposure."||"(t)";
	   run;
   %end;  

   %if &scope. eq average AND &&average_over_. eq time AND &diagnostic. eq 2 %then %do;
       data labelled_input;
	      set sub_input;
		  comparison_label = "&label_exposure."||"(t-"||strip(distance)||") vs "||"&label_covariate."||"(t)";
	   run;
   %end;  


   %if &scope. eq average AND &&average_over_. eq distance AND &diagnostic. ne 2 %then %do;
       data labelled_input;
	      set sub_input;

		  if period_start ne period_end then do;
		     comparison_label = "&label_covariate."||"(t-"||strip(period_end)||":t-"||strip(period_start)||") vs "||"&label_exposure."||"(t)";
		  end;

		  else if period_start eq period_end then do;
		     comparison_label = "&label_covariate."||"(t-"||strip(period_start)||") vs "||"&label_exposure."||"(t)";
		  end;
	   run;
   %end;  



   %if &scope. eq average AND &&average_over_. eq distance AND &diagnostic. eq 2 %then %do;
       data labelled_input;
	      set sub_input;

		  if period_start ne period_end then do;
		     comparison_label = "&label_exposure."||"(t-"||strip(period_end)||":t-"||strip(period_start)||") vs "||"&label_covariate."||"(t)";
		  end;

		  else if period_start eq period_end then do;
		     comparison_label = "&label_exposure."||"(t-"||strip(period_start)||") vs "||"&label_covariate."||"(t)";
		  end;
	   run;
   %end;  



*-------------------------------------*;
* Common formatting for plots         *;
*-------------------------------------*;

   ** Background **;

   %LET bgcolor = white;  /* Background color */
   %LET wcolor = white;   /* Wall color */
   %LET panborder = noborder;  /* Indicates whether borders appear between panels */



   ** Headers **;

   %LET headsize = &text_axis_title.;  /* Header size */
   %LET headcolor = black;  /* Header color */
   %LET headweight = normal;  /* Header weight */

   %LET headbgcolor = white;  /* Header background color */
   %LET headborder = noheaderborder;  /* Indicates whether headers have borders */



   ** Data Points **;

   %LET ptsymbol = CircleFilled;  /* Data point symbol */
   %LET ptcolor = black;  /* Data point color */
   %LET ptsize = &point_size.;  /* Data point size */
   %LET ptunit = PCT;  /* Units of data point size */
   


   ** Axis Labels **;

   %LET xlabsize = &text_strip_x.;  /* x-axis label size */
   %LET xlabcolor = black;  /* x-axis label color */
   %LET xlabweight = bold;  /* x-axis label weight */
  
   %LET xtxtsize = &text_axis_x.;  /* x-axis text size */
   %LET xtxtcolor = black;  /* x-axis text color */
   %LET xtxtweight = normal;  /* x-axis text weight */
  

   %LET ylabsize = &text_strip_y.;  /* y-axis label size */
   %LET ylabcolor = black;  /* y-axis label color */
   %LET ylabweight = bold;  /* y-axis label weight */
  
   %LET ytxtsize = &text_axis_y.;  /* y-axis text size */
   %LET ytxtcolor = black;  /* y-axis text color */
   %LET ytxtweight = normal;  /* y-axis text weight */


   ** Styles for Zero Line and Reference Lines **;

   %LET zeroline_symbol = solid;  /* Zeroline symbol */
   %LET zeroline_color = black;   /* Zeroline color */

   %LET refline_symbol = dot;   /* Reference line symbol */
   %LET refline_color = black;  /* Reference line color */


   ** Sort order for covariates **;

   ** First create macro variable for list of variables in labelled_input data set **;

   proc contents data=labelled_input out=plotVar(keep=VARNUM NAME) varnum noprint;
   run;

   proc sort data=plotVar out=plotVarSort;
      by varnum;
    run;

    data plotVar2;
       set plotVarSort;
    run;

    proc transpose data=plotVar2 out=plotVarWide(drop=_NAME_ _LABEL_);
	   id varnum; 
	   var NAME;
    run;

    data _NULL_;
	   set plotVarWide;

       plotVarNames=CATX(" ",OF _:);

	   %LOCAL plotVarList;
	   CALL SYMPUT ('plotVarList',plotVarNames);  /* Create macro variable for list of variables in labelled_input data set */
    run;


	** Check to see if covariate_order variable is present, define macro sorting variable accordingly **;

    %if %eval(covariate_order in(&&plotVarList.)) %then %do;
	    %LET sortCov = covariate_order;
	%end;

	%else %if NOT %eval(covariate_order in(&&plotVarList.)) %then %do;
	    %LET sortCov = name_cov;
	%end;



   ** Assign a name to the output table/plot **;

   %if &output. ne  AND &output. ne NULL %then %do;
       %LET output_ = &output.;  /* Label the output table and plot with the user-defined name */
   %end;

   %else %do;
       %LET output_ = &input._final_plot;  /* Label the output table and plot with the default name */
   %end;


*-------------------------------------------------------------------------------*;
* Use Attribute Maps so that different point shapes are used for each treatment *;
* See: https://blogs.sas.com/content/iml/2017/01/30/auto-discrete-attr-map.html *;
* and http://documentation.sas.com/?docsetId=grstatproc&docsetTarget=n18szqcwir8q2nn10od9hhdh2ksj.htm&docsetVersion=9.4&locale=en *;

/* semi-automatic way to create a DATTRMAP= data set */
%let VarName = EHcat;           /* specify name of grouping variable */
proc freq data=labelled_input ORDER=FORMATTED;   /* or ORDER=DATA|FREQ  */
   tables &VarName / out=Attrs(rename=(&VarName=Value));
run;
 
data DAttrs;
ID = "&VarName";                 /* or "ID_&VarName" */
set Attrs(keep=Value);
length MarkerStyleElement $11.  markersymbol $15;
MarkerStyleElement = cats("GraphData", 1+mod(_N_-1, 12)); /* GraphData1, GraphData2, etc */
   
   if MarkerStyleElement eq "GraphData1" then markersymbol="Circle";
   if MarkerStyleElement eq "GraphData2" then markersymbol="Triangle";
   if MarkerStyleElement eq "GraphData3" then markersymbol="Diamond";
   if MarkerStyleElement eq "GraphData4" then markersymbol="HomeDown";
   if MarkerStyleElement eq "GraphData5" then markersymbol="Square";
   if MarkerStyleElement eq "GraphData6" then markersymbol="Star";
   if MarkerStyleElement eq "GraphData7" then markersymbol="TriangleDown";
   if MarkerStyleElement eq "GraphData8" then markersymbol="TriangleRight";
   if MarkerStyleElement eq "GraphData9" then markersymbol="TriangleLeft";
   if MarkerStyleElement eq "GraphData10" then markersymbol="Asterisk";
   if MarkerStyleElement eq "GraphData11" then markersymbol="CircleFilled";
   if MarkerStyleElement eq "GraphData12" then markersymbol="TriangleFilled";
   if MarkerStyleElement eq "GraphData13" then markersymbol="DiamondFilled";
   if MarkerStyleElement eq "GraphData14" then markersymbol="HomeDownFilled";
   if MarkerStyleElement eq "GraphData15" then markersymbol="SquareFilled";
   if MarkerStyleElement eq "GraphData16" then markersymbol="StarFilled";
   if MarkerStyleElement eq "GraphData17" then markersymbol="TriangleDownFilled";
   if MarkerStyleElement eq "GraphData18" then markersymbol="TriangleRightFilled";
   if MarkerStyleElement eq "GraphData19" then markersymbol="TriangleLeftFilled";
   if MarkerStyleElement eq "GraphData20" then markersymbol="ArrowDown";
   if MarkerStyleElement eq "GraphData21" then markersymbol="Tack";
   if MarkerStyleElement eq "GraphData22" then markersymbol="Tilde";
   if MarkerStyleElement eq "GraphData23" then markersymbol="GreaterThan";
   if MarkerStyleElement eq "GraphData24" then markersymbol="Hash";
   if MarkerStyleElement eq "GraphData25" then markersymbol="IBeam";
   if MarkerStyleElement eq "GraphData26" then markersymbol="LessThan";
   if MarkerStyleElement eq "GraphData27" then markersymbol="Union";
   if MarkerStyleElement eq "GraphData28" then markersymbol="Plus";
   if MarkerStyleElement eq "GraphData29" then markersymbol="X";
   if MarkerStyleElement eq "GraphData30" then markersymbol="Y";
   if MarkerStyleElement eq "GraphData31" then markersymbol="Z";
run;
 

*-------------------------------------------------------------------------------*;



*-------------------------------------*;
* Plot the results: Scope=all         *;
*-------------------------------------*;

%if &scope eq all %then %do;

    ** For Diagnostics 1 and 3 **;

    %if &diagnostic. eq 1 OR &diagnostic. eq 3 %then %do;

	    %if &approach. ne stratify %then %do;
		    data labelled_input;
			   set labelled_input;
			   time_cov_num = input(time_covariate, 8.);  /* Create a numeric version of time_covariate for sorting */
			   time_exp_num = input(time_exposure, 8.);  /* Create a numeric version of time_exposure for sorting */
			run;

	        proc sort data=labelled_input;
               by time_cov_num descending time_exp_num descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            run;

			/*proc sort data=labelled_input;
               by time_cov_label descending time_exp_label descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            /*run;*/

            proc sgpanel data=labelled_input /*noautolegend*/ aspect=&ratio. dattrmap=DAttrs; 
               panelby time_cov_label time_exp_label / sort=data layout=lattice novarname colheaderpos=top rowheaderpos=right uniscale=all &&panborder. spacing=&panel_margin_size. headerattrs=(size=&&headsize. color=&&headcolor. weight=&&headweight.) headerbackcolor=&&headbgcolor. &&headborder.; 
               styleattrs backcolor=&&bgcolor. wallcolor=&&wcolor.;

               scatter x=plot_metric y=name_cov / group=EHcat markerattrs=(/*symbol=&&ptsymbol.*/ color=&&ptcolor. size=&&ptsize. &&ptunit.) attrid=EHcat;

               colaxis discreteorder=data label="&&axis_title_." labelattrs=(size=&&xlabsize. color=&&xlabcolor. weight=&&xlabweight.) valueattrs=(size=&&xtxtsize. color=&&xtxtcolor. weight=&&xtxtweight.) min=&lbound. max=&ubound.;  /* Display the column axis in ascending order, include title, and set lower and upper bounds */ 
		       rowaxis discreteorder=data label="Covariate" labelattrs=(size=&&ylabsize. color=&&ylabcolor. weight=&&ylabweight.) valueattrs=(size=&&ytxtsize. color=&&ytxtcolor. weight=&&ytxtweight.);   /* Display the row axis in descending order, and include title */ 

		       refline 0 / axis=x lineattrs=(pattern=&&zeroline_symbol. color=&&zeroline_color. thickness=&zeroline_size.);   /* Display zeroline */
		       refline &refline_limit_a. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display lower reference line */
		       refline &refline_limit_b. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display upper reference line */
		      
		       keylegend / title="";
            run;
		%end;

		%else %if &approach. eq stratify %then %do;
		    data labelled_input;
			   set labelled_input;
			   time_cov_num = input(time_covariate, 8.);  /* Create a numeric version of time_covariate for sorting */
			   time_exp_num = input(time_exposure, 8.);  /* Create a numeric version of time_exposure for sorting */
			run;

	        proc sort data=labelled_input;
               by time_cov_num descending time_exp_num descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            run;

			/*proc sort data=labelled_input;
               by time_cov_label descending time_exp_label descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            /*run;*/

            proc sgpanel data=labelled_input /*noautolegend*/ aspect=&ratio. dattrmap=DAttrs; 
               panelby time_cov_label time_exp_label / sort=data layout=lattice rows=&rows_per_page. novarname colheaderpos=top rowheaderpos=right uniscale=all &&panborder. spacing=&panel_margin_size. headerattrs=(size=&&headsize. color=&&headcolor. weight=&&headweight.) headerbackcolor=&&headbgcolor. &&headborder.; 
               styleattrs backcolor=&&bgcolor. wallcolor=&&wcolor.;

               scatter x=plot_metric y=name_cov / group=EHcat markerattrs=(/*symbol=&&ptsymbol. */ color=&&ptcolor. size=&&ptsize. &&ptunit.) attrid=EHcat;

               colaxis discreteorder=data label="&&axis_title_." labelattrs=(size=&&xlabsize. color=&&xlabcolor. weight=&&xlabweight.) valueattrs=(size=&&xtxtsize. color=&&xtxtcolor. weight=&&xtxtweight.) min=&lbound. max=&ubound.;  /* Display the column axis in ascending order, include title, and set lower and upper bounds */ 
		       rowaxis discreteorder=data label="Covariate" labelattrs=(size=&&ylabsize. color=&&ylabcolor. weight=&&ylabweight.) valueattrs=(size=&&ytxtsize. color=&&ytxtcolor. weight=&&ytxtweight.);   /* Display the row axis in descending order, and include title */ 

		       refline 0 / axis=x lineattrs=(pattern=&&zeroline_symbol. color=&&zeroline_color. thickness=&zeroline_size.);   /* Display zeroline */
		       refline &refline_limit_a. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display lower reference line */
		       refline &refline_limit_b. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display upper reference line */
		      
		       keylegend / title="";
            run;
		%end;
	%end;



	** For Diagnostic 2 **;

	%if &diagnostic. eq 2 %then %do;
        %if &approach. ne stratify %then %do;
		    data labelled_input;
			   set labelled_input;
			   time_cov_num = input(time_covariate, 8.);  /* Create a numeric version of time_covariate for sorting */
			   time_exp_num = input(time_exposure, 8.);  /* Create a numeric version of time_exposure for sorting */
			run;

	        proc sort data=labelled_input;
               by time_exp_num descending time_cov_num descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            run;

			/*proc sort data=labelled_input;
               by time_exp_label descending time_cov_label descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            /*run;*/

            proc sgpanel data=labelled_input /*noautolegend*/ aspect=&ratio. dattrmap=DAttrs; 
               panelby time_exp_label time_cov_label / sort=data layout=lattice novarname colheaderpos=top rowheaderpos=right uniscale=all &&panborder. spacing=&panel_margin_size. headerattrs=(size=&&headsize. color=&&headcolor. weight=&&headweight.) headerbackcolor=&&headbgcolor. &&headborder.;
               styleattrs backcolor=&&bgcolor. wallcolor=&&wcolor.;

               scatter x=plot_metric y=name_cov / group=EHcat markerattrs=(/*symbol=&&ptsymbol. */ color=&&ptcolor. size=&&ptsize. &&ptunit.) attrid=EHcat;

               colaxis discreteorder=data label="&&axis_title_." labelattrs=(size=&&xlabsize. color=&&xlabcolor. weight=&&xlabweight.) valueattrs=(size=&&xtxtsize. color=&&xtxtcolor. weight=&&xtxtweight.) min=&lbound. max=&ubound.;  /* Display the column axis in ascending order, include title, and set lower and upper bounds */ 
		       rowaxis discreteorder=data label="Covariate" labelattrs=(size=&&ylabsize. color=&&ylabcolor. weight=&&ylabweight.) valueattrs=(size=&&ytxtsize. color=&&ytxtcolor. weight=&&ytxtweight.);   /* Display the row axis in descending order, and include title */ 

		       refline 0 / axis=x lineattrs=(pattern=&&zeroline_symbol. color=&&zeroline_color. thickness=&zeroline_size.);   /* Display zeroline */
		       refline &refline_limit_a. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display lower reference line */
		       refline &refline_limit_b. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display upper reference line */
		      
		       keylegend / title="";
            run;
		%end;

		%else %if &approach. eq stratify %then %do;
			data labelled_input;
			   set labelled_input;
			   time_cov_num = input(time_covariate, 8.);  /* Create a numeric version of time_covariate for sorting */
			   time_exp_num = input(time_exposure, 8.);  /* Create a numeric version of time_exposure for sorting */
			run;

	        proc sort data=labelled_input;
               by time_exp_num descending time_cov_num descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            run;

			/*proc sort data=labelled_input;
               by time_exp_label descending time_cov_label descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            /*run;*/

            proc sgpanel data=labelled_input /*noautolegend*/ aspect=&ratio. dattrmap=DAttrs; 
               panelby time_exp_label time_cov_label / sort=data layout=lattice rows=&rows_per_page. novarname colheaderpos=top rowheaderpos=right uniscale=all &&panborder. spacing=&panel_margin_size. headerattrs=(size=&&headsize. color=&&headcolor. weight=&&headweight.) headerbackcolor=&&headbgcolor. &&headborder.;
               styleattrs backcolor=&&bgcolor. wallcolor=&&wcolor.;

               scatter x=plot_metric y=name_cov / group=EHcat markerattrs=(/*symbol=&&ptsymbol. */ color=&&ptcolor. size=&&ptsize. &&ptunit.) attrid=EHcat;

               colaxis discreteorder=data label="&&axis_title_." labelattrs=(size=&&xlabsize. color=&&xlabcolor. weight=&&xlabweight.) valueattrs=(size=&&xtxtsize. color=&&xtxtcolor. weight=&&xtxtweight.) min=&lbound. max=&ubound.;  /* Display the column axis in ascending order, include title, and set lower and upper bounds */ 
		       rowaxis discreteorder=data label="Covariate" labelattrs=(size=&&ylabsize. color=&&ylabcolor. weight=&&ylabweight.) valueattrs=(size=&&ytxtsize. color=&&ytxtcolor. weight=&&ytxtweight.);   /* Display the row axis in descending order, and include title */ 

		       refline 0 / axis=x lineattrs=(pattern=&&zeroline_symbol. color=&&zeroline_color. thickness=&zeroline_size.);   /* Display zeroline */
		       refline &refline_limit_a. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display lower reference line */
		       refline &refline_limit_b. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display upper reference line */
		      
		       keylegend / title="";
            run;
		%end;
	%end;
%end;




   
*--------------------------------------*;
* Plot the results: Scope = average    *;
*--------------------------------------*;

%if &scope eq average %then %do;

    ** For average over values **;

    %if &&average_over_. ne  AND &diagnostic. ne 2 %then %do;   /* For Diagnostics 1 and 3 */

        %if %eval(&&average_over_. in(values)) AND &approach. ne stratify %then %do;
			data labelled_input;
			   set labelled_input;
			   time_cov_num = input(time_covariate, 8.);  /* Create a numeric version of time_covariate for sorting */
			   time_exp_num = input(time_exposure, 8.);  /* Create a numeric version of time_exposure for sorting */
			run;

			proc sort data=labelled_input;
               by time_cov_num descending time_exp_num descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            run;

			/*proc sort data=labelled_input;
               by time_cov_label descending time_exp_label descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            /*run;*/

            proc sgpanel data=labelled_input /*noautolegend*/ aspect=&ratio. dattrmap=DAttrs; 
               panelby time_cov_label time_exp_label / sort=data layout=lattice novarname colheaderpos=top rowheaderpos=right uniscale=all &&panborder. spacing=&panel_margin_size. headerattrs=(size=&&headsize. color=&&headcolor. weight=&&headweight.) headerbackcolor=&&headbgcolor. &&headborder.;
			   styleattrs backcolor=&&bgcolor. wallcolor=&&wcolor.;

               scatter x=plot_metric y=name_cov / group=EHcat markerattrs=(/*symbol=&&ptsymbol. */ color=&&ptcolor. size=&&ptsize. &&ptunit.) attrid=EHcat;

               colaxis discreteorder=data label="&&axis_title_." labelattrs=(size=&&xlabsize. color=&&xlabcolor. weight=&&xlabweight.) valueattrs=(size=&&xtxtsize. color=&&xtxtcolor. weight=&&xtxtweight.) min=&lbound. max=&ubound.;  /* Display the column axis in ascending order, include title, and set lower and upper bounds */ 
		       rowaxis discreteorder=data label="Covariate" labelattrs=(size=&&ylabsize. color=&&ylabcolor. weight=&&ylabweight.) valueattrs=(size=&&ytxtsize. color=&&ytxtcolor. weight=&&ytxtweight.);   /* Display the row axis in descending order, and include title */ 

			   refline 0 / axis=x lineattrs=(pattern=&&zeroline_symbol. color=&&zeroline_color. thickness=&zeroline_size.);   /* Display zeroline */
		       refline &refline_limit_a. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display lower reference line */
		       refline &refline_limit_b. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display upper reference line */
		      
		       keylegend / title="";
            run;
	    %end;

		%if %eval(&&average_over_. in(values)) AND &approach. eq stratify %then %do;
			data labelled_input;
			   set labelled_input;
			   time_cov_num = input(time_covariate, 8.);  /* Create a numeric version of time_covariate for sorting */
			   time_exp_num = input(time_exposure, 8.);  /* Create a numeric version of time_exposure for sorting */
			run;

			proc sort data=labelled_input;
               by time_cov_num descending time_exp_num descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            run;

			/*proc sort data=labelled_input;
               by time_cov_label descending time_exp_label descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            /*run;*/

            proc sgpanel data=labelled_input /*noautolegend*/ aspect=&ratio. dattrmap=DAttrs; 
               panelby time_cov_label time_exp_label / sort=data layout=lattice rows=&rows_per_page. novarname colheaderpos=top rowheaderpos=right uniscale=all &&panborder. spacing=&panel_margin_size. headerattrs=(size=&&headsize. color=&&headcolor. weight=&&headweight.) headerbackcolor=&&headbgcolor. &&headborder.;
			   styleattrs backcolor=&&bgcolor. wallcolor=&&wcolor.;

               scatter x=plot_metric y=name_cov / group=EHcat markerattrs=(/*symbol=&&ptsymbol. */ color=&&ptcolor. size=&&ptsize. &&ptunit.) attrid=EHcat;

               colaxis discreteorder=data label="&&axis_title_." labelattrs=(size=&&xlabsize. color=&&xlabcolor. weight=&&xlabweight.) valueattrs=(size=&&xtxtsize. color=&&xtxtcolor. weight=&&xtxtweight.) min=&lbound. max=&ubound.;  /* Display the column axis in ascending order, include title, and set lower and upper bounds */ 
		       rowaxis discreteorder=data label="Covariate" labelattrs=(size=&&ylabsize. color=&&ylabcolor. weight=&&ylabweight.) valueattrs=(size=&&ytxtsize. color=&&ytxtcolor. weight=&&ytxtweight.);   /* Display the row axis in descending order, and include title */ 

			   refline 0 / axis=x lineattrs=(pattern=&&zeroline_symbol. color=&&zeroline_color. thickness=&zeroline_size.);   /* Display zeroline */
		       refline &refline_limit_a. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display lower reference line */
		       refline &refline_limit_b. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display upper reference line */
		      
		       keylegend / title="";
            run;
	    %end;
	%end;


	%if &&average_over_. ne  AND &diagnostic. eq 2 %then %do;   /* For Diagnostic 2 */

        %if %eval(&&average_over_. in(values)) AND &approach. ne stratify %then %do;
			data labelled_input;
			   set labelled_input;
			   time_cov_num = input(time_covariate, 8.);  /* Create a numeric version of time_covariate for sorting */
			   time_exp_num = input(time_exposure, 8.);  /* Create a numeric version of time_exposure for sorting */
			run;

			proc sort data=labelled_input;
               by time_exp_num descending time_cov_num descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            run;

			/*proc sort data=labelled_input;
               by time_exp_label descending time_cov_label descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            /*run;*/

            proc sgpanel data=labelled_input /*noautolegend*/ aspect=&ratio. dattrmap=DAttrs; 
               panelby time_exp_label time_cov_label / sort=data layout=lattice novarname colheaderpos=top rowheaderpos=right uniscale=all &&panborder. spacing=&panel_margin_size. headerattrs=(size=&&headsize. color=&&headcolor. weight=&&headweight.) headerbackcolor=&&headbgcolor. &&headborder.;
			   styleattrs backcolor=&&bgcolor. wallcolor=&&wcolor.;

               scatter x=plot_metric y=name_cov / group=EHcat markerattrs=(/*symbol=&&ptsymbol. */ color=&&ptcolor. size=&&ptsize. &&ptunit.) attrid=EHcat;

			   colaxis discreteorder=data label="&&axis_title_." labelattrs=(size=&&xlabsize. color=&&xlabcolor. weight=&&xlabweight.) valueattrs=(size=&&xtxtsize. color=&&xtxtcolor. weight=&&xtxtweight.) min=&lbound. max=&ubound.;  /* Display the column axis in ascending order, include title, and set lower and upper bounds */ 
		       rowaxis discreteorder=data label="Covariate" labelattrs=(size=&&ylabsize. color=&&ylabcolor. weight=&&ylabweight.) valueattrs=(size=&&ytxtsize. color=&&ytxtcolor. weight=&&ytxtweight.);   /* Display the row axis in descending order, and include title */ 

		       refline 0 / axis=x lineattrs=(pattern=&&zeroline_symbol. color=&&zeroline_color. thickness=&zeroline_size.);   /* Display zeroline */
		       refline &refline_limit_a. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display lower reference line */
		       refline &refline_limit_b. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display upper reference line */
		      
		       keylegend / title="";
            run;
	    %end;

		%if %eval(&&average_over_. in(values)) AND &approach. eq stratify %then %do;
			data labelled_input;
			   set labelled_input;
			   time_cov_num = input(time_covariate, 8.);  /* Create a numeric version of time_covariate for sorting */
			   time_exp_num = input(time_exposure, 8.);  /* Create a numeric version of time_exposure for sorting */
			run;

			proc sort data=labelled_input;
               by time_exp_num descending time_cov_num descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            run;

			/*proc sort data=labelled_input;
               by time_exp_label descending time_cov_label descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            /*run;*/

            proc sgpanel data=labelled_input /*noautolegend*/ aspect=&ratio. dattrmap=DAttrs; 
               panelby time_exp_label time_cov_label / sort=data layout=lattice rows=&rows_per_page. novarname colheaderpos=top rowheaderpos=right uniscale=all &&panborder. spacing=&panel_margin_size. headerattrs=(size=&&headsize. color=&&headcolor. weight=&&headweight.) headerbackcolor=&&headbgcolor. &&headborder.;
			   styleattrs backcolor=&&bgcolor. wallcolor=&&wcolor.;

               scatter x=plot_metric y=name_cov / group=EHcat markerattrs=(/*symbol=&&ptsymbol. */ color=&&ptcolor. size=&&ptsize. &&ptunit.) attrid=EHcat;

			   colaxis discreteorder=data label="&&axis_title_." labelattrs=(size=&&xlabsize. color=&&xlabcolor. weight=&&xlabweight.) valueattrs=(size=&&xtxtsize. color=&&xtxtcolor. weight=&&xtxtweight.) min=&lbound. max=&ubound.;  /* Display the column axis in ascending order, include title, and set lower and upper bounds */ 
		       rowaxis discreteorder=data label="Covariate" labelattrs=(size=&&ylabsize. color=&&ylabcolor. weight=&&ylabweight.) valueattrs=(size=&&ytxtsize. color=&&ytxtcolor. weight=&&ytxtweight.);   /* Display the row axis in descending order, and include title */ 

		       refline 0 / axis=x lineattrs=(pattern=&&zeroline_symbol. color=&&zeroline_color. thickness=&zeroline_size.);   /* Display zeroline */
		       refline &refline_limit_a. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display lower reference line */
		       refline &refline_limit_b. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display upper reference line */
		      
		       keylegend / title="";
            run;
	    %end;
	%end;




    ** For average over history or strata **;

    %if &&average_over_. ne  AND &diagnostic. ne 2 %then %do;   /* For Diagnostics 1 and 3 */

        %if %eval(&&average_over_. in(history strata)) %then %do;
			data labelled_input;
			   set labelled_input;
			   time_cov_num = input(time_covariate, 8.);  /* Create a numeric version of time_covariate for sorting */
			   time_exp_num = input(time_exposure, 8.);  /* Create a numeric version of time_exposure for sorting */
			run;

			proc sort data=labelled_input;
               by time_cov_num descending time_exp_num descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            run;

			/*proc sort data=labelled_input;
               by time_cov_label descending time_exp_label descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            /*run;*/

            proc sgpanel data=labelled_input /*noautolegend*/ aspect=&ratio. dattrmap=DAttrs; 
               panelby time_cov_label time_exp_label / sort=data layout=lattice novarname colheaderpos=top rowheaderpos=right uniscale=all &&panborder. spacing=&panel_margin_size. headerattrs=(size=&&headsize. color=&&headcolor. weight=&&headweight.) headerbackcolor=&&headbgcolor. &&headborder.;
			   styleattrs backcolor=&&bgcolor. wallcolor=&&wcolor.;

               scatter x=plot_metric y=name_cov / group=EHcat markerattrs=(/*symbol=&&ptsymbol. */ color=&&ptcolor. size=&&ptsize. &&ptunit.) attrid=EHcat;

               colaxis discreteorder=data label="&&axis_title_." labelattrs=(size=&&xlabsize. color=&&xlabcolor. weight=&&xlabweight.) valueattrs=(size=&&xtxtsize. color=&&xtxtcolor. weight=&&xtxtweight.) min=&lbound. max=&ubound.;  /* Display the column axis in ascending order, include title, and set lower and upper bounds */ 
		       rowaxis discreteorder=data label="Covariate" labelattrs=(size=&&ylabsize. color=&&ylabcolor. weight=&&ylabweight.) valueattrs=(size=&&ytxtsize. color=&&ytxtcolor. weight=&&ytxtweight.);   /* Display the row axis in descending order, and include title */ 

			   refline 0 / axis=x lineattrs=(pattern=&&zeroline_symbol. color=&&zeroline_color. thickness=&zeroline_size.);   /* Display zeroline */
		       refline &refline_limit_a. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display lower reference line */
		       refline &refline_limit_b. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display upper reference line */
		      
		       keylegend / title="";
            run;
	    %end;
	%end;


	%if &&average_over_. ne  AND &diagnostic. eq 2 %then %do;   /* For Diagnostic 2 */

        %if %eval(&&average_over_. in(history strata)) %then %do;
			data labelled_input;
			   set labelled_input;
			   time_cov_num = input(time_covariate, 8.);  /* Create a numeric version of time_covariate for sorting */
			   time_exp_num = input(time_exposure, 8.);  /* Create a numeric version of time_exposure for sorting */
			run;

			proc sort data=labelled_input;
               by time_exp_num descending time_cov_num descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            run;

			/*proc sort data=labelled_input;
               by time_exp_label descending time_cov_label descending &&sortCov.;  /* Sort the row variable and covariates in descending order */
            /*run;*/

            proc sgpanel data=labelled_input /*noautolegend*/ aspect=&ratio. dattrmap=DAttrs; 
               panelby time_exp_label time_cov_label / sort=data layout=lattice novarname colheaderpos=top rowheaderpos=right uniscale=all &&panborder. spacing=&panel_margin_size. headerattrs=(size=&&headsize. color=&&headcolor. weight=&&headweight.) headerbackcolor=&&headbgcolor. &&headborder.;
			   styleattrs backcolor=&&bgcolor. wallcolor=&&wcolor.;

               scatter x=plot_metric y=name_cov / group=EHcat markerattrs=(/*symbol=&&ptsymbol. */ color=&&ptcolor. size=&&ptsize. &&ptunit.) attrid=EHcat;

			   colaxis discreteorder=data label="&&axis_title_." labelattrs=(size=&&xlabsize. color=&&xlabcolor. weight=&&xlabweight.) valueattrs=(size=&&xtxtsize. color=&&xtxtcolor. weight=&&xtxtweight.) min=&lbound. max=&ubound.;  /* Display the column axis in ascending order, include title, and set lower and upper bounds */ 
		       rowaxis discreteorder=data label="Covariate" labelattrs=(size=&&ylabsize. color=&&ylabcolor. weight=&&ylabweight.) valueattrs=(size=&&ytxtsize. color=&&ytxtcolor. weight=&&ytxtweight.);   /* Display the row axis in descending order, and include title */ 

		       refline 0 / axis=x lineattrs=(pattern=&&zeroline_symbol. color=&&zeroline_color. thickness=&zeroline_size.);   /* Display zeroline */
		       refline &refline_limit_a. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display lower reference line */
		       refline &refline_limit_b. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display upper reference line */
		      
		       keylegend / title="";
            run;
	    %end;
	%end;



    ** For average over time **;

	%if &&average_over_. eq time %then %do;
		proc sort data=labelled_input;
           by descending distance descending &&sortCov.;  /* Sort the labels and covariates in descending order */
        run;

		/*proc sort data=labelled_input;
           by descending comparison_label descending &&sortCov.;  /* Sort the labels and covariates in descending order */
        /*run;*/

        proc sgpanel data=labelled_input /*noautolegend*/ aspect=&ratio. dattrmap=DAttrs; 
           panelby comparison_label / sort=data /*layout=columnlattice*/ columns=&columns_per_page. novarname colheaderpos=top rowheaderpos=right uniscale=all &&panborder. spacing=&panel_margin_size. headerattrs=(size=&&headsize. color=&&headcolor. weight=&&headweight.) headerbackcolor=&&headbgcolor. &&headborder.;
		   styleattrs backcolor=&&bgcolor. wallcolor=&&wcolor.;

		   scatter x=plot_metric y=name_cov / group=distance markerattrs=(/*symbol=&&ptsymbol. */ color=&&ptcolor. size=&&ptsize. &&ptunit.) attrid=EHcat;

		   colaxis discreteorder=data label="&&axis_title_." labelattrs=(size=&&xlabsize. color=&&xlabcolor. weight=&&xlabweight.) valueattrs=(size=&&xtxtsize. color=&&xtxtcolor. weight=&&xtxtweight.) min=&lbound. max=&ubound.;  /* Display the column axis in ascending order, include title, and set lower and upper bounds */ 
		   rowaxis discreteorder=data label="Covariate" labelattrs=(size=&&ylabsize. color=&&ylabcolor. weight=&&ylabweight.) valueattrs=(size=&&ytxtsize. color=&&ytxtcolor. weight=&&ytxtweight.);   /* Display the row axis in descending order, and include title */ 

		   refline 0 / axis=x lineattrs=(pattern=&&zeroline_symbol. color=&&zeroline_color. thickness=&zeroline_size.);   /* Display zeroline */
		   refline &refline_limit_a. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display lower reference line */
		   refline &refline_limit_b. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display upper reference line */
		  
		   keylegend / title="";
        run;
    %end;



	** For average over distance **;

	%if &&average_over_. eq distance %then %do;
		proc sort data=labelled_input;
           by descending period_end descending &&sortCov.;  /* Sort the labels and covariates in descending order */
        run;

		/*proc sort data=labelled_input;
           by descending comparison_label descending &&sortCov.;  /* Sort the labels and covariates in descending order */
        /*run;*/

        proc sgpanel data=labelled_input /*noautolegend*/ aspect=&ratio. dattrmap=DAttrs; 
           panelby comparison_label / sort=data /*layout=columnlattice*/ columns=&columns_per_page. novarname colheaderpos=top rowheaderpos=right uniscale=all &&panborder. spacing=&panel_margin_size. headerattrs=(size=&&headsize. color=&&headcolor. weight=&&headweight.) headerbackcolor=&&headbgcolor. &&headborder.;
		   styleattrs backcolor=&&bgcolor. wallcolor=&&wcolor.;

           scatter x=plot_metric y=name_cov / group=period_id markerattrs=(/*symbol=&&ptsymbol. */ color=&&ptcolor. size=&&ptsize. &&ptunit.) attrid=EHcat;

		   colaxis discreteorder=data label="&&axis_title_." labelattrs=(size=&&xlabsize. color=&&xlabcolor. weight=&&xlabweight.) valueattrs=(size=&&xtxtsize. color=&&xtxtcolor. weight=&&xtxtweight.) min=&lbound. max=&ubound.;  /* Display the column axis in ascending order, include title, and set lower and upper bounds */ 
		   rowaxis discreteorder=data label="Covariate" labelattrs=(size=&&ylabsize. color=&&ylabcolor. weight=&&ylabweight.) valueattrs=(size=&&ytxtsize. color=&&ytxtcolor. weight=&&ytxtweight.);   /* Display the row axis in descending order, and include title */ 

		   refline 0 / axis=x lineattrs=(pattern=&&zeroline_symbol. color=&&zeroline_color. thickness=&zeroline_size.);   /* Display zeroline */
		   refline &refline_limit_a. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display lower reference line */
		   refline &refline_limit_b. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display upper reference line */
		  
		   keylegend / title="";
        run;
	%end;
	
%end;





*--------------------------------------*;
* Plot the results: Scope = recent    *;
*--------------------------------------*;
   
%if &scope eq recent %then %do;

	** For Diagnostics 1 and 3 **;

    %if &diagnostic. eq 1 OR &diagnostic. eq 3 %then %do;
		data labelled_input;
		   set labelled_input;
		   time_cov_num = input(time_covariate, 8.);  /* Create a numeric version of time_covariate for sorting */
		   time_exp_num = input(time_exposure, 8.);  /* Create a numeric version of time_exposure for sorting */
		run;

	    proc sort data=labelled_input;
           by time_exp_num time_cov_num descending &&sortCov.;  /* Sort the covariates in descending order */
        run;

	   /*proc sort data=labelled_input;
           by comparison_label descending &&sortCov.;  /* Sort the covariates in descending order */
       /*run;*/


        proc sgpanel data=labelled_input /*noautolegend*/ aspect=&ratio. dattrmap=DAttrs; 
           panelby comparison_label / sort=data /*layout=columnlattice*/ columns=&columns_per_page. novarname colheaderpos=top rowheaderpos=right uniscale=all &&panborder. spacing=&panel_margin_size. headerattrs=(size=&&headsize. color=&&headcolor. weight=&&headweight.) headerbackcolor=&&headbgcolor. &&headborder.; 
		   styleattrs backcolor=&&bgcolor. wallcolor=&&wcolor.;

           scatter x=plot_metric y=name_cov / group=EHcat markerattrs=(/*symbol=CircleFilled */ color=&&ptcolor. size=&&ptsize. &&ptunit.) attrid=EHcat;
           *scatter x=plot_metric y=name_cov / group=EHcat markerattrs=(symbol=&&ptsymbol. color=&&ptcolor. size=&&ptsize. &&ptunit.);

		   colaxis discreteorder=data label="&&axis_title_." labelattrs=(size=&&xlabsize. color=&&xlabcolor. weight=&&xlabweight.) valueattrs=(size=&&xtxtsize. color=&&xtxtcolor. weight=&&xtxtweight.) min=&lbound. max=&ubound.;  /* Display the column axis in ascending order, include title, and set lower and upper bounds */ 
		   rowaxis discreteorder=data label="Covariate" labelattrs=(size=&&ylabsize. color=&&ylabcolor. weight=&&ylabweight.) valueattrs=(size=&&ytxtsize. color=&&ytxtcolor. weight=&&ytxtweight.);   /* Display the row axis in descending order, and include title */  

		   refline 0 / axis=x lineattrs=(pattern=&&zeroline_symbol. color=&&zeroline_color. thickness=&zeroline_size.);   /* Display zeroline */
		   refline &refline_limit_a. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display lower reference line */
		   refline &refline_limit_b. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display upper reference line */
		  
		   keylegend / title="";
        run;
	%end;


	** For Diagnostic 2 **;

	%if &diagnostic. eq 2 %then %do;
		data labelled_input;
		   set labelled_input;
		   time_cov_num = input(time_covariate, 8.);  /* Create a numeric version of time_covariate for sorting */
		   time_exp_num = input(time_exposure, 8.);  /* Create a numeric version of time_exposure for sorting */
		run;

		proc sort data=labelled_input;
           by time_exp_num time_cov_num descending &&sortCov.;  /* Sort the covariates in descending order */
        run;

	   /*proc sort data=labelled_input;
           by comparison_label descending &&sortCov.;  /* Sort the covariates in descending order */
       /*run;*/

        proc sgpanel data=labelled_input /*noautolegend*/ aspect=&ratio. dattrmap=DAttrs; 
           panelby comparison_label / sort=data /*layout=columnlattice*/ columns=&panels_per_page. novarname colheaderpos=top rowheaderpos=right uniscale=all &&panborder. spacing=&panel_margin_size. headerattrs=(size=&&headsize. color=&&headcolor. weight=&&headweight.) headerbackcolor=&&headbgcolor. &&headborder.;
		   styleattrs backcolor=&&bgcolor. wallcolor=&&wcolor.;

           scatter x=plot_metric y=name_cov / group=EHcat markerattrs=(/*symbol=&&ptsymbol.*/ color=&&ptcolor. size=&&ptsize. &&ptunit.) attrid=EHcat;

		   colaxis discreteorder=data label="&&axis_title_." labelattrs=(size=&&xlabsize. color=&&xlabcolor. weight=&&xlabweight.) valueattrs=(size=&&xtxtsize. color=&&xtxtcolor. weight=&&xtxtweight.) min=&lbound. max=&ubound.;  /* Display the column axis in ascending order, include title, and set lower and upper bounds */ 
		   rowaxis discreteorder=data label="Covariate" labelattrs=(size=&&ylabsize. color=&&ylabcolor. weight=&&ylabweight.) valueattrs=(size=&&ytxtsize. color=&&ytxtcolor. weight=&&ytxtweight.);   /* Display the row axis in descending order, and include title */ 

		   refline 0 / axis=x lineattrs=(pattern=&&zeroline_symbol. color=&&zeroline_color. thickness=&zeroline_size.);   /* Display zeroline */
		   refline &refline_limit_a. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display lower reference line */
		   refline &refline_limit_b. / axis=x lineattrs=(pattern=&&refline_symbol. color=&&refline_color. thickness=&refline_size.);   /* Display upper reference line */
		  
		   keylegend / title="";
        run;
	%end;

%end;




** Rename the labelled_input data set to match the user-defined or default name, as appropriate **;

data &&output_.;  
   set labelled_input;
run;




** Remove all intermediate data sets from the WORK library **;

   proc datasets library=work nolist;
      save &input. &&output_. &&save. DAttrs;
   run;
   quit;



%mend makeplot;  /* End the makeplot macro */





** End of Program **;
