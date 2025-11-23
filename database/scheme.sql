
SET NOCOUNT ON;
CREATE DATABASE LibraryDB; 
USE LibraryDB;


-- 1. Roles
IF OBJECT_ID('dbo.Roles') IS NULL
CREATE TABLE dbo.Roles (
    RoleId     INT IDENTITY(1,1) PRIMARY KEY,
    RoleName   NVARCHAR(100) NOT NULL UNIQUE,
    Description NVARCHAR(500) NULL
);
GO

-- 2. Permissions
IF OBJECT_ID('dbo.Permissions') IS NULL
CREATE TABLE dbo.Permissions (
    PermissionId INT IDENTITY(1,1) PRIMARY KEY,
    Name         NVARCHAR(150) NOT NULL UNIQUE,
    Description  NVARCHAR(500) NULL
);
GO

-- 3. Users
IF OBJECT_ID('dbo.Users') IS NULL
CREATE TABLE dbo.Users (
    UserId       INT IDENTITY(1,1) PRIMARY KEY,
    Login        NVARCHAR(100) NOT NULL UNIQUE,
    PasswordHash VARBINARY(MAX) NOT NULL,
    FullName     NVARCHAR(200) NOT NULL,
    Email        NVARCHAR(150) NULL,
    Phone        NVARCHAR(30) NULL,
    RoleId       INT NOT NULL,
    IsActive     BIT NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT (1),
    CreatedAt    DATETIME2 NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSUTCDATETIME()),
    LastLogin    DATETIME2 NULL,
    RowVersion   ROWVERSION
);
GO
ALTER TABLE dbo.Users WITH CHECK ADD CONSTRAINT FK_Users_Roles FOREIGN KEY (RoleId) REFERENCES dbo.Roles(RoleId);
GO

-- 4. RolePermissions
IF OBJECT_ID('dbo.RolePermissions') IS NULL
CREATE TABLE dbo.RolePermissions (
    RolePermissionId INT IDENTITY(1,1) PRIMARY KEY,
    RoleId           INT NOT NULL,
    PermissionId     INT NOT NULL,
    CONSTRAINT UQ_RolePerm UNIQUE (RoleId, PermissionId)
);
GO
ALTER TABLE dbo.RolePermissions WITH CHECK ADD CONSTRAINT FK_RolePermissions_Roles FOREIGN KEY (RoleId) REFERENCES dbo.Roles(RoleId);
ALTER TABLE dbo.RolePermissions WITH CHECK ADD CONSTRAINT FK_RolePermissions_Permissions FOREIGN KEY (PermissionId) REFERENCES dbo.Permissions(PermissionId);
GO

-- 5. Authors
IF OBJECT_ID('dbo.Authors') IS NULL
CREATE TABLE dbo.Authors (
    AuthorId   INT IDENTITY(1,1) PRIMARY KEY,
    FirstName  NVARCHAR(100) NULL,
    LastName   NVARCHAR(150) NOT NULL,
    BirthDate  DATE NULL,
    Bio        NVARCHAR(MAX) NULL
);
GO

-- 6. Publishers
IF OBJECT_ID('dbo.Publishers') IS NULL
CREATE TABLE dbo.Publishers (
    PublisherId INT IDENTITY(1,1) PRIMARY KEY,
    Name        NVARCHAR(250) NOT NULL,
    Address     NVARCHAR(500) NULL,
    Contact     NVARCHAR(250) NULL
);
GO
CREATE INDEX IX_Publishers_Name ON dbo.Publishers(Name);
GO

-- 7. Categories (self-referencing)
IF OBJECT_ID('dbo.Categories') IS NULL
CREATE TABLE dbo.Categories (
    CategoryId     INT IDENTITY(1,1) PRIMARY KEY,
    Name           NVARCHAR(200) NOT NULL,
    ParentCategoryId INT NULL
);
GO
ALTER TABLE dbo.Categories WITH CHECK ADD CONSTRAINT FK_Categories_Parent FOREIGN KEY (ParentCategoryId) REFERENCES dbo.Categories(CategoryId);
GO
CREATE INDEX IX_Categories_Name ON dbo.Categories(Name);
GO

