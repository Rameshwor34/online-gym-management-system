-- ========================================
-- Gym Management System Full SQL
-- ========================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

-- ========================================
-- USERS
-- ========================================
CREATE TABLE IF NOT EXISTS tbluser (
    id INT AUTO_INCREMENT PRIMARY KEY,
    fname VARCHAR(45),
    lname VARCHAR(45),
    email VARCHAR(45) UNIQUE,
    mobile VARCHAR(45),
    password VARCHAR(100),
    state VARCHAR(45),
    city VARCHAR(45),
    address VARCHAR(200),
    create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========================================
-- ADMINS
-- ========================================
CREATE TABLE IF NOT EXISTS tbladmin (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(45),
    email VARCHAR(45),
    mobile VARCHAR(45),
    password VARCHAR(100),
    create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========================================
-- PACKAGE CATEGORIES
-- ========================================
CREATE TABLE IF NOT EXISTS tblcategory (
    id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(45),
    status VARCHAR(45) DEFAULT '0'
);

-- ========================================
-- PACKAGES
-- ========================================
CREATE TABLE IF NOT EXISTS tblpackage (
    id INT AUTO_INCREMENT PRIMARY KEY,
    cate_id INT,
    PackageName VARCHAR(45),
    FOREIGN KEY (cate_id) REFERENCES tblcategory(id)
);

CREATE TABLE IF NOT EXISTS tbladdpackage (
    id INT AUTO_INCREMENT PRIMARY KEY,
    category VARCHAR(45),
    titlename VARCHAR(450),
    PackageType VARCHAR(45),
    PackageDuratiobn VARCHAR(45),
    Price VARCHAR(45),
    uploadphoto VARCHAR(450),
    Description VARCHAR(450),
    create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========================================
-- BOOKINGS
-- ========================================
CREATE TABLE IF NOT EXISTS tblbooking (
    id INT AUTO_INCREMENT PRIMARY KEY,
    package_id INT,
    userid INT,
    booking_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payment VARCHAR(45),
    paymentType VARCHAR(45),
    expiry_date DATE,
    status VARCHAR(45) DEFAULT 'active',
    FOREIGN KEY (package_id) REFERENCES tblpackage(id),
    FOREIGN KEY (userid) REFERENCES tbluser(id)
);

-- ========================================
-- PAYMENTS
-- ========================================
CREATE TABLE IF NOT EXISTS tblpayment (
    id INT AUTO_INCREMENT PRIMARY KEY,
    bookingID INT,
    paymentType VARCHAR(45),
    payment VARCHAR(45),
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (bookingID) REFERENCES tblbooking(id)
);

-- ========================================
-- TRAINERS
-- ========================================
CREATE TABLE IF NOT EXISTS tbltrainer (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    mobile VARCHAR(20),
    specialization VARCHAR(100)
);

-- ========================================
-- TRAINER SCHEDULE
-- ========================================
CREATE TABLE IF NOT EXISTS tbltrainer_schedule (
    id INT AUTO_INCREMENT PRIMARY KEY,
    trainer_id INT,
    member_id INT,
    schedule_date DATE,
    schedule_time TIME,
    FOREIGN KEY (trainer_id) REFERENCES tbltrainer(id),
    FOREIGN KEY (member_id) REFERENCES tbluser(id)
);

-- ========================================
-- ATTENDANCE
-- ========================================
CREATE TABLE IF NOT EXISTS tblattendance (
    id INT AUTO_INCREMENT PRIMARY KEY,
    member_id INT,
    attendance_date DATE,
    check_in_time TIME,
    FOREIGN KEY (member_id) REFERENCES tbluser(id)
);

-- ========================================
-- TRIGGERS
-- ========================================

DELIMITER $$

-- Auto expiry date based on package duration
CREATE TRIGGER trg_auto_set_membership_expiry
BEFORE INSERT ON tblbooking
FOR EACH ROW
BEGIN
    DECLARE duration INT;
    IF NEW.package_id IS NOT NULL THEN
        SELECT 
            CASE 
                WHEN PackageDuratiobn LIKE '%Month%' THEN CAST(SUBSTRING_INDEX(PackageDuratiobn,' ',1) AS UNSIGNED)
                ELSE 1
            END
        INTO duration
        FROM tbladdpackage
        WHERE id = NEW.package_id;
        
        SET NEW.expiry_date = DATE_ADD(CURDATE(), INTERVAL duration MONTH);
    END IF;
END$$

-- Prevent double booking of trainer
CREATE TRIGGER trg_trainer_schedule_validation
BEFORE INSERT ON tbltrainer_schedule
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM tbltrainer_schedule
        WHERE trainer_id = NEW.trainer_id
          AND schedule_date = NEW.schedule_date
          AND schedule_time = NEW.schedule_time
    ) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Trainer is already booked for this time slot';
    END IF;
END$$

-- Validate payment covers package
CREATE TRIGGER trg_validate_member_payment
BEFORE INSERT ON tblpayment
FOR EACH ROW
BEGIN
    DECLARE pkgPrice DECIMAL(10,2);
    SELECT Price INTO pkgPrice
    FROM tbladdpackage
    WHERE id = (SELECT package_id FROM tblbooking WHERE id = NEW.bookingID);
    
    IF NEW.payment < pkgPrice THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Payment less than package price';
    END IF;
END$$

-- Prevent duplicate attendance check-in
CREATE TRIGGER trg_attendance_check
BEFORE INSERT ON tblattendance
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM tblattendance
        WHERE member_id = NEW.member_id
          AND attendance_date = NEW.attendance_date
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Member already checked in today';
    END IF;
END$$

DELIMITER ;

-- ========================================
-- INDEXES
-- ========================================
CREATE INDEX idx_user_email ON tbluser(email);
CREATE INDEX idx_booking_user ON tblbooking(userid);
CREATE INDEX idx_booking_package ON tblbooking(package_id);
CREATE INDEX idx_payment_booking ON tblpayment(bookingID);
CREATE INDEX idx_package_category ON tbladdpackage(category);
CREATE INDEX idx_attendance_member_date ON tblattendance(member_id, attendance_date);
CREATE INDEX idx_trainer_assignment ON tbltrainer_schedule(trainer_id, schedule_date, schedule_time);
CREATE INDEX idx_membership_expiry ON tblbooking(expiry_date);

-- ========================================
-- VIEWS
-- ========================================
CREATE VIEW active_members_list AS
SELECT u.id AS member_id, CONCAT(u.fname,' ',u.lname) AS member_name, b.Package_id, b.status, b.expiry_date
FROM tbluser u
JOIN tblbooking b ON u.id = b.userid
WHERE b.status='active';

CREATE VIEW membership_expiry_alerts AS
SELECT u.id AS member_id, CONCAT(u.fname,' ',u.lname) AS member_name, b.Package_id, b.expiry_date
FROM tbluser u
JOIN tblbooking b ON u.id = b.userid
WHERE b.expiry_date <= DATE_ADD(CURDATE(), INTERVAL 7 DAY);

CREATE VIEW pending_payment_list AS
SELECT b.id AS booking_id, u.id AS member_id, u.fname, u.lname, b.payment, b.paymentType
FROM tblbooking b
JOIN tbluser u ON u.id = b.userid
WHERE b.payment IS NULL OR b.payment = '';

-- ========================================
-- STORED PROCEDURES
-- ========================================

DELIMITER $$

-- Register new user
CREATE PROCEDURE register_new_user(IN p_fname VARCHAR(45), IN p_lname VARCHAR(45), IN p_email VARCHAR(45), IN p_mobile VARCHAR(45), IN p_password VARCHAR(100))
BEGIN
    INSERT INTO tbluser(fname,lname,email,mobile,password)
    VALUES(p_fname,p_lname,p_email,p_mobile,p_password);
END$$

-- Book Gym Package
CREATE PROCEDURE book_gym_package(IN p_package_id INT, IN p_userid INT, IN p_paymentType VARCHAR(45), IN p_payment VARCHAR(45))
BEGIN
    DECLARE booking_id INT;
    INSERT INTO tblbooking(package_id, userid, payment, paymentType)
    VALUES(p_package_id, p_userid, p_payment, p_paymentType);
    SET booking_id = LAST_INSERT_ID();
    INSERT INTO tblpayment(bookingID, paymentType, payment)
    VALUES(booking_id, p_paymentType, p_payment);
END$$

DELIMITER ;

COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
