
--Selecting the necessary data
Select 
	Location, 
	date, 
	total_cases, 
	new_cases, 
	total_deaths, 
	population
From 
	PortfolioProject..CovidDeaths$
Order by
	Location, date

	
--Calculating the mortality rate on a daily rolling basis
--Shows the number of dead as a % of number of infected
Select 
	Location, 
	date, 
	total_cases, 
	total_deaths, 
	(total_deaths/total_cases)*100 as MortalityRate
From 
	PortfolioProject..CovidDeaths$
Where 
	total_cases is not null and iso_code not like '%owid%'
Order by 
	1,2
--This can also be used drilled down for specific countries. Nigeria has been used as an example here
Select 
	Location, 
	date, 
	total_cases, 
	total_deaths, 
	(total_deaths/total_cases)*100 as MortalityRate
From 
	PortfolioProject..CovidDeaths$
Where 
	total_cases is not null and location like '%nigeria%'
Order by 
	1,2

	
--Investigating infection rates by country. Shows the % of the population infected
Select 
	Location, 
	population, 
	max(total_cases) as HighestInfectionCount, 
	max((total_cases/population))*100 as InfectionRate
From 
	PortfolioProject..CovidDeaths$
Where 
	continent is not null and total_cases is not null
Group by 
	location, population
Order by 
	InfectionRate desc

	
--Investigating the total number of deaths by country
Select 
	Location, 
	population, 
	max(cast(total_deaths as int)) as DeathCount
From 
	PortfolioProject..CovidDeaths$
Where 
	continent is not null
Group by 
	location, population
Order by 
	DeathCount desc

	
--Investigating the total number of deaths by continent
Select 
	location, 
	max(cast(total_deaths as int)) as DeathCount
From 
	PortfolioProject..CovidDeaths$
Where 
	iso_code not like '%owid%'
Group by 
	location
Order by 
	DeathCount desc


--Investigating the global death rate per day
--here, we use nullif() to avoid a zero division error by converting zero to null and use isnull() to convert null to zero
Select 
	date, 
	SUM(new_cases) as total_cases, 
	SUM(new_deaths) as total_deaths, 
	nullif(SUM(new_deaths),0)/nullif(sum(new_cases),0)*100 as DeathRate
From 
	PortfolioProject..CovidDeaths$
Where 
	continent is not null
Group by 
	date
Order by 
	1,2

	
--Total number of infections (cases) and deaths across the entire period. I.e., lumping up the previous query
Select 
	SUM(new_cases) as total_cases, 
	SUM(new_deaths) as total_deaths, 
	nullif(SUM(new_deaths),0)/nullif(sum(new_cases),0)*100 as DeathRate
From 
	PortfolioProject..CovidDeaths$
Where 
	continent is not null


--Total cases globally broken down by country and year
--Method 1: using querying for each year separately
Select 
	location, 
	isnull(sum(new_cases),0) as TotalCases
From 
	PortfolioProject..CovidDeaths$
Where 
	date like '2020%' and iso_code not like '%owid%'
Group by 
	location
Order by 
	TotalCases desc
--Repeat the above query for 2021, 2022, and 2023


--Method 2: Grouping by country and year. This is better and cleaner
	--Step 1: Create a new column called 'year' and add it to the table
Alter table 
	PortfolioProject..CovidDeaths$
Add year 
	nvarchar(50)

	--Step 2: Use parsename to split the date, extract the year and set it to the newly created 'year' column
		/*Step 2.1: To do this, we first have to replace the hyphens in the date with periods as parsename only
			    accepts periods as delimiters. Parsename also counts from right to left, beginning at 1.
			    So, in this instance, the year will be the third of three items after the date is split.*/
Update 
	PortfolioProject..CovidDeaths$
Set 
	year = parsename(replace(date,'-','.'),3)

	--Step 3: Now we write the body of the query 
Select 
	location, 
	year, 
	max(total_cases) as TotalCases
From 
	PortfolioProject..CovidDeaths$
Where
	iso_code not like '%owid%'
Group by 
	location, year
Order by 
	location, year


