-- =====================================================================================
--  attendance_system_db.sql
--  Android Attendance Management System  -  MySQL database script
--
--  Compatible with : MySQL 8.0.16 or newer  (CHECK constraints are enforced from 8.0.16)
--  Also works on   : MariaDB 10.5+
--  Engine / charset: InnoDB, utf8mb4
--  Designed for    : Spring Boot + Spring Data JPA (snake_case names, BIGINT ids,
--                    enums stored as text so @Enumerated(EnumType.STRING) works)
--
--  WARNING: this script DROPS and RE-CREATES the 14 tables below. Running it again
--           erases all data in those tables. It does not touch other databases.
--
--  SAMPLE LOGIN (test data only): every sample user has the password   Password@123
--  Passwords are stored as BCrypt hashes. Never store plain-text passwords.
--
--  How to run:   mysql -u root -p < attendance_system_db.sql
-- =====================================================================================

SET NAMES utf8mb4;

CREATE DATABASE IF NOT EXISTS attendance_system_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE attendance_system_db;

-- ------------------------------------------------------------------
-- Drop old tables (children first) so the script can be re-run safely
-- ------------------------------------------------------------------
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS student_performance;
DROP TABLE IF EXISTS seating_plans;
DROP TABLE IF EXISTS exam_forms;
DROP TABLE IF EXISTS exam_results;
DROP TABLE IF EXISTS exams;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS holidays;
DROP TABLE IF EXISTS fees;
DROP TABLE IF EXISTS timetable;
DROP TABLE IF EXISTS attendance;
DROP TABLE IF EXISTS subjects;
DROP TABLE IF EXISTS teachers;
DROP TABLE IF EXISTS students;
DROP TABLE IF EXISTS users;
SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================================
-- PART 1: TABLES
-- =====================================================================================

-- A. USERS ---------------------------------------------------------------------------
-- One row per person who can log in (admin, teacher or student).
CREATE TABLE users (
    user_id        BIGINT       NOT NULL AUTO_INCREMENT,
    full_name      VARCHAR(100) NOT NULL,
    email          VARCHAR(150) NOT NULL,
    password_hash  VARCHAR(255) NOT NULL,                 -- BCrypt hash, never plain text
    role           VARCHAR(20)  NOT NULL,                 -- ADMIN | TEACHER | STUDENT
    phone_number   VARCHAR(20)  NULL,
    status         VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',-- ACTIVE | INACTIVE | SUSPENDED
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id),
    CONSTRAINT uq_users_email  UNIQUE (email),
    CONSTRAINT chk_users_role  CHECK (role   IN ('ADMIN', 'TEACHER', 'STUDENT')),
    CONSTRAINT chk_users_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    INDEX idx_users_role_status (role, status)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- B. STUDENTS ------------------------------------------------------------------------
