-----------------------------------------
--  MGMT 6570 Data Warehouse Project
--  Electric Vehicle Population Dataset
--  Rohan Thumma
--  May 5th, 2026
--  Research Question: What vehicle, location,
--  and utility characteristics are associated
--  with EV adoption and electric range?
-----------------------------------------

USE EVDW
GO

-----------------------------------------
--  COLLECT: Staging Table
--  Drop, Create, and Load EVStaging
--  No commas/quotes in any key column --
--  BULK INSERT works cleanly with this file
-----------------------------------------

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EVStaging]') AND type = N'U')
    DROP TABLE [dbo].[EVStaging]
GO

CREATE TABLE EVStaging (
    VIN                     VARCHAR(10),
    County                  VARCHAR(100),
    City                    VARCHAR(100),
    State                   VARCHAR(5),
    PostalCode              INT,
    ModelYear               INT,
    Make                    VARCHAR(100),
    Model                   VARCHAR(100),
    ElectricVehicleType     VARCHAR(100),
    CAFVEligibility         VARCHAR(100),
    ElectricRange           INT,
    BaseMSRP                INT,
    LegislativeDistrict     VARCHAR(10),
    DOLVehicleID            BIGINT,
    ElectricUtility         VARCHAR(300)
)

BULK INSERT EVStaging
FROM 'C:\Data\Final_Project_EV\EV_Data.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0a',
    FIRSTROW        = 2,
    TABLOCK
)

-- Quick checks
SELECT TOP 10 * FROM EVStaging;
SELECT COUNT(*) AS StagingRowCount FROM EVStaging;   -- expect 112,634

-----------------------------------------
--  COLLECT: Clean Table (EVClean)
--  Key decisions verified against actual data:
--    - 25 rows dropped for NULL make/model/county/city
--    - ModelYear filtered 2000-2023 (pre-2000 = 4 antique EVs)
--    - BaseMSRP = 0 kept (109,122 rows) -- data not collected
--    - ElectricRange = 0 kept (39,236 rows) -- PHEVs often report 0
--    - ElectricUtility simplified: take first value before | or ,
--    - LegislativeDistrict stored as VARCHAR to handle NULLs cleanly
-----------------------------------------

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EVClean]') AND type = N'U')
    DROP TABLE [dbo].[EVClean]
GO

CREATE TABLE EVClean (
    CleanID                 INT IDENTITY(1,1) PRIMARY KEY,
    VIN                     VARCHAR(10),
    County                  VARCHAR(100),
    City                    VARCHAR(100),
    State                   VARCHAR(5),
    PostalCode              INT,
    ModelYear               INT,
    ModelYearDateKey        INT,            -- YYYY0101 integer for dimDate
    Make                    VARCHAR(100),
    Model                   VARCHAR(100),
    ElectricVehicleType     VARCHAR(100),
    CAFVEligibility         VARCHAR(100),
    ElectricRange           INT,
    BaseMSRP                INT,
    LegislativeDistrict     VARCHAR(10),
    DOLVehicleID            BIGINT,
    ElectricUtilityClean    VARCHAR(200)    -- first utility only, pipe/comma stripped
)

INSERT INTO EVClean (
    VIN, County, City, State, PostalCode,
    ModelYear, ModelYearDateKey,
    Make, Model,
    ElectricVehicleType, CAFVEligibility,
    ElectricRange, BaseMSRP,
    LegislativeDistrict, DOLVehicleID,
    ElectricUtilityClean
)
SELECT
    VIN,
    LTRIM(RTRIM(County)),
    LTRIM(RTRIM(City)),
    LTRIM(RTRIM(State)),
    PostalCode,
    ModelYear,
    -- DateKey: ModelYear as Jan 1 of that year (YYYY*10000 + 0101)
    ModelYear * 10000 + 101                                         AS ModelYearDateKey,
    LTRIM(RTRIM(Make)),
    LTRIM(RTRIM(Model)),
    -- Shorten EV type to BEV or PHEV
    CASE
        WHEN ElectricVehicleType LIKE '%Battery%' THEN 'Battery Electric Vehicle (BEV)'
        WHEN ElectricVehicleType LIKE '%Plug-in%' THEN 'Plug-in Hybrid Electric Vehicle (PHEV)'
        ELSE ElectricVehicleType
    END,
    LTRIM(RTRIM(CAFVEligibility)),
    ElectricRange,
    BaseMSRP,
    LTRIM(RTRIM(LegislativeDistrict)),
    DOLVehicleID,
    -- ElectricUtility already cleaned in preprocessing - use as-is
    LTRIM(RTRIM(ISNULL(ElectricUtility, '')))                       AS ElectricUtilityClean
