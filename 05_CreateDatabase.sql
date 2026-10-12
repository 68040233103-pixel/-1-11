/*
  Project: Parcel Delivery Database
  Platform: Microsoft SQL Server (SSMS)
  Purpose: Create/migrate tables, keys, constraints, and status sync triggers.
  Run this file before 06_InsertExampleData.sql and 07_TestQuery.sql.
*/

IF DB_ID(N'ParcelDeliveryDB') IS NULL
    EXEC(N'CREATE DATABASE ParcelDeliveryDB');
GO

USE ParcelDeliveryDB;
GO

IF OBJECT_ID(N'dbo.Customer', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Customer (
        CustomerID   VARCHAR(10)     NOT NULL,
        CustomerName NVARCHAR(100)   NOT NULL,
        Phone        VARCHAR(20)     NOT NULL,
        Address      NVARCHAR(255)   NOT NULL,
        Email        VARCHAR(254)    NULL,
        CONSTRAINT PK_Customer PRIMARY KEY (CustomerID)
    );
END;
GO

IF OBJECT_ID(N'dbo.Branch', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Branch (
        BranchID   VARCHAR(10)    NOT NULL,
        BranchName NVARCHAR(100)  NOT NULL,
        Phone      VARCHAR(20)    NOT NULL,
        Address    NVARCHAR(255)  NOT NULL,
        CONSTRAINT PK_Branch PRIMARY KEY (BranchID),
        CONSTRAINT UQ_Branch_BranchName UNIQUE (BranchName)
    );
END;
GO

/* Seed a default branch so this script can migrate existing employees safely. */
IF NOT EXISTS (SELECT 1 FROM dbo.Branch WHERE BranchID = 'BR001')
    INSERT dbo.Branch (BranchID, BranchName, Phone, Address)
    VALUES ('BR001', N'ศูนย์อุดรธานี', '042000001', N'อุดรธานี');
GO

IF OBJECT_ID(N'dbo.Employee', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Employee (
        EmployeeID   VARCHAR(10)     NOT NULL,
        EmployeeName NVARCHAR(100)   NOT NULL,
        Phone        VARCHAR(20)     NOT NULL,
        Position     NVARCHAR(50)    NOT NULL,
        HireDate     DATE            NOT NULL,
        BranchID     VARCHAR(10)     NOT NULL,
        CONSTRAINT PK_Employee PRIMARY KEY (EmployeeID),
        CONSTRAINT FK_Employee_Branch FOREIGN KEY (BranchID) REFERENCES dbo.Branch(BranchID)
    );
END;
GO

/* Add the branch assignment to existing Employee tables, preserving all rows. */
IF COL_LENGTH(N'dbo.Employee', N'BranchID') IS NULL
    ALTER TABLE dbo.Employee ADD BranchID VARCHAR(10) NULL;
GO

UPDATE dbo.Employee SET BranchID = 'BR001' WHERE BranchID IS NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Employee') AND name = N'BranchID' AND is_nullable = 1)
    ALTER TABLE dbo.Employee ALTER COLUMN BranchID VARCHAR(10) NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.Employee') AND name = N'FK_Employee_Branch')
    ALTER TABLE dbo.Employee ADD CONSTRAINT FK_Employee_Branch FOREIGN KEY (BranchID) REFERENCES dbo.Branch(BranchID);
GO

IF OBJECT_ID(N'dbo.ParcelType', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ParcelType (
        ParcelTypeID INT             NOT NULL,
        TypeName     NVARCHAR(50)    NOT NULL,
        Description  NVARCHAR(255)   NULL,
        CONSTRAINT PK_ParcelType PRIMARY KEY (ParcelTypeID),
        CONSTRAINT UQ_ParcelType_TypeName UNIQUE (TypeName)
    );
END;
GO

IF OBJECT_ID(N'dbo.ParcelStatus', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ParcelStatus (
        StatusID    INT             NOT NULL,
        StatusName  NVARCHAR(50)    NOT NULL,
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_ParcelStatus PRIMARY KEY (StatusID),
        CONSTRAINT UQ_ParcelStatus_StatusName UNIQUE (StatusName)
    );
END;
GO

IF OBJECT_ID(N'dbo.Parcel', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Parcel (
        ParcelID              VARCHAR(12)     NOT NULL,
        TrackingNumber        VARCHAR(20)     NOT NULL,
        SenderID              VARCHAR(10)     NOT NULL,
        ReceiverID            VARCHAR(10)     NOT NULL,
        ReceivedByEmployeeID  VARCHAR(10)     NOT NULL,
        ParcelTypeID          INT             NOT NULL,
        WeightKg              DECIMAL(8,2)    NOT NULL,
        ShippingFee           DECIMAL(10,2)   NOT NULL,
        ReceivedAt            DATETIME2(0)    NOT NULL,
        SenderAddressSnapshot NVARCHAR(255)   NOT NULL,
        ReceiverAddressSnapshot NVARCHAR(255) NOT NULL,
        CurrentStatusID       INT             NOT NULL,
        CONSTRAINT PK_Parcel PRIMARY KEY (ParcelID),
        CONSTRAINT UQ_Parcel_TrackingNumber UNIQUE (TrackingNumber),
        CONSTRAINT FK_Parcel_Sender FOREIGN KEY (SenderID) REFERENCES dbo.Customer(CustomerID),
        CONSTRAINT FK_Parcel_Receiver FOREIGN KEY (ReceiverID) REFERENCES dbo.Customer(CustomerID),
        CONSTRAINT FK_Parcel_ReceivedBy FOREIGN KEY (ReceivedByEmployeeID) REFERENCES dbo.Employee(EmployeeID),
        CONSTRAINT FK_Parcel_ParcelType FOREIGN KEY (ParcelTypeID) REFERENCES dbo.ParcelType(ParcelTypeID),
        CONSTRAINT FK_Parcel_CurrentStatus FOREIGN KEY (CurrentStatusID) REFERENCES dbo.ParcelStatus(StatusID),
        CONSTRAINT CK_Parcel_Weight CHECK (WeightKg > 0),
        CONSTRAINT CK_Parcel_ShippingFee CHECK (ShippingFee >= 0)
    );
END;
GO

IF OBJECT_ID(N'dbo.TrackingHistory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TrackingHistory (
        HistoryID  BIGINT IDENTITY(1,1) NOT NULL,
        ParcelID   VARCHAR(12)          NOT NULL,
        EmployeeID VARCHAR(10)          NOT NULL,
        BranchID   VARCHAR(10)          NOT NULL,
        StatusID   INT                  NOT NULL,
        UpdateDate DATETIME2(0)         NOT NULL,
        Note       NVARCHAR(255)        NULL,
        CONSTRAINT PK_TrackingHistory PRIMARY KEY (HistoryID),
        CONSTRAINT FK_TrackingHistory_Parcel FOREIGN KEY (ParcelID) REFERENCES dbo.Parcel(ParcelID),
        CONSTRAINT FK_TrackingHistory_Employee FOREIGN KEY (EmployeeID) REFERENCES dbo.Employee(EmployeeID),
        CONSTRAINT FK_TrackingHistory_Branch FOREIGN KEY (BranchID) REFERENCES dbo.Branch(BranchID),
        CONSTRAINT FK_TrackingHistory_Status FOREIGN KEY (StatusID) REFERENCES dbo.ParcelStatus(StatusID)
    );
END;
GO

/* Preserve old tracking events and assign their employee's branch. */
IF COL_LENGTH(N'dbo.TrackingHistory', N'BranchID') IS NULL
    ALTER TABLE dbo.TrackingHistory ADD BranchID VARCHAR(10) NULL;
GO

UPDATE h SET BranchID = COALESCE(e.BranchID, 'BR001')
FROM dbo.TrackingHistory AS h LEFT JOIN dbo.Employee AS e ON e.EmployeeID = h.EmployeeID
WHERE h.BranchID IS NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.TrackingHistory') AND name = N'BranchID' AND is_nullable = 1)
    ALTER TABLE dbo.TrackingHistory ALTER COLUMN BranchID VARCHAR(10) NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.TrackingHistory') AND name = N'FK_TrackingHistory_Branch')
    ALTER TABLE dbo.TrackingHistory ADD CONSTRAINT FK_TrackingHistory_Branch FOREIGN KEY (BranchID) REFERENCES dbo.Branch(BranchID);
GO

IF OBJECT_ID(N'dbo.Payment', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Payment (
        PaymentID     VARCHAR(12)     NOT NULL,
        ParcelID      VARCHAR(12)     NOT NULL,
        PaymentMethod VARCHAR(30)     NOT NULL,
        Amount        DECIMAL(10,2)   NOT NULL,
        PaymentDate   DATETIME2(0)    NOT NULL,
        PaymentStatus VARCHAR(20)     NOT NULL,
        CONSTRAINT PK_Payment PRIMARY KEY (PaymentID),
        CONSTRAINT UQ_Payment_Parcel UNIQUE (ParcelID),
        CONSTRAINT FK_Payment_Parcel FOREIGN KEY (ParcelID) REFERENCES dbo.Parcel(ParcelID),
        CONSTRAINT CK_Payment_Amount CHECK (Amount > 0),
        CONSTRAINT CK_Payment_Method CHECK (PaymentMethod IN ('Cash', 'BankTransfer', 'CreditCard', 'PromptPay')),
        CONSTRAINT CK_Payment_Status CHECK (PaymentStatus = 'Paid')
    );
END;
GO

/* Migrate the earlier demo schema: normalize old sample rows, then enforce immediate payment. */
IF OBJECT_ID(N'dbo.Payment', N'U') IS NOT NULL
BEGIN
    DECLARE @DropPaymentChecks NVARCHAR(MAX) = N'';
    SELECT @DropPaymentChecks = @DropPaymentChecks + N'ALTER TABLE dbo.Payment DROP CONSTRAINT ' + QUOTENAME(cc.name) + N';'
    FROM sys.check_constraints AS cc WHERE cc.parent_object_id = OBJECT_ID(N'dbo.Payment');
    IF @DropPaymentChecks <> N'' EXEC sys.sp_executesql @DropPaymentChecks;

    UPDATE pay
       SET PaymentStatus = 'Paid',
           PaymentMethod = COALESCE(pay.PaymentMethod, 'Cash'),
           PaymentDate = COALESCE(pay.PaymentDate, p.ReceivedAt)
    FROM dbo.Payment AS pay JOIN dbo.Parcel AS p ON p.ParcelID = pay.ParcelID;

    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Payment') AND name = N'PaymentMethod' AND is_nullable = 1)
        ALTER TABLE dbo.Payment ALTER COLUMN PaymentMethod VARCHAR(30) NOT NULL;
    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Payment') AND name = N'PaymentDate' AND is_nullable = 1)
        ALTER TABLE dbo.Payment ALTER COLUMN PaymentDate DATETIME2(0) NOT NULL;

    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.Payment') AND name = N'CK_Payment_Amount')
        ALTER TABLE dbo.Payment ADD CONSTRAINT CK_Payment_Amount CHECK (Amount > 0);
    ALTER TABLE dbo.Payment ADD CONSTRAINT CK_Payment_Method CHECK (PaymentMethod IN ('Cash', 'BankTransfer', 'CreditCard', 'PromptPay'));
    ALTER TABLE dbo.Payment ADD CONSTRAINT CK_Payment_Status CHECK (PaymentStatus = 'Paid');
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.TrackingHistory') AND name = N'IX_TrackingHistory_Parcel_UpdateDate')
    CREATE INDEX IX_TrackingHistory_Parcel_UpdateDate
        ON dbo.TrackingHistory (ParcelID, UpdateDate, HistoryID);
GO

/* Every newly created parcel starts with an initial Received tracking event. */
CREATE OR ALTER TRIGGER dbo.TR_Parcel_CreateInitialTrackingEvent
ON dbo.Parcel
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN dbo.ParcelStatus AS s ON s.StatusID = i.CurrentStatusID
        WHERE s.StatusName <> N'Received'
    )
    BEGIN
        ;THROW 50002, N'สถานะเริ่มต้นของพัสดุต้องเป็น Received', 1;
    END;

    INSERT dbo.TrackingHistory (ParcelID, EmployeeID, BranchID, StatusID, UpdateDate, Note)
    SELECT i.ParcelID, i.ReceivedByEmployeeID, e.BranchID, i.CurrentStatusID, i.ReceivedAt, N'รับพัสดุและเปิดรายการติดตาม'
    FROM inserted AS i
    JOIN dbo.Employee AS e ON e.EmployeeID = i.ReceivedByEmployeeID;
END;
GO

/* Reject direct status changes that do not match the latest tracking event. */
CREATE OR ALTER TRIGGER dbo.TR_Parcel_ValidateCurrentStatus
ON dbo.Parcel
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(CurrentStatusID) AND EXISTS (
        SELECT 1
        FROM inserted AS i
        OUTER APPLY (
            SELECT TOP (1) h.StatusID
            FROM dbo.TrackingHistory AS h
            WHERE h.ParcelID = i.ParcelID
            ORDER BY h.UpdateDate DESC, h.HistoryID DESC
        ) AS latest
        WHERE latest.StatusID IS NULL OR latest.StatusID <> i.CurrentStatusID
    )
    BEGIN
        ;THROW 50003, N'CurrentStatusID ต้องตรงกับ TrackingHistory ล่าสุด', 1;
    END;
END;
GO

/* Keep Parcel.CurrentStatusID synchronized with the newest tracking event. */
CREATE OR ALTER TRIGGER dbo.TR_TrackingHistory_UpdateCurrentStatus
ON dbo.TrackingHistory
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AffectedParcels TABLE (ParcelID VARCHAR(12) NOT NULL PRIMARY KEY);
    INSERT @AffectedParcels (ParcelID)
    SELECT ParcelID FROM inserted
    UNION
    SELECT ParcelID FROM deleted;

    IF EXISTS (
        SELECT 1
        FROM @AffectedParcels AS a
        WHERE NOT EXISTS (SELECT 1 FROM dbo.TrackingHistory AS h WHERE h.ParcelID = a.ParcelID)
    )
    BEGIN
        ;THROW 50001, N'พัสดุต้องมีประวัติการติดตามอย่างน้อยหนึ่งเหตุการณ์', 1;
    END;

    ;WITH LatestEvent AS (
        SELECT h.ParcelID, h.StatusID,
               ROW_NUMBER() OVER (PARTITION BY h.ParcelID ORDER BY h.UpdateDate DESC, h.HistoryID DESC) AS RowNum
        FROM dbo.TrackingHistory AS h
        INNER JOIN @AffectedParcels AS a ON a.ParcelID = h.ParcelID
    )
    UPDATE p
       SET p.CurrentStatusID = le.StatusID
    FROM dbo.Parcel AS p
    INNER JOIN LatestEvent AS le ON le.ParcelID = p.ParcelID AND le.RowNum = 1;
END;
GO

PRINT N'ParcelDeliveryDB is ready. Run 06_InsertExampleData.sql next.';
GO
