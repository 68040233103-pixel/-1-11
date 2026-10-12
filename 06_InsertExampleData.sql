/*
  Project: Parcel Delivery Database
  Platform: Microsoft SQL Server (SSMS)
  Purpose: Add reference values and example records. Safe to run more than once.
*/

USE ParcelDeliveryDB;
GO

MERGE dbo.ParcelType AS target
USING (VALUES
    (1, N'General', N'พัสดุทั่วไปที่ไม่ต้องดูแลเป็นพิเศษ เหมาะกับสิ่งของใช้งานทั่วไปที่บรรจุหีบห่อเรียบร้อย'),
    (2, N'Fragile', N'สิ่งของแตกหักง่าย เช่น แก้วหรืออุปกรณ์อิเล็กทรอนิกส์ ควรห่อกันกระแทกและติดเครื่องหมายระมัดระวัง'),
    (3, N'Document', N'เอกสารหรือกระดาษสำคัญ บรรจุในซองหรือแฟ้มเพื่อป้องกันการพับ เปียก หรือฉีกขาด')
) AS source(ParcelTypeID, TypeName, Description)
ON target.ParcelTypeID = source.ParcelTypeID
WHEN MATCHED THEN UPDATE SET TypeName = source.TypeName, Description = source.Description
WHEN NOT MATCHED THEN INSERT (ParcelTypeID, TypeName, Description)
    VALUES (source.ParcelTypeID, source.TypeName, source.Description);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.ParcelStatus WHERE StatusID = 1)
    INSERT dbo.ParcelStatus (StatusID, StatusName, Description) VALUES
    (1, N'Received', N'รับพัสดุแล้ว'),
    (2, N'In Transit', N'กำลังจัดส่ง'),
    (3, N'Delivered', N'จัดส่งสำเร็จ'),
    (4, N'Delivery Failed', N'จัดส่งไม่สำเร็จ');
GO

DECLARE @CustomerSeed TABLE (
    CustomerID VARCHAR(10) NOT NULL PRIMARY KEY,
    CustomerName NVARCHAR(100) NOT NULL,
    Phone VARCHAR(20) NOT NULL,
    Address NVARCHAR(255) NOT NULL,
    Email VARCHAR(254) NULL
);

INSERT @CustomerSeed (CustomerID, CustomerName, Phone, Address, Email) VALUES
('CUS001', N'สมชาย ใจดี', '0812345678', N'123 ถนนมิตรภาพ อุดรธานี', 'somchai@example.com'),
('CUS002', N'วรรณา สุขใจ', '0891234567', N'45 ถนนสุขุมวิท กรุงเทพฯ', 'wanna@example.com'),
('CUS003', N'ปรีชา แสงทอง', '0865551234', N'88 ถนนประชารักษา ขอนแก่น', NULL),
('CUS004', N'มาลี มีสุข', '0924446789', N'19 ถนนโพศรี อุดรธานี', 'malee@example.com');

INSERT dbo.Customer (CustomerID, CustomerName, Phone, Address, Email)
SELECT s.CustomerID, s.CustomerName, s.Phone, s.Address, s.Email
FROM @CustomerSeed AS s
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Customer AS c WHERE c.CustomerID = s.CustomerID
);
GO

/* Add 96 fictional profiles so the demonstration dataset has 100 customers total.
   Emails use the reserved example.com domain; phone values are replaced below. */