FROM EVStaging
WHERE
    ModelYear   BETWEEN 2000 AND 2023
    AND Make    IS NOT NULL AND Make    <> ''
    AND Model   IS NOT NULL AND Model   <> ''
    AND County  IS NOT NULL AND County  <> ''
    AND City    IS NOT NULL AND City    <> ''
    AND State   IS NOT NULL
    AND (
        ElectricVehicleType LIKE '%Battery%'
        OR ElectricVehicleType LIKE '%Plug-in%'
    )

-- Checks
SELECT COUNT(*) AS CleanRowCount 
FROM EVClean;  

SELECT TOP 10 * 
FROM EVClean;


-----------------------------------------
--  ORGANIZE: Drop existing DW tables
--  Drop order: fact first, then all dims
-----------------------------------------

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[factEVRegistration]') AND type = N'U')
    DROP TABLE factEVRegistration;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[dimDate]') AND type = N'U')
    DROP TABLE dimDate;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[dimCAFV]') AND type = N'U')
    DROP TABLE dimCAFV;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[dimEVType]') AND type = N'U')
    DROP TABLE dimEVType;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[dimUtility]') AND type = N'U')
    DROP TABLE dimUtility;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[dimLocation]') AND type = N'U')
    DROP TABLE dimLocation;
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[dimVehicle]') AND type = N'U')
    DROP TABLE dimVehicle;

-----------------------------------------
--  Dimension: dimVehicle
--  One row per unique Make + Model combination
-----------------------------------------

CREATE TABLE dimVehicle (
    VehicleKey      INT IDENTITY(1,1)
        CONSTRAINT PK_dimVehicle PRIMARY KEY CLUSTERED,
    Make            VARCHAR(100),
    Model           VARCHAR(100),
    VehicleLabel    VARCHAR(200)    -- Make + Model combined label
)

INSERT INTO dimVehicle (Make, Model, VehicleLabel)
SELECT DISTINCT
    Make,
    Model,
    Make + ' ' + Model
FROM EVClean;

SELECT TOP 10 * FROM dimVehicle;
SELECT COUNT(*) AS dimVehicleCount FROM dimVehicle;   

-----------------------------------------
--  Dimension: dimLocation
--  One row per unique City + County + State + PostalCode
-----------------------------------------

CREATE TABLE dimLocation (
    LocationKey     INT IDENTITY(1,1)
        CONSTRAINT PK_dimLocation PRIMARY KEY CLUSTERED,
    City            VARCHAR(100),
    County          VARCHAR(100),
    State           VARCHAR(5),
    PostalCode      INT,
    StateLabel      VARCHAR(50)  
)

INSERT INTO dimLocation (City, County, State, PostalCode, StateLabel)
SELECT DISTINCT
    City,
    County,
    State,
    PostalCode,
    CASE State
        WHEN 'WA' THEN 'Washington'
        WHEN 'CA' THEN 'California'
        WHEN 'OR' THEN 'Oregon'
        WHEN 'TX' THEN 'Texas'
        WHEN 'FL' THEN 'Florida'
        WHEN 'NY' THEN 'New York'
        WHEN 'AZ' THEN 'Arizona'
        WHEN 'NV' THEN 'Nevada'
        WHEN 'CO' THEN 'Colorado'
        WHEN 'VA' THEN 'Virginia'
        WHEN 'IL' THEN 'Illinois'
        WHEN 'MD' THEN 'Maryland'
        WHEN 'GA' THEN 'Georgia'
        WHEN 'NC' THEN 'North Carolina'
        WHEN 'PA' THEN 'Pennsylvania'
        WHEN 'OH' THEN 'Ohio'
        WHEN 'MN' THEN 'Minnesota'
        WHEN 'MA' THEN 'Massachusetts'
        WHEN 'NJ' THEN 'New Jersey'
        WHEN 'HI' THEN 'Hawaii'
        ELSE State
    END
FROM EVClean;

SELECT TOP 10 * 
FROM dimLocation;

SELECT COUNT(*) AS dimLocationCount 
FROM dimLocation;

