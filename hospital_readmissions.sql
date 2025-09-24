#Check MySQL secure folder (where files can be read/written)
SHOW VARIABLES LIKE 'secure_file_priv';
#Switch to the project database
USE vbc_project;
#Clear the table so we don’t get duplicate rows if we reload
TRUNCATE TABLE hospital_visits;
#Load the hospital readmissions CSV file into the table
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 9.4/Uploads/hospital_readmissions.csv'
INTO TABLE hospital_visits
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
  age,
  time_in_hospital,
  discharge_date,
  follow_up_date,
  cpt_code,
  cost_usd,
  n_lab_procedures,
  n_procedures,
  n_medications,
  n_outpatient,
  n_inpatient,
  n_emergency,
  medical_specialty,
  diag_1,
  diag_2,
  diag_3,
  glucose_test,
  A1Ctest,
  `change`,
  diabetes_med,
  readmitted
);

#Sanity checks to confirm data is loaded correctly
SELECT COUNT(*) FROM hospital_visits;
SELECT * FROM hospital_visits LIMIT 10;
SELECT 
  SUM(discharge_date IS NULL) AS missing_discharge,
  SUM(follow_up_date IS NULL) AS missing_followup
FROM hospital_visits;

#Simple example - average hospital stay by age group
SELECT age, AVG(time_in_hospital) AS avg_days
FROM hospital_visits
GROUP BY age
ORDER BY age;

CREATE OR REPLACE VIEW visit_enriched AS
SELECT
  v.*,
  DATEDIFF(v.follow_up_date, v.discharge_date) AS days_to_followup,
  CASE
    WHEN v.follow_up_date IS NOT NULL AND DATEDIFF(v.follow_up_date, v.discharge_date) <= 7  THEN '≤7d'
    WHEN v.follow_up_date IS NOT NULL AND DATEDIFF(v.follow_up_date, v.discharge_date) BETWEEN 8 AND 14 THEN '8–14d'
    ELSE '>14d / none'
  END AS followup_window,
  CASE
    WHEN UPPER(v.readmitted) IN ('<30','YES') THEN 'Yes'
    ELSE 'No'
  END AS readmit_flag
FROM hospital_visits v;
SELECT * FROM visit_enriched LIMIT 10;

#Simple example - average hospital stay by age group
SELECT
  followup_window,
  COUNT(*)                                     AS patients,
  ROUND(AVG(readmit_flag='Yes')*100,2)         AS readmit_rate_pct,
  ROUND(AVG(cost_usd),0)                       AS avg_cost_usd
FROM visit_enriched
GROUP BY followup_window
ORDER BY FIELD(followup_window,'≤7d','8–14d','>14d / none');

#KPI view: by follow-up window
CREATE OR REPLACE VIEW kpi_by_window AS
SELECT
  followup_window,
  COUNT(*)                                     AS patients,
  ROUND(AVG(readmit_flag='Yes')*100,2)         AS readmit_rate_pct,
  ROUND(AVG(cost_usd),0)                       AS avg_cost_usd
FROM visit_enriched
GROUP BY followup_window
ORDER BY FIELD(followup_window,'≤7d','8–14d','>14d / none');

#KPI view: by medical specialty
CREATE OR REPLACE VIEW kpi_by_specialty AS
SELECT
  medical_specialty,
  COUNT(*)                              AS patients,
  ROUND(AVG(readmit_flag='Yes')*100,2)  AS readmit_rate_pct,
  ROUND(AVG(cost_usd),0)                AS avg_cost_usd
FROM visit_enriched
GROUP BY medical_specialty
ORDER BY patients DESC;

#KPI view: by age group and follow-up window
CREATE OR REPLACE VIEW kpi_age_window AS
SELECT
  age,
  followup_window,
  COUNT(*)                              AS patients,
  ROUND(AVG(readmit_flag='Yes')*100,2)  AS readmit_rate_pct,
  ROUND(AVG(cost_usd),0)                AS avg_cost_usd
FROM visit_enriched
GROUP BY age, followup_window;

#KPI view: distribution of follow-up days
CREATE OR REPLACE VIEW kpi_followup_dist AS
SELECT
  days_to_followup,
  COUNT(*) AS patients
FROM visit_enriched
GROUP BY days_to_followup
ORDER BY days_to_followup;

#Show follow-up windows with patient counts and readmit rates
SELECT * FROM kpi_by_window;

-- Show specialties with patient counts and readmit rates
SELECT * FROM kpi_by_specialty LIMIT 10;