;WITH FirstNames AS (
    SELECT * FROM (VALUES
        (1, N'ณัฐพล'), (2, N'กิตติ'), (3, N'ธนกร'), (4, N'ภัทร'),
        (5, N'ปกรณ์'), (6, N'วรัญญู'), (7, N'ชนากานต์'), (8, N'ศิริพร'),
        (9, N'พิมพ์ชนก'), (10, N'อรทัย'), (11, N'นภัสสร'), (12, N'ธนพร')
    ) AS n(Seq, Name)
),
LastNames AS (
    SELECT * FROM (VALUES
        (1, N'วัฒนกุล'), (2, N'ศรีสวัสดิ์'), (3, N'พูนทรัพย์'), (4, N'ทองดี'),
        (5, N'บุญมี'), (6, N'เจริญสุข'), (7, N'ตั้งมั่น'), (8, N'รุ่งเรือง')
    ) AS n(Seq, Name)
),
Roads AS (
    SELECT * FROM (VALUES
        (1, N'มิตรภาพ'), (2, N'สุขุมวิท'), (3, N'ประชารักษา'), (4, N'โพศรี'),
        (5, N'รอบเมือง'), (6, N'เลี่ยงเมือง'), (7, N'ศรีจันทร์'), (8, N'ราชดำเนิน')
    ) AS r(Seq, Name)
),
Provinces AS (
    SELECT * FROM (VALUES
        (1, N'กรุงเทพฯ'), (2, N'เชียงใหม่'), (3, N'ขอนแก่น'), (4, N'อุดรธานี'),
        (5, N'นครราชสีมา'), (6, N'ชลบุรี'), (7, N'ภูเก็ต'), (8, N'สงขลา')
    ) AS p(Seq, Name)
),
CustomerCandidates AS (
    SELECT ROW_NUMBER() OVER (ORDER BY f.Seq, l.Seq) AS RowNum,
           f.Name + N' ' + l.Name AS CustomerName
    FROM FirstNames AS f
    CROSS JOIN LastNames AS l
)
INSERT dbo.Customer (CustomerID, CustomerName, Phone, Address, Email)
SELECT 'CUS' + RIGHT('000' + CONVERT(VARCHAR(3), c.RowNum + 4), 3),
       c.CustomerName,
       '000000' + RIGHT('0000' + CONVERT(VARCHAR(4), c.RowNum), 4),
       CONVERT(NVARCHAR(10), 100 + c.RowNum) + N' ถนน' + r.Name + N' ' + p.Name,
       'customer' + RIGHT('000' + CONVERT(VARCHAR(3), c.RowNum + 4), 3) + '@example.com'
FROM CustomerCandidates AS c
JOIN Roads AS r ON r.Seq = ((c.RowNum - 1) % 8) + 1
JOIN Provinces AS p ON p.Seq = ((c.RowNum - 1) % 8) + 1
WHERE c.RowNum <= 96
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.Customer AS existing
      WHERE existing.CustomerID = 'CUS' + RIGHT('000' + CONVERT(VARCHAR(3), c.RowNum + 4), 3)
  );

/* Assign varied, deterministic fictional profiles to all 100 seed customers.
   Customer IDs remain sequential; the profile fields are distributed by a fixed permutation.
   Phone values are ten-digit Thai mobile-style examples, not verified subscriber numbers. */
