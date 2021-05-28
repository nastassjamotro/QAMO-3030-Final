*Set directory for data
	cd "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0"

*Turn csv files into dta files
	// run only once
	foreach file in indexes indexes2 us-states {
		import delimited using `file'.csv, clear
		save `file'
	}


cd "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0"
* Collapsing NY Times Case Counts
	use "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0/us-states.dta", replace
		gen date2 = date(date,"YMD")
		// Indexes: 3/29 - 4/04, 4/04 - 4/11
		
	// keep if week of date or week prior to date
		gen daysSince329 = date2-td(29mar2021) // number of days since 3/29
		gen daysSince404 = date2-td(04apr2021) // number of days since 4/04
		keep if (daysSince329 >= -7 & daysSince329 <= 7) | (daysSince404 >= -7 & daysSince404 <= 7)
		
	// collapse by weeks
		gen week = .
			replace week = 1 if daysSince329 >=- 7 & daysSince329 < 0		// week before 3/29
			replace week = 2 if daysSince329 >= 0 & daysSince329 < 7		// week of 3/29
			replace week = 3 if daysSince404 >= 0 & daysSince404 <= 7 		// week of 4/04
		collapse (sum) cases deaths (min) date2, by(week state fip)
		
		gen day = day(date2)
		gen month = month(date2)
		gen year = year(date2)
		
	// generating change and % change variables, week by week
		sort state week
		by state: gen ch_cases = cases - cases[_n-1] 	// change in case counts since last week
		by state: gen ch_deaths = deaths - deaths[_n-1] 	// change in deaths since last week
		
		gen log_cases = log(cases)
		gen log_deaths = log(deaths)
		
		by state: gen pct_ch_cases = log_cases - log_cases[_n-1] 	// % change in case counts since last week
		by state: gen pct_ch_deaths = log_deaths - log_deaths[_n-1] // % change in deaths since last week
		
		drop if week == 1
		drop week
		sort state date2
		
		save cdc_by_week.dta, replace
		
* Reading in 3/29 Week File
	use "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0/indexes.dta", replace
	keep if v2 != "NAICS_SECTOR"
	rename v1 stateAbr
	rename v2 naics
	rename v3 index_name
	rename v4 estimate_percentage	
	drop if stateAbr == "-"
	drop naics
	
	gen month = 3
	gen day = 29
	gen year = 2021
	gen date2 = mdy(month, day, year)
	
	save index1.dta, replace

* Reading in 4/04 Week File
	use "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0/indexes2.dta", replace
	keep if v2 != "NAICS_SECTOR"
	rename v1 stateAbr
	rename v2 naics
	rename v3 index_name
	rename v4 estimate_percentage	
	drop if stateAbr == "-"
	drop naics

	gen month = 4
	gen day = 4
	gen year = 2021
	gen date2 = mdy(month, day, year)
	
	save index2.dta, replace
	
* Append two weeks of data together
	cd "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0"
	use "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0/index1.dta"
	append using index2.dta
	save index, replace

* Merging Together
	// state in CPS data is abbreviation, state in CDC is full name
		statastates, a(stateAbr) 	//matches full name to abbreviation
		drop _merge
		rename state_fips fips
	sort fips date2
	
	merge m:1 fips date2 using cdc_by_week.dta
		keep if _merge == 3
		drop _merge
		
* Cleaning Data
	keep if index_name == "Overall sentiment index"
	destring estimate_percentage, generate(est_percent) ignore("%") //changing string variable into numeric
	drop estimate_percentage
	
* Running First Basic Regression
	reg est_percent cases, robust

* Add in population variable to control for different densities per state
	cd "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0"
	// run only once
	foreach file in state-pop {
		import delimited using `file'.csv, clear
		save `file'
	}
	drop ïrank
	save state-pop, replace
	
* Merging in population data
	cd "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0"
	merge m:1 state using state-pop.dta
	keep if _merge == 3
	drop _merge 
	drop pop2018 pop2010 growth growthsince2010 percent density
	
	save CDC_weekly.dta, replace

	
