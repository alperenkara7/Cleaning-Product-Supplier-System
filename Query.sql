--CREATE INDEX
CREATE INDEX product_index
ON Product (ProductID);

-- ADD UNIQUE CONSTRAIN
ALTER TABLE Employee
ADD UNIQUE (EmployeeID);

ALTER TABLE Product
ADD UNIQUE (ProductID);

-- UPDATE AGE COLUMN
UPDATE Employee SET Age=DATEDIFF(YY, Birthdate, GETDATE());
SELECT * FROM Employee;

-- ADD IDENTITY WITH STORED PROCEDURE
CREATE TABLE Product2
(
	ProductID int NOT NULL UNIQUE
	IDENTITY(100, 1),
	ProductName varchar(50) NOT NULL,
	ProductCategory varchar(50) NULL,
	Price decimal(18,2)
)
ON  [PRIMARY]
go
SET IDENTITY_INSERT Product2 ON
go
IF EXISTS ( SELECT  *
            FROM    Product ) 
    INSERT  INTO Product2 ( ProductID, ProductName, ProductCategory, Price)
            SELECT  ProductID,
                    ProductName,
					ProductCategory,
					Price
            FROM    Product TABLOCKX
go
SET IDENTITY_INSERT Product2 OFF
go
DROP TABLE Product
go
 

-- ADD CHECK CONSTRAIN
ALTER TABLE Employee
ADD CHECK (Age>=18);

-- ADD DEFAULT CONSTRAIN
ALTER TABLE DrivingLicence
ADD CONSTRAINT df_Class
DEFAULT 'B' FOR Class;

ALTER TABLE Orders
ADD CONSTRAINT df_TotalPrice
DEFAULT 0 FOR TotalPrice;

ALTER TABLE Product2
ADD TaxRate tinyint;

ALTER TABLE Product2
ADD CONSTRAINT df_TaxRate2
DEFAULT 18 FOR TaxRate;

--ADD COMPUTED COLUMNS
alter table Product2
drop column TaxedPrice
ALTER TABLE Product2
ADD TaxedPrice AS CAST((Price*(TaxRate*1.0/100+1.0)) as decimal(18,2))

--VIEW 1
CREATE VIEW [Ambalaj Products That Have Ordered Less Than 3]
AS
SELECT p.ProductID, OrderProductCount.Total
FROM     dbo.Product AS p INNER JOIN
                      (SELECT p1.ProductID, COUNT(*) AS Total
                       FROM      dbo.Product AS p1 INNER JOIN
                                         dbo.Orders AS o ON p1.ProductID = o.ProductID
                       GROUP BY p1.ProductID) AS OrderProductCount ON p.ProductID = OrderProductCount.ProductID
WHERE  (p.ProductCategory LIKE '%Ambalaj') AND (OrderProductCount.Total < 3)

