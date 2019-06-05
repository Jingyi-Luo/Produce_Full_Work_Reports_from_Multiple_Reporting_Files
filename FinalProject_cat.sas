
* Statistics 6430: SAS Final Project ;
* Catherine Beazley and Jingyi Luo ;
* cmb5et and jl6zh ;



*================================================================================;
*=========================== Objective 1 ========================================;
*================================================================================;

* Reading in all the files and saving to temp datasets ;
filename correc 'C:\Users\cathe\Desktop\STAT6430\Corrections.csv';
data corrections;
infile correc dsd firstobs=2;
retain projnum date hours stage;
informat date $10.;
input projnum date $ hours stage;
format date $10.;
run;

filename assig 'C:\Users\cathe\Desktop\STAT6430\Assignments.csv';
data assignment;
infile assig dsd firstobs=2;
input consultant $ projnum;
run;

filename master1 'C:\Users\cathe\Desktop\STAT6430\Master.csv';
data master;
infile master1 dsd firstobs=2;
retain consultant projnum date hours stage complete;
informat consultant $6. projnum 3. date $10. hours 3.2 stage 2. complete 2.;
input consultant $ projnum date hours stage complete;
run;

filename nwfrm 'C:\Users\cathe\Desktop\STAT6430\NewForms.csv';
data newforms;
infile nwfrm dsd firstobs=2;
retain projnum date hours stage complete;
informat date $10.;
input projnum date $ hours stage complete;
run;

filename proj 'C:\Users\cathe\Desktop\STAT6430\ProjClass.csv';
data projclass;
infile proj dsd firstobs=2;
retain type projnum;
informat type $18.;
input type $ projnum;
run;


* Creating a dataset of all the consultant names and project numbers ;

* First need to sort by project number;
proc sort data=master;
by projnum;
run; 

* This is a dataset of all the consultants and project numbers from the original master file (master.csv); 
data consultsM;
set master;
by projnum;
keep consultant projNum;
if first.projnum then output;
run;

* Merging with assignments to get list of all unique pairs of consultants and project number;
proc sort data=assignment;
by projnum;
run; 

* This is list of all consultant and project number pairs ;
data consultants;
merge consultsM assignment;
by projnum;
run;

* Now that we have all consultant/projnum pairs, interleaving old master with new forms;

* First need to update New Forms by filling in consultant names. 
Merging dataset of all unique consultants and project numbers to do so ;
proc sort data=newforms;
by projnum;
run;

data updNewForms;
merge consultants newforms(in=in2);
by projnum;
if in2;
run;

* Interleaving the complete New Forms with the old master;
data master1;
set updNewForms master;
by projnum;
informat date $10.;
format date $10.;
run;

* Correcting the above master file according to the corrections dataset ;

* First need to sort both datasets according to project number and date;
proc sort data=master1;
by projnum date;
run; 

proc sort data=corrections;
by projnum date;
run;

* Need to combine rows within the corrections dataset that have the same projnum and date ;
data correc2;
update corrections (obs=0) corrections;
by projnum date;
run;
* https://communities.sas.com/t5/Base-SAS-Programming/How-can-I-combine-multiple-rows-to-a-single-row/td-p/16151 ;

* Updating the master set using the corrections dataset ;
data updated;
merge master1(in=in1) correc2(rename=(stage=stageupd hours=hoursupd) in=in2);
by projnum date;
if stageupd ^= . then do;
	stage=stageupd;
	correction="Yes";
	end;
if hoursupd ^= . then do;
	hours=hoursupd;
	correction="Yes";
	end;
else correction="No";
drop stageupd hoursupd;
run;

* Adding project Classifications to the new Master file ;
proc sort data=updated;
by projnum;
run;

proc sort data=projclass;
by projnum;
run;

data finalmstr;
merge updated(in=in1) projclass(in=in2);
by projnum;
format type $18.;
run;

* Filling the missing values:
If project complete and stage missing, set stage=4, if not complete and first instance of stage, set stage=1, 
else stage=previous stage. If hours missing, set hours=0 ;