-- Extra details for users whose role is STUDENT (one-to-one with users).
CREATE TABLE students (
    student_id         BIGINT       NOT NULL AUTO_INCREMENT,
    user_id            BIGINT       NOT NULL,
    enrollment_number  VARCHAR(30)  NOT NULL,
    course             VARCHAR(100) NOT NULL,
    semester           INT          NOT NULL,
    section            VARCHAR(10)  NOT NULL,
    admission_date     DATE         NOT NULL,
    PRIMARY KEY (student_id),
    CONSTRAINT uq_students_user       UNIQUE (user_id),
    CONSTRAINT uq_students_enrollment UNIQUE (enrollment_number),
    CONSTRAINT chk_students_semester  CHECK (semester BETWEEN 1 AND 12),
    CONSTRAINT fk_students_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE CASCADE,
    INDEX idx_students_class (course, semester, section)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- C. TEACHERS ------------------------------------------------------------------------
-- Extra details for users whose role is TEACHER (one-to-one with users).
CREATE TABLE teachers (
    teacher_id   BIGINT       NOT NULL AUTO_INCREMENT,
    user_id      BIGINT       NOT NULL,
    employee_id  VARCHAR(30)  NOT NULL,
    department   VARCHAR(100) NOT NULL,
    PRIMARY KEY (teacher_id),
    CONSTRAINT uq_teachers_user     UNIQUE (user_id),
    CONSTRAINT uq_teachers_employee UNIQUE (employee_id),
    CONSTRAINT fk_teachers_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE CASCADE,
    INDEX idx_teachers_department (department)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- D. SUBJECTS ------------------------------------------------------------------------
-- One teacher can teach many subjects. teacher_id may be empty if not assigned yet.
CREATE TABLE subjects (
    subject_id    BIGINT       NOT NULL AUTO_INCREMENT,
    subject_name  VARCHAR(120) NOT NULL,
    subject_code  VARCHAR(20)  NOT NULL,
    semester      INT          NOT NULL,
    teacher_id    BIGINT       NULL,
    PRIMARY KEY (subject_id),
    CONSTRAINT uq_subjects_code      UNIQUE (subject_code),
    CONSTRAINT chk_subjects_semester CHECK (semester BETWEEN 1 AND 12),
    CONSTRAINT fk_subjects_teacher FOREIGN KEY (teacher_id)
        REFERENCES teachers (teacher_id) ON DELETE SET NULL,
    INDEX idx_subjects_semester (semester)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- E. ATTENDANCE ----------------------------------------------------------------------
-- One row per student, per subject, per day. The UNIQUE key blocks duplicates.
-- marked_by = teachers.teacher_id of the teacher who recorded it.
CREATE TABLE attendance (
    attendance_id    BIGINT      NOT NULL AUTO_INCREMENT,
    student_id       BIGINT      NOT NULL,
    subject_id       BIGINT      NOT NULL,
    attendance_date  DATE        NOT NULL,
    status           VARCHAR(10) NOT NULL,                -- PRESENT | ABSENT | LATE
    marked_by        BIGINT      NULL,
    created_at       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (attendance_id),
    CONSTRAINT uq_attendance_student_subject_date UNIQUE (student_id, subject_id, attendance_date),
    CONSTRAINT chk_attendance_status CHECK (status IN ('PRESENT', 'ABSENT', 'LATE')),
    CONSTRAINT fk_attendance_student FOREIGN KEY (student_id)
        REFERENCES students (student_id) ON DELETE CASCADE,
    CONSTRAINT fk_attendance_subject FOREIGN KEY (subject_id)
        REFERENCES subjects (subject_id) ON DELETE RESTRICT,
    CONSTRAINT fk_attendance_teacher FOREIGN KEY (marked_by)
        REFERENCES teachers (teacher_id) ON DELETE SET NULL,
    INDEX idx_attendance_subject_date (subject_id, attendance_date),
    INDEX idx_attendance_date (attendance_date)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- F. TIMETABLE -----------------------------------------------------------------------
-- Weekly class schedule. A teacher or a room cannot be used twice at the same time.
CREATE TABLE timetable (
    timetable_id  BIGINT      NOT NULL AUTO_INCREMENT,
    subject_id    BIGINT      NOT NULL,
    teacher_id    BIGINT      NOT NULL,
    day_of_week   VARCHAR(10) NOT NULL,                   -- MONDAY ... SUNDAY
    start_time    TIME        NOT NULL,
    end_time      TIME        NOT NULL,
    room_number   VARCHAR(20) NOT NULL,
    semester      INT         NOT NULL,
    section       VARCHAR(10) NOT NULL,
    PRIMARY KEY (timetable_id),
    CONSTRAINT uq_timetable_teacher_slot UNIQUE (teacher_id, day_of_week, start_time),
    CONSTRAINT uq_timetable_room_slot    UNIQUE (room_number, day_of_week, start_time),
    CONSTRAINT chk_timetable_day CHECK (day_of_week IN
        ('MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY','SUNDAY')),
    CONSTRAINT chk_timetable_time     CHECK (end_time > start_time),
    CONSTRAINT chk_timetable_semester CHECK (semester BETWEEN 1 AND 12),
    CONSTRAINT fk_timetable_subject FOREIGN KEY (subject_id)
        REFERENCES subjects (subject_id) ON DELETE CASCADE,
    CONSTRAINT fk_timetable_teacher FOREIGN KEY (teacher_id)
        REFERENCES teachers (teacher_id) ON DELETE RESTRICT,
    INDEX idx_timetable_class (semester, section, day_of_week, start_time),
    INDEX idx_timetable_subject (subject_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- G. FEES ----------------------------------------------------------------------------
-- A student can have many fee records. due_amount must equal total - paid.
CREATE TABLE fees (
    fee_id          BIGINT        NOT NULL AUTO_INCREMENT,
    student_id      BIGINT        NOT NULL,
    total_amount    DECIMAL(10,2) NOT NULL,
    paid_amount     DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    due_amount      DECIMAL(10,2) NOT NULL,
    payment_status  VARCHAR(20)   NOT NULL DEFAULT 'PENDING', -- PENDING | PARTIAL | PAID | OVERDUE
    due_date        DATE          NOT NULL,
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (fee_id),
    CONSTRAINT chk_fees_total  CHECK (total_amount > 0),
    CONSTRAINT chk_fees_paid   CHECK (paid_amount >= 0 AND paid_amount <= total_amount),
    CONSTRAINT chk_fees_due    CHECK (due_amount = total_amount - paid_amount),
    CONSTRAINT chk_fees_status CHECK (payment_status IN ('PENDING', 'PARTIAL', 'PAID', 'OVERDUE')),
    CONSTRAINT fk_fees_student FOREIGN KEY (student_id)
        REFERENCES students (student_id) ON DELETE CASCADE,
    INDEX idx_fees_student (student_id),
    INDEX idx_fees_status_due (payment_status, due_date)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- H. HOLIDAYS ------------------------------------------------------------------------
CREATE TABLE holidays (
    holiday_id    BIGINT       NOT NULL AUTO_INCREMENT,
    holiday_name  VARCHAR(100) NOT NULL,
    holiday_date  DATE         NOT NULL,
    description   VARCHAR(255) NULL,
    PRIMARY KEY (holiday_id),
    CONSTRAINT uq_holidays_date UNIQUE (holiday_date)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- I. NOTIFICATIONS -------------------------------------------------------------------
-- recipient_role: who should see it. ALL means every role.
CREATE TABLE notifications (
    notification_id  BIGINT       NOT NULL AUTO_INCREMENT,
    title            VARCHAR(150) NOT NULL,
    message          TEXT         NOT NULL,
    recipient_role   VARCHAR(20)  NOT NULL DEFAULT 'ALL', -- ALL | ADMIN | TEACHER | STUDENT
    created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active        TINYINT(1)   NOT NULL DEFAULT 1,
    PRIMARY KEY (notification_id),
    CONSTRAINT chk_notifications_role CHECK (recipient_role IN ('ALL', 'ADMIN', 'TEACHER', 'STUDENT')),
    CONSTRAINT chk_notifications_active CHECK (is_active IN (0, 1)),
    INDEX idx_notifications_role_active (recipient_role, is_active, created_at)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- J. EXAMS ---------------------------------------------------------------------------
CREATE TABLE exams (
    exam_id      BIGINT       NOT NULL AUTO_INCREMENT,
    subject_id   BIGINT       NOT NULL,
    exam_name    VARCHAR(120) NOT NULL,
    exam_date    DATE         NOT NULL,
    semester     INT          NOT NULL,
    total_marks  DECIMAL(6,2) NOT NULL,
    PRIMARY KEY (exam_id),
    CONSTRAINT uq_exams_subject_name UNIQUE (subject_id, exam_name),
    CONSTRAINT chk_exams_marks    CHECK (total_marks > 0),
    CONSTRAINT chk_exams_semester CHECK (semester BETWEEN 1 AND 12),
    CONSTRAINT fk_exams_subject FOREIGN KEY (subject_id)
        REFERENCES subjects (subject_id) ON DELETE RESTRICT,
    INDEX idx_exams_semester_date (semester, exam_date)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- K. EXAM RESULTS (REPORT CARD) ------------------------------------------------------
-- One result per student per exam.
CREATE TABLE exam_results (
    result_id       BIGINT       NOT NULL AUTO_INCREMENT,
    exam_id         BIGINT       NOT NULL,
    student_id      BIGINT       NOT NULL,
    marks_obtained  DECIMAL(6,2) NOT NULL,
    grade           VARCHAR(5)   NULL,
    remarks         VARCHAR(255) NULL,
    PRIMARY KEY (result_id),
    CONSTRAINT uq_results_exam_student UNIQUE (exam_id, student_id),
    CONSTRAINT chk_results_marks CHECK (marks_obtained >= 0),
    CONSTRAINT fk_results_exam FOREIGN KEY (exam_id)
        REFERENCES exams (exam_id) ON DELETE CASCADE,
    CONSTRAINT fk_results_student FOREIGN KEY (student_id)
        REFERENCES students (student_id) ON DELETE CASCADE,
    INDEX idx_results_student (student_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- L. EXAM FORMS ----------------------------------------------------------------------
-- One exam form per student per semester.
CREATE TABLE exam_forms (
    exam_form_id       BIGINT      NOT NULL AUTO_INCREMENT,
    student_id         BIGINT      NOT NULL,
    semester           INT         NOT NULL,
    submission_status  VARCHAR(20) NOT NULL DEFAULT 'DRAFT', -- DRAFT | SUBMITTED | APPROVED | REJECTED
    submitted_at       DATETIME    NULL,
    PRIMARY KEY (exam_form_id),
    CONSTRAINT uq_exam_forms_student_semester UNIQUE (student_id, semester),
    CONSTRAINT chk_exam_forms_semester CHECK (semester BETWEEN 1 AND 12),
    CONSTRAINT chk_exam_forms_status CHECK (submission_status IN ('DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED')),
    CONSTRAINT fk_exam_forms_student FOREIGN KEY (student_id)
        REFERENCES students (student_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- M. SEATING PLANS -------------------------------------------------------------------
-- A student has one seat per exam, and one seat holds only one student.
CREATE TABLE seating_plans (
    seating_id   BIGINT      NOT NULL AUTO_INCREMENT,
    exam_id      BIGINT      NOT NULL,
    student_id   BIGINT      NOT NULL,
    room_number  VARCHAR(20) NOT NULL,
    seat_number  VARCHAR(10) NOT NULL,
    PRIMARY KEY (seating_id),
    CONSTRAINT uq_seating_exam_student UNIQUE (exam_id, student_id),
    CONSTRAINT uq_seating_exam_seat    UNIQUE (exam_id, room_number, seat_number),
    CONSTRAINT fk_seating_exam FOREIGN KEY (exam_id)
        REFERENCES exams (exam_id) ON DELETE CASCADE,
    CONSTRAINT fk_seating_student FOREIGN KEY (student_id)
        REFERENCES students (student_id) ON DELETE CASCADE,
    INDEX idx_seating_student (student_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- N. STUDENT PERFORMANCE -------------------------------------------------------------
-- Quizzes, assignments and other internal assessments.
CREATE TABLE student_performance (
    performance_id   BIGINT       NOT NULL AUTO_INCREMENT,
    student_id       BIGINT       NOT NULL,
    subject_id       BIGINT       NOT NULL,
    assessment_name  VARCHAR(120) NOT NULL,
    marks_obtained   DECIMAL(6,2) NOT NULL,
    total_marks      DECIMAL(6,2) NOT NULL,
    assessment_date  DATE         NOT NULL,
    PRIMARY KEY (performance_id),
    CONSTRAINT uq_performance_assessment UNIQUE (student_id, subject_id, assessment_name),
    CONSTRAINT chk_performance_total CHECK (total_marks > 0),
    CONSTRAINT chk_performance_marks CHECK (marks_obtained >= 0 AND marks_obtained <= total_marks),
    CONSTRAINT fk_performance_student FOREIGN KEY (student_id)
        REFERENCES students (student_id) ON DELETE CASCADE,
    CONSTRAINT fk_performance_subject FOREIGN KEY (subject_id)
        REFERENCES subjects (subject_id) ON DELETE RESTRICT,
    INDEX idx_performance_subject (subject_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- =====================================================================================
-- PART 2: SAMPLE DATA  (fictional people only; loaded in ONE transaction)
-- If any INSERT fails, nothing is saved. Run ROLLBACK; to undo, or fix the error and retry.
-- =====================================================================================
START TRANSACTION;

-- Users: 1 admin, 2 teachers, 5 students (password for all: Password@123)
INSERT INTO users (user_id, full_name, email, password_hash, role, phone_number, status) VALUES
    (1, 'Meera Kapoor', 'admin@attendance.example.com', '$2a$10$PmH4o/VISrUwEZLFIAUw.eJFSJCH/gB0D42nfcqFGVs48MHh6fvlm', 'ADMIN', '+91 90000 00001', 'ACTIVE'),
    (2, 'Rohan Verma', 'rohan.verma@attendance.example.com', '$2a$10$j2SnR6TG6yUTNKBBjucP6uEQ7RRTdGEQC/3Wkg52ZSSApGZOvpJaS', 'TEACHER', '+91 90000 00002', 'ACTIVE'),
    (3, 'Priya Nair', 'priya.nair@attendance.example.com', '$2a$10$tO5A50HHtArRZwmOAJwX0u3SezYZcZjH7sqX/JSKhkxBPQgo7fyoK', 'TEACHER', '+91 90000 00003', 'ACTIVE'),
    (4, 'Aarav Mehta', 'aarav.mehta@student.example.com', '$2a$10$oN4lkswB2qdr42hVQ4Axee.0p1HgERP5uQ4uN1RbWzA.y8qnx/3LW', 'STUDENT', '+91 90000 00004', 'ACTIVE'),
    (5, 'Diya Iyer', 'diya.iyer@student.example.com', '$2a$10$.fts1Xs.wGupzzHyk4byIO6Ip0dEulgk27SHag.JjraCykVkEjvny', 'STUDENT', '+91 90000 00005', 'ACTIVE'),
    (6, 'Kabir Malhotra', 'kabir.malhotra@student.example.com', '$2a$10$eDL.DojlT6elYec1BK7JBePpu63XTgbYC/gB6piGiAsy9ImZJaTJy', 'STUDENT', '+91 90000 00006', 'ACTIVE'),
    (7, 'Ananya Rao', 'ananya.rao@student.example.com', '$2a$10$DRfbXuh0J0RHxJSCxFgYmeaDJ1nBvU5CmFOeJxJ3.IOnoFoCLw/.O', 'STUDENT', '+91 90000 00007', 'ACTIVE'),
    (8, 'Vihaan Patel', 'vihaan.patel@student.example.com', '$2a$10$QsutnILu3bqnPtcDgmxhxu5maIE45sePrh9cNh74URpJYjAyX1x7e', 'STUDENT', '+91 90000 00008', 'ACTIVE');

-- Teachers
INSERT INTO teachers (teacher_id, user_id, employee_id, department) VALUES
    (1, 2, 'EMP1001', 'Computer Science'),
    (2, 3, 'EMP1002', 'Mathematics');

-- Students (Semester 3: students 1-3 in Section A, students 4-5 in Section B)
INSERT INTO students (student_id, user_id, enrollment_number, course, semester, section, admission_date) VALUES
    (1, 4, 'ENR2024001', 'B.Tech Computer Science', 3, 'A', '2024-07-15'),
    (2, 5, 'ENR2024002', 'B.Tech Computer Science', 3, 'A', '2024-07-15'),
    (3, 6, 'ENR2024003', 'B.Tech Computer Science', 3, 'A', '2024-07-16'),
    (4, 7, 'ENR2024004', 'B.Tech Computer Science', 3, 'B', '2024-07-16'),
    (5, 8, 'ENR2024005', 'B.Tech Computer Science', 3, 'B', '2024-07-17');

-- Subjects (Rohan Verma teaches 1-2, Priya Nair teaches 3-4)
INSERT INTO subjects (subject_id, subject_name, subject_code, semester, teacher_id) VALUES
    (1, 'Data Structures', 'CS301', 3, 1),
    (2, 'Database Management Systems', 'CS302', 3, 1),
    (3, 'Discrete Mathematics', 'MA301', 3, 2),
    (4, 'Technical Communication', 'HS301', 3, 2);

-- Timetable (Semester 3, Section A in room A-101, Section B in room B-201)
INSERT INTO timetable (timetable_id, subject_id, teacher_id, day_of_week, start_time, end_time, room_number, semester, section) VALUES
    (1, 1, 1, 'MONDAY', '09:00:00', '10:00:00', 'A-101', 3, 'A'),
    (2, 3, 2, 'MONDAY', '10:00:00', '11:00:00', 'A-101', 3, 'A'),
    (3, 2, 1, 'TUESDAY', '09:00:00', '10:00:00', 'A-101', 3, 'A'),
    (4, 4, 2, 'TUESDAY', '10:00:00', '11:00:00', 'A-101', 3, 'A'),
    (5, 1, 1, 'WEDNESDAY', '09:00:00', '10:00:00', 'A-101', 3, 'A'),
    (6, 3, 2, 'THURSDAY', '09:00:00', '10:00:00', 'A-101', 3, 'A'),
    (7, 2, 1, 'FRIDAY', '09:00:00', '10:00:00', 'A-101', 3, 'A'),
    (8, 1, 1, 'MONDAY', '11:00:00', '12:00:00', 'B-201', 3, 'B'),
    (9, 3, 2, 'MONDAY', '12:00:00', '13:00:00', 'B-201', 3, 'B'),
    (10, 2, 1, 'TUESDAY', '11:00:00', '12:00:00', 'B-201', 3, 'B'),
    (11, 4, 2, 'TUESDAY', '12:00:00', '13:00:00', 'B-201', 3, 'B'),
    (12, 1, 1, 'WEDNESDAY', '11:00:00', '12:00:00', 'B-201', 3, 'B'),
    (13, 3, 2, 'THURSDAY', '11:00:00', '12:00:00', 'B-201', 3, 'B'),
    (14, 2, 1, 'FRIDAY', '11:00:00', '12:00:00', 'B-201', 3, 'B');

-- Attendance: 70 records for 5 students, 12-23 October 2026 (only on days each subject is scheduled)
INSERT INTO attendance (attendance_id, student_id, subject_id, attendance_date, status, marked_by) VALUES
    (1, 1, 1, '2026-10-12', 'PRESENT', 1),
    (2, 2, 1, '2026-10-12', 'PRESENT', 1),
    (3, 3, 1, '2026-10-12', 'PRESENT', 1),
    (4, 4, 1, '2026-10-12', 'ABSENT', 1),
    (5, 5, 1, '2026-10-12', 'PRESENT', 1),
    (6, 1, 1, '2026-10-14', 'PRESENT', 1),
    (7, 2, 1, '2026-10-14', 'PRESENT', 1),
    (8, 3, 1, '2026-10-14', 'PRESENT', 1),
    (9, 4, 1, '2026-10-14', 'LATE', 1),
    (10, 5, 1, '2026-10-14', 'PRESENT', 1),
    (11, 1, 2, '2026-10-13', 'PRESENT', 1),
    (12, 2, 2, '2026-10-13', 'PRESENT', 1),
    (13, 3, 2, '2026-10-13', 'ABSENT', 1),
    (14, 4, 2, '2026-10-13', 'PRESENT', 1),
    (15, 5, 2, '2026-10-13', 'PRESENT', 1),
    (16, 1, 2, '2026-10-16', 'PRESENT', 1),
    (17, 2, 2, '2026-10-16', 'PRESENT', 1),
    (18, 3, 2, '2026-10-16', 'ABSENT', 1),
    (19, 4, 2, '2026-10-16', 'PRESENT', 1),
    (20, 5, 2, '2026-10-16', 'PRESENT', 1),
    (21, 1, 3, '2026-10-12', 'PRESENT', 2),
    (22, 2, 3, '2026-10-12', 'PRESENT', 2),
    (23, 3, 3, '2026-10-12', 'PRESENT', 2),
    (24, 4, 3, '2026-10-12', 'PRESENT', 2),
    (25, 5, 3, '2026-10-12', 'LATE', 2),
    (26, 1, 3, '2026-10-15', 'LATE', 2),
    (27, 2, 3, '2026-10-15', 'PRESENT', 2),
    (28, 3, 3, '2026-10-15', 'ABSENT', 2),
    (29, 4, 3, '2026-10-15', 'PRESENT', 2),
    (30, 5, 3, '2026-10-15', 'PRESENT', 2),
    (31, 1, 4, '2026-10-13', 'PRESENT', 2),
    (32, 2, 4, '2026-10-13', 'PRESENT', 2),
    (33, 3, 4, '2026-10-13', 'PRESENT', 2),
    (34, 4, 4, '2026-10-13', 'PRESENT', 2),
    (35, 5, 4, '2026-10-13', 'PRESENT', 2),
    (36, 1, 1, '2026-10-19', 'PRESENT', 1),
    (37, 2, 1, '2026-10-19', 'PRESENT', 1),
    (38, 3, 1, '2026-10-19', 'PRESENT', 1),
    (39, 4, 1, '2026-10-19', 'PRESENT', 1),
    (40, 5, 1, '2026-10-19', 'PRESENT', 1),
    (41, 1, 1, '2026-10-21', 'PRESENT', 1),
    (42, 2, 1, '2026-10-21', 'PRESENT', 1),
    (43, 3, 1, '2026-10-21', 'PRESENT', 1),
    (44, 4, 1, '2026-10-21', 'PRESENT', 1),
    (45, 5, 1, '2026-10-21', 'PRESENT', 1),
    (46, 1, 2, '2026-10-20', 'PRESENT', 1),
    (47, 2, 2, '2026-10-20', 'PRESENT', 1),
    (48, 3, 2, '2026-10-20', 'LATE', 1),
    (49, 4, 2, '2026-10-20', 'PRESENT', 1),
    (50, 5, 2, '2026-10-20', 'PRESENT', 1),
    (51, 1, 2, '2026-10-23', 'PRESENT', 1),
    (52, 2, 2, '2026-10-23', 'PRESENT', 1),
    (53, 3, 2, '2026-10-23', 'ABSENT', 1),
    (54, 4, 2, '2026-10-23', 'PRESENT', 1),
    (55, 5, 2, '2026-10-23', 'PRESENT', 1),
    (56, 1, 3, '2026-10-19', 'PRESENT', 2),
    (57, 2, 3, '2026-10-19', 'PRESENT', 2),
    (58, 3, 3, '2026-10-19', 'PRESENT', 2),
    (59, 4, 3, '2026-10-19', 'PRESENT', 2),
    (60, 5, 3, '2026-10-19', 'PRESENT', 2),
    (61, 1, 3, '2026-10-22', 'PRESENT', 2),
    (62, 2, 3, '2026-10-22', 'PRESENT', 2),
    (63, 3, 3, '2026-10-22', 'LATE', 2),
    (64, 4, 3, '2026-10-22', 'PRESENT', 2),
    (65, 5, 3, '2026-10-22', 'PRESENT', 2),
    (66, 1, 4, '2026-10-20', 'PRESENT', 2),
    (67, 2, 4, '2026-10-20', 'LATE', 2),
    (68, 3, 4, '2026-10-20', 'LATE', 2),
    (69, 4, 4, '2026-10-20', 'PRESENT', 2),
    (70, 5, 4, '2026-10-20', 'PRESENT', 2);

-- Fees (student 2 has two fee records)
INSERT INTO fees (fee_id, student_id, total_amount, paid_amount, due_amount, payment_status, due_date) VALUES
    (1, 1, 60000, 60000, 0, 'PAID', '2026-08-31'),
    (2, 2, 60000, 30000, 30000, 'PARTIAL', '2026-11-30'),
    (3, 3, 60000, 0, 60000, 'PENDING', '2026-11-30'),
    (4, 4, 60000, 20000, 40000, 'OVERDUE', '2026-09-30'),
    (5, 5, 60000, 60000, 0, 'PAID', '2026-08-31'),
    (6, 2, 2500, 0, 2500, 'PENDING', '2026-12-05');

-- Holidays
INSERT INTO holidays (holiday_id, holiday_name, holiday_date, description) VALUES
    (1, 'Christmas Day', '2026-12-25', 'Public holiday. College closed.'),
    (2, 'New Year Day', '2027-01-01', 'Public holiday. College closed.');

-- Notifications
INSERT INTO notifications (notification_id, title, message, recipient_role, created_at, is_active) VALUES
    (1, 'Mid-term results published', 'Mid-term exam results for Semester 3 are now available in the app.', 'STUDENT', '2026-10-20 09:00:00', 1),
    (2, 'Attendance submission reminder', 'Please submit attendance for all classes before 6 PM every day.', 'TEACHER', '2026-10-21 08:30:00', 1),
    (3, 'Holiday notice', 'The college will remain closed on Christmas Day and New Year Day.', 'ALL', '2026-10-22 10:00:00', 1);

-- Exams (4 completed mid-terms + 1 upcoming final exam)
INSERT INTO exams (exam_id, subject_id, exam_name, exam_date, semester, total_marks) VALUES
    (1, 1, 'Mid-Term Exam', '2026-09-14', 3, 50),
    (2, 2, 'Mid-Term Exam', '2026-09-15', 3, 50),
    (3, 3, 'Mid-Term Exam', '2026-09-16', 3, 50),
    (4, 4, 'Mid-Term Exam', '2026-09-17', 3, 50),
    (5, 1, 'Final Exam', '2026-12-10', 3, 100);

-- Exam results for the 4 completed mid-term exams
INSERT INTO exam_results (result_id, exam_id, student_id, marks_obtained, grade, remarks) VALUES
    (1, 1, 1, 50, 'A+', 'Outstanding performance'),
    (2, 1, 2, 35, 'B+', 'Very good'),
    (3, 1, 3, 24, 'D', 'Needs improvement'),
    (4, 1, 4, 33, 'B', 'Good'),
    (5, 1, 5, 46, 'A+', 'Outstanding performance'),
    (6, 2, 1, 43, 'A', 'Excellent work'),
    (7, 2, 2, 40, 'A', 'Excellent work'),
    (8, 2, 3, 24, 'D', 'Needs improvement'),
    (9, 2, 4, 28, 'C', 'Satisfactory'),
    (10, 2, 5, 48, 'A+', 'Outstanding performance'),
    (11, 3, 1, 43, 'A', 'Excellent work'),
    (12, 3, 2, 40, 'A', 'Excellent work'),
    (13, 3, 3, 27, 'C', 'Satisfactory'),
    (14, 3, 4, 35, 'B+', 'Very good'),
    (15, 3, 5, 45, 'A+', 'Outstanding performance'),
    (16, 4, 1, 42, 'A', 'Excellent work'),
    (17, 4, 2, 35, 'B+', 'Very good'),
    (18, 4, 3, 28, 'C', 'Satisfactory'),
    (19, 4, 4, 27, 'C', 'Satisfactory'),
    (20, 4, 5, 47, 'A+', 'Outstanding performance');

-- Exam forms for Semester 3
INSERT INTO exam_forms (exam_form_id, student_id, semester, submission_status, submitted_at) VALUES
    (1, 1, 3, 'APPROVED', '2026-10-20 10:15:00'),
    (2, 2, 3, 'SUBMITTED', '2026-10-21 11:40:00'),
    (3, 3, 3, 'SUBMITTED', '2026-10-22 09:05:00'),
    (4, 4, 3, 'DRAFT', NULL),
    (5, 5, 3, 'APPROVED', '2026-10-19 16:20:00');

-- Seating plan for the upcoming Final Exam (exam_id 5)
INSERT INTO seating_plans (seating_id, exam_id, student_id, room_number, seat_number) VALUES
    (1, 5, 1, 'EX-101', 'A1'),
    (2, 5, 2, 'EX-101', 'A2'),
    (3, 5, 3, 'EX-101', 'A3'),
    (4, 5, 4, 'EX-102', 'B1'),
    (5, 5, 5, 'EX-102', 'B2');

-- Student performance (quizzes and assignments)
INSERT INTO student_performance (performance_id, student_id, subject_id, assessment_name, marks_obtained, total_marks, assessment_date) VALUES
    (1, 1, 1, 'Quiz 1', 18, 20, '2026-09-25'),
    (2, 1, 2, 'Assignment 1', 25, 25, '2026-10-05'),
    (3, 2, 1, 'Quiz 1', 13, 20, '2026-09-25'),
    (4, 2, 2, 'Assignment 1', 19, 25, '2026-10-05'),
    (5, 3, 1, 'Quiz 1', 12, 20, '2026-09-25'),
    (6, 3, 2, 'Assignment 1', 12, 25, '2026-10-05'),
    (7, 4, 1, 'Quiz 1', 16, 20, '2026-09-25'),
    (8, 4, 2, 'Assignment 1', 15, 25, '2026-10-05'),
    (9, 5, 1, 'Quiz 1', 18, 20, '2026-09-25'),
    (10, 5, 2, 'Assignment 1', 25, 25, '2026-10-05');

COMMIT;

-- Quick check: list all tables
SHOW TABLES;
