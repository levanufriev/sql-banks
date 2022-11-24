CREATE DATABASE bank;
GO

USE bank;
GO

CREATE TABLE banks
(
	Id INT IDENTITY PRIMARY KEY,
	Name NVARCHAR(30)
);

CREATE TABLE cities
(
	Id INT IDENTITY PRIMARY KEY,
	Name NVARCHAR(30)
);	

CREATE TABLE banks_cities
(
	BankId INT,
	CityId INT,
	FOREIGN KEY (BankId) REFERENCES banks(Id),
	FOREIGN KEY (CityId) REFERENCES cities(Id),
	UNIQUE (BankId, CityId)
);

CREATE TABLE statuses
(
	Id INT IDENTITY PRIMARY KEY,
	Name NVARCHAR(30)
);

CREATE TABLE clients
(
	Id INT IDENTITY PRIMARY KEY,
	StatusId INT,
	Name NVARCHAR(30),
	FOREIGN KEY (StatusId) REFERENCES statuses(Id)
);

CREATE TABLE accounts
(
	Id INT IDENTITY PRIMARY KEY,
	BankId INT,
	ClientId INT,
	Balance INT,
	FOREIGN KEY (BankId) REFERENCES banks(Id),
	FOREIGN KEY (ClientId) REFERENCES clients(Id),
	UNIQUE (BankId, ClientId)
);

CREATE TABLE cards
(
	Id INT IDENTITY PRIMARY KEY,
	AccountId INT,
	Balance INT,
	FOREIGN KEY (AccountId) REFERENCES accounts(Id),
);

GO

INSERT INTO statuses
VALUES
('Pensioner'),
('Disabled'),
('Veteran'),
('Chernobyl victim'),
('None');

INSERT INTO banks
VALUES
('Belarusbank'),
('Priorbank'),
('Belinvestbank'),
('MTBank'),
('Alphabank');

INSERT INTO cities
VALUES
('Minsk'),
('Vitebsk'),
('Grondo'),
('Gomel'),
('Brest'),
('Mogilev');

INSERT INTO banks_cities
VALUES
(1,1),
(1,2),
(1,3),
(2,4),
(2,5),
(2,6),
(3,3),
(3,4),
(4,1),
(5,1),
(5,2),
(5,5),
(5,6);

INSERT INTO clients
VALUES
(1,'John'),
(2,'Will'),
(5,'Jack'),
(4,'Harry'),
(5,'Bob'),
(3,'Ryan'),
(3,'Tom');

INSERT INTO accounts
VALUES
(1,1,50),
(1,2,20),
(1,3,15),
(2,4,0),
(2,5,35),
(3,2,50),
(3,4,10),
(4,1,50),
(4,3,60),
(4,5,60),
(5,5,0);

INSERT INTO cards
VALUES
(1, 20),
(1, 30),
(2, 15),
(3, 15),
(5, 35),
(6, 25),
(6, 15),
(8, 10),
(8, 10),
(8, 30),
(9, 50),
(10, 60);

GO

--TASK 2
SELECT banks.Name 
FROM banks
JOIN banks_cities ON banks.Id=BankId
JOIN cities ON CityId=cities.Id
WHERE cities.Name='Minsk';

--TASK 3
SELECT clients.Name, cards.Balance, banks.Name
FROM cards
JOIN accounts ON cards.AccountId=accounts.Id
JOIN banks ON accounts.BankId=banks.Id
JOIN clients ON accounts.ClientId=clients.Id;

--TASK 4
SELECT accounts.Id,
MAX(accounts.Balance)-(CASE COUNT(cards.Id)
		       WHEN 0 THEN 0
		       ELSE SUM(cards.Balance)
		       END) AS Diff
FROM accounts
LEFT JOIN cards ON accounts.Id=AccountId
GROUP BY accounts.Id
HAVING MAX(accounts.Balance)-(CASE COUNT(cards.Id)
			      WHEN 0 THEN 0
			      ELSE SUM(cards.Balance)
			      END) > 0;

--TASK 5
SELECT statuses.Name, COUNT(cards.Id) AS amount
FROM statuses
JOIN clients ON statuses.Id=StatusId
LEFT JOIN accounts ON clients.Id=ClientId
LEFT JOIN cards ON accounts.Id=AccountId
GROUP BY statuses.Name
ORDER BY statuses.Name;

SELECT statuses.Name, 
(SELECT COUNT(cards.Id)
FROM cards
JOIN accounts ON accounts.Id=AccountId
JOIN clients ON clients.Id=ClientId
WHERE statuses.Id=StatusId) AS amount
FROM statuses
ORDER BY statuses.Name;

GO

--TASK 6
CREATE PROCEDURE AddTenDollars
	@Id INT