--VIEW 2
CREATE VIEW [Customers Need To Pay Because They Didn't do Payment Of 2 Orders Past]
AS
SELECT numoforder.CustomerID
FROM     (SELECT CustomerID, COUNT(*) AS num
                  FROM      (SELECT CustomerID, OrderID
                                     FROM      dbo.Orders AS o
                                     GROUP BY CustomerID, OrderID) AS custworder
                  GROUP BY CustomerID) AS numoforder INNER JOIN
                      (SELECT CustomerID, COUNT(*) AS num
                       FROM      dbo.Collection AS c
                       GROUP BY CustomerID) AS numofcol ON numoforder.CustomerID = numofcol.CustomerID
WHERE  (numoforder.num - numofcol.num > 2)

--VIEW 3
CREATE VIEW [Customers That Have Order But No Payment]
AS
SELECT DISTINCT CustomerID
FROM     (SELECT DISTINCT CustomerID
                  FROM      dbo.Orders AS o
                  WHERE   (CustomerID LIKE '1%')) AS customerwithorder
WHERE  (CustomerID NOT IN (SELECT CustomerID FROM dbo.Collection))

--VIEW 4
CREATE VIEW [Drivers That Older Than 35 and Having Less Than 3 Licence]
AS
SELECT d.DriverID
FROM dbo.Driver AS d INNER JOIN
                  dbo.Employee AS e ON d.DriverID = e.EmployeeID INNER JOIN
                      (SELECT DriverID, COUNT(*) AS TotalLicence
                       FROM      dbo.DrivingLicence AS dl
                       GROUP BY DriverID) AS LicenceCount ON d.DriverID = LicenceCount.DriverID
WHERE  (e.Age > 35) AND (LicenceCount.TotalLicence < 3)

--VIEW 5
CREATE VIEW [Managers That Their Car Model Less Then 2018]
AS
SELECT m.ManagerID, v.VehicleID, v.Year
FROM     dbo.Manager AS m INNER JOIN
                  dbo.Vehicle AS v ON m.VehicleID = v.VehicleID
WHERE  (v.Year < 2018)



--STORED PROCEDURES--
--SP1 -ADD EMPLOYEE
CREATE PROCEDURE sp_AddEmployee (
@Dno int,
@FirstName nvarchar(50),
@LastName nvarchar(50),
@BirthDate date,
@Gender char(1),
@Adress nvarchar(50),
@Salary decimal(18,2))

as
	begin
		insert into Employee (
		EmployeeID,
		Dno,
		FirstName,
		LastName,
		BirthDate,
		Gender,
		Age,
		Adress,
		Salary)

		values (
		(select (max(EmployeeID)+1)from Employee),
		@Dno,
		@FirstName,
		@LastName,
		@BirthDate,
		@Gender,
		DATEDIFF(YY, @Birthdate, GETDATE()),
		@Adress,
		@Salary)
	end


--SP2 -ADD ITEM TO BASKET
create procedure sp_AddItemToBasket @ProductID int, @ProductName varchar(50), @Price decimal(18,2)
as
	begin
		insert into Basket ("ProductID","ProductName","Price")
		values (@ProductID,@ProductName,@Price)

	end
--SP3 -ADD NEW CUSTOMER
create procedure sp_AddnewCustomer (@CustomerName varchar(50),
						@Adress varchar(50),
						@Phonenumber varchar(15))
as 
	begin 
		insert into Customer(CustomerID,
							CustomerName,
							Adress,
							Balance,
							PhoneNumber)

		values ((select (MAX(CustomerID)+1)
				from Customer),
				@customerName,
				@Adress,
				0,
				@Phonenumber)

	end

--SP4 -ADD NEW PRODUCT
create procedure sp_AddNewProduct (
@ProductName varchar(15),
@ProductCategory varchar(15),
@Price decimal(18,2))

as 
	begin 
		insert into Product 
					(ProductID,
					ProductName,
					ProductCategory,
					Price)

		values ((select (max(productID)+1)
				from Product),
				@ProductName,
				@ProductCategory,
				@Price)

	end



--SP5 -ADD ORDER
create procedure sp_AddOrder(
@OrderID	int,
@CustomerID int,
@ProductID int,
@DepotID tinyint)

as 
	begin 
		insert into Orders
					(OrderID,
					CustomerID,
					ProductID,
					DeliverID,
					orders.Date,
					DepotID)
		



		values (@OrderID,
				@CustomerID,
				@ProductID,
				(select (max(deliverID)+1)
				from deliver),
				GETDATE(),
				@DepotID)
	exec sp_UpdateTotalPrice @OrderID=@OrderID	
	end
	begin 
		update Customer
		set Balance=Balance+pprice.TaxedPrice
		from (select p.productID, p.TaxedPrice
		from Product p 
		where p.productID=@ProductID) pprice
		where CustomerID=@CustomerID
	end


--SP6 ADDPAYMENT
create procedure sp_addpayment (@supplierID int, @amount decimal(18,2))
as
	if @supplierID in (select SupplierID
					   from Payment)
	begin 
		declare @paymentID int
		select @paymentID = (MAX(PaymentID)+1) 
								from Payment
								where SupplierID=@supplierID
	
		insert into Payment(SupplierID,PaymentDate,Amount,PaymentID)
		values(@supplierID,getdate(),@Amount,@paymentID)
	
		update Supplier
		set Balance=balance-@Amount
		where SupplierID=@supplierID
	end
	else 
		begin
			declare @paymentIDvchar varchar(10)
			select @paymentIDvchar= (cast(@supplierID as varchar(5)) + CAST(1 as varchar(1)))

			insert into Payment(SupplierID,PaymentDate,Amount,PaymentID)
			values(@supplierID,getdate(),@Amount,@paymentIDvchar)
		
			update Supplier
			set Balance=balance-@Amount
			where SupplierID=@supplierID

		end

--SP7 -ADD SUPPLIER
create procedure sp_AddSupplier  (@SupplierID int,
							   @SupplierName nvarchar(50),
							   @PhoneNumber varchar(15),
							   @Adress nvarchar(50))
as
	Begin
			insert into Supplier(SupplierID,
						SupplierName,
						PhoneNumber,
						Adress,
						Balance)

			values(@SupplierID,
					@SupplierName,
					@PhoneNumber,
					@Adress,
					0)
	End		

--SP8 -ALL CUSTOMER VIEW
create procedure sp_AllCustomerView 
as 
	begin
		select *
		from Customer
	end

--SP9 -ALL ORDER VIEW
create procedure sp_AllOrderView
as
	begin
		select * 
		from Orders
	end

--SP10 NUMBER OF CUSTOMER ORDERS
create procedure sp_CountOrderNumber @CustomerID int

as
	begin
		select count(distinct(orderID)) from Orders where CustomerID=@CustomerID

	end

--SP11 DELETE ITEMS IN THE BASKET
create procedure sp_DeleteBasketItems
as
	begin
		delete Basket
	end


--SP12 -DELETE CUSTOMER
create procedure sp_DeleteCustomer (@CustomerID int)

as
	begin
		delete
		from Customer
		where CustomerID=@CustomerID

	end

--SP13-DELETE ORDER
create procedure sp_DeleteOrder (@OrderID int)
as
	Begin
		update Customer
		set Balance=c.Balance-price.TotalPrice
		from (select OrderID, CustomerID, TotalPrice
			  from Orders) price inner join Customer c on price.CustomerID=c.CustomerID
	End
	Begin
		Delete 
			from Orders
			where OrderID=@OrderID
	End

--SP14 DELETE PRODUCT BY PRODUCT ID
create procedure sp_DeleteProduct @ProductID int 
as
	begin
		delete Product
		where ProductID=@ProductID
	end


--SP15-DELETE SUPLIER
create procedure sp_DeleteSupplier (@SupplierID int)
as
	Begin
		DELETE
		FROM Supplier
		WHERE SupplierID=@SupplierID
	END

--SP16 MAKE COLLECTION FROM SUPPLIER
create procedure sp_MakeCollection (@CustomerID int,@Amount decimal(18,2))
as
	
	if @CustomerID in (select CustomerID
					   from Collection)
	begin 
		declare @collectionID int
		select @collectionID = (MAX(collectionID)+1) 
								from collection
								where CustomerID=@CustomerID
	
		insert into Collection(CustomerID,PaymentDate,Amount,CollectionID)
		values(@CustomerID,getdate(),@Amount,@collectionID)
	
		update Customer
		set Balance=balance-@Amount
		where CustomerID=@CustomerID
	end
	else 
		begin
		declare @collectionIDvarchar varchar(10)
			select @collectionIDvarchar = (cast(@customerID as varchar(5)) + CAST(1 as varchar(1)))
			insert into Collection (CustomerID,PaymentDate,Amount,CollectionID)
			values(@CustomerID,GETDATE(),@Amount,@collectionIDvarchar)

			update Customer
			set Balance=balance-@Amount
			where CustomerID=@CustomerID
	
		end

--SP17 SEARCH EVERY ORDER OF A CUSTOMER BY CUSTOMER ID
create procedure sp_SearchOrderByCustomerID @CustomerID int
as
	begin
		select * 
		from Orders
		where CustomerID=@customerID

	end



--SP18 -SELECT ORDER
create procedure sp_SelectOrder (@OrderID int)

  as 
	Begin 
			select o.OrderID, o.CustomerID, o.ProductID, o.Date, o.DepotID
			from orders o
			where OrderID=@OrderID
			group by OrderID, o.CustomerID, o.ProductID, o.Date, o.DepotID
			
	End

--SP19 -FILL ADDRESS COLUMNS OF DELIVER TABLE 
create procedure sp_UpdateAddress  @orderID intAsBegin	update Deliver
	set VehicleID=vhcl.VehicleID
	from(select dpt.DepotID,dpt.VehicleID,o.DeliverID,o.OrderID
	from Orders o inner join Depot dpt on o.DepotID=dpt.DepotID
	group by dpt.DepotID,dpt.VehicleID,o.DeliverID,o.OrderID) vhcl
	where Deliver.DeliverID=vhcl.DeliverID and @orderID=vhcl.OrderID  update Deliver
	set AdressFrom=adrs.Adress
	from (select distinct(dpt.Adress), o.OrderID
	from Orders o inner join Depot dpt on o.DepotID=dpt.DepotID
	where o.OrderID=@orderID) adrs
	where Deliver.OrderID=adrs.OrderID  Update d  Set d.AdressTo=c.Adress  From  Deliver d inner join Orders ord on d.OrderID=ord.OrderID	inner join Customer c on ord.CustomerID=c.CustomerID  Where ord.CustomerID like '1%' and @orderID=d.OrderID  Update d  Set d.AdressTo=s.Adress  From  Deliver d inner join Orders ord on d.OrderID=ord.OrderID	inner join Supplier s on ord.CustomerID=s.SupplierID  Where ord.CustomerID like '5%' and @orderID=d.OrderIDEnd


--SP20 -UPDATE CUSTOMER INFO
create procedure sp_UpdateCustomer (@CustomerID int,
								   @CustomerName nvarchar(50),
								   @Adress nvarchar(50),
								   @PhoneNumber varchar(15))
as 
	begin 
		update customer
		set CustomerName=@CustomerName, Adress=@Adress, PhoneNumber=@PhoneNumber
		where CustomerID=@CustomerID

	end

--SP21 -UPDATE PRODUCT INFO
create procedure sp_UpdateProduct
@ProductID int,
@ProductName varchar(50),
@ProductCategory varchar(50),
@Price decimal(18,2)
as
	begin
		update Product
		set ProductName=@ProductName, ProductCategory=@ProductCategory,Price=@Price
		where ProductID=@ProductID
	end


--SP22 -UPDATE SUPPLIER INFO
create procedure sp_UpdateSupplier (@SupplierID int,
								    @SupplierName nvarchar(50),
									@Adress nvarchar(50),
									@PhoneNumber varchar(15))

as
	begin
		update Supplier
		set SupplierName=@SupplierName, Adress=@Adress, PhoneNumber=@PhoneNumber
		where SupplierID=@SupplierID
	end


--SP23 UPDATE TOTAL PRICE
create PROCEDURE sp_UpdateTotalPrice (
@OrderID int)
AS 
BEGIN
	UPDATE ORDERS
	SET TotalPrice=calculations.TotalPrice
		FROM Orders o inner join (SELECT o.OrderID, sum(p.TaxedPrice) as TotalPrice FROM Orders o INNER JOIN Product p ON o.ProductID=p.ProductID
		Group by o.OrderID) as calculations on o.OrderID=calculations.OrderID
		where o.OrderID=@OrderID;
END



--TRIGGER-- CREATES A DELIVERY WHEN A NEW ORDER IS ADDED
create trigger trg_updatedelivery 
on Orders 
after insert
as
	if (select i.OrderID from inserted i) not in (select d.OrderID from Deliver d)
	begin
		declare @orderid int
		set @orderid = (select i.OrderID from inserted i)


		insert into Deliver(DeliverID,OrderID)
		values((select MAX(deliverID)+1 from Deliver),
		(select i.orderID from inserted i))

		exec sp_UpdateAddress @orderid
	end
		 
		