* First need to sort by projnum, complete, stage, and date;
proc sort data=finalmstr;
by projnum complete stage date;
run; 

* Following two datasets fill in missing hours and missing stages ;
data fixdmstr;
set finalmstr;
if missing(hours) then hours=0;
if missing(stage) & complete = 1 then stage = 4;
else if missing(stage) & lag(complete)=1 then stage=1;
run;

* In one case, there are two consecutive missing stages. By making two columns of the lag stage value I could
fill them in. ;
data fixedmstr2;
set fixdmstr;
lag_stage=lag(stage);
lag_stage2=lag(lag_stage);
if missing(stage) & complete=0 then stage=lag_stage;
if missing(stage) & complete=0 & missing(lag_stage) then stage=lag_stage2;
drop lag_stage lag_stage2;
run;
* https://communities.sas.com/t5/Base-SAS-Programming/Use-previous-row-value-of-one-variable-for-a-new-variable/td-p/389443 ;

* Printing out Final Report of New Master.;
title 'Analytic Consulting Lab: Consulting Projects Report';
proc print data=fixedmstr2 noobs label;
var consultant projnum type date hours stage complete correction;
label consultant='Consultant' projnum='Project Number' type='Project Type' date='Date' hours='Hours Worked' stage='Project Stage' complete='Completed? (0=no 1=yes)' correction='Correction Made?';
run;

* Writing the Final Master Dataset to a csv file ;
filename fullmstr 'C:\Users\cathe\Desktop\STAT6430\NewMaster.csv';
data _NULL_;
set fixedmstr2;
file fullmstr dsd;
put consultant projnum type date hours stage complete correction;
run;

* Saving the Final Master Dataset into a permanent SAS file ;

libname outdata 'C:\Users\cathe\Desktop\STAT6430';
data outdata.master;
set fixdmstr;
run;

*================================================================================;
*=========================== Objective 2 ========================================;
*================================================================================;

* Sorting the master by project number, complete, and stage;
proc sort data=fixdmstr;
by projnum complete;
run;

* Summing 'complete' per project number. All sums will be either 0, 1, or 2 ;
data ongoing1;
set fixdmstr;
by projnum;
retain sum_complete;
if first.projnum then sum_complete=0;
sum_complete = sum_complete + complete;
if last.projnum then output;
keep projnum sum_complete;
run;

* Pulling out all instances where the sum of complete per projnum is 0 because that means there 
was never a 1 in complete column that would indicate complete. ;

data ongoing (label='Project Numbers of Ongoing Projects');
set ongoing1;
if sum_complete = 0;
keep projnum;
run;

* Printing out Final Report of Ongoing Project ;
title 'Project Numbers of Ongoing Projects';
proc print data=ongoing noobs label;
var projnum;
label projnum='Project Number';
run;

*================================================================================;
*=========================== Objective 3 ========================================;
*================================================================================;

* Changing to Date format ;
data masterDate (drop=date rename=(num_date=date));
set outdata.master;
num_date=input(date, MMDDYY10.);
format num_date MMDDYY10.;
run;

proc sort data=masterDate;
by projnum complete stage date;
run;

* Creating start date and end date columns;
data dates;
set masterDate;
by projnum;
retain start_date end_date;
if first.projnum then start_date=date;
if last.projnum then end_date=date;
format date MMDDYY10.;
run;

data datesFinal;
set dates;
by projnum;
format date MMDDYY10.;
if last.projnum then output;
keep projnum start_date end_date;
run;


* Calculating the hours worked. ;
proc means data=masterDate noprint;
class consultant projnum;
output out=hrsWorked1 sum(hours)=hours_worked;
run;

data hrsworked;
set hrsworked1;
if ^missing(consultant) & ^missing(projnum);
keep projnum hours_worked;
run;

* Merging hrsworked and start/end date so that I have projnum, startdate, enddate, hrsworked ;
proc sort data=hrsworked;
by projnum;
run;