* Reading in Oxford Data
	cd "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0"
	// run only once
	foreach file in OxCGRT_US_latest {
		import delimited using `file'.csv, clear
		save `file'
	}
	
	use "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0/OxCGRT_US_latest.dta", replace
	rename regionname state
	drop countryname countrycode jurisdiction regioncode 
	drop c1_flag c1_notes c2_flag c2_notes c3_flag c3_notes c4_flag c4_notes c5_flag c5_notes c6_flag c6_notes c7_flag c7_notes c8_notes e1_flag e1_notes e2_notes e3_notes e4_notes h1_flag h1_notes h2_notes h3_notes h4_notes h5_notes h6_flag h6_notes h7_flag h7_notes h8_flag h8_notes m1_notes
	drop if state == ""
	drop confirmedcases confirmeddeaths //already in CDC dataset
	
* Collapsing Oxford data
	tostring date, replace format(%20.0f)
	replace date = "0" + date if length(date) == 7
	gen date2 = date(date, "YMD")
		// dates to keep: 3/29 - 4/04, 4/04 - 4/11
		
	// keep if week of date or week prior to date
		gen daysSince329 = date2-td(29mar2021) // number of days since 3/29
		gen daysSince404 = date2-td(04apr2021) // number of days since 4/04
		keep if (daysSince329 >= -7 & daysSince329 <= 7) | (daysSince404 >= -7 & daysSince404 <= 7)
		
	// collapse by weeks
		gen week = .
			replace week = 1 if daysSince329 >=- 7 & daysSince329 < 0		// week before 3/29
			replace week = 2 if daysSince329 >= 0 & daysSince329 < 7		// week of 3/29
			replace week = 3 if daysSince404 >= 0 & daysSince404 <= 7 		// week of 4/04
		collapse c1_schoolclosing c2_workplaceclosing h6_facialcoverings h7_vaccinationpolicy e1_incomesupport   c3_cancelpublicevents c4_restrictionsongatherings c5_closepublictransport c6_stayathomerequirements c7_restrictionsoninternalmovemen c8_internationaltravelcontrols e2_debtcontractrelief e4_internationalsupport h1_publicinformationcampaigns h2_testingpolicy h3_contacttracing h8_protectionofelderlypeople m1_wildcard stringencyindex stringencyindexfordisplay stringencylegacyindex stringencylegacyindexfordisplay governmentresponseindex governmentresponseindexfordispla containmenthealthindex containmenthealthindexfordisplay economicsupportindex economicsupportindexfordisplay (sum) e3_fiscalmeasures h4_emergencyinvestmentinhealthca h5_investmentinvaccines (min) date2, by(week state)		
		
		drop if week == 1
		drop week
		
		gen day = day(date2)
		gen month = month(date2)
		gen year = year(date2)
		
		sort state date2
		
		save Oxford_by_week.dta, replace
	
* Merging in Oxford data
	cd "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0"
	use CDC_weekly.dta
	merge m:m state using Oxford_by_week.dta
	sort state
	
	keep if _merge == 3
	drop _merge
	drop m1_wildcard
	
	save CDC_Oxford_weekly.dta, replace
	
* Merging in Minimum Wage Data
	cd "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0"
	// run only once
	foreach file in min-wage {
		import delimited using `file'.csv, clear
		save `file'
	}

	use "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0/min-wage.dta", replace
	rename minimumwage min_wage
	save min-wage.dta, replace

	cd "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0"
	use CDC_Oxford_weekly.dta
	merge m:1 state using min-wage.dta
		replace min_wage = 8.75 in 95
		replace min_wage = 8.75 in 96
	
	drop if _merge == 2
	drop _merge
	
	save CDC_Oxford_weekly.dta, replace

* Loading in Business Application Data
	cd "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0"
	// run only once
	foreach file in buss-app {
		import delimited using `file'.csv, clear
		save `file'
	}
	
	use "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0/buss-app.dta", replace
	rename busappwnsaus buss_app
	
* Collapsing data down to two weeks
		gen date2 = date(date, "YMD")
		
	// keep if week of date or week prior to date
		gen daysSince329 = date2-td(29mar2021)
		gen daysSince404 = date2-td(04apr2021)
		keep if (daysSince329 >= -7 & daysSince329 <= 7) | (daysSince404 >= -7 & daysSince404 <= 7)
		
	// keep necessary weeks
		gen week = .
			replace week = 1 if daysSince329 >= -7 & daysSince329 < 0
			replace week = 2 if daysSince329 >= 0 & daysSince329 < 7
			replace week = 3 if daysSince404 >= 0 & daysSince404 <= 7
		collapse (mean) buss_app (min) date2, by(week)

		replace date2 = 22368 in 2
		replace date2 = 22374 in 3
		
	save buss-app.dta, replace
	