;WITH FirstNames AS (
    SELECT * FROM (VALUES
        (1, N'ณัฐพล', 'nattapon'), (2, N'กิตติ', 'kitti'), (3, N'ธนกร', 'thanakorn'),
        (4, N'ภัทร', 'phat'), (5, N'ปกรณ์', 'pakorn'), (6, N'วรัญญู', 'waranyu'),
        (7, N'ชนากานต์', 'chanakan'), (8, N'ศิริพร', 'siriporn'),
        (9, N'พิมพ์ชนก', 'pimchanok'), (10, N'อรทัย', 'orathai')
    ) AS n(Seq, Name, EmailName)
),
LastNames AS (
    SELECT * FROM (VALUES
        (1, N'วัฒนกุล', 'wattanakul'), (2, N'ศรีสวัสดิ์', 'srisawat'),
        (3, N'พูนทรัพย์', 'poonsap'), (4, N'ทองดี', 'thongdee'), (5, N'บุญมี', 'boonmee'),
        (6, N'เจริญสุข', 'charoensuk'), (7, N'ตั้งมั่น', 'tangman'),
        (8, N'รุ่งเรือง', 'rungreung'), (9, N'แสงไพศาล', 'saengpaisan'),
        (10, N'คำสิงห์', 'khamsing')
    ) AS n(Seq, Name, EmailName)
),
Roads AS (
    SELECT * FROM (VALUES
        (1, N'มิตรภาพ'), (2, N'สุขุมวิท'), (3, N'ประชารักษา'), (4, N'โพศรี'), (5, N'รอบเมือง'),
        (6, N'เลี่ยงเมือง'), (7, N'ศรีจันทร์'), (8, N'ราชดำเนิน'), (9, N'นิมมานเหมินท์'), (10, N'พหลโยธิน')
    ) AS r(Seq, Name)
),
Provinces AS (
    SELECT * FROM (VALUES
        (1, N'กรุงเทพฯ'), (2, N'เชียงใหม่'), (3, N'ขอนแก่น'), (4, N'อุดรธานี'), (5, N'นครราชสีมา'),
        (6, N'ชลบุรี'), (7, N'ภูเก็ต'), (8, N'สงขลา'), (9, N'พิษณุโลก'), (10, N'นครศรีธรรมราช')
    ) AS p(Seq, Name)
),
CustomerProfiles AS (
    SELECT ROW_NUMBER() OVER (ORDER BY f.Seq, l.Seq) AS CustomerNum,
           ((ROW_NUMBER() OVER (ORDER BY f.Seq, l.Seq) * 37 + 13) % 100) + 1 AS ProfileNum
    FROM FirstNames AS f
    CROSS JOIN LastNames AS l
),
ProfileDetails AS (
    SELECT cp.CustomerNum,
           f.Name + N' ' + l.Name AS CustomerName,
           CASE ABS(CONVERT(BIGINT, CHECKSUM('CUS' + RIGHT('000' + CONVERT(VARCHAR(3), cp.CustomerNum), 3)))) % 2
               WHEN 0 THEN '08' ELSE '09' END
               + RIGHT('00000000' + CONVERT(VARCHAR(8), ((cp.CustomerNum * 7919 + 31415927) % 90000000) + 10000000), 8) AS Phone,
           CONVERT(NVARCHAR(10), ((cp.CustomerNum * 137 + 389) % 997) + 1)
               + N' ถนน' + r.Name + N' ' + p.Name AS Address,
           f.EmailName + '.' + l.EmailName + '@example.com' AS Email
    FROM CustomerProfiles AS cp
    JOIN FirstNames AS f ON f.Seq = ((cp.ProfileNum - 1) / 10) + 1
    JOIN LastNames AS l ON l.Seq = ((cp.ProfileNum - 1) % 10) + 1
    JOIN Roads AS r ON r.Seq = ((cp.CustomerNum * cp.CustomerNum * 7 + cp.CustomerNum * 13 + 3) % 10) + 1
    JOIN Provinces AS p ON p.Seq = ((cp.CustomerNum * cp.CustomerNum * 3 + cp.CustomerNum * 7 + 2) % 10) + 1
)
UPDATE c
SET c.CustomerName = d.CustomerName,
    c.Phone = d.Phone,
    c.Address = d.Address,
    c.Email = d.Email
FROM dbo.Customer AS c
JOIN ProfileDetails AS d
  ON c.CustomerID = 'CUS' + RIGHT('000' + CONVERT(VARCHAR(3), d.CustomerNum), 3)
WHERE d.CustomerNum BETWEEN 1 AND 100;
GO

MERGE dbo.Branch AS target
USING (VALUES
    ('BR001', N'ศูนย์รับส่งพัสดุหลัก', '042000001', N'อุดรธานี')
) AS source(BranchID, BranchName, Phone, Address)
ON target.BranchID = source.BranchID
WHEN MATCHED THEN UPDATE SET BranchName = source.BranchName, Phone = source.Phone, Address = source.Address
WHEN NOT MATCHED THEN INSERT (BranchID, BranchName, Phone, Address)
    VALUES (source.BranchID, source.BranchName, source.Phone, source.Address);
GO

