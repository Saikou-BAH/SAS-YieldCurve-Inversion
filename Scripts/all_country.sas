
/*  data import */
proc import datafile="C:\Users\Saikou\Desktop\Projet Sas/data_interest_rates_more_variables.csv"
            out=interest_rates 
            dbms=csv 
            replace;
    getnames=yes;
run;

libname in "C:\Users\Saikou\Desktop\Projet Sas";


/* Re-organizing the dataframe */
data interest_rates2;
	set interest_rates(keep= MEASURE OBS_VALUE Reference_area time_period); 
run;

proc sort data=interest_rates2; 
	by reference_area time_period; 
run; 

proc transpose data=interest_rates2 out=interest_rates3; 
	by reference_area time_period;
	id measure;
	var obs_value;
run; 


data interest_rates3(drop=_name_); 
	set interest_rates3(rename=(B1GQ=GDP_Growth_Rate UNEM=Unemployment_Growth_Rate IR3T=IRST reference_area=Country CP=Inflation MABM=M3_Growth_Rate)); 
run; 


/* new variable spread : i long term � i short term */
data interest_rates3;
    set interest_rates3;
    spread = IRLT - IRST;
run;

/* lag gdp*/

data interest_rates3; set interest_rates3;
lag_GDP_Growth_Rate=lag(GDP_Growth_Rate);
run;

/*Recession*/
data interest_rates3; set interest_rates3;
if GDP_Growth_Rate < 0 and lag_GDP_Growth_Rate < 0 then Recession = 1;
else Recession = 0;
run;

/*Suppression*/

data interest_rates3; set interest_rates3;
if TIME_PERIOD ="1991-Q1" then delete ;
run;

proc print data=interest_rates3;
where Recession=1;
var Recession TIME_PERIOD ;
by country  ;
run;

/*data interest_rates3;
    set interest_rates3;
    if GDP_Growth_Rate < 0 then Recession = 1;
    else Recession = 0;
run;*/

proc means data=interest_rates3 N sum;
class country;
var recession;
run;

proc print data=interest_rates3;
    where country="United State";
    var TIME_PERIOD Country GDP_growth_rate Recession;
run;

data interest_rates3;set interest_rates3;
length DATE 8;
format DATE yymon7.;
Year = input(substr(TIME_PERIOD, 1, 4), 4.);
Quarter = substr(TIME_PERIOD, 6, 2);
    if Quarter = 'Q1' then DATE = mdy(1, 1, Year);
    else if Quarter = 'Q2' then DATE = mdy(4, 1, Year);
    else if Quarter = 'Q3' then DATE = mdy(7, 1, Year);
    else if Quarter = 'Q4' then DATE = mdy(10, 1, Year);
drop Year Quarter;
run;



symbol1 v=dot i=join c=purple;

proc gplot data=interest_rates3;
    by Country;
    plot spread*DATE/ vref=0 lvref=2 cvref=black;
    title "Spread : #byval(Country)";
    label DATE = 'Time Period' spread = 'Spread';
run;

data interest_rates3;set interest_rates3;
drop date;
run;

/*TABLE par pyas*/

%let countries = France South_Africa Germany Canada United_State United_Kingd;

%macro create_country_tables;
    %let num_countries = %sysfunc(countw(&countries));

    %do i = 1 %to &num_countries;
        %let country = %scan(&countries, &i);

        /* Replace underscores with spaces for the country names in the dataset */
        %let country_name = %sysfunc(tranwrd(&country, _, %str( )));

        proc sql;
            create table &country as
            select * from interest_rates3
            where Country = "&country_name";
        quit;
    %end;
%mend create_country_tables;

%create_country_tables;

proc means data=united_state N SUM;
var recession;
run;


/* new variable Recession_future :  Recession between t+2 to t+6 */
proc iml;
    /* convert to matrix */
    use interest_rates3;
    read all var {Recession} into Recession_vector;
    close interest_rates3;
	
    /* new columns */
    n = nrow(Recession_vector);
    Recession_sum = j(n, 1, .); 
    Recession_future = j(n, 1, .);

    /* filling of Recession_sum */
    do i = 1 to (n-6);
        Recession_sum[i] = Recession_vector[i+2] + Recession_vector[i+3] + Recession_vector[i+4] + Recession_vector[i+5] + Recession_vector[i+6];
    end;

    /* filling of Recession_future */
    do i = 1 to n;
        if Recession_sum[i] = 0 then
            Recession_future[i] = 0;
        else
            Recession_future[i] = 1;
    end;

    /* correction of irrelevant values at the end for each country */
    /* number of quarters by country */
	n_q= (2024-1990)*4 - 3;
	do i = 1 to n;
        if mod(i, n_q)=0 then do;
			do j=0 to 5;
            	Recession_future[i-j]=.;
			end;
		end;						
    end;
	
    /* adding Recession_future to the dataframe */
    use interest_rates3;
    read all into interest_rates3_data;
    close interest_rates3;

    interest_rates3_data = interest_rates3_data || Recession_future;

    create interest_rates4 from interest_rates3_data[colname={"IRLT" "GDP_Growth_Rate" "IRST" "Unemployment_Growth_Rate" "Inflation" "M3_Growth_Rate" "spread" "Recession" "Recession_future"}];
    append from interest_rates3_data;
    close interest_rates4;
