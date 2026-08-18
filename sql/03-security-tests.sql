SET NOCOUNT ON;
SET XACT_ABORT ON;

PRINT 'Starting DIO Azure SQL Secure Lab security tests...';


DECLARE @FailureCount INT = 0;

DECLARE @Results TABLE
(
    TestOrder INT IDENTITY(1,1) NOT NULL,
    TestName NVARCHAR(150) NOT NULL,
    Status VARCHAR(4) NOT NULL,
    Details NVARCHAR(400) NOT NULL
);

/*
    ------------------------------------------------------------
    Critical prerequisites
    ------------------------------------------------------------
*/

IF OBJECT_ID(N'dbo.CloudAsset', N'U') IS NULL
BEGIN
    THROW 51001, 'Required table dbo.CloudAsset does not exist.', 1;
END;

IF OBJECT_ID(N'dbo.SecurityEvent', N'U') IS NULL
BEGIN
    THROW 51002, 'Required table dbo.SecurityEvent does not exist.', 1;
END;

/*
    ------------------------------------------------------------
    Test 01 - Database context
    ------------------------------------------------------------
*/

IF DB_NAME() <> N'master'
BEGIN

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Database context',
        'PASS',
        N'Execution is running against the expected laboratory database.'
    );
END
ELSE
BEGIN

    SET @FailureCount += 1;

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Database context',
        'FAIL',
        N'Execution is not running against the expected database.'
    );
END;

/*
    ------------------------------------------------------------
    Test 02 - Expected tables
    ------------------------------------------------------------
*/

DECLARE @ExpectedTableCount INT;

SELECT
    @ExpectedTableCount = COUNT(*)
FROM sys.tables
WHERE object_id IN
(
    OBJECT_ID(N'dbo.CloudAsset'),
    OBJECT_ID(N'dbo.SecurityEvent')
);

IF @ExpectedTableCount = 2
BEGIN

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Expected tables',
        'PASS',
        N'CloudAsset and SecurityEvent are present.'
    );
END
ELSE
BEGIN

    SET @FailureCount += 1;

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Expected tables',
        'FAIL',
        N'One or more expected tables are missing.'
    );
END;

/*
    ------------------------------------------------------------
    Test 03 - Primary keys
    ------------------------------------------------------------
*/

DECLARE @PrimaryKeyCount INT;

SELECT
    @PrimaryKeyCount = COUNT(*)
FROM sys.key_constraints
WHERE
    type = 'PK'
    AND
    (
        (
            parent_object_id =
                OBJECT_ID(N'dbo.CloudAsset')
            AND name = N'PK_CloudAsset'
        )
        OR
        (
            parent_object_id =
                OBJECT_ID(N'dbo.SecurityEvent')
            AND name = N'PK_SecurityEvent'
        )
    );

IF @PrimaryKeyCount = 2
BEGIN

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Primary keys',
        'PASS',
        N'Both expected primary keys are present.'
    );
END
ELSE
BEGIN

    SET @FailureCount += 1;

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Primary keys',
        'FAIL',
        N'One or more expected primary keys are missing.'
    );
END;

/*
    ------------------------------------------------------------
    Test 04 - Foreign key
    ------------------------------------------------------------
*/

DECLARE @ForeignKeyCount INT;

SELECT
    @ForeignKeyCount = COUNT(*)
FROM sys.foreign_keys
WHERE
    name = N'FK_SecurityEvent_CloudAsset'
    AND parent_object_id =
        OBJECT_ID(N'dbo.SecurityEvent')
    AND referenced_object_id =
        OBJECT_ID(N'dbo.CloudAsset')
    AND is_disabled = 0
    AND is_not_trusted = 0;

IF @ForeignKeyCount = 1
BEGIN

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Foreign key integrity',
        'PASS',
        N'FK_SecurityEvent_CloudAsset is enabled and trusted.'
    );
END
ELSE
BEGIN

    SET @FailureCount += 1;

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Foreign key integrity',
        'FAIL',
        N'Expected foreign key is missing, disabled, or untrusted.'
    );
END;

/*
    ------------------------------------------------------------
    Test 05 - CHECK constraints
    ------------------------------------------------------------
*/

DECLARE @CheckConstraintCount INT;

SELECT
    @CheckConstraintCount = COUNT(*)
