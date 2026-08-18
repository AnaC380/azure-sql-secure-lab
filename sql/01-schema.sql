SET NOCOUNT ON;
SET XACT_ABORT ON;

PRINT 'Validating DIO Azure SQL Secure Lab schema...';

IF OBJECT_ID(N'dbo.CloudAsset', N'U') IS NULL
BEGIN

    CREATE TABLE dbo.CloudAsset
    (
        AssetId INT IDENTITY(1,1) NOT NULL,
        AssetName NVARCHAR(100) NOT NULL,
        AssetType NVARCHAR(50) NOT NULL,
        Environment NVARCHAR(20) NOT NULL,
        Region NVARCHAR(50) NOT NULL,

        IsActive BIT NOT NULL
            CONSTRAINT DF_CloudAsset_IsActive
            DEFAULT (1),

        CreatedAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_CloudAsset_CreatedAtUtc
            DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_CloudAsset
            PRIMARY KEY (AssetId),

        CONSTRAINT CK_CloudAsset_Environment
            CHECK (
                Environment IN (
                    N'Lab',
                    N'Development',
                    N'Test'
                )
            )
    );

    PRINT 'Created dbo.CloudAsset.';
END;
ELSE
BEGIN
    PRINT 'dbo.CloudAsset already exists. No destructive action performed.';
END;

IF OBJECT_ID(N'dbo.SecurityEvent', N'U') IS NULL
BEGIN

    CREATE TABLE dbo.SecurityEvent
    (
        SecurityEventId BIGINT IDENTITY(1,1) NOT NULL,
        AssetId INT NOT NULL,
        EventType NVARCHAR(50) NOT NULL,
        Severity VARCHAR(10) NOT NULL,
        Description NVARCHAR(400) NOT NULL,

        OccurredAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_SecurityEvent_OccurredAtUtc
            DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_SecurityEvent
            PRIMARY KEY (SecurityEventId),

        CONSTRAINT FK_SecurityEvent_CloudAsset
            FOREIGN KEY (AssetId)
            REFERENCES dbo.CloudAsset (AssetId),

        CONSTRAINT CK_SecurityEvent_Severity
            CHECK (
                Severity IN (
                    'Low',
                    'Medium',
                    'High'
                )
            )
    );

    PRINT 'Created dbo.SecurityEvent.';
END;
ELSE
BEGIN
    PRINT 'dbo.SecurityEvent already exists. No destructive action performed.';
END;

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE
        name = N'IX_CloudAsset_Environment'
        AND object_id = OBJECT_ID(N'dbo.CloudAsset')
)
BEGIN

    CREATE INDEX IX_CloudAsset_Environment
        ON dbo.CloudAsset (Environment);

    PRINT 'Created IX_CloudAsset_Environment.';
END;

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE
        name = N'IX_SecurityEvent_AssetId'
        AND object_id = OBJECT_ID(N'dbo.SecurityEvent')
)
BEGIN

    CREATE INDEX IX_SecurityEvent_AssetId
        ON dbo.SecurityEvent (AssetId);

    PRINT 'Created IX_SecurityEvent_AssetId.';
END;

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE
        name = N'IX_SecurityEvent_Severity'
        AND object_id = OBJECT_ID(N'dbo.SecurityEvent')
)
BEGIN

    CREATE INDEX IX_SecurityEvent_Severity
        ON dbo.SecurityEvent (Severity);

    PRINT 'Created IX_SecurityEvent_Severity.';
END;

PRINT 'Schema validation completed successfully.';