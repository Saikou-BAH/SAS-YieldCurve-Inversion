/*  data import */
proc import datafile="C:\Users\Saikou\Desktop\Projet Sas/USA.csv"
            out=USA
            dbms=csv 
            replace;
    getnames=yes;
run;


Proc contents data=usa;
run;

/* Re-organizing the dataframe */
data usa; set usa(keep= SASDATE UNRATE GDPC1 GS10 TB3MS);
Run;

/* new variable spread : i long term � i short term */
data usa;
    set usa;
    spread=GS10 -TB3MS;
run;

/*taux gdp*/
data usa; set usa;
lag_gdp=lag(GDPC1);
GDP_Growth_Rate=(GDPC1-lag_gdp)/lag_gdp;
run;

/* lag gdp*/ 

*data usa; *set usa;
*lag_GDP_Growth_Rate=lag(GDP_Growth_Rate);
*run;

/*Recession*//*si methode 2 faudrait ajouter la seconde condition et donc calculer le lag_gdp_groth_rate*/
data usa; set usa;
if GDP_Growth_Rate < 0 then Recession = 1;
else Recession = 0;
run;

/*Valeurs manquantes*/
data usa;
    set usa;
    if cmiss(of _all_) then delete;
run;



/*GRAPHE pour voir les moments ou la courbe s'inverse*/
symbol1 v=dot i=join c=purple;

proc gplot data=usa;
    plot spread*sasdate/ vref=0 lvref=2 cvref=black;
    title "Spread";
    label DATE = 'Time Period' spread = 'Spread';
run;

/*Nombre de recession*/
proc means data=usa N sum;
var recession;
run;

/*drop des variables : regarder la liste sur le proc iml et ne garder que cela, sinon apres IML, depalcment des variables  */
data usa1; set usa;
drop date  sasdate;
run;



/* new variable Recession_future :  Recession between t+2 to t+6 */
proc iml;
    /* convert to matrix */
    use Usa1;
    read all var {Recession} into Recession_vector;
    close Usa1;
	
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
    use Usa1;
    read all into Usa1_data; 
    close Usa1;       

    Usa1_data = Usa1_data || Recession_future;

    create interest_rates4 from Usa1_data[colname={"GDPC1" "UNRATE" "TB3MS" "GS10" "spread" "lag_gdp" "GDP_Growth_Rate"  "Recession" "Recession_future"}];
    append from Usa1_data;
    close interest_rates4;
quit;


/*JE SUPPRIME LES 6 DERNIERES OBSERVTIONS: On s'arrete au troisieme trimestre 2021*/
Data interest_rates4; set interest_rates4;
if _N_> 249 then delete ;
run;


/*VERIFICATION DES OSBERVATIONS OU RECESSION_FUTURE=1*/

proc freq data=interest_rates4;
    tables recession_future / nocum;
run; 

proc print data=interest_rates4;
where recession_future=1;
run;


/* Create the testing dataset */

data df_train;
    set interest_rates4;
    if _N_ <= 200;
run;

data df_test;
    set interest_rates4;
    if _N_ > 200;
run;

/*IN SAMPLE*/
/*logistic model*/
proc logistic data=df_train ;
    model recession_future(event='1') = spread   ;
    store out=logistic_model;
	roc;
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
    model recession_future(event='1') = spread  ;
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


/* logit model with LASSO penalization */
proc hpgenselect data=interest_rates4;
    model recession_future(event='1') = spread   / dist=binomial link=logit;
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