FROM sys.check_constraints
WHERE
    (
        (
            name = N'CK_CloudAsset_Environment'
            AND parent_object_id =
                OBJECT_ID(N'dbo.CloudAsset')
        )
        OR
        (
            name = N'CK_SecurityEvent_Severity'
            AND parent_object_id =
                OBJECT_ID(N'dbo.SecurityEvent')
        )
    )
    AND is_disabled = 0
    AND is_not_trusted = 0;

IF @CheckConstraintCount = 2
BEGIN

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'CHECK constraints',
        'PASS',
        N'Environment and severity constraints are enabled and trusted.'
    );
END
ELSE
BEGIN

    SET @FailureCount += 1;

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'CHECK constraints',
        'FAIL',
        N'Expected CHECK constraints are missing, disabled, or untrusted.'
    );
END;

/*
    ------------------------------------------------------------
    Test 06 - Expected indexes
    ------------------------------------------------------------
*/

DECLARE @ExpectedIndexCount INT;

SELECT
    @ExpectedIndexCount = COUNT(*)
FROM sys.indexes
WHERE
    is_disabled = 0
    AND
    (
        (
            object_id =
                OBJECT_ID(N'dbo.CloudAsset')
            AND name =
                N'IX_CloudAsset_Environment'
        )
        OR
        (
            object_id =
                OBJECT_ID(N'dbo.SecurityEvent')
            AND name =
                N'IX_SecurityEvent_AssetId'
        )
        OR
        (
            object_id =
                OBJECT_ID(N'dbo.SecurityEvent')
            AND name =
                N'IX_SecurityEvent_Severity'
        )
    );

IF @ExpectedIndexCount = 3
BEGIN

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Expected indexes',
        'PASS',
        N'All three expected indexes are enabled.'
    );
END
ELSE
BEGIN

    SET @FailureCount += 1;

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Expected indexes',
        'FAIL',
        N'One or more expected indexes are missing or disabled.'
    );
END;

/*
    ------------------------------------------------------------
    Test 07 - Seed assets
    ------------------------------------------------------------
*/

DECLARE @LabAssetCount INT;

SELECT
    @LabAssetCount = COUNT(*)
FROM dbo.CloudAsset
WHERE AssetName IN
(
    N'Lab SQL Logical Server',
    N'Lab SQL Database',
    N'Lab Firewall Policy'
);

IF @LabAssetCount = 3
BEGIN

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Expected seed assets',
        'PASS',
        N'Exactly three expected laboratory assets are present.'
    );
END
ELSE
BEGIN

    SET @FailureCount += 1;

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Expected seed assets',
        'FAIL',
        N'Expected laboratory asset count is not equal to three.'
    );
END;

/*
    ------------------------------------------------------------
    Test 08 - Seed security events
    ------------------------------------------------------------
*/

DECLARE @SecurityEventCount INT;

SELECT
    @SecurityEventCount = COUNT(*)
FROM dbo.SecurityEvent
WHERE EventType IN
(
    N'TlsBaselineValidation',
    N'EntraOnlyValidation',
    N'TdeValidation',
    N'FirewallPolicyValidation'
);

IF @SecurityEventCount = 4
BEGIN

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Expected security events',
        'PASS',
        N'Exactly four expected security events are present.'
    );
END
ELSE
BEGIN

    SET @FailureCount += 1;

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Expected security events',
        'FAIL',
        N'Expected security event count is not equal to four.'
    );
END;

/*
    ------------------------------------------------------------
    Test 09 - Duplicate assets
    ------------------------------------------------------------
*/

DECLARE @DuplicateAssetGroups INT;

SELECT
    @DuplicateAssetGroups = COUNT(*)
FROM
(
    SELECT
        AssetName,
        AssetType,
        Environment,
        Region
    FROM dbo.CloudAsset
    WHERE AssetName IN
    (
        N'Lab SQL Logical Server',
        N'Lab SQL Database',
        N'Lab Firewall Policy'
    )
    GROUP BY
        AssetName,
        AssetType,
        Environment,
        Region
    HAVING COUNT(*) > 1
) AS DuplicateAssets;

IF @DuplicateAssetGroups = 0
BEGIN

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Duplicate assets',
        'PASS',
        N'No duplicate laboratory assets were detected.'
    );
END
ELSE
BEGIN

    SET @FailureCount += 1;

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Duplicate assets',
        'FAIL',
        N'Duplicate laboratory assets were detected.'
    );
END;

/*
    ------------------------------------------------------------
    Test 10 - Duplicate security events
    ------------------------------------------------------------
*/

DECLARE @DuplicateEventGroups INT;