-- 8. Books
IF OBJECT_ID('dbo.Books') IS NULL
CREATE TABLE dbo.Books (
    BookId         INT IDENTITY(1,1) PRIMARY KEY,
    Title          NVARCHAR(500) NOT NULL,
    ISBN           VARCHAR(20) NULL,
    PublisherId    INT NULL,
    PublicationYear INT NULL,
    Pages          INT NULL,
    Language       NVARCHAR(50) NULL,
    Description    NVARCHAR(MAX) NULL,
    CoverPath      NVARCHAR(500) NULL,
    CategoryId     INT NULL,
    TotalCopies    INT NOT NULL CONSTRAINT DF_Books_TotalCopies DEFAULT (0),
    AvailableCopies INT NOT NULL CONSTRAINT DF_Books_AvailableCopies DEFAULT (0),
    RowVersion     ROWVERSION
);
GO
ALTER TABLE dbo.Books WITH CHECK ADD CONSTRAINT FK_Books_Publishers FOREIGN KEY (PublisherId) REFERENCES dbo.Publishers(PublisherId);
ALTER TABLE dbo.Books WITH CHECK ADD CONSTRAINT FK_Books_Categories FOREIGN KEY (CategoryId) REFERENCES dbo.Categories(CategoryId);
GO
CREATE INDEX IX_Books_ISBN ON dbo.Books(ISBN);
CREATE INDEX IX_Books_Title ON dbo.Books(Title);
GO
-- 9. BookAuthors (many-to-many)
IF OBJECT_ID('dbo.BookAuthors') IS NULL
CREATE TABLE dbo.BookAuthors (
    BookAuthorId INT IDENTITY(1,1) PRIMARY KEY,
    BookId       INT NOT NULL,
    AuthorId     INT NOT NULL,
    AuthorOrder  INT NOT NULL CONSTRAINT DF_BookAuthors_AuthorOrder DEFAULT (1)
);
GO
ALTER TABLE dbo.BookAuthors WITH CHECK ADD CONSTRAINT FK_BookAuthors_Books FOREIGN KEY (BookId) REFERENCES dbo.Books(BookId);
ALTER TABLE dbo.BookAuthors WITH CHECK ADD CONSTRAINT FK_BookAuthors_Authors FOREIGN KEY (AuthorId) REFERENCES dbo.Authors(AuthorId);
GO
CREATE INDEX IX_BookAuthors_BookId ON dbo.BookAuthors(BookId);
CREATE INDEX IX_BookAuthors_AuthorId ON dbo.BookAuthors(AuthorId);
GO

-- 10. Copies (physical items)
IF OBJECT_ID('dbo.Copies') IS NULL
CREATE TABLE dbo.Copies (
    CopyId         INT IDENTITY(1,1) PRIMARY KEY,
    BookId         INT NOT NULL,
    Barcode        NVARCHAR(100) NOT NULL UNIQUE,
    AcquisitionDate DATE NULL,
    Condition      NVARCHAR(100) NULL,
    LocationCode   NVARCHAR(100) NULL,
    Status         NVARCHAR(20) NOT NULL CONSTRAINT DF_Copies_Status DEFAULT ('Available')
    -- Status values: 'Available','Loaned','Reserved','Lost'
);
GO
ALTER TABLE dbo.Copies WITH CHECK ADD CONSTRAINT FK_Copies_Books FOREIGN KEY (BookId) REFERENCES dbo.Books(BookId);
GO
CREATE INDEX IX_Copies_BookId ON dbo.Copies(BookId);
CREATE INDEX IX_Copies_Status ON dbo.Copies(Status);
GO

-- 11. Members (читатели)
IF OBJECT_ID('dbo.Members') IS NULL
CREATE TABLE dbo.Members (
    MemberId        INT IDENTITY(1,1) PRIMARY KEY,
    UserId          INT NULL, -- optional link to Users
    CardNumber      NVARCHAR(100) NOT NULL UNIQUE,
    Address         NVARCHAR(500) NULL,
    BirthDate       DATE NULL,
    RegistrationDate DATETIME2 NOT NULL CONSTRAINT DF_Members_Registration DEFAULT (SYSUTCDATETIME()),
    Status          NVARCHAR(50) NOT NULL CONSTRAINT DF_Members_Status DEFAULT ('Active')
);
GO
ALTER TABLE dbo.Members WITH CHECK ADD CONSTRAINT FK_Members_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId);
GO
CREATE INDEX IX_Members_CardNumber ON dbo.Members(CardNumber);
GO

-- 12. Loans
IF OBJECT_ID('dbo.Loans') IS NULL
CREATE TABLE dbo.Loans (
    LoanId       INT IDENTITY(1,1) PRIMARY KEY,
    CopyId       INT NOT NULL,
    MemberId     INT NOT NULL,
    LibrarianId  INT NULL, -- UserId of staff who processed
    LoanDate     DATETIME2 NOT NULL CONSTRAINT DF_Loans_LoanDate DEFAULT (SYSUTCDATETIME()),
    DueDate      DATETIME2 NOT NULL,
    ReturnDate   DATETIME2 NULL,
    FineAmount   DECIMAL(10,2) NULL CONSTRAINT DF_Loans_Fine DEFAULT (0.00),
    Status       NVARCHAR(20) NOT NULL CONSTRAINT DF_Loans_Status DEFAULT ('Loaned')
    -- Status values: 'Loaned','Returned','Overdue','Lost'
);
GO
ALTER TABLE dbo.Loans WITH CHECK ADD CONSTRAINT FK_Loans_Copies FOREIGN KEY (CopyId) REFERENCES dbo.Copies(CopyId);
ALTER TABLE dbo.Loans WITH CHECK ADD CONSTRAINT FK_Loans_Members FOREIGN KEY (MemberId) REFERENCES dbo.Members(MemberId);
ALTER TABLE dbo.Loans WITH CHECK ADD CONSTRAINT FK_Loans_Librarian FOREIGN KEY (LibrarianId) REFERENCES dbo.Users(UserId);
GO
CREATE INDEX IX_Loans_MemberId ON dbo.Loans(MemberId);
CREATE INDEX IX_Loans_CopyId ON dbo.Loans(CopyId);
CREATE INDEX IX_Loans_Status_DueDate ON dbo.Loans(Status, DueDate);
GO