-----------------------------------------
--  Dimension: dimEVType
--  Two EV types confirmed in this dataset
--  Manually seeded -- no IDENTITY, IDs explicit
-----------------------------------------

CREATE TABLE dimEVType (
    EVTypeKey       INT
        CONSTRAINT PK_dimEVType PRIMARY KEY CLUSTERED,
    EVTypeCode      VARCHAR(10),
    EVTypeFullName  VARCHAR(100),
    EVTypeCategory  VARCHAR(50)
)

INSERT INTO dimEVType (EVTypeKey, EVTypeCode, EVTypeFullName, EVTypeCategory)
VALUES
    (1, 'BEV',  'Battery Electric Vehicle (BEV)',              'Fully Electric'),
    (2, 'PHEV', 'Plug-in Hybrid Electric Vehicle (PHEV)',      'Hybrid Electric')

SELECT * 
FROM dimEVType; 

-----------------------------------------
--  Dimension: dimCAFV
--  Three CAFV eligibility statuses in this dataset
--  Manually seeded -- no IDENTITY, IDs explicit
-----------------------------------------

CREATE TABLE dimCAFV (
    CAFVKey             INT
        CONSTRAINT PK_dimCAFV PRIMARY KEY CLUSTERED,
    CAFVEligibility     VARCHAR(100),
    CAFVShortLabel      VARCHAR(50),
    IsEligible          VARCHAR(10)
)

INSERT INTO dimCAFV (CAFVKey, CAFVEligibility, CAFVShortLabel, IsEligible)
VALUES
    (1, 'Clean Alternative Fuel Vehicle Eligible',
        'Eligible',         'yes'),
    (2, 'Not eligible due to low battery range',
        'Not Eligible',     'no'),
    (3, 'Eligibility unknown as battery range has not been researched',
        'Unknown',          'unknown')

SELECT * 
FROM dimCAFV; 

-----------------------------------------
--  Dimension: dimUtility
--  One row per unique electric utility provider
--  Loaded via SELECT DISTINCT from EVClean
-----------------------------------------

CREATE TABLE dimUtility (
    UtilityKey      INT IDENTITY(1,1)
        CONSTRAINT PK_dimUtility PRIMARY KEY CLUSTERED,
    UtilityName     VARCHAR(200),
    UtilityLabel    VARCHAR(200)    -- cleaned display name
)

INSERT INTO dimUtility (UtilityName, UtilityLabel)
SELECT DISTINCT
    ISNULL(NULLIF(ElectricUtilityClean, ''), 'Unknown'),
    CASE
        WHEN ElectricUtilityClean IS NULL OR ElectricUtilityClean = ''
             THEN 'Unknown'
        ELSE ElectricUtilityClean
    END
FROM EVClean;

SELECT TOP 10 * FROM dimUtility;
SELECT COUNT(*) AS dimUtilityCount FROM dimUtility;

-----------------------------------------
--  Dimension: dimDate
--  One row per Model Year (2000-2023)
--  DateKey = ModelYear * 10000 + 101 (Jan 1 of that year)
-----------------------------------------

CREATE TABLE dimDate (
    DateKey         INT
        CONSTRAINT PK_dimDate PRIMARY KEY CLUSTERED,
    ModelYear       INT,
    Decade          VARCHAR(10),
    EVEra           VARCHAR(50)     -- readable era label
)

INSERT INTO dimDate (DateKey, ModelYear, Decade, EVEra)
SELECT DISTINCT
    ModelYearDateKey,
    ModelYear,
    CAST((ModelYear / 10) * 10 AS VARCHAR) + 's'   AS Decade,
    CASE
        WHEN ModelYear BETWEEN 2000 AND 2010 THEN 'Early Adoption (2000-2010)'
        WHEN ModelYear BETWEEN 2011 AND 2015 THEN 'Growth Phase (2011-2015)'
        WHEN ModelYear BETWEEN 2016 AND 2019 THEN 'Mainstream Entry (2016-2019)'
        WHEN ModelYear BETWEEN 2020 AND 2023 THEN 'Mass Market (2020-2023)'
    END                                             AS EVEra
FROM EVClean
WHERE ModelYearDateKey IS NOT NULL;

SELECT * FROM dimDate ORDER BY DateKey;   -- expect 24 rows (2000-2023)