SELECT
    @DuplicateEventGroups = COUNT(*)
FROM
(
    SELECT
        AssetId,
        EventType,
        Description
    FROM dbo.SecurityEvent
    WHERE EventType IN
    (
        N'TlsBaselineValidation',
        N'EntraOnlyValidation',
        N'TdeValidation',
        N'FirewallPolicyValidation'
    )
    GROUP BY
        AssetId,
        EventType,
        Description
    HAVING COUNT(*) > 1
) AS DuplicateEvents;

IF @DuplicateEventGroups = 0
BEGIN

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Duplicate security events',
        'PASS',
        N'No duplicate laboratory security events were detected.'
    );
END
ELSE
BEGIN

    SET @FailureCount += 1;

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Duplicate security events',
        'FAIL',
        N'Duplicate laboratory security events were detected.'
    );
END;

/*
    ------------------------------------------------------------
    Test 11 - Referential integrity
    ------------------------------------------------------------
*/

DECLARE @OrphanEventCount INT;

SELECT
    @OrphanEventCount = COUNT(*)
FROM dbo.SecurityEvent AS EventData
LEFT JOIN dbo.CloudAsset AS Asset
    ON Asset.AssetId =
        EventData.AssetId
WHERE Asset.AssetId IS NULL;

IF @OrphanEventCount = 0
BEGIN

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Referential integrity',
        'PASS',
        N'No orphan SecurityEvent rows were detected.'
    );
END
ELSE
BEGIN

    SET @FailureCount += 1;

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Referential integrity',
        'FAIL',
        N'Orphan SecurityEvent rows were detected.'
    );
END;

/*
    ------------------------------------------------------------
    Test 12 - Environment domain
    ------------------------------------------------------------
*/

DECLARE @InvalidEnvironmentCount INT;

SELECT
    @InvalidEnvironmentCount = COUNT(*)
FROM dbo.CloudAsset
WHERE Environment NOT IN
(
    N'Lab',
    N'Development',
    N'Test'
);

IF @InvalidEnvironmentCount = 0
BEGIN

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Environment domain',
        'PASS',
        N'All CloudAsset environment values are allowed.'
    );
END
ELSE
BEGIN

    SET @FailureCount += 1;

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Environment domain',
        'FAIL',
        N'Unexpected CloudAsset environment values were detected.'
    );
END;

/*
    ------------------------------------------------------------
    Test 13 - Severity domain
    ------------------------------------------------------------
*/

DECLARE @InvalidSeverityCount INT;

SELECT
    @InvalidSeverityCount = COUNT(*)
FROM dbo.SecurityEvent
WHERE Severity NOT IN
(
    'Low',
    'Medium',
    'High'
);

IF @InvalidSeverityCount = 0
BEGIN

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Severity domain',
        'PASS',
        N'All SecurityEvent severity values are allowed.'
    );
END
ELSE
BEGIN

    SET @FailureCount += 1;

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Severity domain',
        'FAIL',
        N'Unexpected SecurityEvent severity values were detected.'
    );
END;

/*
    ------------------------------------------------------------
    Test 14 - Database-level firewall
    ------------------------------------------------------------

    This laboratory intentionally manages network access
    with a server-level single-IP firewall rule.

    Therefore no database-level firewall rule is expected.
*/

DECLARE @DatabaseFirewallRuleCount INT;

SELECT
    @DatabaseFirewallRuleCount = COUNT(*)
FROM sys.database_firewall_rules;

IF @DatabaseFirewallRuleCount = 0
BEGIN

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Current database firewall',
        'PASS',
        N'No database-level firewall rules are configured in the current database.'
    );
END
ELSE
BEGIN

    SET @FailureCount += 1;

    INSERT INTO @Results
    (
        TestName,
        Status,
        Details
    )
    VALUES
    (
        N'Current database firewall',
        'FAIL',
        N'Unexpected database-level firewall rules were detected in the current database.'
    );
END;

/*
    ------------------------------------------------------------
    Results
    ------------------------------------------------------------
*/

SELECT
    TestOrder,
    TestName,
    Status,
    Details
FROM @Results
ORDER BY TestOrder;

PRINT '';

PRINT
    'Security tests completed. Failures: '
    + CAST(@FailureCount AS VARCHAR(10));

IF @FailureCount > 0
BEGIN

    THROW 51000,
        'Security validation failed. Review FAIL results.',
        1;
END;

PRINT 'All database security tests passed successfully.';