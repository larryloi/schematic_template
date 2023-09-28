PRINT N'Creating [Tzdb].[IntervalTable]...';


GO
CREATE TYPE [Tzdb].[IntervalTable] AS TABLE (
    [UtcStart]      DATETIME2 (0) NOT NULL,
    [UtcEnd]        DATETIME2 (0) NOT NULL,
    [LocalStart]    DATETIME2 (0) NOT NULL,
    [LocalEnd]      DATETIME2 (0) NOT NULL,
    [OffsetMinutes] SMALLINT      NOT NULL,
    [Abbreviation]  VARCHAR (10)  NOT NULL);


GO
PRINT N'Creating [Tzdb].[Intervals]...';


GO
CREATE TABLE [Tzdb].[Intervals] (
    [Id]            INT           IDENTITY (1, 1) NOT NULL,
    [ZoneId]        INT           NOT NULL,
    [UtcStart]      DATETIME2 (0) NOT NULL,
    [UtcEnd]        DATETIME2 (0) NOT NULL,
    [LocalStart]    DATETIME2 (0) NOT NULL,
    [LocalEnd]      DATETIME2 (0) NOT NULL,
    [OffsetMinutes] SMALLINT      NOT NULL,
    [Abbreviation]  VARCHAR (10)  NOT NULL,
    PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
PRINT N'Creating [Tzdb].[Intervals].[IX_Intervals_Utc]...';


GO
CREATE NONCLUSTERED INDEX [IX_Intervals_Utc]
    ON [Tzdb].[Intervals]([ZoneId] ASC, [UtcStart] ASC, [UtcEnd] ASC)
    INCLUDE([OffsetMinutes], [Abbreviation]);


GO
PRINT N'Creating [Tzdb].[Intervals].[IX_Intervals_Local]...';


GO
CREATE NONCLUSTERED INDEX [IX_Intervals_Local]
    ON [Tzdb].[Intervals]([ZoneId] ASC, [LocalStart] ASC, [LocalEnd] ASC, [UtcStart] ASC)
    INCLUDE([OffsetMinutes], [Abbreviation]);


GO
PRINT N'Creating [Tzdb].[Zones]...';


GO
CREATE TABLE [Tzdb].[Zones] (
    [Id]   INT          IDENTITY (1, 1) NOT NULL,
    [Name] VARCHAR (50) NOT NULL,
    PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
PRINT N'Creating [Tzdb].[Zones].[IX_Zones_Name]...';


GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_Zones_Name]
    ON [Tzdb].[Zones]([Name] ASC);


GO
PRINT N'Creating [Tzdb].[Links]...';


GO
CREATE TABLE [Tzdb].[Links] (
    [LinkZoneId]      INT NOT NULL,
    [CanonicalZoneId] INT NOT NULL,
    PRIMARY KEY CLUSTERED ([LinkZoneId] ASC)
);


GO
PRINT N'Creating [Tzdb].[VersionInfo]...';


GO
CREATE TABLE [Tzdb].[VersionInfo] (
    [Version] CHAR (5)           NOT NULL,
    [Loaded]  DATETIMEOFFSET (0) NOT NULL,
    PRIMARY KEY CLUSTERED ([Version] ASC)
);


GO
PRINT N'Creating [Tzdb].[FK_Intervals_Zones]...';


GO
ALTER TABLE [Tzdb].[Intervals]
    ADD CONSTRAINT [FK_Intervals_Zones] FOREIGN KEY ([ZoneId]) REFERENCES [Tzdb].[Zones] ([Id]);


GO
PRINT N'Creating [Tzdb].[FK_Links_Zones_1]...';


GO
ALTER TABLE [Tzdb].[Links]
    ADD CONSTRAINT [FK_Links_Zones_1] FOREIGN KEY ([LinkZoneId]) REFERENCES [Tzdb].[Zones] ([Id]);


GO
PRINT N'Creating [Tzdb].[FK_Links_Zones_2]...';


GO
ALTER TABLE [Tzdb].[Links]
    ADD CONSTRAINT [FK_Links_Zones_2] FOREIGN KEY ([CanonicalZoneId]) REFERENCES [Tzdb].[Zones] ([Id]);


GO
PRINT N'Creating [Tzdb].[GetZoneId]...';


GO
CREATE FUNCTION [Tzdb].[GetZoneId]
(
    @tz varchar(50)
)
RETURNS int
AS
BEGIN
    DECLARE @ZoneId int

    SELECT TOP 1 @ZoneId = l.[CanonicalZoneId]
    FROM [Tzdb].[Zones] z
    JOIN [Tzdb].[Links] l on z.[Id] = l.[LinkZoneId]
    WHERE z.[Name] = @tz

    IF @ZoneId IS NULL
    SELECT TOP 1 @ZoneId = [Id]
    FROM [Tzdb].[Zones]
    WHERE [Name] = @tz

    RETURN @ZoneId
END
GO
PRINT N'Creating [Tzdb].[GetZoneAbbreviation]...';


GO
CREATE FUNCTION [Tzdb].[GetZoneAbbreviation]
(
    @dto datetimeoffset,
    @tz varchar(50)
)
RETURNS varchar(10)
AS
BEGIN
    DECLARE @utc datetime2
    SET @utc = CONVERT(datetime2, SWITCHOFFSET(@dto, 0))

    DECLARE @ZoneId int
    SET @ZoneId = [Tzdb].GetZoneId(@tz)

    DECLARE @Abbreviation varchar(10)
    SELECT TOP 1 @Abbreviation = [Abbreviation]
    FROM [Tzdb].[Intervals]
    WHERE [ZoneId] = @ZoneId
      AND [UtcStart] <= @utc AND [UtcEnd] > @utc

    RETURN @Abbreviation
END
GO
PRINT N'Creating [Tzdb].[LocalToUtc]...';


GO
CREATE FUNCTION [Tzdb].[LocalToUtc]
(
    @local datetime2,
    @tz varchar(50),
    @SkipOnSpringForwardGap bit = 1, -- if the local time is in a gap, 1 skips forward and 0 will return null
    @FirstOnFallBackOverlap bit = 1  -- if the local time is ambiguous, 1 uses the first (daylight) instance and 0 will use the second (standard) instance
)
RETURNS datetimeoffset
AS
BEGIN
    DECLARE @OffsetMinutes int

    DECLARE @ZoneId int
    SET @ZoneId = [Tzdb].GetZoneId(@tz)

    IF @FirstOnFallBackOverlap = 1
        SELECT TOP 1 @OffsetMinutes = [OffsetMinutes]
        FROM [Tzdb].[Intervals]
        WHERE [ZoneId] = @ZoneId
          AND [LocalStart] <= @local AND [LocalEnd] > @local
        ORDER BY [UtcStart]
    ELSE
        SELECT TOP 1 @OffsetMinutes = [OffsetMinutes]
        FROM [Tzdb].[Intervals]
        WHERE [ZoneId] = @ZoneId
          AND [LocalStart] <= @local AND [LocalEnd] > @local
        ORDER BY [UtcStart] DESC

    IF @OffsetMinutes IS NULL
    BEGIN
        IF @SkipOnSpringForwardGap = 0 RETURN NULL

        SET @local = DATEADD(MINUTE, CASE @tz WHEN 'Australia/Lord_Howe' THEN 30 ELSE 60 END, @local)
        SELECT TOP 1 @OffsetMinutes = [OffsetMinutes]
        FROM [Tzdb].[Intervals]
        WHERE [ZoneId] = @ZoneId
          AND [LocalStart] <= @local AND [LocalEnd] > @local
    END

    RETURN TODATETIMEOFFSET(DATEADD(MINUTE, -@OffsetMinutes, @local), 0)
END
GO
PRINT N'Creating [Tzdb].[UtcToLocal]...';


GO
CREATE FUNCTION [Tzdb].[UtcToLocal]
(
    @utc datetime2,
    @tz varchar(50)
)
RETURNS datetimeoffset
AS
BEGIN
    DECLARE @OffsetMinutes int

    DECLARE @ZoneId int
    SET @ZoneId = [Tzdb].GetZoneId(@tz)

    SELECT TOP 1 @OffsetMinutes = [OffsetMinutes]
    FROM [Tzdb].[Intervals]
    WHERE [ZoneId] = @ZoneId
      AND [UtcStart] <= @utc AND [UtcEnd] > @utc

    RETURN TODATETIMEOFFSET(DATEADD(MINUTE, @OffsetMinutes, @utc), @OffsetMinutes)
END
GO
PRINT N'Creating [Tzdb].[ConvertZone]...';


GO
CREATE FUNCTION [Tzdb].[ConvertZone]
(
    @dt datetime2,
    @source_tz varchar(50),
    @dest_tz varchar(50),
    @SkipOnSpringForwardGap bit = 1,
    @FirstOnFallBackOverlap bit = 1
)
RETURNS datetimeoffset
AS
BEGIN
    DECLARE @utc datetimeoffset
    SET @utc = [Tzdb].[LocalToUtc](@dt, @source_tz, @SkipOnSpringForwardGap, @FirstOnFallBackOverlap)
    RETURN [Tzdb].[UtcToLocal](@utc, @dest_tz)
END
GO
PRINT N'Creating [Tzdb].[SwitchZone]...';


GO
CREATE FUNCTION [Tzdb].[SwitchZone]
(
    @dto datetimeoffset,
    @tz varchar(50)
)
RETURNS datetimeoffset
AS
BEGIN
    DECLARE @utc datetime2
    SET @utc = CONVERT(datetime2, SWITCHOFFSET(@dto, 0))
    RETURN [Tzdb].[UtcToLocal](@utc, @tz)
END
GO
PRINT N'Creating [Tzdb].[SetIntervals]...';


GO
CREATE PROCEDURE [Tzdb].[SetIntervals]
	@ZoneId int,
	@Intervals [Tzdb].[IntervalTable] READONLY
AS
DELETE FROM [Tzdb].[Intervals] WHERE [ZoneId] = @ZoneId
INSERT INTO [Tzdb].[Intervals] ([ZoneId], [UtcStart], [UtcEnd], [LocalStart], [LocalEnd], [OffsetMinutes], [Abbreviation])
SELECT @ZoneId as [ZoneId], [UtcStart], [UtcEnd], [LocalStart], [LocalEnd], [OffsetMinutes], [Abbreviation]
FROM @Intervals
GO
PRINT N'Creating [Tzdb].[SetVersion]...';


GO
CREATE PROCEDURE [Tzdb].[SetVersion]
	@Version char(5)
AS
DELETE FROM [Tzdb].[VersionInfo]
INSERT INTO [Tzdb].[VersionInfo] ([Version],[Loaded]) VALUES (@Version, GETUTCDATE())
GO
PRINT N'Creating [Tzdb].[AddLink]...';


GO
CREATE PROCEDURE [Tzdb].[AddLink]
	@LinkZoneId int,
	@CanonicalZoneId int
AS
DECLARE @cid int
SELECT @cid = @CanonicalZoneId FROM [Tzdb].[Links] WHERE [LinkZoneId] = @LinkZoneId
IF @cid is null
	INSERT INTO [Tzdb].[Links] ([LinkZoneId], [CanonicalZoneId]) VALUES (@LinkZoneId, @CanonicalZoneId)
ELSE IF @cid <> @CanonicalZoneId
	UPDATE [Tzdb].[Links] SET [CanonicalZoneId] = @CanonicalZoneId WHERE [LinkZoneId] = @LinkZoneId
GO
PRINT N'Creating [Tzdb].[AddZone]...';


GO
CREATE PROCEDURE [Tzdb].[AddZone]
    @Name varchar(50)
AS
DECLARE @id int
SELECT @id = [Id] FROM [Tzdb].[Zones] WHERE [Name] = @Name
IF @id is null
BEGIN
    INSERT INTO [Tzdb].[Zones] ([Name]) VALUES (@Name)
    SET @id = SCOPE_IDENTITY()
END
SELECT @id as [Id]
GO
PRINT N'Update complete.';


GO