--Investigating the daily number of vaccinated individuals by country in each continent
Select 
	d.continent, 
	d.location, d.date, 
	d.population, 
	vax.new_vaccinations, 
	SUM(vax.new_vaccinations) over (partition by d.location Order by d.location, d.date) as VaxxedToDate 
--This entire line (above) takes the death in each day in a specific location and adds them to those of the preceding day, thereby creating a rolling count
From 
	PortfolioProject..CovidDeaths$ as d
JOIN 
	PortfolioProject..CovidVaccinations$ as vax
	ON 
	d.location = vax.location
	and 
	d.date = vax.date
Where 
	d.continent is not null
Order by 
	2,3
/*Running this code kept throwing this error: “ORDER BY list of RANGE window frame has total size of 1020 bytes. Largest size supported is 900”
Upon research, turns out too many characters (255) were allocated to the location column, causing a bloat. Since we know no country has a name consisting
of 255 characters, we can reduce the number of allocated characters cutting down the required memory space by doing the following:*/

Alter table 
	PortfolioProject..CovidDeaths$
Alter column 
	location nvarchar(50)
--Running the query again should give the desired result now


--Investigating the rolling total number of people vaccinated as a percentage of the population
--Method 1: Using a CTE
With 
	VaccinatedPopulation 
	(Continent, 
	location, 
	date, 
	population, 
	new_vaccinations, 
	VaccinationsToDate)
as 
	(
	Select 
	d.continent, 
	d.location, 
	d.date, 
	d.population, 
	vax.new_vaccinations,
SUM(vax.new_vaccinations) over (partition by d.location Order by d.location, d.date) as VaccinationsToDate 
From 
	PortfolioProject..CovidDeaths$ as d
JOIN 
	PortfolioProject..CovidVaccinations$ as vax
	ON 
	d.location = vax.location
	and 
	d.date = vax.date
Where 
	d.continent is not null
	)
Select 
	*, 
	(VaccinationsToDate/population)*100 as PercentageVaccinated
From 
	VaccinatedPopulation

--Method 2: Using a temp table
Drop table if exists 
	#VaccinatedPopulation
Create Table 
	#VaccinatedPopulation
	(
	continent nvarchar(150), 
	Location nvarchar(150), 
	Date datetime, 
	Population numeric, 
	new_vaccination numeric, 
	VaccinationsToDate numeric
	)

Insert into 
	#VaccinatedPopulation
Select 
	d.continent, 
	d.location, 
	d.date, 
	d.population, 
	vax.new_vaccinations,
	SUM(vax.new_vaccinations) over (partition by d.location Order by d.location, d.date) as VaccinationsToDate
From 
	PortfolioProject..CovidDeaths$ as d
JOIN 
	PortfolioProject..CovidVaccinations$ as vax
	ON 
	d.location = vax.location
	and 
	d.date = vax.date
Where 
	d.continent is not null
Select 
	*, (VaccinationsToDate/population)*100 as PercentageVaccinated
From 
	#VaccinatedPopulation


--Creating views which can be used for future visualisations
--View 1: Infection rate by country	
Create View InfectionRateByCountry as
Select 
	Location, 
	population, 
	max(total_cases) as HighestInfectionCount, 
	max((total_cases/population))*100 as InfectionRate
From 
	PortfolioProject..CovidDeaths$
Where 
	continent is not null and total_cases is not null
Group by 
	location, population

--View 2: Infection rate by country	
Create View PercentPopulationVaccinated as
Select 
	d.continent, 
	d.location, d.date, 
	d.population, 
	vax.new_vaccinations,
	SUM(vax.new_vaccinations) over (partition by d.location Order by d.location, d.date) as VaccinationsToDate 
From 
	PortfolioProject..CovidDeaths$ as d
JOIN 
	PortfolioProject..CovidVaccinations$ as vax
	ON 
	d.location = vax.location
	and 
	d.date = vax.date
Where d.continent is not null

--View 3: Total cases globally broken down by country and year. This could be used for interactive dashboards
Select 
	location, 
	year, 
	max(total_cases) as TotalCases
From 
	PortfolioProject..CovidDeaths$
Where
	iso_code not like '%owid%'
Group by 
	location, year
Order by 
	location, year
