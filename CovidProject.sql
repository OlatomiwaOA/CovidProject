

--Selecting the necessary data

Select Location, date, total_cases, new_cases, total_deaths, population
From PortfolioProject..CovidDeaths$
Order by 1,2

--Total cases vs Total deaths
--Shows likelihood of dying after contracting covid

Select Location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as MortalityRate
From PortfolioProject..CovidDeaths$
Where location like '%nigeria%'
Order by 1,2

--Total cases vs Population by country
--Shows the % of population infected

Select Location, date, population, total_cases, (total_cases/population)*100 as InfectionRate
From PortfolioProject..CovidDeaths$
Order by 1,2

--Investigating infection rates by country

Select Location, population, max(total_cases) as HighestInfectionCount, max((total_cases/population))*100 as InfectionRate
From PortfolioProject..CovidDeaths$
Where continent is not null and total_cases is not null
Group by location, population
Order by InfectionRate desc


--Showing Death Rate per population by country

Select Location, population, max(cast(total_deaths as int)) as DeathCount
From PortfolioProject..CovidDeaths$
Where continent is not null
Group by location, population
Order by DeathCount desc

--Showing the death count by continent

Select location, max(cast(total_deaths as int)) as DeathCount
From PortfolioProject..CovidDeaths$
Where continent is null and location not like '%income%'
Group by location
Order by DeathCount desc


--Showing number of daily new cases and deaths globally
--use nullif to avoid a zero division error

Select date, SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths, nullif(SUM(new_deaths),0)/nullif(sum(new_cases),0)*100 as DeathRate
From PortfolioProject..CovidDeaths$
Where continent is not null
Group by date
Order by 1,2

--Total number of new cases and new deaths across the entire period

Select SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths, nullif(SUM(new_deaths),0)/nullif(sum(new_cases),0)*100 as DeathRate
From PortfolioProject..CovidDeaths$
Where continent is not null
Order by 1,2

--Total New cases globally (per country) from 2020 - 2023 (per year)

--Method 1: using
--Select location, isnull(sum(new_cases),0) as TotalNewCases
--From PortfolioProject..CovidDeaths$
--Where date like '2020%' and continent is not null and location not like '%income'
--Where date like '2020%' and iso_code not like '%owid%'
--Group by location
--Order by location 

Select location, isnull(sum(new_cases),0) as TotalNewCases
From PortfolioProject..CovidDeaths$
Where date like '2020%' and continent is not null and location not like '%income'
Group by location
Order by TotalNewCases desc

Select location, isnull(sum(new_cases),0) as TotalNewCases
From PortfolioProject..CovidDeaths$
Where date like '2021%' and continent is not null and location not like '%income'
Group by location
Order by TotalNewCases desc

Select location, isnull(sum(new_cases),0) as TotalNewCases
From PortfolioProject..CovidDeaths$
Where date like '2022%' and continent is not null and location not like '%income'
Group by location
Order by TotalNewCases desc

Select location, isnull(sum(new_cases),0) as TotalNewCases
From PortfolioProject..CovidDeaths$
Where date like '2023%' and continent is not null and location not like '%income'
Group by location
Order by TotalNewCases desc

--Total New cases globally (per country) from 2020 - 2023 (per year)

--First ceate a new column as year and add to the table

Alter table PortfolioProject..CovidDeaths$
Add year nvarchar(150)

--Then we use parsename to split the date and extract the year and set it to the newly created year column

Update PortfolioProject..CovidDeaths$
Set year = parsename(replace(date,'-','.'),3)

--Query showing total cases per country per year

Select location, year, max(total_cases) as Total_Cases
From PortfolioProject..CovidDeaths$
Group by location, year
Order by location, YEAR

Select *
From PortfolioProject..CovidDeaths$
Group by year, location


Select location, sum(new_cases) over(partition by location, date Order by date) as TotalNewCases
From PortfolioProject..CovidDeaths$
Where continent is not null and location not like '%income'
Group by location
Order by TotalNewCases desc

--Total population vs Vaccinations

--alter table PortfolioProject..CovidDeaths$
--alter column location nvarchar(150)

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
