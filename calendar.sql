SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET ANSI_PADDING ON
GO

IF EXISTS(SELECT 1 FROM sys.objects WHERE [name] = 'Calendar' AND [schema_id] = 1)
    BEGIN
        DROP TABLE dbo.Calendar;
    END

CREATE TABLE [dbo].[Calendar]
(
    [CalendarDate] [date] NOT NULL,
    [IsWeekend] [bit] NOT NULL CONSTRAINT df_dbo_Calendar_IsWeekend DEFAULT (0),
    [IsHoliday] [bit] NOT NULL CONSTRAINT df_dbo_Calendar_IsHoliday DEFAULT (0),
    [IsLeapYear] bit NOT NULL,
    [Y] [smallint] NOT NULL,
    [Q] [smallint] NOT NULL,
    [M] [smallint] NOT NULL,
    [W] [smallint] NOT NULL,
    [D] [smallint] NOT NULL,
    [DW] [smallint] NOT NULL,
    [BD] [smallint] NULL,
    [BDM] [smallint] NULL,
    [YYYYMM] [int] NOT NULL,
    [YYYYMMDD] int NOT NULL CONSTRAINT uq_dbo_Calendar_YYYYMMDD UNIQUE,
    [MonthName] [varchar](15) NOT NULL,
    [DayName] [varchar](15) NOT NULL,
    [FirstDayOfMonth] [date] NOT NULL,
    [LastDayOfMonth] [date] NOT NULL,
    [FirstBusinessDayOfMonth] date NULL,
    [LastBusinessDayOfMonth] date NULL,
    [FirstDayOfQuarter] [date] NOT NULL,
    [LastDayOfQuarter] [date] NOT NULL,
    [FirstBusinessDayOfQuarter] [date] NULL,
    [LastBusinessDayOfQuarter] [date] NULL,
    [FirstDayOfYear] [date] NOT NULL,
    [LastDayOfYear] [date] NOT NULL,
    [FirstBusinessDayOfYear] [date] NULL,
    [LastBusinessDayOfYear] [date] NULL,
    [HolidayName] varchar(100) NULL
    CONSTRAINT [PK_CALENDAR] PRIMARY KEY CLUSTERED 
    (
	    [CalendarDate] ASC
    )WITH (DATA_COMPRESSION = PAGE)
);
GO

