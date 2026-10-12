/*
  Project: Parcel Delivery Database
  Platform: Microsoft SQL Server (SSMS)
  Purpose: Demonstrate basic joins, tracking history, summary, and payment checks.
*/

USE ParcelDeliveryDB;
GO

-- 1. Customer directory and total customer count.
SELECT CustomerID,
       CustomerName,
       Phone,
       Address,
       Email,
       COUNT(*) OVER () AS TotalCustomers
FROM dbo.Customer
ORDER BY CustomerID;
GO

-- 2. Shipment counts by customer role; retains every customer, even if a future dataset has no activity.
SELECT c.CustomerID,
       c.CustomerName,
       COUNT(DISTINCT CASE WHEN p.SenderID = c.CustomerID THEN p.ParcelID END) AS SentParcelCount,
       COUNT(DISTINCT CASE WHEN p.ReceiverID = c.CustomerID THEN p.ParcelID END) AS ReceivedParcelCount
FROM dbo.Customer AS c
LEFT JOIN dbo.Parcel AS p
  ON p.SenderID = c.CustomerID OR p.ReceiverID = c.CustomerID
GROUP BY c.CustomerID, c.CustomerName
ORDER BY c.CustomerID;
GO

-- 2b. Customer activity coverage; every stored customer should have sent or received a parcel.
WITH SentCustomers AS (
    SELECT SenderID AS CustomerID FROM dbo.Parcel GROUP BY SenderID
),
ReceivedCustomers AS (
    SELECT ReceiverID AS CustomerID FROM dbo.Parcel GROUP BY ReceiverID
)
SELECT COUNT(*) AS TotalCustomers,
       SUM(CASE WHEN s.CustomerID IS NULL THEN 0 ELSE 1 END) AS CustomersWhoSent,
       SUM(CASE WHEN r.CustomerID IS NULL THEN 0 ELSE 1 END) AS CustomersWhoReceived,
       SUM(CASE WHEN s.CustomerID IS NULL AND r.CustomerID IS NULL THEN 1 ELSE 0 END) AS CustomersWithNoShipments
FROM dbo.Customer AS c
LEFT JOIN SentCustomers AS s ON s.CustomerID = c.CustomerID
LEFT JOIN ReceivedCustomers AS r ON r.CustomerID = c.CustomerID;
GO

-- 3. Parcel list with sender, receiver, type, current status, and fee.
SELECT p.TrackingNumber,
       s.CustomerName AS SenderName,
       r.CustomerName AS ReceiverName,
       t.TypeName AS ParcelType,
       ps.StatusName AS CurrentStatus,
       p.WeightKg,
       p.ShippingFee,
       p.ReceivedAt
FROM dbo.Parcel AS p
JOIN dbo.Customer AS s ON s.CustomerID = p.SenderID
JOIN dbo.Customer AS r ON r.CustomerID = p.ReceiverID
JOIN dbo.ParcelType AS t ON t.ParcelTypeID = p.ParcelTypeID
JOIN dbo.ParcelStatus AS ps ON ps.StatusID = p.CurrentStatusID
ORDER BY p.ReceivedAt, p.TrackingNumber;
GO

-- 4. Tracking timeline for all parcels. Set @TrackingNumber to a value to filter one parcel.
DECLARE @TrackingNumber VARCHAR(20) = NULL;
SELECT p.TrackingNumber,
       h.UpdateDate,
       ps.StatusName,
       e.EmployeeName AS UpdatedBy,
       b.BranchName AS EventBranch,
       h.Note
FROM dbo.Parcel AS p
JOIN dbo.TrackingHistory AS h ON h.ParcelID = p.ParcelID
JOIN dbo.ParcelStatus AS ps ON ps.StatusID = h.StatusID
JOIN dbo.Employee AS e ON e.EmployeeID = h.EmployeeID
JOIN dbo.Branch AS b ON b.BranchID = h.BranchID
WHERE @TrackingNumber IS NULL OR p.TrackingNumber = @TrackingNumber
ORDER BY h.UpdateDate, h.HistoryID;
GO

-- 5. Parcel count and total shipping fees grouped by current status.
SELECT ps.StatusName,
       COUNT(*) AS ParcelCount,
       SUM(p.ShippingFee) AS TotalShippingFee
FROM dbo.Parcel AS p
JOIN dbo.ParcelStatus AS ps ON ps.StatusID = p.CurrentStatusID
GROUP BY ps.StatusName
ORDER BY ps.StatusName;
GO

-- 6. Payment summary; this model records only completed payments at parcel acceptance.
SELECT p.TrackingNumber,
       pay.Amount,
       pay.PaymentMethod,
       pay.PaymentStatus,
       pay.PaymentDate
FROM dbo.Payment AS pay
JOIN dbo.Parcel AS p ON p.ParcelID = pay.ParcelID
WHERE pay.PaymentStatus = 'Paid'
ORDER BY p.TrackingNumber;
GO

-- 6b. Confirm every parcel has one paid payment record.
SELECT COUNT(*) AS ParcelCount,
       COUNT(pay.PaymentID) AS PaidParcelCount,
       SUM(CASE WHEN pay.PaymentID IS NULL OR pay.PaymentStatus <> 'Paid' THEN 1 ELSE 0 END) AS ParcelsWithoutPaidRecord
FROM dbo.Parcel AS p
LEFT JOIN dbo.Payment AS pay ON pay.ParcelID = p.ParcelID;
GO

-- 7. Compare current status with the latest tracking event for consistency.
WITH LatestHistory AS (
    SELECT h.ParcelID, h.StatusID,
           ROW_NUMBER() OVER (PARTITION BY h.ParcelID ORDER BY h.UpdateDate DESC, h.HistoryID DESC) AS RowNum
    FROM dbo.TrackingHistory AS h
)
SELECT p.TrackingNumber,
       currentStatus.StatusName AS CurrentStatus,
       latestStatus.StatusName AS LatestHistoryStatus,
       CASE WHEN p.CurrentStatusID = lh.StatusID THEN N'ตรงกัน' ELSE N'ไม่ตรงกัน' END AS Consistency
FROM dbo.Parcel AS p
JOIN dbo.ParcelStatus AS currentStatus ON currentStatus.StatusID = p.CurrentStatusID
LEFT JOIN LatestHistory AS lh ON lh.ParcelID = p.ParcelID AND lh.RowNum = 1
LEFT JOIN dbo.ParcelStatus AS latestStatus ON latestStatus.StatusID = lh.StatusID
ORDER BY p.TrackingNumber;
GO

-- 8. Employee roster: role, branch, parcels accepted, and tracking events recorded.
SELECT e.EmployeeID,
       e.EmployeeName,
       e.Position,
       b.BranchName,
       COUNT(DISTINCT p.ParcelID) AS ParcelsAccepted,
       COUNT(DISTINCT h.HistoryID) AS TrackingEventsRecorded
FROM dbo.Employee AS e
JOIN dbo.Branch AS b ON b.BranchID = e.BranchID
LEFT JOIN dbo.Parcel AS p ON p.ReceivedByEmployeeID = e.EmployeeID
LEFT JOIN dbo.TrackingHistory AS h ON h.EmployeeID = e.EmployeeID
GROUP BY e.EmployeeID, e.EmployeeName, e.Position, b.BranchName
ORDER BY e.Position, e.EmployeeID;
GO
