---Restructure the standards table

select NAICS_Industry_Description,
		iif (NAICS_Industry_Description like '%–%', substring(NAICS_Industry_Description, 8,2),'')
from sba_industry_std
where NAICS_Codes=''

--OR
select NAICS_Industry_Description,sector,sector_code
into sba_naics_sector_table
from
(select NAICS_Industry_Description,
	case when 
	NAICS_Industry_Description like '%–%' 
	then substring(NAICS_Industry_Description,charindex('–',NAICS_Industry_Description)+1,len(NAICS_Industry_Description)) end as sector,
	case when
	NAICS_Industry_Description like '%–%'
	then substring(NAICS_Industry_Description,8,2) end as sector_code
from sba_industry_std
where NAICS_Codes='') ltab
where sector_code!=''

----we will insert the missing sector codes into the sector table
insert into sba_naics_sector_table values
('Sector 31 – 33 – Manufacturing','Manufacturing', 32),
('Sector 31 – 33 – Manufacturing','Manufacturing', 33),
('Sector 44 - 45 – Retail Trade',' Retail Trade', 45),
('Sector 48 - 49 – Transportation and Warehousing','Transportation and Warehousing', 49)

update sba_naics_sector_table
set sector='Manufacturing'
where sector_code=31

select * from sba_naics_sector_table

---Analysis
--check for duplicate data
select loannumber,borrowername
from(
select loannumber,borrowername,
	ROW_NUMBER() over(partition by loannumber,  borrowername order by dateapproved) as dup
from sba_public_data) as duptab
where dup >1
---No dupliate data

---1.What is the summary of all Loans approved?
select *
from sba_public_data

---count of loan, initailapprovalamount, avg loan, loan forgiven

select year(DateApproved) as year,
	count(LoanNumber) as count_of_loans,
	sum(InitialApprovalAmount) as total_approved_loan,
	avg(InitialApprovalAmount) as avg_loan,
	sum(ForgivenessAmount) as total_loan_forgiven
from sba_public_data
group by year(DateApproved)
order by 3 desc


---The number of lenders  that facilitated loans each year
select year(DateApproved) year,
	count(distinct OriginatingLender) count_of_lenders,
	count(LoanNumber) as no_of_loan_app,
	sum(InitialApprovalAmount) sum_of_loans,
	avg(InitialApprovalAmount) avg_loan
from sba_public_data
group by year(DateApproved)
order by 4 desc


---The lenders that helped to facilitate the loans

select distinct OriginatingLender,
	count(LoanNumber) as no_of_loan_app,
	sum(InitialApprovalAmount) sum_of_loans,
	avg(InitialApprovalAmount) avg_loan
from sba_public_data
where year(DateApproved)=2021
group by OriginatingLender
order by 3 desc


---The top 20 industries/sector that received loans each year
---2020
select top 20 s.sector,
	count(LoanNumber) count_of_lon_applicatn,
	sum(InitialApprovalAmount) sum_of_loans_approved,
	avg(InitialApprovalAmount) avg_loan
from sba_public_data as d
left join sba_naics_sector_table as s
on left(d.NAICSCode,2)=s.sector_code
where year(DateApproved) =2020
group by s.sector
order by 3 desc

---2021
select top 20 s.sector,
	count(LoanNumber) count_of_lon_applicatn,
	sum(InitialApprovalAmount) sum_of_loans_approved,
	avg(InitialApprovalAmount) avg_loan
from sba_public_data as d
 join sba_naics_sector_table as s
on left(d.NAICSCode,2)=s.sector_code
where year(DateApproved) =2020
group by s.sector
order by 3 desc

---allocation of loans by sector in percentage
with sector_tab as
(select s.sector,
	count(LoanNumber) as loan_app_count,
	sum(InitialApprovalAmount) as total_loans_approved,
	avg(InitialApprovalAmount) as avg_loan
from sba_public_data d
 join sba_naics_sector_table s
on left(d.NAICSCode,2)=s.sector_code
where year(DateApproved)=2020
group by s.sector)

select *,
	round((total_loans_approved/sum(total_loans_approved)over()),4) *100 as PerecentLoanApproved
from sector_tab
order by 3 desc

---How much of the loan has been forgiven?
with forg_table as
(select year(DateApproved) year,
	count(LoanNumber) LoanCount,
	sum(CurrentApprovalAmount) TotApprovedLoan,
	sum(ForgivenessAmount) TotForgivenLoan
from sba_public_data
group by year(DateApproved))

select year,
	TotApprovedLoan,
	TotApprovedLoan-TotForgivenLoan as LoanLeft,
	(TotForgivenLoan/TotApprovedLoan) * 100 as PercentForgiven
from forg_table

---How much of the loan has been forgiven per sector?
;with secloan as 
(
select year(DateApproved) year,
	s.sector,
	count(d.LoanNumber) LoanCount,
	round(sum(d.InitialApprovalAmount),2) RequestedLoan,
	round(sum(d.CurrentApprovalAmount),2) ApprovedLoan,
	round(sum(d.ForgivenessAmount),2) ForgivenLoan
from sba_public_data as d
join sba_naics_sector_table as s
on left(d.NAICSCode,2)=s.sector_code
where year(d.DateApproved)=2021
group by year(d.DateApproved),s.sector)

select *,
	ApprovedLoan-ForgivenLoan as NotForgivenLoan,
	(ForgivenLoan/ApprovedLoan) * 100 as PerctLoanForgiven
from secloan
order by PerctLoanForgiven desc

---month where the highest loan approved
select
	year(DateApproved) year,
	count(LoanNumber) LoanCount,
	month(DateApproved) month,
	round(sum(CurrentApprovalAmount),2) TotalApprovedLoan
from sba_public_data
group by   year(DateApproved),month(DateApproved)
order by TotalApprovedLoan desc

--Who got the highest loan

select distinct BorrowerName,
	s.sector,
	year(DateApproved) as year,
	month(DateApproved) as month,
	round(sum(CurrentApprovalAmount),2) as TotalLoan
from sba_public_data as d
join sba_naics_sector_table as s
on left(d.NAICSCode,2)=s.sector_code
group by BorrowerName,year(DateApproved),month(DateApproved),s.sector
order by TotalLoan desc

---combining the tables for visualization
create view sba_data as
select d.*,s.*
from sba_public_data as d
join sba_naics_sector_table as s
on left(d.NAICSCode,2)=s.sector_code


