-- =====================================================
-- DATABASE CREATION
-- =====================================================

CREATE DATABASE IF NOT EXISTS university_registration;

USE university_registration;

-- =====================================================
-- USERS TABLE
-- =====================================================

CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20),
    role ENUM('student', 'doctor', 'admin') NOT NULL,
    status ENUM(
        'pending',
        'approved',
        'rejected'
    ) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (
        (
            role = 'student'
            AND code LIKE 'S%'
        )
        OR (
            role = 'doctor'
            AND code LIKE 'D%'
        )
        OR (
            role = 'admin'
            AND code LIKE 'A%'
        )
    )
);

CREATE INDEX idx_users_role ON users (role);

-- =====================================================
-- STUDENTS TABLE
-- =====================================================

CREATE TABLE students (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    specialization VARCHAR(100),
    year INT NOT NULL DEFAULT 4,
    CHECK (year = 4),
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

-- =====================================================
-- DOCTORS TABLE
-- =====================================================

CREATE TABLE doctors (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    specialization VARCHAR(100),
    year INT NOT NULL DEFAULT 4,
    CHECK (year = 4),
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);


-- =====================================================
-- ADMINS TABLE
-- =====================================================

CREATE TABLE admins (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);


-- =====================================================
-- COURSES TABLE
-- =====================================================

CREATE TABLE courses (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    year INT NOT NULL DEFAULT 4,
    semester INT NOT NULL,
    doctor_id INT NOT NULL,
    max_students INT DEFAULT 300,
    CHECK (year = 4),
    CHECK (semester IN (1, 2)),
    FOREIGN KEY (doctor_id) REFERENCES doctors (id) ON DELETE RESTRICT
);

CREATE INDEX idx_courses_semester ON courses (semester);

-- =====================================================
-- ENROLLMENTS TABLE
-- =====================================================

CREATE TABLE enrollments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    course_id INT NOT NULL,
    semester INT NOT NULL,
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (student_id, course_id),
    FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
    FOREIGN KEY (course_id) REFERENCES courses (id) ON DELETE CASCADE,
    CHECK (semester IN (1, 2))
);

CREATE INDEX idx_enrollments_student ON enrollments (student_id);

CREATE INDEX idx_enrollments_course ON enrollments (course_id);

-- =====================================================
-- REGISTRATION SESSIONS TABLE
-- =====================================================

CREATE TABLE registration_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    year INT NOT NULL DEFAULT 4,
    semester INT NOT NULL,
    is_open BOOLEAN DEFAULT FALSE,
    start_date DATE,
    end_date DATE,
    CHECK (year = 4),
    CHECK (semester IN (1, 2)),
    UNIQUE (year, semester)
);

-- =====================================================
-- TRIGGER: PREVENT COURSE OVER CAPACITY
-- =====================================================

DELIMITER / /

CREATE TRIGGER before_enrollment_insert
BEFORE INSERT ON enrollments
FOR EACH ROW
BEGIN
    DECLARE current_count INT;
    DECLARE max_allowed INT;

    SELECT COUNT(*) INTO current_count
    FROM enrollments
    WHERE course_id = NEW.course_id;

    SELECT max_students INTO max_allowed
    FROM courses
    WHERE id = NEW.course_id;

    IF current_count >= max_allowed THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Course is full';
    END IF;
END //

DELIMITER;

-- =====================================================
-- STORED PROCEDURE: REGISTER STUDENT FOR SEMESTER
-- =====================================================

DELIMITER / /

CREATE PROCEDURE register_student_for_semester(
    IN p_user_id INT,
    IN p_semester INT
)
BEGIN
    DECLARE v_student_id INT;
    DECLARE v_status VARCHAR(20);
    DECLARE v_is_open BOOLEAN;
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_course_id INT;
    
    DECLARE course_cursor CURSOR FOR
        SELECT id FROM courses
        WHERE semester = p_semester AND year = 4;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    START TRANSACTION;

    -- Check student status
    SELECT status INTO v_status
    FROM users
    WHERE id = p_user_id AND role = 'student';

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid student';
    END IF;

    IF v_status != 'approved' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Student not approved';
    END IF;

    -- Get student_id
    SELECT id INTO v_student_id
    FROM students
    WHERE user_id = p_user_id;

    -- Check registration session
    SELECT is_open INTO v_is_open
    FROM registration_sessions
    WHERE semester = p_semester AND year = 4;

    IF v_is_open IS NULL OR v_is_open = FALSE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Registration is closed';
    END IF;

    -- Enroll student in all semester courses
    OPEN course_cursor;

    course_loop: LOOP
        FETCH course_cursor INTO v_course_id;
        IF done THEN
            LEAVE course_loop;
        END IF;

        INSERT INTO enrollments(student_id, course_id, semester)
        VALUES (v_student_id, v_course_id, p_semester);

    END LOOP;

    CLOSE course_cursor;

    COMMIT;

END //

DELIMITER;