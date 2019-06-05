filename master "/folders/myfolders/Project_summer_semester_07_2018/Master.csv";

data master;
infile master DSD firstobs=2;
retain consultant projnum date hours stage complete; 
length date $10;
input consultant $ projnum date $ hours stage complete;
run;

filename newforms "/folders/myfolders/Project_summer_semester_07_2018/NewForms.csv";

data newforms;
infile newforms DSD firstobs=2;
retain projnum date hours stage complete; 
length date $10;
input projnum date $ hours stage complete; 
run;

filename projclas "/folders/myfolders/Project_summer_semester_07_2018/ProjClass.csv";

data projclas;
infile projclas DSD firstobs=2;
retain type projnum;
length type $18;
input type $ projnum; 
run;

filename correct "/folders/myfolders/Project_summer_semester_07_2018/Corrections.csv";

data correct;
infile correct DSD firstobs=2;
retain projnum date hours stage; 
length date $10;
input projnum date $ hours stage; 
run;

filename assignmt "/folders/myfolders/Project_summer_semester_07_2018/Assignments.csv";

data assignmt;
infile assignmt DSD firstobs=2;
input consultant $ projnum; 
run;

*=======================;
/*Objective 1*/
*=======================;

proc sort data=newforms out=newform_s; by projnum; run;  *newform1 is sorted newform based on projnum;
proc sort data=assignmt out=assignm_s; by projnum; run;  *assignm1 is sorted assignmt based on projnum;
proc sort data=master out=master_s; by projnum; run;     *master1 is sorted master based on projnum;

/*get old_assign from master*/
data old_assign;         
set master_s;
by projnum;
if first.projnum;       *remove duplicates(projnum);
keep consultant projnum;
run;

proc sort data=old_assign; by projnum; run;

/*get new _assign by stacking old_assign and assign_s*/
data new_assign;    *stack master_cut and assignment to get all the projnums and corresponding names; 
set old_assign assignm_s;   *we can merge here instead of stack to avoid getting rid of duplicate;
by projnum;
if first.projnum;         *remove duplicates(projnum) after stacking;
run;

proc sort data= new_assign; by projnum; run;

/*merge new_assign with newform to get newform_all*/
data newform_all;        
merge new_assign(in=in1) newform_s(in=in2);
by projnum;
if in2;
run;

proc sort data=newform_all; by projnum; run;

/*stack master file with newform_all*/
data master_all;
set newform_all master_s;
run;

proc sort data=master_all out=master_as; by projnum date; run;
proc sort data=correct out=correct_s; by projnum date; run;

/*correct master file, and note yes for corrections*/
data master_cor;
update master_as(in=in1) correct_s(in=in2);
by projnum Date;
if in2 then corrected = 'yes';
else corrected = 'no';
run;

proc sort data=master_cor out=master_cors; by projnum; run;
proc sort data=projclas out=projclass_s; by projnum; run;

/*add classification type to the new master file*/
data master_class;
merge master_cors projclass_s;
by projnum;
run;
/*
/*replace missing hours values*/***********

data master_class_mish;
set master_class;
array date _NUMERIC_;
    do over date;
    if date=. then date=0;
    end;
run
*/;

DATA master_class;
SET master_class;
retain _variable;
if not missing(stage) then _variable=variable;
else variable=_variable;
drop _variable;
RUN;

/*write new master to a .csv file named NewMaster.csv*/                                     /*No header here*/
filename n_master "/folders/myfolders/Project_summer_semester_07_2018/NewMaster.csv";

data _NULL_;
set master_class;
file n_master DSD;
put (_ALL_)(~);
run;

/*save the new master file to a permanent file*/
LIBNAME project "/folders/myfolders/Project_summer_semester_07_2018";

data project.newmaster;
set master_class;
run;

*===================================================================================================;

*=======================;
/*Objective 2*/
*=======================;
LIBNAME project "/folders/myfolders/Project_summer_semester_07_2018";

proc sort data=project.newmaster out=newmaster_sort; by projnum; run;

data project_temp;
set newmaster_sort;
by projnum;
retain sum_complete;
if first.projnum then sum_complete = 0;
sum_complete = sum_complete + complete;
if last.projnum then output;
keep projnum sum_complete;
run;

data project_going;
set project_temp;
/*if sum_complete > 0 then delete;*/
if sum_complete = 0;
keep projnum;
run;
 
title 'Body data';

proc print data=project_going;  
run;
 
*===================================================================================================;

*=======================;
/*Objective 3*/
*=======================;
LIBNAME project "/folders/myfolders/Project_summer_semester_07_2018";

data newmaster_time (drop=date rename = (num_date = date));
set project.newmaster;
/*informat date MMDDYY10.;*/
num_date = input(date, MMDDYY10.);
format num_date MMDDYY10.;
run;

/*get total hours*/
proc sort data=newmaster_time; by projnum date; run;

data newmaster_hours;
set newmaster_time (drop=stage);
by projnum;
retain total_hours;
if first.projnum then total_hours = 0;
total_hours = total_hours + hours;
if last.projnum then output;
keep consultant projnum total_hours type;
run;

/*get start_date*/
proc sort data=newmaster_time; by projnum date; run;

data newmaster_date0; 
set newmaster_time (rename=(date = start_date));
by projnum;
retain dates_2;
if first.projnum;
keep projnum start_date;
run; 

/*get end_date*/
data newmaster_date1; 
set newmaster_time (rename=(date = end_date));
by projnum;
retain dates_3;
if last.projnum;
keep projnum end_date;
run; 

/*get sum of complete*/
data newmaster_sumComplete; 
set newmaster_time (drop=stage);
by projnum;
retain complete_sum;
if first.projnum then complete_sum = 0;
complete_sum = complete_sum + complete;
if last.projnum then output;
keep projnum complete_sum;
run;

/*get finish_status*/
data newmaster_complete;
set newmaster_sumComplete;
if complete_sum > 0 then finish_status = 'yes';
else finish_status = 'no';
keep projnum finish_status;
run;

proc sort data=newmaster_hours; by projnum; run;
proc sort data=newmaster_date0; by projnum; run;
proc sort data=newmaster_date1; by projnum; run;
proc sort data=newmaster_complete; by projnum; run;


/*merge total_hours start_date end_date finish_status type based on projnum*/
data newmaster_total;
merge newmaster_hours newmaster_date0 newmaster_date1 newmaster_complete;
by projnum;
run;

data Jones Smith Brown;
set newmaster_total;
if consultant = 'Jones' then output Jones;
else if consultant = 'Smith' then output Smith;
else output Brown;
run;



/*
if first.projnum then do;
    total_hours = total_hours + hours;
    start_date = first.date;
    end;
if last.projnum then do;
    end_date = last.date;
    end;
keep projnum total_hours type complete start_date end_date;
run;
*/
    








