
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
	
Select 
	location, 
	isnull(sum(new_cases),0) as TotalCases
From 
	PortfolioProject..CovidDeaths$
Where 
	date like '2021%' and iso_code not like '%owid%'
Group by 
	location
Order by 
	TotalCases desc

Select 
	location, 
	isnull(sum(new_cases),0) as TotalCases
From 
	PortfolioProject..CovidDeaths$
Where 
	date like '2022%' and iso_code not like '%owid%'
Group by 
	location
Order by 
	TotalCases desc

Select 
	location, 
	isnull(sum(new_cases),0) as TotalCases
From 
	PortfolioProject..CovidDeaths$
Where 
	date like '2023%' and iso_code not like '%owid%'
Group by 
	location
Order by 
	TotalCases desc

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
Group by 
	location, year
Order by 
	location, year

--Investigating the daily number of vaccinated individuals by country in each continent

--alter table PortfolioProject..CovidDeaths$
--alter column location nvarchar(50)

Select d.continent, d.location, d.date, d.population, vax.new_vaccinations,
SUM(vax.new_vaccinations) over (partition by d.location Order by d.location, d.date) as VaxxedToDate 
--This entire line takes the death in each day in a specific location and adds them to those of the previous date, thereby creating a rolling count
From PortfolioProject..CovidDeaths$ as d
JOIN PortfolioProject..CovidVaccinations$ as vax
	ON d.location = vax.location
	and d.date = vax.date
Where d.continent is not null
Order by 2,3

--Using a CTE

With PopvsVax (Continent, location, date, population, new_vaccinations, VaxxedToDate)
as
(
Select d.continent, d.location, d.date, d.population, vax.new_vaccinations,
SUM(vax.new_vaccinations) over (partition by d.location Order by d.location, d.date) as VaxxedToDate 
--This entire line takes the death in each day in a specific location and adds them to those of the previous date, thereby creating a rolling count
From PortfolioProject..CovidDeaths$ as d
JOIN PortfolioProject..CovidVaccinations$ as vax
	ON d.location = vax.location
	and d.date = vax.date
Where d.continent is not null
)
Select *, (VaxxedToDate/population)*100 as PercentageVaxxed
From PopvsVax


--Using a temp table

Drop table if exists #PercentPopulationVaccinated
Create Table #PercentPopulationVaccinated
(
continent nvarchar(255), Location nvarchar(255), Date datetime, Population numeric, new_vaccination numeric, VaxxedToDate numeric
)

Insert into #PercentPopulationVaccinated
Select d.continent, d.location, d.date, d.population, vax.new_vaccinations,
SUM(vax.new_vaccinations) over (partition by d.location Order by d.location, d.date) as VaxxedToDate 
From PortfolioProject..CovidDeaths$ as d
JOIN PortfolioProject..CovidVaccinations$ as vax
	ON d.location = vax.location
	and d.date = vax.date
Where d.continent is not null
Select *, (VaxxedToDate/population)*100 as PercentageVaxxed
From #PercentPopulationVaccinated


--Creating views
	
Create View InfectionRateByCountry as
Select Location, population, max(total_cases) as HighestInfectionCount, max((total_cases/population))*100 as InfectionRate
From PortfolioProject..CovidDeaths$
Where continent is not null and total_cases is not null
Group by location, population


Create View PercentPopulationVaccinated as
Select d.continent, d.location, d.date, d.population, vax.new_vaccinations,
SUM(vax.new_vaccinations) over (partition by d.location Order by d.location, d.date) as VaxxedToDate 
From PortfolioProject..CovidDeaths$ as d
JOIN PortfolioProject..CovidVaccinations$ as vax
	ON d.location = vax.location
	and d.date = vax.date
Where d.continent is not null