* DatesFinal is already sorted by projnum so I can merge without sorting beforehand. ;
data datesHrs;
merge datesFinal hrsworked;
by projnum;
run;

* Creating whether or not completed column. Already sorted by complete so don't need to sort here. ;
* Adds consultant, type, and completed as columns;
data complete1;
set masterdate;
by projnum;
retain sum_complete;
if first.projnum then sum_complete=0;
sum_complete = sum_complete + complete;
if last.projnum then output;
keep consultant projnum sum_complete type;
run;

data complete;
set complete1;
informat complete $3.;
if sum_complete=0 then complete="No";
else complete="Yes";
format complete 3.;
drop sum_complete;
run;

* Adding completed column ;

* This is the dataset of all consultants and their projects hours_worked, type, completed, start_date, and end_date per project ;
data fullactivity;
merge complete dateshrs;
by projnum;
retain hours_worked type completed start_date end_date;
format start_date end_date MMDDYY10.;
run;

* This creates a dataset per consultant. ;
data Brown Jones Smith;
set fullactivity;
if consultant="Brown" then output Brown;
if consultant="Jones" then output Jones;
if consultant="Smith" then output Smith;
drop consultant;
run;

* Printing out Final Consultant Activity Datasets ;
title "Consulting Activity: Brown";
proc print data=Brown noobs label;
label projnum="Project Number" type="Project Type" complete="Completed?" start_date="Project Start Date" end_date="Project End Date" hours_worked="Hours Worked";
run;

title "Consulting Activity: Jones";
proc print data=Jones noobs label;
label projnum="Project Number" type="Project Type" complete="Completed?" start_date="Project Start Date" end_date="Project End Date" hours_worked="Hours Worked";
run;

title "Consulting Activity: Smith";
proc print data=Smith noobs label;
label projnum="Project Number" type="Project Type" complete="Completed?" start_date="Project Start Date" end_date="Project End Date" hours_worked="Hours Worked";
run;

*================================================================================;
*=========================== Objective 4 ========================================;
*================================================================================;

* Making a dataset of the four types of project and the average amount of hours each took to complete.;

data master4;
set outdata.master;
run;

* First, creating a dataset of all the completed projects and the hours each project took.;

* finding all the completed projects ;
proc sort data=master4;
by projnum complete stage;
run;

data comp4a;
set master4;
by projnum;
retain sum_complete;
if first.projnum then sum_complete=0;
sum_complete = sum_complete + complete;
if last.projnum then output;
run;

* This is a data set of all the completed projects. ;
data comp4b;
set comp4a;
if sum_complete ^= 0;
keep projnum;
run;

* Now summing hours worked per project;
proc means data=master4 noprint;
class projnum type;
output out=hrstype sum(hours)=hours_worked;
run;

* This is the final dataset of hours worked per project with project type.;
data hrstype2;
set hrstype;
if ^missing(projnum) & ^missing(type);
keep projnum type hours_worked;
run;

* Matching set of completed project numbers with the hours_worked totals dataset to make a dataset of completed projects 
with total hours worked per project.(This step gets rid of ongoing projects from hrstype2) ;
proc sort data= comp4b;
by projnum;
run;

proc sort data= hrstype2;
by projnum;
run;

* This is a dataset of all completed projects with the hours worked per project;
data compHrsType;
merge comp4b(in=in1) hrstype2(in=in2);
by projnum;
if in1;
run;

* Now grouping by project type with average hours worked per type;
proc means data=compHrsType noprint;
class type;
output out=typeHours mean(hours_worked)=avg_hours;
run;

* This is the final dataset of the four types of project type and the average hours worked for each.;
data hrsTypeFinal;
set typeHours;
if ^missing(type);
drop _TYPE_;
run;

*Printing out Final Dataset of Average Hours Worked per Project Type ;
title 'Average Hours Worked per Project Type';
proc print data=hrsTypeFinal noobs label;
label type='Project Type' _FREQ_='Number of Projects' avg_hours='Average Hours Worked';
run;