MERGE dbo.Employee AS target
USING (VALUES
    ('EMP001', N'อนันต์ สุขสันต์', '0891234567', N'พนักงานรับพัสดุ', CONVERT(DATE,'2025-01-15'), 'BR001'),
    ('EMP002', N'กมลวรรณ ศรีดี', '0815552468', N'พนักงานคัดแยกพัสดุ', CONVERT(DATE,'2025-03-01'), 'BR001'),
    ('EMP003', N'ธนา พูนผล', '0863331478', N'พนักงานนำจ่าย', CONVERT(DATE,'2024-06-10'), 'BR001'),
    ('EMP004', N'พิมพ์ชนก วัฒนกุล', '0823456789', N'พนักงานรับพัสดุ', CONVERT(DATE,'2025-05-12'), 'BR001'),
    ('EMP005', N'วรัญญู ศรีสวัสดิ์', '0845678910', N'พนักงานคัดแยกพัสดุ', CONVERT(DATE,'2025-07-01'), 'BR001'),
    ('EMP006', N'ชนากานต์ พูนทรัพย์', '0867890123', N'พนักงานนำจ่าย', CONVERT(DATE,'2025-08-18'), 'BR001'),
    ('EMP007', N'นภัสสร ทองดี', '0912345678', N'หัวหน้าศูนย์', CONVERT(DATE,'2024-06-10'), 'BR001')
) AS source(EmployeeID, EmployeeName, Phone, Position, HireDate, BranchID)
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED THEN UPDATE SET EmployeeName = source.EmployeeName,
                              Phone = source.Phone,
                              Position = source.Position,
                              HireDate = source.HireDate,
                              BranchID = source.BranchID
WHEN NOT MATCHED THEN INSERT (EmployeeID, EmployeeName, Phone, Position, HireDate, BranchID)
    VALUES (source.EmployeeID, source.EmployeeName, source.Phone, source.Position, source.HireDate, source.BranchID);
GO

/* This project models one branch, so all staff and tracking events use BR001. */
UPDATE dbo.Employee SET BranchID = 'BR001';
UPDATE dbo.TrackingHistory SET BranchID = 'BR001';
DELETE FROM dbo.Branch WHERE BranchID IN ('BR002','BR003');
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Parcel WHERE ParcelID = 'PCL0001')
    INSERT dbo.Parcel (ParcelID, TrackingNumber, SenderID, ReceiverID, ReceivedByEmployeeID,
                       ParcelTypeID, WeightKg, ShippingFee, ReceivedAt,
                       SenderAddressSnapshot, ReceiverAddressSnapshot, CurrentStatusID) VALUES
    ('PCL0001', 'TH123456789', 'CUS001', 'CUS002', 'EMP001', 2, 2.50, 50.00,
     '2026-10-03T09:30:00', N'123 ถนนมิตรภาพ อุดรธานี', N'45 ถนนสุขุมวิท กรุงเทพฯ', 1),
    ('PCL0002', 'TH123456790', 'CUS002', 'CUS003', 'EMP001', 1, 5.20, 75.00,
     '2026-10-03T10:15:00', N'45 ถนนสุขุมวิท กรุงเทพฯ', N'88 ถนนประชารักษา ขอนแก่น', 1),
    ('PCL0003', 'TH123456791', 'CUS004', 'CUS001', 'EMP001', 3, 0.30, 80.00,
     '2026-10-03T11:00:00', N'19 ถนนโพศรี อุดรธานี', N'123 ถนนมิตรภาพ อุดรธานี', 1);
GO

