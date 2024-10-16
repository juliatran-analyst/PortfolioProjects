/*

COVID-19 Pandemic SQL Data Exploration
Skills used: Joins, CTE's, Temp Tables, Window Functions, Aggregate Functions, Creating Views, Converting Data Types

*/

SELECT *
FROM COVIDProject..CovidDeaths
WHERE continent is not null
ORDER BY 3, 4

--Select data we are going to be using

SELECT location, date, total_cases, new_cases, total_deaths, population
FROM COVIDProject..CovidDeaths
WHERE continent is not null
ORDER BY 1, 2 --Orders data by columns 1, 2 (country and date)


--Looking at total cases vs. total deaths
--Shows likelihood of dying if you contract COVID in your country (for me USA)

SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases) * 100 AS DeathPercentage
FROM COVIDProject..CovidDeaths
WHERE location like '%states%'
and continent is not null
ORDER BY 1, 2

--Looking at total cases vs. population
--Shows what percentage of population contracted COVID by country

SELECT location, date, total_cases, population, (total_cases/population)*100 AS PercentPopulationInfected
FROM COVIDProject..CovidDeaths
--WHERE location like '%states%'
ORDER BY 1, 2

--Rank countries with Highest Infection Rate compared to Population 

SELECT location, population, MAX(total_cases) AS HighestInfectionCount, MAX((total_cases/population))*100 AS PercentPopulationInfected
FROM COVIDProject..CovidDeaths
--WHERE location like '%states%'
GROUP BY location, population
ORDER BY PercentPopulationInfected DESC

--Countries with the Highest Death Count per Population

SELECT location, MAX(CAST(total_deaths as int)) AS TotalDeathCount
FROM COVIDProject..CovidDeaths
WHERE continent is not null --Where it is null, location is continent instead of country
GROUP BY location
ORDER BY TotalDeathCount DESC


--LET'S BREAK THINGS DOWN BY CONTINENT

--Showing continents with highest death count per population

SELECT continent, MAX(CAST(total_deaths as int)) AS TotalDeathCount
FROM COVIDProject..CovidDeaths
WHERE continent is not null
GROUP BY continent
ORDER BY TotalDeathCount DESC


--GLOBAL NUMBERS

--Total cases, total deaths, and death percentage across the world
SELECT sum(new_cases) as total_cases, sum(cast(new_deaths as int)) as total_deaths,
	(sum(cast(new_deaths as int))/sum(new_cases)) * 100 AS DeathPercentage
FROM COVIDProject..CovidDeaths
Where continent is not null
ORDER BY 1, 2

--Death percentage across the world by day
SELECT date, sum(new_cases) as total_cases, sum(cast(new_deaths as int)) as total_deaths,
	(sum(cast(new_deaths as int))/sum(new_cases)) * 100 AS DeathPercentage
FROM COVIDProject..CovidDeaths
Where continent is not null
Group By date
ORDER BY 1, 2

--Looking at rolling people vaccinated for each country in the world

Select dea.continent, dea.location, dea.date, dea.population,
	sum(cast(vac.new_vaccinations as int)) Over (Partition by dea.location Order by dea.location,
	dea.date) as RollingPeopleVaccinated
From COVIDProject..CovidDeaths dea
Join COVIDProject..CovidVaccinations vac
	On dea.location = vac.location and dea.date = vac.date
Where dea.continent is not null
Order by 2, 3

--Now must use CTE to get the vaccination rate of each country
--Cannot do (RollingPeopleVaccinated/population) * 100 because it's a column you create
--Gets vaccination percentage per country via rolling people vaccinated per population

With PopulationvsVaccinations
as
(
Select
	dea.continent,
	dea.location,
	dea.date,
	dea.population,
	vac.new_vaccinations,
	--Calculate rolling sum of vaccinations
	sum(cast(vac.new_vaccinations as int))
		Over (Partition by dea.location Order by dea.date) as RollingPeopleVaccinated
From COVIDProject..CovidDeaths dea
Join COVIDProject..CovidVaccinations vac
	On dea.location = vac.location and dea.date = vac.date
Where dea.continent is not null
)
--Calculate max rolling total per country
Select
	location,
	max(RollingPeopleVaccinated) as MaxRollingPeopleVaccinated,
	max(RollingPeopleVaccinated) / max(population) * 100 as VaccinationPercentage
From PopulationvsVaccinations
Group by location

--temp table
DROP TABLE if exists #PercentPopulationVaccinated
CREATE TABLE #PercentPopulationVaccinated
(
continent nvarchar(255),
location nvarchar(255),
date datetime,
population numeric,
new_vaccinations numeric,
RollingPeopleVaccinated numeric
)

INSERT INTO #PercentPopulationVaccinated
SELECT
	dea.continent,
	dea.location,
	dea.date,
	dea.population,
	vac.new_vaccinations,
	SUM(cast(vac.new_vaccinations as int))
		OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
FROM COVIDProject..CovidDeaths dea
JOIN COVIDProject..CovidVaccinations vac
	ON dea.location = vac.location
		AND dea.date = vac.date

SELECT *, (RollingPeopleVaccinated/population) * 100
FROM #PercentPopulationVaccinated

--Create view to store data for later visualizations
CREATE VIEW PercentPopulationVaccinated as
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
	sum(cast(vac.new_vaccinations as int)) over (partition by dea.location order by dea.location, dea.date)
	as RollingPeopleVaccinated
FROM COVIDProject..CovidDeaths dea
JOIN COVIDProject..CovidVaccinations vac
	ON dea.location = vac.location
	and dea.date = vac.date
WHERE dea.continent is not null

SELECT *
FROM PercentPopulationVaccinated