* Now creating a bar chart of average number of hours it takes to complete each type of project: ;

* Printing bar chart of Average Hours Worked Per Project Type ;
title 'Average Hours Worked Per Project Type';
proc sgplot data=hrsTypeFinal;
vbar type / response = avg_hours;
xaxis label='Project Type';
yaxis label='Average Hours Worked';
run;



* Now making a dataset of the average amount of time each consultant spent on each project type. ;

* Creating 3 datasets. One for each consultant. Each dataset shows the project types, how many of each project the 
consultant has done, and how long on average they spent on each type. ;

* The 'Brown' 'Jones' and 'Smith' datasets are from Objective 3 and consist of the project numbers, types, start dates,
end dates, and hours worked of each consultant. ;

* Brown. These three steps will create a dataset of the four project types, number of each and the average number of hours Brown
spent on each.;
proc means data=Brown noprint;
class type;
output out=browntypes mean(hours_worked)=avg_hours ;
run;

proc sort browntypes;
by type;
run;

data Brownavgs;
set browntypes;
if ^missing(type);
drop _TYPE_;
run;

* Jones. These three steps will create a dataset of the four project types, number of each, and the average number of hours Jones
spent on each.;
proc means data=Jones noprint;
class type;
output out=jonestypes mean(hours_worked)=avg_hours;
run;

data jonesavgs;
set jonestypes;
if ^missing(type);
drop _TYPE_;
run;

* Smith. These three steps will create a dataset of the four project types, number of each, and the average number of hours Smith
spent on each.;
proc means data=Smith noprint;
class type;
output out=smithtypes mean(hours_worked)=avg_hours;
run;

data smithavgs;
set smithtypes;
if ^missing(type);
drop _TYPE_;
run;

* Printing datasets for each consultant of project type, number of projects per type, and average hours worked per type. ;
title 'Brown: Average Hours Spent per Project Type';
proc print data=brownavgs noobs label;
label type='Project Type' _FREQ_='Number of Projects' avg_hours='Average Hours Worked';
run;

title 'Jones: Average Hours Spent per Project Type';
proc print data=jonesavgs noobs label;
label type='Project Type' _FREQ_='Number of Projects' avg_hours='Average Hours Worked';
run;

title 'Smith: Average Hours Spent per Project Type';
proc print data=smithavgs noobs label;
label type='Project Type' _FREQ_='Number of Projects' avg_hours='Average Hours Worked';
run;

* Creating dataset of the average hours worked per project type per consultant;

* 'fullactivity' is a dataset from Objective 3 that has all of the consulting activity of all consultants ;
proc means data=fullactivity noprint;
class consultant type;
output out=consulPlot1 mean(hours_worked)=avg_hours;
run;

* Editing the dataset above to only show consultant, project types, number of completed projects of each type, 
and average hours worked per project. ;
data consulplot;
set consulplot1;
informat consultant $8.;
if _TYPE_ = 3;
drop _TYPE_;
run;


* Adding overage averages to above dataset to compare average to the consultants ;

* 'hrstypefinal' is the Final Dataset of Average Hours Worked per Project Type. Merging that
with the data set of consultant, project type, number of that type of projects performed, 
and average hours from above.;
data final;
set consulplot hrstypefinal;
if missing(consultant) then consultant="Avg";
run;

* Bar chart of Average Hours Worked per Project Type per Person with Average included;
title 'Average Hours Worked per Project Type per Person, Average included';
proc sgplot data=final;
vbar consultant/ group=type groupdisplay=cluster response=avg_hours;
xaxis label='Consultant';
yaxis label='Average Hours Worked';
run;

* Bar chart of Average Hours Worked per Project Type per Person;
title 'Average Hours Worked per Project Type per Person';
proc sgplot data=consulplot;
vbar consultant/ group=type groupdisplay=cluster response=avg_hours;
xaxis label='Consultant';
yaxis label='Average Hours Worked';
run; 
*https://blogs.sas.com/content/iml/2011/08/12/side-by-side-bar-plots-in-sas-9-3.html;