INSERT dbo.Payment (PaymentID, ParcelID, PaymentMethod, Amount, PaymentDate, PaymentStatus)
SELECT seed.PaymentID, seed.ParcelID, seed.PaymentMethod, seed.Amount, seed.PaymentDate, 'Paid'
FROM (VALUES
    ('PAY0001', 'PCL0001', 'Cash', CAST(50.00 AS DECIMAL(10,2)), CAST('2026-10-03T09:35:00' AS DATETIME2(0))),
    ('PAY0002', 'PCL0002', 'PromptPay', CAST(75.00 AS DECIMAL(10,2)), CAST('2026-10-03T10:20:00' AS DATETIME2(0))),
    ('PAY0003', 'PCL0003', 'Cash', CAST(80.00 AS DECIMAL(10,2)), CAST('2026-10-03T11:05:00' AS DATETIME2(0)))
) AS seed(PaymentID, ParcelID, PaymentMethod, Amount, PaymentDate)
WHERE NOT EXISTS (SELECT 1 FROM dbo.Payment AS pay WHERE pay.ParcelID = seed.ParcelID);
GO

/* Normalize existing rows too; every shipment is paid at acceptance in this model. */
UPDATE pay
   SET PaymentStatus = 'Paid',
       PaymentMethod = COALESCE(pay.PaymentMethod, 'Cash'),
       PaymentDate = COALESCE(pay.PaymentDate, p.ReceivedAt)
FROM dbo.Payment AS pay JOIN dbo.Parcel AS p ON p.ParcelID = pay.ParcelID;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.TrackingHistory WHERE ParcelID = 'PCL0001' AND StatusID = 2)
BEGIN
    INSERT dbo.TrackingHistory (ParcelID, EmployeeID, BranchID, StatusID, UpdateDate, Note) VALUES
    ('PCL0001', 'EMP002', 'BR001', 2, '2026-10-03T12:00:00', N'รับเข้ากระบวนการคัดแยกและเตรียมนำจ่าย'),
    ('PCL0001', 'EMP002', 'BR001', 3, '2026-10-03T15:30:00', N'นำจ่ายสำเร็จ ส่งมอบแก่ผู้รับแล้ว'),
    ('PCL0002', 'EMP002', 'BR001', 2, '2026-10-03T13:10:00', N'พัสดุอยู่ระหว่างนำจ่าย'),
    ('PCL0003', 'EMP002', 'BR001', 2, '2026-10-03T14:05:00', N'ออกนำจ่ายไปยังที่อยู่ผู้รับ'),
    ('PCL0003', 'EMP002', 'BR001', 4, '2026-10-03T17:20:00', N'ไม่พบผู้รับ ติดต่อเพื่อนัดหมายนำจ่ายอีกครั้ง');
END;
GO

/* Add parcels PCL0004-PCL0100 so there are 100 shipments in the sample set. */
;WITH ParcelNumbers AS (
    SELECT 4 AS ParcelNumber
    UNION ALL
    SELECT ParcelNumber + 1 FROM ParcelNumbers WHERE ParcelNumber < 100
),
ParcelDrafts AS (
    SELECT n.ParcelNumber,
           'PCL' + RIGHT('0000' + CONVERT(VARCHAR(4), n.ParcelNumber), 4) AS ParcelID,
           'TH' + RIGHT('000000000' + CONVERT(VARCHAR(9), 123456789 + n.ParcelNumber - 1), 9) AS TrackingNumber,
           'CUS' + RIGHT('000' + CONVERT(VARCHAR(3), ((n.ParcelNumber * 7) % 100) + 1), 3) AS SenderID,
           'CUS' + RIGHT('000' + CONVERT(VARCHAR(3), ((n.ParcelNumber * 13 + 17) % 100) + 1), 3) AS ReceiverID,
           CASE WHEN n.ParcelNumber % 2 = 0 THEN 'EMP004' ELSE 'EMP001' END AS EmployeeID,
           ((n.ParcelNumber - 1) % 3) + 1 AS ParcelTypeID,
           CAST(1.00 + (n.ParcelNumber % 20) * 0.35 AS DECIMAL(8,2)) AS WeightKg,
           DATEADD(MINUTE, (n.ParcelNumber * 137) % 600,
               DATEADD(DAY, (n.ParcelNumber * 11) % 30,
                   CAST('2026-10-01T08:00:00' AS DATETIME2(0)))) AS ReceivedAt
    FROM ParcelNumbers AS n
)
INSERT dbo.Parcel (ParcelID, TrackingNumber, SenderID, ReceiverID, ReceivedByEmployeeID,
                   ParcelTypeID, WeightKg, ShippingFee, ReceivedAt,
                   SenderAddressSnapshot, ReceiverAddressSnapshot, CurrentStatusID)
