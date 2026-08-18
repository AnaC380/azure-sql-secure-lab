SET NOCOUNT ON;
SET XACT_ABORT ON;

PRINT 'Starting DIO Azure SQL Secure Lab seed validation...';

IF OBJECT_ID(N'dbo.CloudAsset', N'U') IS NULL
BEGIN
    THROW 50001, 'Required table dbo.CloudAsset does not exist.', 1;
END;

IF OBJECT_ID(N'dbo.SecurityEvent', N'U') IS NULL
BEGIN
    THROW 50002, 'Required table dbo.SecurityEvent does not exist.', 1;
END;

BEGIN TRY

    BEGIN TRANSACTION;

    /*
        Cloud assets

        The seed contains only fictional laboratory data.
        No credentials, identifiers, personal information,
        IP addresses, tokens, or secrets are stored.
    */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.CloudAsset
        WHERE
            AssetName = N'Lab SQL Logical Server'
            AND AssetType = N'AzureSqlServer'
            AND Environment = N'Lab'
            AND Region = N'Brazil South'
    )
    BEGIN

        INSERT INTO dbo.CloudAsset
        (
            AssetName,
            AssetType,
            Environment,
            Region,
            IsActive
        )
        VALUES
        (
            N'Lab SQL Logical Server',
            N'AzureSqlServer',
            N'Lab',
            N'Brazil South',
            1
        );

        PRINT 'Inserted Lab SQL Logical Server.';
    END
    ELSE
    BEGIN
        PRINT 'Lab SQL Logical Server already exists. Skipping.';
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.CloudAsset
        WHERE
            AssetName = N'Lab SQL Database'
            AND AssetType = N'AzureSqlDatabase'
            AND Environment = N'Lab'
            AND Region = N'Brazil South'
    )
    BEGIN

        INSERT INTO dbo.CloudAsset
        (
            AssetName,
            AssetType,
            Environment,
            Region,
            IsActive
        )
        VALUES
        (
            N'Lab SQL Database',
            N'AzureSqlDatabase',
            N'Lab',
            N'Brazil South',
            1
        );

        PRINT 'Inserted Lab SQL Database.';
    END
    ELSE
    BEGIN
        PRINT 'Lab SQL Database already exists. Skipping.';
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.CloudAsset
        WHERE
            AssetName = N'Lab Firewall Policy'
            AND AssetType = N'SecurityControl'
            AND Environment = N'Lab'
            AND Region = N'Brazil South'
    )
    BEGIN

        INSERT INTO dbo.CloudAsset
        (
            AssetName,
            AssetType,
            Environment,
            Region,
            IsActive
        )
        VALUES
        (
            N'Lab Firewall Policy',
            N'SecurityControl',
            N'Lab',
            N'Brazil South',
            1
        );

        PRINT 'Inserted Lab Firewall Policy.';
    END
    ELSE
    BEGIN
        PRINT 'Lab Firewall Policy already exists. Skipping.';
    END;

    /*
        Resolve generated identifiers.

        IDs are obtained from the database itself.
        No Azure resource identifiers are hardcoded.
    */

    DECLARE @ServerAssetId INT;
    DECLARE @DatabaseAssetId INT;
    DECLARE @FirewallAssetId INT;

    SELECT
        @ServerAssetId = AssetId
    FROM dbo.CloudAsset
    WHERE
        AssetName = N'Lab SQL Logical Server'
        AND AssetType = N'AzureSqlServer'
        AND Environment = N'Lab'
        AND Region = N'Brazil South';

    SELECT
        @DatabaseAssetId = AssetId
    FROM dbo.CloudAsset
    WHERE
        AssetName = N'Lab SQL Database'
        AND AssetType = N'AzureSqlDatabase'
        AND Environment = N'Lab'
        AND Region = N'Brazil South';

    SELECT
        @FirewallAssetId = AssetId
    FROM dbo.CloudAsset
    WHERE
        AssetName = N'Lab Firewall Policy'
        AND AssetType = N'SecurityControl'
        AND Environment = N'Lab'
        AND Region = N'Brazil South';

    IF @ServerAssetId IS NULL
    BEGIN
        THROW 50003, 'Unable to resolve server asset.', 1;
    END;

    IF @DatabaseAssetId IS NULL
    BEGIN
        THROW 50004, 'Unable to resolve database asset.', 1;
    END;

    IF @FirewallAssetId IS NULL
    BEGIN
        THROW 50005, 'Unable to resolve firewall asset.', 1;
    END;

    /*
        Security events

        These events represent successful laboratory
        security baseline validations.
    */

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.SecurityEvent
        WHERE
            AssetId = @ServerAssetId
            AND EventType = N'TlsBaselineValidation'
            AND Description =
                N'TLS minimum version validated as 1.2.'
    )
    BEGIN

        INSERT INTO dbo.SecurityEvent
        (
            AssetId,
            EventType,
            Severity,
            Description
        )
        VALUES
        (
            @ServerAssetId,
            N'TlsBaselineValidation',
            'Low',
            N'TLS minimum version validated as 1.2.'
        );

        PRINT 'Inserted TLS baseline security event.';
    END
    ELSE
    BEGIN
        PRINT 'TLS baseline security event already exists. Skipping.';
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.SecurityEvent
        WHERE
            AssetId = @ServerAssetId
            AND EventType = N'EntraOnlyValidation'
            AND Description =
                N'Microsoft Entra-only authentication validated.'
    )
    BEGIN

        INSERT INTO dbo.SecurityEvent
        (
            AssetId,
            EventType,
            Severity,
            Description
        )
        VALUES
        (
            @ServerAssetId,
            N'EntraOnlyValidation',
            'Low',
            N'Microsoft Entra-only authentication validated.'
        );

        PRINT 'Inserted Microsoft Entra-only security event.';
    END
    ELSE
    BEGIN
        PRINT 'Microsoft Entra-only security event already exists. Skipping.';
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.SecurityEvent
        WHERE
            AssetId = @DatabaseAssetId
            AND EventType = N'TdeValidation'
            AND Description =
                N'Transparent Data Encryption validated as enabled.'
    )
    BEGIN

        INSERT INTO dbo.SecurityEvent
        (
            AssetId,
            EventType,
            Severity,
            Description
        )
        VALUES
        (
            @DatabaseAssetId,
            N'TdeValidation',
            'Low',
            N'Transparent Data Encryption validated as enabled.'
        );

        PRINT 'Inserted TDE security event.';
    END
    ELSE
    BEGIN
        PRINT 'TDE security event already exists. Skipping.';
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.SecurityEvent
        WHERE
            AssetId = @FirewallAssetId
            AND EventType = N'FirewallPolicyValidation'
            AND Description =
                N'Public access validated against the single-IP firewall policy.'
    )
    BEGIN

        INSERT INTO dbo.SecurityEvent
        (
            AssetId,
            EventType,
            Severity,
            Description
        )
        VALUES
        (
            @FirewallAssetId,
            N'FirewallPolicyValidation',
            'Low',
            N'Public access validated against the single-IP firewall policy.'
        );

        PRINT 'Inserted firewall policy security event.';
    END
    ELSE
    BEGIN
        PRINT 'Firewall policy security event already exists. Skipping.';
    END;

    COMMIT TRANSACTION;

    PRINT 'Seed validation completed successfully.';
    PRINT 'No sensitive or personal data was inserted.';

END TRY
BEGIN CATCH

    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;

END CATCH;