AS
BEGIN
	BEGIN TRY
		IF @Id NOT IN (SELECT Id FROM statuses)
		THROW 50100, 'Status does not exist.', 1
		IF @Id NOT IN (SELECT statuses.Id AS StatusId
			       FROM accounts
			       JOIN clients ON clients.Id=ClientId
			       JOIN statuses ON statuses.Id=StatusId
			       GROUP BY statuses.Id)
		THROW 50200, 'Accounts for this status do not exist.', 1
		UPDATE accounts
		SET Balance=Balance+10
		WHERE accounts.Id IN (SELECT accounts.Id
				      FROM accounts
				      JOIN clients ON clients.Id=ClientId
				      JOIN statuses ON statuses.Id=StatusId
				      WHERE statuses.Id=@Id);
	END TRY
	BEGIN CATCH
		PRINT(ERROR_MESSAGE())
	END CATCH
END
GO

EXEC AddTenDollars 10;
EXEC AddTenDollars 3;

SELECT accounts.*, statuses.*
FROM accounts
JOIN clients ON clients.Id=ClientId
JOIN statuses ON statuses.Id=StatusId
WHERE statuses.Id=2;

EXEC AddTenDollars 2;

SELECT accounts.*, statuses.*
FROM accounts
JOIN clients ON clients.Id=ClientId
JOIN statuses ON statuses.Id=StatusId
WHERE statuses.Id=2;

--TASK 7 
SELECT clients.Id as ClientId, accounts.Id as AccountId,
MAX(accounts.Balance)-(CASE COUNT(cards.Id)
		       WHEN 0 THEN 0
		       ELSE SUM(cards.Balance)
		       END) AS Available
FROM clients
JOIN accounts ON clients.Id=ClientId
LEFT JOIN cards ON accounts.Id=AccountId
GROUP BY clients.Id, accounts.Id
ORDER BY clients.Id, accounts.Id

GO

--TASK 8
CREATE PROCEDURE TransferMoney
	@AccountId INT,
	@CardId INT,
	@Amount INT
AS
BEGIN
	BEGIN TRY
		IF (SELECT MAX(accounts.Balance)-(CASE COUNT(cards.Id)
						  WHEN 0 THEN 0
						  ELSE SUM(cards.Balance)
						  END)
		    FROM accounts
		    LEFT JOIN cards ON accounts.Id=AccountId
		    WHERE accounts.Id=@AccountId
		    GROUP BY accounts.Id) < @Amount
		THROW 50300, 'There are no money to transfer.', 1
		IF @CardId NOT IN (SELECT cards.Id
				   FROM accounts
				   JOIN cards ON accounts.Id=AccountId
				   WHERE accounts.Id=@AccountId)
		THROW 50400, 'The card is not linked to the account.', 1
		BEGIN TRANSACTION
			UPDATE cards
			SET Balance=Balance+@Amount
			WHERE cards.Id=@CardId
		COMMIT
	END TRY
	BEGIN CATCH
		PRINT(ERROR_MESSAGE())
	END CATCH
END
GO

EXEC TransferMoney 2,3,20;
EXEC TransferMoney 2,4,10;

SELECT *
FROM accounts
JOIN cards ON accounts.Id=AccountId
WHERE accounts.Id=2

EXEC TransferMoney 2,3,10;

SELECT *
FROM accounts
JOIN cards ON accounts.Id=AccountId
WHERE accounts.Id=2

GO

--TASK 9
CREATE TRIGGER accounts_update
ON accounts
INSTEAD OF UPDATE
AS
IF UPDATE(Balance) 
   AND 
   (SELECT Balance FROM inserted) <
   (SELECT CASE COUNT(cards.Id)
	   WHEN 0 THEN 0
	   ELSE SUM(cards.Balance)
	   END
    FROM inserted 
    LEFT JOIN cards ON AccountId=inserted.Id
    GROUP BY inserted.Id)
SELECT NULL
ELSE
UPDATE accounts
SET Balance=inserted.Balance
FROM accounts
JOIN inserted ON inserted.Id=accounts.Id
GO

SELECT *
FROM accounts
JOIN cards ON AccountId=accounts.Id
WHERE accounts.Id=1;

UPDATE accounts
SET Balance=20
WHERE Id=1;

UPDATE accounts
SET Balance=100
WHERE Id=1;

SELECT *
FROM accounts
JOIN cards ON AccountId=accounts.Id
WHERE accounts.Id=1;

GO

CREATE TRIGGER cards_update
ON cards
INSTEAD OF UPDATE
AS
IF UPDATE(Balance) 
   AND 
   (SELECT SUM(cards.Balance)+MAX(inserted.Balance)-(SELECT cards.Balance FROM cards JOIN inserted ON inserted.Id=cards.Id)
    FROM cards
    JOIN inserted ON inserted.AccountId=cards.AccountId) >
   (SELECT accounts.Balance
    FROM accounts
    JOIN inserted ON inserted.AccountId=accounts.Id)
SELECT NULL
ELSE
UPDATE cards
SET Balance=inserted.Balance
FROM cards
JOIN inserted ON inserted.Id=cards.Id
GO

SELECT *
FROM accounts
JOIN cards ON AccountId=accounts.Id
WHERE accounts.Id=1;

UPDATE cards
SET Balance=100
WHERE Id=2;

UPDATE cards
SET Balance=10
WHERE Id=2;

SELECT *
FROM accounts
JOIN cards ON AccountId=accounts.Id
WHERE accounts.Id=1;