* Merging in Business Application Data
	cd "/Users/nastassjamotro/Documents/COLLEGE/SPRING 2021/QAMO 3030/Paper/Data 2.0"
	use CDC_Oxford_weekly.dta, replace
	merge m:1 date2 using buss-app.dta
	
	keep if _merge == 3
	drop _merge week
	
	save CDC_Oxford_weekly.dta, replace

/*---------------------------------------------------------*/

* Running First Basic Regression
	reg est_percent cases, robust
	outreg2 using QAMO3030_Controls_Output.doc, replace ctitle(Basic)
	outreg2 using QAMO3030_Final_Output, excel replace ctitle(Basic)
	
	reg est_percent log_cases, robust
	outreg2 using QAMO3030_Final_Output, excel append ctitle(Basic_Log)
	
	
* Regressions with omitted variable controls
	gen case_rates = cases/pop
	//reg est_percent case_rates c1_schoolclosing c2_workplaceclosing e1_incomesupport h6_facialcoverings h7_vaccinationpolicy deaths, robust
	
	reg est_percent cases pop c1_schoolclosing c2_workplaceclosing e1_incomesupport h6_facialcoverings h7_vaccinationpolicy deaths, robust
	outreg2 using QAMO3030_Controls_Output.doc, append ctitle(Controls)
	outreg2 using QAMO3030_Final_Output, excel append ctitle(Controls)
	
	reg est_percent log_cases pop c1_schoolclosing c2_workplaceclosing e1_incomesupport h6_facialcoverings h7_vaccinationpolicy deaths, robust
	outreg2 using QAMO3030_Final_Output, excel append ctitle(Controls_Log)
	outreg2 using QAMO3030_Controls_Output.doc, append ctitle(Controls_Log)
	

* Regressions with controls that explain Y	
	reg est_percent cases pop c1_schoolclosing c2_workplaceclosing e1_incomesupport h6_facialcoverings h7_vaccinationpolicy deaths min_wage buss_app, robust 
	outreg2 using QAMO3030_Controls_Output.doc, append ctitle(Controls+Y)
	outreg2 using QAMO3030_Final_Output, excel append ctitle(Controls+Y)
	
	reg est_percent log_cases pop c1_schoolclosing c2_workplaceclosing e1_incomesupport h6_facialcoverings h7_vaccinationpolicy deaths min_wage buss_app, robust
	outreg2 using QAMO3030_Final_Output, excel append ctitle(Controls+Y_Log)
	outreg2 using QAMO3030_Controls_Output.doc, append ctitle(Controls+Y_Log)


* Regression with state time fixed effects
	//xtset state date2
	egen state_id = group(state)
	xtset state_id date2
	
	xtreg est_percent cases, fe vce(cluster state)
	outreg2 using QAMO3030_Panel_Output.doc, replace ctitle(Basic)
	
	xtreg est_percent log_cases, fe vce(cluster state)
	outreg2 using QAMO3030_Panel_Output.doc, append ctitle(Basic_Log)
	
	xtreg est_percent cases c1_schoolclosing c2_workplaceclosing e1_incomesupport h6_facialcoverings h7_vaccinationpolicy    buss_app, fe vce(cluster state)
	outreg2 using QAMO3030_Panel_Output.doc, append ctitle(Controls)
	outreg2 using QAMO3030_Final_Output, excel append ctitle(Panel)
	
	xtreg est_percent log_cases c1_schoolclosing c2_workplaceclosing e1_incomesupport h6_facialcoverings h7_vaccinationpolicy   buss_app, fe vce(cluster state)
	outreg2 using QAMO3030_Final_Output, excel append ctitle(Panel_Log)
	outreg2 using QAMO3030_Panel_Output.doc, append ctitle(Controls_Log)

save CDC_Oxford_weekly.dta, replace
	
	
	
	