-----------------------------------------
--  Fact Table: factEVRegistration
--  Grain: one row per registered vehicle (VIN)
--  Measures: ElectricRange, BaseMSRP
--  FK columns allow NULLs per pattern
-----------------------------------------

CREATE TABLE factEVRegistration (
    EVFactKey           INT IDENTITY(1,1)
        CONSTRAINT PK_factEVRegistration PRIMARY KEY CLUSTERED,
    VehicleKey          INT NULL,
    LocationKey         INT NULL,
    EVTypeKey           INT NULL,
    CAFVKey             INT NULL,
    UtilityKey          INT NULL,
    DateKey             INT NULL,
    ElectricRange       INT,
    BaseMSRP            INT,
    LegislativeDistrict VARCHAR(10),
    DOLVehicleID        BIGINT,
    CONSTRAINT FK_factEV_dimVehicle
        FOREIGN KEY (VehicleKey)  REFERENCES dimVehicle(VehicleKey),
    CONSTRAINT FK_factEV_dimLocation
        FOREIGN KEY (LocationKey) REFERENCES dimLocation(LocationKey),
    CONSTRAINT FK_factEV_dimEVType
        FOREIGN KEY (EVTypeKey)   REFERENCES dimEVType(EVTypeKey),
    CONSTRAINT FK_factEV_dimCAFV
        FOREIGN KEY (CAFVKey)     REFERENCES dimCAFV(CAFVKey),
    CONSTRAINT FK_factEV_dimUtility
        FOREIGN KEY (UtilityKey)  REFERENCES dimUtility(UtilityKey),
    CONSTRAINT FK_factEV_dimDate
        FOREIGN KEY (DateKey)     REFERENCES dimDate(DateKey)
)

-----------------------------------------
--  Load factEVRegistration from EVClean
--  EVTypeKey and CAFVKey resolved via CASE
--  All other dims resolved via INNER JOIN
-----------------------------------------

INSERT INTO factEVRegistration (
    VehicleKey, LocationKey, EVTypeKey, CAFVKey, UtilityKey, DateKey,
    ElectricRange, BaseMSRP, LegislativeDistrict, DOLVehicleID
)
SELECT
    V.VehicleKey,
    L.LocationKey,

    -- CASE resolves EVTypeKey from cleaned type string
    CASE EC.ElectricVehicleType
        WHEN 'Battery Electric Vehicle (BEV)'             THEN 1
        WHEN 'Plug-in Hybrid Electric Vehicle (PHEV)'     THEN 2
    END                     AS EVTypeKey,

    -- CASE resolves CAFVKey from eligibility string
    CASE EC.CAFVEligibility
        WHEN 'Clean Alternative Fuel Vehicle Eligible'                          THEN 1
        WHEN 'Not eligible due to low battery range'                            THEN 2
        WHEN 'Eligibility unknown as battery range has not been researched'     THEN 3
    END                     AS CAFVKey,

    U.UtilityKey,
    D.DateKey,
    EC.ElectricRange,
    EC.BaseMSRP,
    EC.LegislativeDistrict,
    EC.DOLVehicleID

FROM EVClean EC

    INNER JOIN dimVehicle V
        ON  V.Make  = EC.Make
        AND V.Model = EC.Model

    INNER JOIN dimLocation L
        ON  L.City       = EC.City
        AND L.County     = EC.County
        AND L.State      = EC.State
        AND L.PostalCode = EC.PostalCode

    INNER JOIN dimUtility U
        ON  U.UtilityName = ISNULL(NULLIF(EC.ElectricUtilityClean, ''), 'Unknown')

    INNER JOIN dimDate D
        ON  D.DateKey = EC.ModelYearDateKey;

-- Row count check
SELECT COUNT(*) AS FactRowCount FROM factEVRegistration;   -- expect ~112,609

-----------------------------------------
--  VERIFY: Full star join sample
-----------------------------------------

SELECT TOP 20
    F.EVFactKey,
    V.Make,
    V.Model,
    L.City,
    L.County,
    L.State,
    ET.EVTypeCode,
    ET.EVTypeCategory,
    C.CAFVShortLabel,
    C.IsEligible,
    U.UtilityLabel,
    D.ModelYear,
    D.EVEra,
    F.ElectricRange,
    F.BaseMSRP,
    F.LegislativeDistrict
