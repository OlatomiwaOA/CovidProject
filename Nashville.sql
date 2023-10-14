--Cleaning data using SQL queries
-----------------------------------------------------------------------------------------------------
--Standardising date format

Alter table NashvilleHousingData$
Add SaleDateConverted Date;

Update NashvilleHousingData$
SET SaleDateConverted = CONVERT(Date, SaleDate)

Select SaleDateConverted
From PortfolioProject..NashvilleHousingData$

-----------------------------------------------------------------------------------------------------
--Getting year from date

Select
PARSENAME(Replace(SaleDateConverted, '-', '.'), 3)
From PortfolioProject..NashvilleHousingData$

Alter table NashvilleHousingData$
Add YearSold float;

Update NashvilleHousingData$
SET YearSold = PARSENAME(Replace(SaleDateConverted, '-', '.'), 3)

-----------------------------------------------------------------------------------------------------
--Corectly populating property address data

Select a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, ISNULL(a.PropertyAddress, b.PropertyAddress)
From PortfolioProject..NashvilleHousingData$ as a
Join PortfolioProject..NashvilleHousingData$ as b
	on a.ParcelID = b.ParcelID
	and a.[UniqueID ] <> b.[UniqueID ]
Where a.PropertyAddress is null

/*The query above will allow details to be duplicated across locations that are similar where data is missing in some of the entries.
what it is doing is essentially joining a table on itself*/

Update a
SET PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
From PortfolioProject..NashvilleHousingData$ as a
Join PortfolioProject..NashvilleHousingData$ as b
	on a.ParcelID = b.ParcelID
	and a.[UniqueID ] <> b.[UniqueID ]
Where a.PropertyAddress is null

-----------------------------------------------------------------------------------------------------
--Splitting address into separate columns. i.e. address, city, state
--Method 1: Uisng Substrings

Select
SUBSTRING(PropertyAddress, 1, charindex(',', PropertyAddress)) as Address
From PortfolioProject..NashvilleHousingData$

/*Running this gives an output with commas after the street name. To alter this, we add -1 in the query as below
So it takes all characters up to the first comma, then removes the comma.*/

Select
SUBSTRING(PropertyAddress, 1, charindex(',', PropertyAddress)-1) as StreetAddress,
SUBSTRING(PropertyAddress, charindex(',', PropertyAddress)+1, LEN(PropertyAddress)) as City
From PortfolioProject..NashvilleHousingData$

Alter table NashvilleHousingData$
Add StreetAddress nvarchar(250);

Update NashvilleHousingData$
SET StreetAddress = SUBSTRING(PropertyAddress, 1, charindex(',', PropertyAddress)-1)

Alter table NashvilleHousingData$
Add City nvarchar(250);

Update NashvilleHousingData$
SET City = SUBSTRING(PropertyAddress, charindex(',', PropertyAddress)+1, LEN(PropertyAddress))

--Method 2: Using PARSENAME

 Select
 Parsename(REPLACE(OwnerAddress, ',', '.'), 3),
 Parsename(REPLACE(OwnerAddress, ',', '.'), 2),
 Parsename(REPLACE(OwnerAddress, ',', '.'), 1)
 From PortfolioProject..NashvilleHousingData$

Alter table NashvilleHousingData$
Add OwnerStreetAddress nvarchar(250);

Update NashvilleHousingData$
SET OwnerStreetAddress = Parsename(REPLACE(OwnerAddress, ',', '.'), 3)

Alter table NashvilleHousingData$
Add OwnerCity nvarchar(250);

Update NashvilleHousingData$
SET OwnerCity = Parsename(REPLACE(OwnerAddress, ',', '.'), 2)

Alter table NashvilleHousingData$
Add OwnerState nvarchar(250);

Update NashvilleHousingData$
SET OwnerState = Parsename(REPLACE(OwnerAddress, ',', '.'), 1)

Select *
From PortfolioProject..NashvilleHousingData$

-----------------------------------------------------------------------------------------------------
--Changing Y and N to Yes and No in the 'SoldAsVacant' column

Select SoldAsVacant,
CASE 
	When SoldAsVacant = 'Y' THEN 'Yes'
	When SoldAsVacant = 'N' THEN 'NO'
	ELSE SoldAsVacant
	END
From PortfolioProject..NashvilleHousingData$

Update NashvilleHousingData$
SET SoldAsVacant = CASE
			When SoldAsVacant = 'Y' THEN 'Yes'
			When SoldAsVacant = 'N' THEN 'NO'
			ELSE SoldAsVacant
			END

Select Distinct(SoldAsVacant), COUNT(SoldAsVacant)
From PortfolioProject..NashvilleHousingData$
Group by SoldAsVacant
Order by 2

-----------------------------------------------------------------------------------------------------
--Removing duplicates

WITH RowCTE AS (
Select *,
	ROW_NUMBER() Over(
	Partition by ParcelID,
			     PropertyAddress,
				 SalePrice,
				 SaleDate,
				 LegalReference
				 Order by
					UniqueID
					) ROW_NUM

From PortfolioProject..NashvilleHousingData$
)
DELETE
From RowCTE
Where ROW_NUM > 1

-----------------------------------------------------------------------------------------------------
--Delete unused columns (try not to delete anything from your raw data. Delete from views)

Alter table PortfolioProject..NashvilleHousingData$
Drop Column OwnerAddress, TaxDistrict, PropertyAddress, SaleDate

Select *
From PortfolioProject..NashvilleHousingData$

-----------------------------------------------------------------------------------------------------
--Creating Views

Create View PropertyAge as
Select [UniqueID ], ParcelID, OwnerName, YearBuilt, YearSold, (YearSold - YearBuilt) as PropertyAge
From PortfolioProject..NashvilleHousingData$