-- 13. Reservations
IF OBJECT_ID('dbo.Reservations') IS NULL
CREATE TABLE dbo.Reservations (
    ReservationId INT IDENTITY(1,1) PRIMARY KEY,
    BookId        INT NOT NULL,
    MemberId      INT NOT NULL,
    ReservationDate DATETIME2 NOT NULL CONSTRAINT DF_Reservations_Date DEFAULT (SYSUTCDATETIME()),
    ExpiryDate    DATETIME2 NULL,
    Status        NVARCHAR(20) NOT NULL CONSTRAINT DF_Reservations_Status DEFAULT ('Active')
    -- Status: 'Active','Fulfilled','Expired','Cancelled'
);
GO
ALTER TABLE dbo.Reservations WITH CHECK ADD CONSTRAINT FK_Reservations_Books FOREIGN KEY (BookId) REFERENCES dbo.Books(BookId);
ALTER TABLE dbo.Reservations WITH CHECK ADD CONSTRAINT FK_Reservations_Members FOREIGN KEY (MemberId) REFERENCES dbo.Members(MemberId);
GO
CREATE INDEX IX_Reservations_BookId ON dbo.Reservations(BookId);
CREATE INDEX IX_Reservations_MemberId ON dbo.Reservations(MemberId);
GO

-- 14. TransactionsLog (журнал операций)
IF OBJECT_ID('dbo.TransactionsLog') IS NULL
CREATE TABLE dbo.TransactionsLog (
    TransactionId BIGINT IDENTITY(1,1) PRIMARY KEY,
    EntityName    NVARCHAR(200) NOT NULL,
    EntityId      NVARCHAR(200) NULL,
    Action        NVARCHAR(50) NOT NULL, -- INSERT, UPDATE, DELETE, EXECUTE
    UserId        INT NULL,
    [Timestamp]   DATETIME2 NOT NULL CONSTRAINT DF_TransactionsLog_Timestamp DEFAULT (SYSUTCDATETIME()),
    Details       NVARCHAR(MAX) NULL -- JSON или текст с деталями
);
GO
ALTER TABLE dbo.TransactionsLog WITH CHECK ADD CONSTRAINT FK_TransactionsLog_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId);
GO
CREATE INDEX IX_TransactionsLog_Entity_Timestamp ON dbo.TransactionsLog(EntityName, [Timestamp]);
GO

-- 15. Backups (метаданные резервных копий)
IF OBJECT_ID('dbo.Backups') IS NULL
CREATE TABLE dbo.Backups (
    BackupId    INT IDENTITY(1,1) PRIMARY KEY,
    BackupType  NVARCHAR(20) NOT NULL, -- Full, Differential, Log
    FilePath    NVARCHAR(1000) NOT NULL,
    CreatedAt   DATETIME2 NOT NULL CONSTRAINT DF_Backups_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedBy   INT NULL, -- UserId
    Success     BIT NOT NULL CONSTRAINT DF_Backups_Success DEFAULT (0),
    Notes       NVARCHAR(MAX) NULL
);
GO
ALTER TABLE dbo.Backups WITH CHECK ADD CONSTRAINT FK_Backups_Users FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(UserId);
GO
CREATE INDEX IX_Backups_CreatedAt ON dbo.Backups(CreatedAt);
GO

-- CHECK для статусов (Copies, Loans, Reservations)
ALTER TABLE dbo.Copies ADD CONSTRAINT CHK_Copies_Status CHECK (Status IN ('Available','Loaned','Reserved','Lost'));
ALTER TABLE dbo.Loans ADD CONSTRAINT CHK_Loans_Status CHECK (Status IN ('Loaned','Returned','Overdue','Lost'));
ALTER TABLE dbo.Reservations ADD CONSTRAINT CHK_Reservations_Status CHECK (Status IN ('Active','Fulfilled','Expired','Cancelled'));
GO

CREATE INDEX IX_Books_Category ON dbo.Books(CategoryId);
CREATE INDEX IX_Books_Publisher ON dbo.Books(PublisherId);
GO