INSERT INTO Calendar
(
    CalendarDate,
    IsWeekend,
    IsHoliday,
    IsLeapYear,
    Y,
    Q,
    M,
    W,
    D,
    DW,
    YYYYMM,
    YYYYMMDD,
    [MonthName],
    [DayName],
    FirstDayOfMonth,
    LastDayOfMonth,
    FirstDayOfQuarter,
    LastDayOfQuarter,
    FirstDayOfYear,
    LastDayOfYear,
    HolidayName
)
SELECT
    CalendarDate = DatetimeVal,
    IsWeekend = IIF(SQL#.Date_Extract('ISODOW',DatetimeVal) > 5,1,0),
    IsHoliday = IIF(SQL#.Date_IsBusinessDay(DatetimeVal,260108156) = 0,1,0),
    IsLeapYear = SQL#.Date_IsLeapYear(YEAR(DatetimeVal)),
    Y = YEAR(DatetimeVal),
    Q = SQL#.Date_Extract('Quarter',DatetimeVal),
    M = SQL#.Date_Extract('Month',DatetimeVal),
    W = SQL#.Date_Extract('Week',DatetimeVal),
    D = SQL#.Date_Extract('Day',DatetimeVal),
    DW = SQL#.Date_Extract('Weekday',DatetimeVal),
    YYYYMM = CAST(LEFT(CAST(SQL#.Date_GetIntDate(DatetimeVal) AS char(8)),6) AS int),
    YYYYMMDD = SQL#.Date_GetIntDate(DatetimeVal),
    [MonthName] = DATENAME(month,DatetimeVal),
    [DayName] = DATENAME(weekday,DatetimeVal),
    FirstDayOfMonth = CAST(SQL#.Date_FirstDayOfMonth(DatetimeVal,0,0,0,0) AS date),
    LastDayOfMonth = CAST(SQL#.Date_LastDayOfMonth(DatetimeVal,0,0,0,0) AS date),
    FirstDayOfQuarter = CAST(DATEADD(qq,DATEDIFF(qq,0,DatetimeVal),0) AS date),
    LastDayOfQuarter = CAST(DATEADD(qq,DATEDIFF(qq,-1,DatetimeVal),-1) AS date),
    FirstDayOfYear = CAST(SQL#.Date_NewDateTime(YEAR(DatetimeVal),1,1,0,0,0,0) AS date),
    LastDayOfYear = CAST(SQL#.Date_NewDateTime(YEAR(DatetimeVal),12,31,0,0,0,0) AS date),
    HolidayName = CASE
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,4) = 0 THEN 'New Year''s Day'
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,8) = 0 THEN 'New Year''s Day'
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,16) = 0 THEN 'New Year''s Day'
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,32) = 0 THEN 'Martin Luther King Jr. Day'
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,64) = 0 THEN 'Memorial Day'
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,256) = 0 THEN 'Independence Day'
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,512) = 0 THEN 'Independence Day'
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,1024) = 0 THEN 'Labor Day'
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,2048) = 0 THEN 'Thanksgiving Day'
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,8192) = 0 THEN 'Christmas'
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,16384) = 0 THEN 'Christmas'
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,32768) = 0 THEN 'Christmas'
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,33554432) = 0 THEN 'Veterans Day'
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,67108864) = 0 THEN 'Veterans Day'
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,134217728) = 0 THEN 'Veterans Day'
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,8388608) = 0 THEN 'Presidents Day'
        WHEN SQL#.Date_IsBusinessDay(DatetimeVal,16777216) = 0 THEN 'Columbus Day'
        ELSE NULL
    END
FROM SQL#.Util_GenerateDateTimeRange('1/1/1900','12/31/2099',1,'day');
GO