SELECT d.ParcelID, d.TrackingNumber, d.SenderID, d.ReceiverID, d.EmployeeID,
       d.ParcelTypeID, d.WeightKg,
       CAST(35.00 + (d.ParcelNumber % 5) * 10 + d.WeightKg * 5 AS DECIMAL(10,2)),
       d.ReceivedAt, sender.Address, receiver.Address, 1
FROM ParcelDrafts AS d
JOIN dbo.Customer AS sender ON sender.CustomerID = d.SenderID
JOIN dbo.Customer AS receiver ON receiver.CustomerID = d.ReceiverID
WHERE NOT EXISTS (SELECT 1 FROM dbo.Parcel AS p WHERE p.ParcelID = d.ParcelID)
OPTION (MAXRECURSION 100);
GO

/* Distribute 100 shipments realistically; every stored customer is a sender or receiver. */
;WITH ParcelCustomerMap AS (
    SELECT p.ParcelID,
           CONVERT(INT, RIGHT(p.ParcelID, 4)) AS ParcelNumber,
           CASE WHEN CONVERT(INT, RIGHT(p.ParcelID, 4)) <= 70
                THEN ((CONVERT(INT, RIGHT(p.ParcelID, 4)) - 1) * 17 % 50) + 1
                ELSE ((CONVERT(INT, RIGHT(p.ParcelID, 4)) * 7 % 15) + 1)
           END AS SenderNumber,
           CASE WHEN CONVERT(INT, RIGHT(p.ParcelID, 4)) <= 80
                THEN 41 + ((CONVERT(INT, RIGHT(p.ParcelID, 4)) - 1) * 17 % 60)
                ELSE 41 + ((CONVERT(INT, RIGHT(p.ParcelID, 4)) * 11 % 15))
           END AS ReceiverNumber
    FROM dbo.Parcel AS p
    WHERE p.ParcelID LIKE 'PCL[0-9][0-9][0-9][0-9]'
      AND CONVERT(INT, RIGHT(p.ParcelID, 4)) BETWEEN 1 AND 100
)
UPDATE p
   SET SenderID = sender.CustomerID,
       ReceiverID = receiver.CustomerID,
       ReceivedByEmployeeID = CASE WHEN m.ParcelNumber % 2 = 0 THEN 'EMP004' ELSE 'EMP001' END,
       SenderAddressSnapshot = sender.Address,
       ReceiverAddressSnapshot = receiver.Address
FROM dbo.Parcel AS p
JOIN ParcelCustomerMap AS m ON m.ParcelID = p.ParcelID
JOIN dbo.Customer AS sender
  ON sender.CustomerID = 'CUS' + RIGHT('000' + CONVERT(VARCHAR(3), m.SenderNumber), 3)
JOIN dbo.Customer AS receiver
  ON receiver.CustomerID = 'CUS' + RIGHT('000' + CONVERT(VARCHAR(3), m.ReceiverNumber), 3);
GO

/* Align each tracking event with the employee role responsible for that status. */
UPDATE h
   SET EmployeeID = CASE
       WHEN h.StatusID = 1 THEN p.ReceivedByEmployeeID
       WHEN h.StatusID = 2 THEN CASE WHEN CONVERT(INT, RIGHT(p.ParcelID, 4)) % 2 = 0 THEN 'EMP005' ELSE 'EMP002' END
       ELSE CASE WHEN CONVERT(INT, RIGHT(p.ParcelID, 4)) % 2 = 0 THEN 'EMP006' ELSE 'EMP003' END
   END,
   BranchID = 'BR001'