FROM factEVRegistration F
    INNER JOIN dimVehicle  V  ON F.VehicleKey  = V.VehicleKey
    INNER JOIN dimLocation L  ON F.LocationKey = L.LocationKey
    INNER JOIN dimEVType   ET ON F.EVTypeKey   = ET.EVTypeKey
    INNER JOIN dimCAFV     C  ON F.CAFVKey     = C.CAFVKey
    INNER JOIN dimUtility  U  ON F.UtilityKey  = U.UtilityKey
    INNER JOIN dimDate     D  ON F.DateKey     = D.DateKey;

-----------------------------------------
--  ANALYSIS QUERIES
--  Exported each as a csv to create graphics in R
-----------------------------------------

-- 1. Registration count and avg electric range by Make
SELECT
    V.Make,
    COUNT(*)                    AS Registrations,
    AVG(F.ElectricRange)        AS AvgElectricRange,
    MAX(F.ElectricRange)        AS MaxElectricRange
FROM factEVRegistration F
    INNER JOIN dimVehicle V ON F.VehicleKey = V.VehicleKey
GROUP BY V.Make
ORDER BY Registrations DESC;

-- 2. BEV vs PHEV count by model year (adoption trend over time)
SELECT
    D.ModelYear,
    D.EVEra,
    ET.EVTypeCode,
    COUNT(*)                    AS Registrations,
    AVG(F.ElectricRange)        AS AvgElectricRange
FROM factEVRegistration F
    INNER JOIN dimDate   D  ON F.DateKey   = D.DateKey
    INNER JOIN dimEVType ET ON F.EVTypeKey = ET.EVTypeKey
GROUP BY D.ModelYear, D.EVEra, ET.EVTypeCode
ORDER BY D.ModelYear, ET.EVTypeCode;

-- 3. Top 15 counties by EV registration count
SELECT TOP 15
    L.County,
    L.State,
    COUNT(*)                    AS Registrations,
    AVG(F.ElectricRange)        AS AvgElectricRange,
    SUM(CASE WHEN F.EVTypeKey = 1 THEN 1 ELSE 0 END) AS BEVCount,
    SUM(CASE WHEN F.EVTypeKey = 2 THEN 1 ELSE 0 END) AS PHEVCount
FROM factEVRegistration F
    INNER JOIN dimLocation L ON F.LocationKey = L.LocationKey
GROUP BY L.County, L.State
ORDER BY Registrations DESC;

-- 4. CAFV eligibility breakdown by EV type
SELECT
    ET.EVTypeCode,
    C.CAFVShortLabel,
    C.IsEligible,
    COUNT(*)                    AS Registrations,
    AVG(F.ElectricRange)        AS AvgElectricRange
FROM factEVRegistration F
    INNER JOIN dimEVType ET ON F.EVTypeKey = ET.EVTypeKey
    INNER JOIN dimCAFV   C  ON F.CAFVKey   = C.CAFVKey
GROUP BY ET.EVTypeCode, C.CAFVShortLabel, C.IsEligible
ORDER BY ET.EVTypeCode, Registrations DESC;

-- 5. Top 10 electric utilities by registration count and avg range
SELECT TOP 10
    U.UtilityLabel,
    COUNT(*)                    AS Registrations,
    AVG(F.ElectricRange)        AS AvgElectricRange,
    SUM(CASE WHEN F.EVTypeKey = 1 THEN 1 ELSE 0 END) AS BEVCount,
    SUM(CASE WHEN F.EVTypeKey = 2 THEN 1 ELSE 0 END) AS PHEVCount
FROM factEVRegistration F
    INNER JOIN dimUtility U ON F.UtilityKey = U.UtilityKey
GROUP BY U.UtilityLabel
ORDER BY Registrations DESC;

-- 6. EV adoption by era -- growth across time periods
SELECT
    D.EVEra,
    D.Decade,
    COUNT(*)                    AS Registrations,
    AVG(F.ElectricRange)        AS AvgElectricRange,
    SUM(CASE WHEN F.EVTypeKey = 1 THEN 1 ELSE 0 END) AS BEVCount,
    SUM(CASE WHEN F.EVTypeKey = 2 THEN 1 ELSE 0 END) AS PHEVCount
FROM factEVRegistration F
    INNER JOIN dimDate D ON F.DateKey = D.DateKey
GROUP BY D.EVEra, D.Decade
ORDER BY MIN(D.ModelYear);