quit;


/**/
proc iml;
    /* convert to matrix */
    use United_state;
    read all var {Recession} into Recession_vector;
    close United_state;
	
    /* new columns */
    n = nrow(Recession_vector);
    Recession_sum = j(n, 1, .); 
    Recession_future = j(n, 1, .);

    /* filling of Recession_sum */
    do i = 1 to (n-6);
        Recession_sum[i] = Recession_vector[i+2] + Recession_vector[i+3] + Recession_vector[i+4] + Recession_vector[i+5] + Recession_vector[i+6];
    end;

    /* filling of Recession_future */
    do i = 1 to n;
        if Recession_sum[i] = 0 then
            Recession_future[i] = 0;
        else
            Recession_future[i] = 1;
    end;

	
    /* adding Recession_future to the dataframe */
    use United_state;
    read all into United_state_data;
    close United_state;

    United_state_data = United_state_data || Recession_future;

    create interest_rates4 from United_state_data[colname={"IRLT" "GDP_Growth_Rate" "IRST" "Unemployment_Growth_Rate" "Inflation" "M3_Growth_Rate" "spread" "Recession" "Recession_future"}];
    append from United_state_data;
    close interest_rates4;
quit;

/**/



/* Removal of row with missing (incalculable) values */
data interest_rates4;
    set interest_rates4;
    if cmiss(of _all_) then delete;
run;

/* Final dataframe */
proc print data=interest_rates4;
run;
		


/* Stats */
proc contents data=interest_rates4;
run; 

proc means data=interest_rates4; 
	var IRST IRLT GDP_Growth_Rate SPREAD RECESSION RECESSION_Future; 
run; 
/* we can see that the results are consistent */

proc univariate data=interest_rates4; 
	var IRST IRLT GDP_Growth_Rate Inflation M3_Growth_Rate Unemployment_Growth_Rate SPREAD RECESSION RECESSION_Future; 
run; 

/* OUT OF SAMPLE */
/* data train test separation */

/*random selection*/
proc surveyselect data=interest_rates4 rate=0.8 outall out=selection seed=111;
run;

/*df train and test*/
data df_train df_test; 
set selection; 
if selected =1 then output df_train; 
else output df_test; 
drop selected;
run;

/*logistic model*/
proc logistic data=df_train;
    model recession_future(event='1') = spread Inflation M3_Growth_Rate Unemployment_Growth_Rate;
    store out=logistic_model;
run;

/*prediction on df test*/
proc plm restore=logistic_model;
    score data=df_test out=pred_test predicted=prob;
run;


data pred_test;
    set pred_test;
	/*classification threshold here : 0.5 */
    predicted_class = (prob >= 0.5);
run;

/* confusion matrix */
proc freq data=pred_test;
    tables recession_future*predicted_class  / norow nocol nopercent;
run;

/*IN SAMPLE*/
/* logit model in sample : data=interest_rates4
or out of sample : data=df_train*/

proc logistic data=interest_rates4;
    model recession_future(event='1') = spread Inflation M3_Growth_Rate Unemployment_Growth_Rate ;
    output out=pred p=prob;
run;

data pred;
    set pred;
	/*classification threshold here : 0.5 */
    predicted_class = (prob >= 0.5);
run;


/* confusion matrix */
proc freq data=pred;
    tables recession_future*predicted_class  / norow nocol nopercent;
run;
/* AUC */
proc logistic data=interest_rates4;
    model recession_future(event='1') = spread Inflation M3_Growth_Rate Unemployment_Growth_Rate ;
    roc;
run;

/* logit model with LASSO penalization */
proc hpgenselect data=interest_rates4;
    model recession_future(event='1') = spread Inflation M3_Growth_Rate Unemployment_Growth_Rate Inflation M3_Growth_Rate Unemployment_Growth_Rate / dist=binomial link=logit;
    selection method=lasso;
    output out=pred_lasso p=prob_lasso;
run;
data pred_lasso;
    set pred_lasso;
	/*classification threshold here : 0.5 */
    predicted_class_lasso = (prob_lasso >= 0.5);
run;
/* confusion matrix lasso*/
data pred_lasso;
    set pred_lasso;
    ID = _N_;
run;

data pred;
    set pred;
    ID = _N_;
run;
data pred_lasso_nolasso;
   merge pred pred_lasso;
   by ID;
run;

proc freq data=pred_lasso_nolasso;
    tables recession_future*predicted_class_lasso  / norow nocol nopercent;
run;