FROM dbo.TrackingHistory AS h
JOIN dbo.Parcel AS p ON p.ParcelID = h.ParcelID;
GO

/* Add one paid-at-acceptance payment per added parcel. */
INSERT dbo.Payment (PaymentID, ParcelID, PaymentMethod, Amount, PaymentDate, PaymentStatus)
SELECT 'PAY' + RIGHT('0000' + CONVERT(VARCHAR(4), CONVERT(INT, RIGHT(p.ParcelID, 4))), 4),
       p.ParcelID,
       CASE WHEN n.ParcelNumber % 2 = 0 THEN 'Cash'
            ELSE 'PromptPay' END,
       p.ShippingFee,
       DATEADD(MINUTE, 2, p.ReceivedAt),
       'Paid'
FROM dbo.Parcel AS p
CROSS APPLY (SELECT CONVERT(INT, RIGHT(p.ParcelID, 4)) AS ParcelNumber) AS n
WHERE n.ParcelNumber BETWEEN 4 AND 100
  AND NOT EXISTS (SELECT 1 FROM dbo.Payment AS pay WHERE pay.ParcelID = p.ParcelID);
GO

/* Every added parcel gets an In Transit event; most then reach Delivered or Delivery Failed. */
;WITH ParcelEvents AS (
    SELECT p.ParcelID, n.ParcelNumber, 2 AS StatusID,
           DATEADD(MINUTE, 600 + ((n.ParcelNumber * 47) % 240),
               DATEADD(DAY, 1, CONVERT(DATETIME2(0), CONVERT(DATE, p.ReceivedAt)))) AS UpdateDate
    FROM dbo.Parcel AS p
    CROSS APPLY (SELECT CONVERT(INT, RIGHT(p.ParcelID, 4)) AS ParcelNumber) AS n
    WHERE n.ParcelNumber BETWEEN 4 AND 100

    UNION ALL

    SELECT p.ParcelID, n.ParcelNumber, 3 AS StatusID,
           DATEADD(MINUTE, 480 + ((n.ParcelNumber * 137) % 600),
               DATEADD(DAY, 2 + (n.ParcelNumber % 3), CONVERT(DATETIME2(0), CONVERT(DATE, p.ReceivedAt)))) AS UpdateDate
    FROM dbo.Parcel AS p
    CROSS APPLY (SELECT CONVERT(INT, RIGHT(p.ParcelID, 4)) AS ParcelNumber) AS n
    WHERE n.ParcelNumber BETWEEN 4 AND 100 AND n.ParcelNumber % 3 = 0

    UNION ALL

    SELECT p.ParcelID, n.ParcelNumber, 4 AS StatusID,
           DATEADD(MINUTE, 480 + ((n.ParcelNumber * 137) % 600),
               DATEADD(DAY, 2 + (n.ParcelNumber % 3), CONVERT(DATETIME2(0), CONVERT(DATE, p.ReceivedAt)))) AS UpdateDate
    FROM dbo.Parcel AS p
    CROSS APPLY (SELECT CONVERT(INT, RIGHT(p.ParcelID, 4)) AS ParcelNumber) AS n
    WHERE n.ParcelNumber BETWEEN 4 AND 100 AND n.ParcelNumber % 3 = 2
)
INSERT dbo.TrackingHistory (ParcelID, EmployeeID, BranchID, StatusID, UpdateDate, Note)
SELECT e.ParcelID,
       emp.EmployeeID, emp.BranchID,
       e.StatusID, e.UpdateDate,
       CASE e.StatusID
           WHEN 2 THEN N'พัสดุออกจากศูนย์คัดแยก กำลังนำจ่าย'
           WHEN 3 THEN N'จัดส่งพัสดุถึงผู้รับเรียบร้อย'
           ELSE N'นำจ่ายไม่สำเร็จ รอติดต่อผู้รับ'
       END