/* update business day counter */
UPDATE c
SET BD = bd.BusinessDayNum
FROM Calendar c
    INNER JOIN  (
                SELECT 
                    DatetimeVal CalendarDate,
                     ROW_NUMBER() OVER(PARTITION BY CAST(LEFT(CAST(SQL#.Date_GetIntDate(DatetimeVal) AS char(8)),6) AS int) ORDER BY DatetimeVal) BusinessDayNum
                FROM SQL#.Util_GenerateDateTimeRange('1/1/1900','12/31/2099',1,'day')
                WHERE SQL#.Date_IsBusinessDay(DatetimeVal,260108159) = 1  -- include Sat & Sun
                ) bd
        ON c.CalendarDate = bd.CalendarDate;
GO

/* update monthly business days */
UPDATE c
SET FirstBusinessDayOfMonth = bd.FirstBusinessDayOfMonth,
    LastBusinessDayOfMonth = bd.LastBusinessDayOfMonth
FROM Calendar c
    INNER JOIN  (
                SELECT 
                    YYYYMM,
                    MIN(CalendarDate) FirstBusinessDayOfMonth,
                    MAX(CalendarDate) LastBusinessDayOfMonth
                FROM Calendar
                WHERE BD IS NOT NULL
                GROUP BY YYYYMM
                ) bd
        ON c.YYYYMM = bd.YYYYMM
GO

/* update quarterly business days */
UPDATE c
SET FirstBusinessDayOfQuarter = bd.FirstBusinessDayOfQuarter,
    LastBusinessDayOfQuarter = bd.LastBusinessDayOfQuarter
FROM Calendar c
    INNER JOIN  (
                SELECT 
                    Y,
                    Q,
                    MIN(CalendarDate) FirstBusinessDayOfQuarter,
                    MAX(CalendarDate) LastBusinessDayOfQuarter
                FROM Calendar
                WHERE BD IS NOT NULL
                GROUP BY Y,Q
                ) bd
        ON c.Y = bd.Y
        AND c.Q = bd.Q
GO

/* update yearly business days*/
UPDATE c
SET FirstBusinessDayOfYear = bd.FirstBusinessDayOfYear,
    LastBusinessDayOfYear = bd.LastBusinessDayOfYear
FROM Calendar c
    INNER JOIN  (
                SELECT 
                    Y,
                    MIN(CalendarDate) FirstBusinessDayOfYear,
                    MAX(CalendarDate) LastBusinessDayOfYear
                FROM Calendar
                WHERE BD IS NOT NULL
                GROUP BY Y
                ) bd
        ON c.Y = bd.Y
GO

UPDATE Calendar
SET BDM = SQL#.Date_BusinessDays(FirstDayOfMonth,LastDayOfMonth,260108159) -- include sat & sun
GO

/* make columns not null */
ALTER TABLE Calendar ALTER COLUMN FirstBusinessDayOfMonth date NOT NULL;
ALTER TABLE Calendar ALTER COLUMN LastBusinessDayOfMonth date NOT NULL;
ALTER TABLE Calendar ALTER COLUMN FirstBusinessDayOfQuarter date NOT NULL;
ALTER TABLE Calendar ALTER COLUMN LastBusinessDayOfQuarter date NOT NULL;
ALTER TABLE Calendar ALTER COLUMN FirstBusinessDayOfYear date NOT NULL;
ALTER TABLE Calendar ALTER COLUMN LastBusinessDayOfYear date NOT NULL;
ALTER TABLE Calendar ALTER COLUMN BDM smallint NOT NULL;
GO

/* Add metadata */
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Utility calendar table with dates from 1/1/1900 to 12/31/2999.  The table and columns are pretty self explanatory, except for the logic for the holidays.  The table identifies these holidays: New Years Day, Martin Luther King Jr Day, Memorial Day, Independence Day, Labor Day, Veterans Day, Thanksgiving, Christmas.', @level0type = N'SCHEMA', @level0name = 'dbo', @level1type = N'TABLE',  @level1name = 'Calendar';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Calendar Date (without time) - Primary Key',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'CalendarDate';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Is Calendar Date a weekend (Saturday - Sunday) - 0: No, 1: Yes',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'IsWeekend';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Is Calendar Date a holiday (based on US Bank Holiday schedule) - 0: No, 1: Yes',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'IsHoliday';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Is the year of Calendar Date a Leap Year - 0: No, 1: Yes',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'IsLeapYear';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Year number of Calendar Date',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'Y';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Quarter number of Calendar Date (1-4)',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'Q';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Month number of Calendar Date (1-12)',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'M';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Week number of Calendar Date (1-53)',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'W';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Day number of month (1-31)',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'D';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Day of week number within week (1-7)',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'DW';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Business day number within month (1-31)',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'BD';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Number of business days in month (1-31)',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'BDM';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Calendar Date in numeric YYYYMM format',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'YYYYMM';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Calendar Date in numeric YYYYMMDD format',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'YYYYMMDD';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Name of month in English',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'MonthName';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Name of day in English',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'DayName';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Date of the first day of the month',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'FirstDayOfMonth';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Date of the last day of the month',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'LastDayOfMonth';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Date of the first business day of the month',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'FirstBusinessDayOfMonth';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Date of the last business day of the month',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'LastBusinessDayOfMonth';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Date of the first day of the quarter',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'FirstDayOfQuarter';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Date of the last day of the quarter',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'LastDayOfQuarter';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Date of the first business day of the quarter',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'FirstBusinessDayOfQuarter';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Date of the last business day of the quarter',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'LastBusinessDayOfQuarter';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Date of the first day of the year',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'FirstDayOfYear';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Date of the last day of the year',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'LastDayOfYear';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Date of the first business day of the year',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'FirstBusinessDayOfYear';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Date of the last business day of the year',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'LastBusinessDayOfYear';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = 'Name of the holiday if Calendar Date is a holiday',@level0type = N'Schema', @level0name = 'dbo',@level1type = N'Table',  @level1name = 'Calendar',@level2type = N'Column', @level2name = 'HolidayName';

GO