FROM ParcelEvents AS e
CROSS APPLY (SELECT CASE
    WHEN e.StatusID = 2 THEN CASE WHEN e.ParcelNumber % 2 = 0 THEN 'EMP005' ELSE 'EMP002' END
    ELSE CASE WHEN e.ParcelNumber % 2 = 0 THEN 'EMP006' ELSE 'EMP003' END
END AS EmployeeID) AS chosen
JOIN dbo.Employee AS emp ON emp.EmployeeID = chosen.EmployeeID
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.TrackingHistory AS h
    WHERE h.ParcelID = e.ParcelID AND h.StatusID = e.StatusID AND h.UpdateDate = e.UpdateDate
);
GO

/* Spread all sample receipt times across October during branch business hours.
   Tracking milestones are then placed on later days with varied daytime times. */
;WITH SampleParcels AS (
    SELECT p.ParcelID,
           CONVERT(INT, RIGHT(p.ParcelID, 4)) AS ParcelNumber,
           DATEADD(MINUTE, (CONVERT(INT, RIGHT(p.ParcelID, 4)) * 137) % 600,
               DATEADD(DAY, (CONVERT(INT, RIGHT(p.ParcelID, 4)) * 11) % 30,
                   CAST('2026-10-01T08:00:00' AS DATETIME2(0)))) AS SampleReceivedAt
    FROM dbo.Parcel AS p
    WHERE p.ParcelID LIKE 'PCL[0-9][0-9][0-9][0-9]'
      AND CONVERT(INT, RIGHT(p.ParcelID, 4)) BETWEEN 1 AND 100
)
UPDATE p
   SET ReceivedAt = s.SampleReceivedAt
FROM dbo.Parcel AS p
JOIN SampleParcels AS s ON s.ParcelID = p.ParcelID;

UPDATE pay
   SET PaymentDate = DATEADD(MINUTE, 5, p.ReceivedAt)
FROM dbo.Payment AS pay
JOIN dbo.Parcel AS p ON p.ParcelID = pay.ParcelID
WHERE p.ParcelID LIKE 'PCL[0-9][0-9][0-9][0-9]'
  AND CONVERT(INT, RIGHT(p.ParcelID, 4)) BETWEEN 1 AND 100;

UPDATE h
   SET UpdateDate = CASE h.StatusID
       WHEN 1 THEN p.ReceivedAt
       WHEN 2 THEN DATEADD(MINUTE, 600 + ((n.ParcelNumber * 47) % 240),
                    DATEADD(DAY, 1, CONVERT(DATETIME2(0), CONVERT(DATE, p.ReceivedAt))))
       ELSE DATEADD(MINUTE, 480 + ((n.ParcelNumber * 137) % 600),
                    DATEADD(DAY, 2 + (n.ParcelNumber % 3), CONVERT(DATETIME2(0), CONVERT(DATE, p.ReceivedAt))))
   END
FROM dbo.TrackingHistory AS h
JOIN dbo.Parcel AS p ON p.ParcelID = h.ParcelID
CROSS APPLY (SELECT CONVERT(INT, RIGHT(p.ParcelID, 4)) AS ParcelNumber) AS n
WHERE p.ParcelID LIKE 'PCL[0-9][0-9][0-9][0-9]'
  AND n.ParcelNumber BETWEEN 1 AND 100;

;WITH DuplicateSampleEvents AS (
    SELECT h.HistoryID,
           ROW_NUMBER() OVER (
               PARTITION BY h.ParcelID, h.StatusID, h.UpdateDate
               ORDER BY h.HistoryID
           ) AS RowNum
    FROM dbo.TrackingHistory AS h
    CROSS APPLY (SELECT TRY_CONVERT(INT, RIGHT(h.ParcelID, 4)) AS ParcelNumber) AS n
    WHERE h.ParcelID LIKE 'PCL[0-9][0-9][0-9][0-9]'
      AND n.ParcelNumber BETWEEN 1 AND 100
)
DELETE FROM DuplicateSampleEvents WHERE RowNum > 1;
GO

PRINT N'Sample-data script finished. Check Messages for errors, then run 07_TestQuery.sql to review the data.';
GO
