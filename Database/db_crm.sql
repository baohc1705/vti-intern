-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Apr 10, 2026 at 03:37 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `db_crm`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_ConvertLeadToCustomer` (IN `p_lead_id` BIGINT, IN `p_user_id` BIGINT, OUT `p_customer_id` BIGINT, OUT `p_contact_id` BIGINT, OUT `p_opportunity_id` BIGINT)   BEGIN
    DECLARE v_contact_name VARCHAR(150); DECLARE v_company_name VARCHAR(200); DECLARE v_phone VARCHAR(20); DECLARE v_email VARCHAR(150); DECLARE v_address VARCHAR(255); DECLARE v_province_id INT; DECLARE v_tax_code VARCHAR(50); DECLARE v_expected_revenue DECIMAL(15,2); DECLARE v_source_id BIGINT; DECLARE v_assigned_to BIGINT; DECLARE v_is_converted TINYINT;
    DECLARE exit handler for sqlexception BEGIN ROLLBACK; RESIGNAL; END;

    SELECT contact_name, company_name, phone, email, address, province_id, tax_code, expected_revenue, source_id, assigned_to, is_converted INTO v_contact_name, v_company_name, v_phone, v_email, v_address, v_province_id, v_tax_code, v_expected_revenue, v_source_id, v_assigned_to, v_is_converted FROM leads WHERE id = p_lead_id AND deleted_at IS NULL;
    IF v_is_converted = 1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lead đã được chuyển đổi!'; END IF;

    START TRANSACTION;
    -- 1. Create Customer
    INSERT INTO customers (type, name, short_name, tax_code, phone, email, description, source_id, assigned_to, created_by) VALUES (IF(v_company_name IS NOT NULL AND v_company_name != '', 'B2B', 'B2C'), IFNULL(v_company_name, v_contact_name), IFNULL(v_company_name, v_contact_name), v_tax_code, v_phone, v_email, CONCAT('Convert từ Lead ID: ', p_lead_id), v_source_id, v_assigned_to, p_user_id);
    SET p_customer_id = LAST_INSERT_ID();
    
    -- 2. Create Address
    IF v_address IS NOT NULL OR v_province_id IS NOT NULL THEN INSERT INTO customer_addresses (customer_id, address_type, full_address, province_id, is_primary) VALUES (p_customer_id, 'HQ', IFNULL(v_address, ''), v_province_id, 1); END IF;
    
    -- 3. Create Contact
    INSERT INTO contacts (customer_id, full_name, phone, email, address, is_primary, created_by) VALUES (p_customer_id, v_contact_name, v_phone, v_email, v_address, 1, p_user_id);
    SET p_contact_id = LAST_INSERT_ID();
    
    -- 4. Create Opportunity
    INSERT INTO opportunities (name, customer_id, total_amount, expected_close_date, assigned_user_id, created_by) VALUES (CONCAT('Cơ hội từ ', IFNULL(v_company_name, v_contact_name)), p_customer_id, v_expected_revenue, DATE_ADD(CURRENT_DATE, INTERVAL 30 DAY), v_assigned_to, p_user_id);
    SET p_opportunity_id = LAST_INSERT_ID();
    
    -- 5. Update Lead
    UPDATE leads SET status = 'CONVERTED', is_converted = 1, converted_customer_id = p_customer_id, converted_contact_id = p_contact_id, converted_opportunity_id = p_opportunity_id, converted_at = NOW(), updated_by = p_user_id WHERE id = p_lead_id;
    
    -- 6. Transfer Links (Activities, Tasks, Attachments)
    UPDATE activities SET related_to_type = 'CUSTOMER', related_to_id = p_customer_id, updated_by = p_user_id WHERE related_to_type = 'LEAD' AND related_to_id = p_lead_id;
    UPDATE tasks SET related_to_type = 'CUSTOMER', related_to_id = p_customer_id, updated_by = p_user_id WHERE related_to_type = 'LEAD' AND related_to_id = p_lead_id;
    UPDATE attachments SET attachable_type = 'CUSTOMER', attachable_id = p_customer_id WHERE attachable_type = 'LEAD' AND attachable_id = p_lead_id;
    
    -- 7. Audit
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, changes) VALUES (p_user_id, 'CONVERT', 'LEADS', p_lead_id, JSON_OBJECT('new_customer_id', p_customer_id, 'new_opportunity_id', p_opportunity_id, 'new_contact_id', p_contact_id));
    
    COMMIT;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `activities`
--

CREATE TABLE `activities` (
  `id` bigint(20) NOT NULL,
  `activity_type` tinyint(4) NOT NULL,
  `subject` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `start_date` datetime DEFAULT NULL,
  `end_date` datetime DEFAULT NULL,
  `completed_at` datetime DEFAULT NULL,
  `outcome` varchar(100) DEFAULT NULL,
  `related_to_type` varchar(50) NOT NULL,
  `related_to_id` bigint(20) NOT NULL,
  `performed_by` bigint(20) NOT NULL,
  `created_by` bigint(20) DEFAULT NULL,
  `updated_by` bigint(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `status` tinyint(4) DEFAULT NULL,
  `is_important` tinyint(1) DEFAULT 0,
  `deleted_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `attachments`
--

CREATE TABLE `attachments` (
  `id` bigint(20) NOT NULL,
  `file_name` varchar(255) NOT NULL,
  `file_url` varchar(500) NOT NULL,
  `file_type` varchar(50) DEFAULT NULL,
  `file_size` int(11) DEFAULT NULL,
  `attachable_type` enum('LEAD','CUSTOMER','OPPORTUNITY','CONTRACT','PRODUCT','ACTIVITY','TASK','FEEDBACK') NOT NULL,
  `attachable_id` bigint(20) NOT NULL,
  `uploaded_by` bigint(20) NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `audit_logs`
--

CREATE TABLE `audit_logs` (
  `id` bigint(20) NOT NULL,
  `user_id` bigint(20) NOT NULL,
  `action` varchar(50) NOT NULL COMMENT 'CREATE, UPDATE, DELETE, CONVERT',
  `entity_type` varchar(100) NOT NULL COMMENT 'LEADS, QUOTES, CUSTOMERS...',
  `entity_id` bigint(20) NOT NULL,
  `changes` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Lưu dạng JSON: {"field": {"old": 1, "new": 2}}' CHECK (json_valid(`changes`)),
  `ip_address` varchar(45) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `campaigns`
--

CREATE TABLE `campaigns` (
  `id` bigint(20) NOT NULL,
  `name` varchar(255) NOT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `categories`
--

CREATE TABLE `categories` (
  `id` bigint(20) NOT NULL,
  `name` varchar(255) NOT NULL,
  `description` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `contacts`
--

CREATE TABLE `contacts` (
  `id` bigint(20) NOT NULL,
  `customer_id` bigint(20) NOT NULL,
  `full_name` varchar(50) DEFAULT NULL,
  `position` varchar(100) DEFAULT NULL,
  `phone` varchar(10) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `address` varchar(500) DEFAULT NULL,
  `dob` date DEFAULT NULL,
  `notes` varchar(500) DEFAULT NULL,
  `is_primary` tinyint(1) DEFAULT 0,
  `created_by` bigint(20) DEFAULT NULL,
  `updated_by` bigint(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `deleted_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `contacts`
--

INSERT INTO `contacts` (`id`, `customer_id`, `full_name`, `position`, `phone`, `email`, `address`, `dob`, `notes`, `is_primary`, `created_by`, `updated_by`, `created_at`, `updated_at`, `is_active`, `deleted_at`) VALUES
(1, 1, 'Trịnh Công Sơn', 'Giám đốc Kỹ thuật', '0908111223', 'son.trinh@softx.vn', 'ấp Chiến Thắng', '2026-03-31', 'Giám đốc', 1, NULL, NULL, NULL, '2026-04-10 07:23:46', 1, NULL),
(20, 1, 'Huynh Chi Bao', 'Nhân viên', '0337778965', 'chibao@gmail.com', 'ấp Chiến Thắng', '2026-04-03', '11111111', 1, 1, NULL, '2026-04-10 02:27:23', '2026-04-10 02:27:23', 1, NULL),
(27, 3, 'Testa', 'Testa', '0999999999', 'Testa@gmail.com', 'ấp Chiến Thắng', '1996-04-10', 'Testa', 0, NULL, NULL, NULL, '2026-04-10 07:33:46', 0, '2026-04-10 07:33:46'),
(28, 2, 'testatesta', 'testatesta', '0999999999', 'Testa@gmail.com', 'ấp Chiến Thắng', '1996-04-10', 'testa', 1, 1, NULL, '2026-04-10 05:09:18', '2026-04-10 05:09:18', 1, NULL),
(31, 3, 'testa', 'testa', '0999999999', 'Testa@gmail.com', 'ấp Chiến Thắng', '1996-04-10', 'testa', 1, NULL, NULL, NULL, '2026-04-10 05:10:52', 1, NULL),
(32, 2, 'testc', 'Lead', '0999999999', 'Testa@gmail.com', 'ấp Chiến Thắng', '1996-04-10', 'testctestc', 1, 1, NULL, '2026-04-10 05:11:36', '2026-04-10 05:11:36', 1, NULL),
(33, 1, 'testctestc', 'testc', '0999999999', 'Testa@gmail.com', 'ấp Chiến Thắng', '1996-04-10', 'testc', 1, 1, NULL, '2026-04-10 05:11:55', '2026-04-10 07:33:46', 0, '2026-04-10 07:33:46'),
(34, 1, 'Huỳnh Chí Bảo', 'Thư ký', '0999999999', 'chibao@gmail.com', 'ấp chiến thắng', '1990-04-08', 'test', 1, 1, NULL, '2026-04-10 08:37:53', '2026-04-10 08:37:53', 1, NULL),
(35, 2, 'Huỳnh Văn Tý', 'Thư ký', '0999999999', 'chibao@gmail.com', 'Ấp Chiến Thắng', '1990-04-08', 'Đây là ghi chú', 1, 1, NULL, '2026-04-10 09:21:28', '2026-04-10 09:21:28', 1, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `contracts`
--

CREATE TABLE `contracts` (
  `id` bigint(20) NOT NULL,
  `contract_number` varchar(50) DEFAULT NULL,
  `customer_id` bigint(20) DEFAULT NULL,
  `quote_id` bigint(20) DEFAULT NULL,
  `template_id` bigint(20) DEFAULT NULL,
  `contract_value` decimal(15,2) DEFAULT NULL,
  `currency_code` varchar(10) DEFAULT 'VND',
  `exchange_rate` decimal(10,4) DEFAULT 1.0000,
  `status` enum('DRAFT','SIGNED','ACTIVE','COMPLETED','CANCELLED') DEFAULT 'DRAFT',
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `owner_id` bigint(20) DEFAULT NULL,
  `created_by` bigint(20) DEFAULT NULL,
  `updated_by` bigint(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `customers`
--

CREATE TABLE `customers` (
  `id` bigint(20) NOT NULL,
  `parent_id` bigint(20) DEFAULT NULL,
  `customer_code` varchar(50) DEFAULT NULL,
  `type` enum('B2B','B2C') DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `short_name` varchar(100) DEFAULT NULL,
  `tax_code` varchar(50) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `fax` varchar(50) DEFAULT NULL,
  `established_date` date DEFAULT NULL,
  `description` text DEFAULT NULL,
  `source_id` bigint(20) DEFAULT NULL,
  `status_id` bigint(20) DEFAULT NULL,
  `tier_id` bigint(20) DEFAULT NULL,
  `assigned_to` bigint(20) DEFAULT NULL,
  `created_by` bigint(20) DEFAULT NULL,
  `updated_by` bigint(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `customers`
--

INSERT INTO `customers` (`id`, `parent_id`, `customer_code`, `type`, `name`, `short_name`, `tax_code`, `phone`, `email`, `fax`, `established_date`, `description`, `source_id`, `status_id`, `tier_id`, `assigned_to`, `created_by`, `updated_by`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, NULL, NULL, 'B2B', 'Công ty Giải pháp Phần mềm X', NULL, NULL, '0281234567', 'info@softx.vn', NULL, NULL, NULL, 2, NULL, NULL, 2, 1, NULL, '2026-04-08 08:14:46', '2026-04-08 08:14:46', NULL),
(2, NULL, NULL, 'B2B', 'Công ty ABC', 'ABC Corp', NULL, '0999999999', 'abc@gmail.com', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-04-10 04:41:08', '2026-04-10 04:43:02', NULL),
(3, NULL, NULL, NULL, 'Công ty XYZ', 'XYZ', NULL, '0835350867', 'xyz@gmail.com', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-04-10 04:42:37', '2026-04-10 04:42:37', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `customer_addresses`
--

CREATE TABLE `customer_addresses` (
  `id` bigint(20) NOT NULL,
  `customer_id` bigint(20) NOT NULL,
  `address_type` enum('HQ','BILLING','SHIPPING','OTHER') DEFAULT 'HQ',
  `full_address` varchar(500) NOT NULL,
  `province_id` int(11) DEFAULT NULL,
  `is_primary` tinyint(1) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `customer_addresses`
--

INSERT INTO `customer_addresses` (`id`, `customer_id`, `address_type`, `full_address`, `province_id`, `is_primary`) VALUES
(1, 1, 'HQ', '123 Đường số 1, Quận 1', 1, 1);

-- --------------------------------------------------------

--
-- Table structure for table `document_templates`
--

CREATE TABLE `document_templates` (
  `id` bigint(20) NOT NULL,
  `type` enum('QUOTE','CONTRACT','INVOICE') NOT NULL,
  `name` varchar(255) NOT NULL,
  `content_html` longtext NOT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `feedbacks`
--

CREATE TABLE `feedbacks` (
  `id` bigint(20) NOT NULL,
  `customer_id` bigint(20) NOT NULL,
  `subject` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `priority` enum('LOW','NORMAL','HIGH','URGENT') DEFAULT 'NORMAL',
  `status` enum('OPEN','IN_PROGRESS','RESOLVED','CLOSED') DEFAULT 'OPEN',
  `assigned_to` bigint(20) DEFAULT NULL,
  `created_by` bigint(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `invoices`
--

CREATE TABLE `invoices` (
  `id` bigint(20) NOT NULL,
  `invoice_number` varchar(50) DEFAULT NULL,
  `customer_id` bigint(20) DEFAULT NULL,
  `order_id` bigint(20) DEFAULT NULL,
  `template_id` bigint(20) DEFAULT NULL,
  `total_amount` decimal(15,2) DEFAULT NULL,
  `currency_code` varchar(10) DEFAULT 'VND',
  `exchange_rate` decimal(10,4) DEFAULT 1.0000,
  `issue_date` date DEFAULT NULL,
  `due_date` date DEFAULT NULL,
  `status` enum('DRAFT','SENT','PAID','OVERDUE','CANCELLED') DEFAULT 'DRAFT',
  `created_by` bigint(20) DEFAULT NULL,
  `updated_by` bigint(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `invoice_line_items`
--

CREATE TABLE `invoice_line_items` (
  `id` bigint(20) NOT NULL,
  `invoice_id` bigint(20) NOT NULL,
  `product_id` bigint(20) NOT NULL,
  `quantity` int(11) NOT NULL,
  `unit_price` decimal(18,2) NOT NULL,
  `total_price` decimal(18,2) GENERATED ALWAYS AS (`quantity` * `unit_price`) STORED,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `kpi_configs`
--

CREATE TABLE `kpi_configs` (
  `id` bigint(20) NOT NULL,
  `name` varchar(255) NOT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `status` enum('ACTIVE','INACTIVE') DEFAULT 'ACTIVE',
  `description` text DEFAULT NULL,
  `created_by` bigint(20) DEFAULT NULL,
  `updated_by` bigint(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `kpi_targets`
--

CREATE TABLE `kpi_targets` (
  `id` bigint(20) NOT NULL,
  `kpi_config_id` bigint(20) NOT NULL,
  `metric_type` varchar(100) DEFAULT NULL,
  `target_value` decimal(15,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `leads`
--

CREATE TABLE `leads` (
  `id` bigint(20) NOT NULL,
  `contact_name` varchar(150) NOT NULL,
  `company_name` varchar(200) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `email` varchar(150) DEFAULT NULL,
  `address` varchar(255) DEFAULT NULL,
  `website` varchar(255) DEFAULT NULL,
  `tax_code` varchar(50) DEFAULT NULL,
  `citizen_id` varchar(20) DEFAULT NULL,
  `province_id` int(11) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `expected_revenue` decimal(15,2) DEFAULT NULL,
  `status` enum('NEW','CONTACTING','CONVERTED','LOST') DEFAULT 'NEW',
  `source_id` bigint(20) DEFAULT NULL,
  `campaign_id` bigint(20) DEFAULT NULL,
  `organization_id` bigint(20) DEFAULT NULL,
  `assigned_to` bigint(20) DEFAULT NULL,
  `is_converted` tinyint(1) DEFAULT 0,
  `converted_customer_id` bigint(20) DEFAULT NULL,
  `converted_contact_id` bigint(20) DEFAULT NULL,
  `converted_opportunity_id` bigint(20) DEFAULT NULL,
  `converted_at` datetime DEFAULT NULL,
  `created_by` bigint(20) DEFAULT NULL,
  `updated_by` bigint(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `lead_product_interests`
--

CREATE TABLE `lead_product_interests` (
  `lead_id` bigint(20) NOT NULL,
  `product_id` bigint(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `loss_reasons`
--

CREATE TABLE `loss_reasons` (
  `id` bigint(20) NOT NULL,
  `name` varchar(255) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `menus`
--

CREATE TABLE `menus` (
  `id` bigint(20) NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `parent_id` bigint(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `notes`
--

CREATE TABLE `notes` (
  `id` bigint(20) NOT NULL,
  `content` text NOT NULL,
  `created_date` timestamp NULL DEFAULT current_timestamp(),
  `notable_type` varchar(50) NOT NULL,
  `notable_id` bigint(20) NOT NULL,
  `created_by` bigint(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `notes`
--

INSERT INTO `notes` (`id`, `content`, `created_date`, `notable_type`, `notable_id`, `created_by`) VALUES
(1, 'Khách hàng yêu cầu hỗ trợ sau 2h chiều', '2026-04-08 08:14:54', 'CONTACTS', 1, 2);

-- --------------------------------------------------------

--
-- Table structure for table `opportunities`
--

CREATE TABLE `opportunities` (
  `id` bigint(20) NOT NULL,
  `name` varchar(255) NOT NULL,
  `customer_id` bigint(20) DEFAULT NULL,
  `pipeline_id` bigint(20) DEFAULT NULL,
  `stage_id` bigint(20) DEFAULT NULL,
  `total_amount` decimal(15,2) DEFAULT NULL,
  `deposit_amount` decimal(15,2) DEFAULT NULL,
  `remaining_amount` decimal(15,2) DEFAULT NULL,
  `currency_code` varchar(10) DEFAULT 'VND',
  `exchange_rate` decimal(10,4) DEFAULT 1.0000,
  `expected_close_date` date DEFAULT NULL,
  `loss_reason_id` bigint(20) DEFAULT NULL,
  `health_status` enum('ON_TRACK','AT_RISK','OFF_TRACK') DEFAULT 'ON_TRACK',
  `assigned_user_id` bigint(20) DEFAULT NULL,
  `created_by` bigint(20) DEFAULT NULL,
  `updated_by` bigint(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `orders`
--

CREATE TABLE `orders` (
  `id` bigint(20) NOT NULL,
  `order_number` varchar(50) DEFAULT NULL,
  `customer_id` bigint(20) DEFAULT NULL,
  `opportunity_id` bigint(20) DEFAULT NULL,
  `total_amount` decimal(15,2) DEFAULT NULL,
  `currency_code` varchar(10) DEFAULT 'VND',
  `exchange_rate` decimal(10,4) DEFAULT 1.0000,
  `status` enum('DRAFT','CONFIRMED','PROCESSING','COMPLETED','CANCELLED') DEFAULT 'DRAFT',
  `created_by` bigint(20) DEFAULT NULL,
  `updated_by` bigint(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `order_line_items`
--

CREATE TABLE `order_line_items` (
  `id` bigint(20) NOT NULL,
  `order_id` bigint(20) NOT NULL,
  `product_id` bigint(20) NOT NULL,
  `quantity` int(11) NOT NULL,
  `unit_price` decimal(18,2) NOT NULL,
  `total_price` decimal(18,2) GENERATED ALWAYS AS (`quantity` * `unit_price`) STORED,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `organizations`
--

CREATE TABLE `organizations` (
  `id` bigint(20) NOT NULL,
  `name` varchar(255) NOT NULL,
  `parent_id` bigint(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `organizations`
--

INSERT INTO `organizations` (`id`, `name`, `parent_id`, `created_at`, `updated_at`) VALUES
(1, 'Tổng Công Ty CRM', NULL, '2026-04-08 08:14:29', '2026-04-08 08:14:29');

-- --------------------------------------------------------

--
-- Table structure for table `pipelines`
--

CREATE TABLE `pipelines` (
  `id` bigint(20) NOT NULL,
  `name` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `pipeline_stages`
--

CREATE TABLE `pipeline_stages` (
  `id` bigint(20) NOT NULL,
  `pipeline_id` bigint(20) NOT NULL,
  `stage_name` varchar(255) NOT NULL,
  `probability` int(11) DEFAULT NULL,
  `max_days_allowed` int(11) DEFAULT NULL COMMENT 'SLA cảnh báo ngâm Deal',
  `sort_order` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `products`
--

CREATE TABLE `products` (
  `id` bigint(20) NOT NULL,
  `sku_code` varchar(100) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `type` enum('PRODUCT','SERVICE') NOT NULL DEFAULT 'PRODUCT',
  `category_id` bigint(20) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_by` bigint(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `product_prices`
--

CREATE TABLE `product_prices` (
  `id` bigint(20) NOT NULL,
  `product_id` bigint(20) NOT NULL,
  `base_price` decimal(15,2) DEFAULT NULL,
  `tax_rate` decimal(5,2) DEFAULT NULL,
  `final_price` decimal(15,2) DEFAULT NULL,
  `currency_code` varchar(10) DEFAULT 'VND',
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `provinces`
--

CREATE TABLE `provinces` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `code` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `provinces`
--

INSERT INTO `provinces` (`id`, `name`, `code`) VALUES
(1, 'Thành phố Hồ Chí Minh', 'HCM'),
(2, 'Thành phố Hà Nội', 'HN');

-- --------------------------------------------------------

--
-- Table structure for table `quotes`
--

CREATE TABLE `quotes` (
  `id` bigint(20) NOT NULL,
  `quote_number` varchar(50) DEFAULT NULL,
  `customer_id` bigint(20) DEFAULT NULL,
  `opportunity_id` bigint(20) DEFAULT NULL,
  `status_id` bigint(20) DEFAULT NULL,
  `total_amount` decimal(15,2) DEFAULT 0.00,
  `currency_code` varchar(10) DEFAULT 'VND',
  `exchange_rate` decimal(10,4) DEFAULT 1.0000,
  `valid_until` date DEFAULT NULL,
  `template_id` bigint(20) DEFAULT NULL,
  `created_by` bigint(20) DEFAULT NULL,
  `updated_by` bigint(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `quote_line_items`
--

CREATE TABLE `quote_line_items` (
  `id` bigint(20) NOT NULL,
  `quote_id` bigint(20) NOT NULL,
  `product_id` bigint(20) DEFAULT NULL,
  `quantity` int(11) NOT NULL,
  `unit_price` decimal(15,2) NOT NULL,
  `discount_value` decimal(15,2) DEFAULT 0.00,
  `line_total` decimal(15,2) GENERATED ALWAYS AS (`quantity` * `unit_price` - `discount_value`) STORED
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Triggers `quote_line_items`
--
DELIMITER $$
CREATE TRIGGER `trg_qli_after_delete` AFTER DELETE ON `quote_line_items` FOR EACH ROW BEGIN UPDATE quotes q SET q.total_amount = (SELECT IFNULL(SUM(line_total), 0) FROM quote_line_items WHERE quote_id = OLD.quote_id) WHERE q.id = OLD.quote_id; END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_qli_after_insert` AFTER INSERT ON `quote_line_items` FOR EACH ROW BEGIN UPDATE quotes q SET q.total_amount = (SELECT IFNULL(SUM(line_total), 0) FROM quote_line_items WHERE quote_id = NEW.quote_id) WHERE q.id = NEW.quote_id; END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_qli_after_update` AFTER UPDATE ON `quote_line_items` FOR EACH ROW BEGIN UPDATE quotes q SET q.total_amount = (SELECT IFNULL(SUM(line_total), 0) FROM quote_line_items WHERE quote_id = OLD.quote_id) WHERE q.id = OLD.quote_id; IF NEW.quote_id <> OLD.quote_id THEN UPDATE quotes q SET q.total_amount = (SELECT IFNULL(SUM(line_total), 0) FROM quote_line_items WHERE quote_id = NEW.quote_id) WHERE q.id = NEW.quote_id; END IF; END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `roles`
--

CREATE TABLE `roles` (
  `id` bigint(20) NOT NULL,
  `name` varchar(50) NOT NULL,
  `description` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `roles`
--

INSERT INTO `roles` (`id`, `name`, `description`) VALUES
(1, 'Administrator', 'Quản trị hệ thống toàn quyền'),
(2, 'Sales Manager', 'Quản lý kinh doanh');

-- --------------------------------------------------------

--
-- Table structure for table `role_menu_permissions`
--

CREATE TABLE `role_menu_permissions` (
  `role_id` bigint(20) NOT NULL,
  `menu_id` bigint(20) NOT NULL,
  `can_view` tinyint(1) DEFAULT 0,
  `can_create` tinyint(1) DEFAULT 0,
  `can_update` tinyint(1) DEFAULT 0,
  `can_delete` tinyint(1) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `stage_checklists`
--

CREATE TABLE `stage_checklists` (
  `id` bigint(20) NOT NULL,
  `stage_id` bigint(20) NOT NULL,
  `task_name` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `is_mandatory` tinyint(1) DEFAULT 1,
  `sort_order` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `sys_configs`
--

CREATE TABLE `sys_configs` (
  `id` int(11) NOT NULL,
  `config_key` varchar(100) NOT NULL COMMENT 'timezone, language, default_currency, smtp_server...',
  `config_value` text DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `sys_customer_statuses`
--

CREATE TABLE `sys_customer_statuses` (
  `id` bigint(20) NOT NULL,
  `code` varchar(50) DEFAULT NULL,
  `name` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `sys_customer_tiers`
--

CREATE TABLE `sys_customer_tiers` (
  `id` bigint(20) NOT NULL,
  `code` varchar(50) DEFAULT NULL,
  `name` varchar(100) DEFAULT NULL,
  `min_spending` decimal(15,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `sys_lead_sources`
--

CREATE TABLE `sys_lead_sources` (
  `id` bigint(20) NOT NULL,
  `name` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `sys_lead_sources`
--

INSERT INTO `sys_lead_sources` (`id`, `name`) VALUES
(1, 'Facebook Marketing'),
(2, 'Website Hotline');

-- --------------------------------------------------------

--
-- Table structure for table `target_assignments`
--

CREATE TABLE `target_assignments` (
  `id` bigint(20) NOT NULL,
  `kpi_config_id` bigint(20) NOT NULL,
  `user_id` bigint(20) DEFAULT NULL COMMENT 'Áp dụng cho Cá nhân',
  `organization_id` bigint(20) DEFAULT NULL COMMENT 'Áp dụng cho Nhóm/Phòng ban',
  `commission_percent` decimal(5,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `tasks`
--

CREATE TABLE `tasks` (
  `id` bigint(20) NOT NULL,
  `subject` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `start_date` datetime DEFAULT NULL,
  `due_date` datetime NOT NULL,
  `completed_at` datetime DEFAULT NULL,
  `status` enum('NOT_STARTED','IN_PROGRESS','WAITING','COMPLETED','DEFERRED') DEFAULT 'NOT_STARTED',
  `priority` enum('LOW','NORMAL','HIGH','URGENT') DEFAULT 'NORMAL',
  `progress_percent` int(11) DEFAULT 0,
  `related_to_type` varchar(50) DEFAULT NULL,
  `related_to_id` bigint(20) DEFAULT NULL,
  `assigned_to` bigint(20) NOT NULL,
  `assigned_by` bigint(20) NOT NULL,
  `created_by` bigint(20) DEFAULT NULL,
  `updated_by` bigint(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL,
  `contact_id` bigint(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `tasks`
--

INSERT INTO `tasks` (`id`, `subject`, `description`, `start_date`, `due_date`, `completed_at`, `status`, `priority`, `progress_percent`, `related_to_type`, `related_to_id`, `assigned_to`, `assigned_by`, `created_by`, `updated_by`, `created_at`, `updated_at`, `deleted_at`, `contact_id`) VALUES
(1, 'Gửi hợp đồng bảo trì', NULL, NULL, '2026-04-20 17:00:00', NULL, 'NOT_STARTED', 'HIGH', 0, 'CUSTOMER', 1, 2, 1, NULL, NULL, '2026-04-08 08:14:54', '2026-04-08 08:14:54', NULL, 1);

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` bigint(20) NOT NULL,
  `username` varchar(100) NOT NULL,
  `password` varchar(255) NOT NULL,
  `email` varchar(150) DEFAULT NULL,
  `full_name` varchar(255) DEFAULT NULL,
  `role_id` bigint(20) NOT NULL,
  `organization_id` bigint(20) NOT NULL,
  `status` enum('ACTIVE','INACTIVE','LOCKED') DEFAULT 'ACTIVE',
  `ui_preferences` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Cấu hình UI Dashboard cá nhân' CHECK (json_valid(`ui_preferences`)),
  `last_login` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `username`, `password`, `email`, `full_name`, `role_id`, `organization_id`, `status`, `ui_preferences`, `last_login`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 'admin_super', 'secure_hash_1', 'admin@example.com', 'Nguyễn Văn Admin', 1, 1, 'ACTIVE', NULL, NULL, '2026-04-08 08:14:38', '2026-04-08 08:14:38', NULL),
(2, 'sale_pro_01', 'secure_hash_2', 'sale01@example.com', 'Trần Thị Sale', 2, 1, 'ACTIVE', NULL, NULL, '2026-04-08 08:14:38', '2026-04-08 08:14:38', NULL);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `activities`
--
ALTER TABLE `activities`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_activity_polymorphic` (`related_to_type`,`related_to_id`),
  ADD KEY `fk_act_user` (`performed_by`);

--
-- Indexes for table `attachments`
--
ALTER TABLE `attachments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_attachable` (`attachable_type`,`attachable_id`),
  ADD KEY `fk_attach_user` (`uploaded_by`);

--
-- Indexes for table `audit_logs`
--
ALTER TABLE `audit_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_audit_entity` (`entity_type`,`entity_id`),
  ADD KEY `idx_audit_user` (`user_id`);

--
-- Indexes for table `campaigns`
--
ALTER TABLE `campaigns`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `categories`
--
ALTER TABLE `categories`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `contacts`
--
ALTER TABLE `contacts`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_contact_cust` (`customer_id`),
  ADD KEY `idx_contact_active` (`is_active`),
  ADD KEY `idx_contact_fullname` (`full_name`);

--
-- Indexes for table `contracts`
--
ALTER TABLE `contracts`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `contract_number` (`contract_number`),
  ADD KEY `fk_contract_cust` (`customer_id`),
  ADD KEY `fk_contracts_template` (`template_id`);

--
-- Indexes for table `customers`
--
ALTER TABLE `customers`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `customer_code` (`customer_code`),
  ADD KEY `idx_cus_dashboard` (`assigned_to`,`status_id`),
  ADD KEY `fk_cust_parent` (`parent_id`);

--
-- Indexes for table `customer_addresses`
--
ALTER TABLE `customer_addresses`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_address_customer` (`customer_id`);

--
-- Indexes for table `document_templates`
--
ALTER TABLE `document_templates`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `feedbacks`
--
ALTER TABLE `feedbacks`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_fb_cust` (`customer_id`),
  ADD KEY `fk_fb_assign` (`assigned_to`);

--
-- Indexes for table `invoices`
--
ALTER TABLE `invoices`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `invoice_number` (`invoice_number`),
  ADD KEY `fk_inv_cust` (`customer_id`),
  ADD KEY `fk_invoices_template` (`template_id`);

--
-- Indexes for table `invoice_line_items`
--
ALTER TABLE `invoice_line_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_ili_invoice` (`invoice_id`),
  ADD KEY `fk_ili_product` (`product_id`);

--
-- Indexes for table `kpi_configs`
--
ALTER TABLE `kpi_configs`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `kpi_targets`
--
ALTER TABLE `kpi_targets`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_kpit_conf` (`kpi_config_id`);

--
-- Indexes for table `leads`
--
ALTER TABLE `leads`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_lead_phone` (`phone`),
  ADD KEY `idx_lead_dashboard` (`assigned_to`,`status`),
  ADD KEY `fk_lead_org` (`organization_id`),
  ADD KEY `fk_lead_conv_cust` (`converted_customer_id`),
  ADD KEY `fk_leads_campaign` (`campaign_id`),
  ADD KEY `fk_leads_province` (`province_id`);

--
-- Indexes for table `lead_product_interests`
--
ALTER TABLE `lead_product_interests`
  ADD PRIMARY KEY (`lead_id`,`product_id`),
  ADD KEY `fk_lpi_prod` (`product_id`);

--
-- Indexes for table `loss_reasons`
--
ALTER TABLE `loss_reasons`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `menus`
--
ALTER TABLE `menus`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_menu_parent` (`parent_id`);

--
-- Indexes for table `notes`
--
ALTER TABLE `notes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_note_polymorphic` (`notable_type`,`notable_id`,`created_date`),
  ADD KEY `idx_note_created` (`created_by`);

--
-- Indexes for table `opportunities`
--
ALTER TABLE `opportunities`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_opp_dashboard` (`assigned_user_id`,`stage_id`),
  ADD KEY `fk_opp_cust` (`customer_id`),
  ADD KEY `fk_opp_stage` (`stage_id`),
  ADD KEY `fk_opp_loss` (`loss_reason_id`);

--
-- Indexes for table `orders`
--
ALTER TABLE `orders`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `order_number` (`order_number`),
  ADD KEY `fk_order_cust` (`customer_id`);

--
-- Indexes for table `order_line_items`
--
ALTER TABLE `order_line_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_oli_order` (`order_id`),
  ADD KEY `fk_oli_product` (`product_id`);

--
-- Indexes for table `organizations`
--
ALTER TABLE `organizations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_org_parent` (`parent_id`);

--
-- Indexes for table `pipelines`
--
ALTER TABLE `pipelines`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `pipeline_stages`
--
ALTER TABLE `pipeline_stages`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_stage_pipe` (`pipeline_id`);

--
-- Indexes for table `products`
--
ALTER TABLE `products`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_product_sku` (`sku_code`),
  ADD KEY `fk_prod_cat` (`category_id`);

--
-- Indexes for table `product_prices`
--
ALTER TABLE `product_prices`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_price_prod` (`product_id`);

--
-- Indexes for table `provinces`
--
ALTER TABLE `provinces`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `quotes`
--
ALTER TABLE `quotes`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `quote_number` (`quote_number`),
  ADD KEY `fk_quote_cust` (`customer_id`),
  ADD KEY `fk_quotes_template` (`template_id`);

--
-- Indexes for table `quote_line_items`
--
ALTER TABLE `quote_line_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_qli_quote` (`quote_id`),
  ADD KEY `fk_qli_prod` (`product_id`);

--
-- Indexes for table `roles`
--
ALTER TABLE `roles`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `name` (`name`);

--
-- Indexes for table `role_menu_permissions`
--
ALTER TABLE `role_menu_permissions`
  ADD PRIMARY KEY (`role_id`,`menu_id`),
  ADD KEY `menu_id` (`menu_id`);

--
-- Indexes for table `stage_checklists`
--
ALTER TABLE `stage_checklists`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_check_stage` (`stage_id`);

--
-- Indexes for table `sys_configs`
--
ALTER TABLE `sys_configs`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_config_key` (`config_key`);

--
-- Indexes for table `sys_customer_statuses`
--
ALTER TABLE `sys_customer_statuses`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `sys_customer_tiers`
--
ALTER TABLE `sys_customer_tiers`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `sys_lead_sources`
--
ALTER TABLE `sys_lead_sources`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `target_assignments`
--
ALTER TABLE `target_assignments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_ta_conf` (`kpi_config_id`),
  ADD KEY `fk_ta_user` (`user_id`),
  ADD KEY `fk_ta_org` (`organization_id`);

--
-- Indexes for table `tasks`
--
ALTER TABLE `tasks`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_task_assignee` (`assigned_to`),
  ADD KEY `idx_task_polymorphic` (`related_to_type`,`related_to_id`),
  ADD KEY `fk_task_assigner` (`assigned_by`),
  ADD KEY `fk_tasks_contact` (`contact_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`),
  ADD UNIQUE KEY `email` (`email`),
  ADD KEY `idx_user_role` (`role_id`),
  ADD KEY `idx_user_org` (`organization_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `activities`
--
ALTER TABLE `activities`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `attachments`
--
ALTER TABLE `attachments`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `audit_logs`
--
ALTER TABLE `audit_logs`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `campaigns`
--
ALTER TABLE `campaigns`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `categories`
--
ALTER TABLE `categories`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `contacts`
--
ALTER TABLE `contacts`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=36;

--
-- AUTO_INCREMENT for table `contracts`
--
ALTER TABLE `contracts`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `customers`
--
ALTER TABLE `customers`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `customer_addresses`
--
ALTER TABLE `customer_addresses`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `document_templates`
--
ALTER TABLE `document_templates`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `feedbacks`
--
ALTER TABLE `feedbacks`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `invoices`
--
ALTER TABLE `invoices`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `invoice_line_items`
--
ALTER TABLE `invoice_line_items`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `kpi_configs`
--
ALTER TABLE `kpi_configs`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `kpi_targets`
--
ALTER TABLE `kpi_targets`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `leads`
--
ALTER TABLE `leads`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `loss_reasons`
--
ALTER TABLE `loss_reasons`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `menus`
--
ALTER TABLE `menus`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `notes`
--
ALTER TABLE `notes`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `opportunities`
--
ALTER TABLE `opportunities`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `orders`
--
ALTER TABLE `orders`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `order_line_items`
--
ALTER TABLE `order_line_items`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `organizations`
--
ALTER TABLE `organizations`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `pipelines`
--
ALTER TABLE `pipelines`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `pipeline_stages`
--
ALTER TABLE `pipeline_stages`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `products`
--
ALTER TABLE `products`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `product_prices`
--
ALTER TABLE `product_prices`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `provinces`
--
ALTER TABLE `provinces`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `quotes`
--
ALTER TABLE `quotes`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `quote_line_items`
--
ALTER TABLE `quote_line_items`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `roles`
--
ALTER TABLE `roles`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `stage_checklists`
--
ALTER TABLE `stage_checklists`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `sys_configs`
--
ALTER TABLE `sys_configs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `sys_customer_statuses`
--
ALTER TABLE `sys_customer_statuses`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `sys_customer_tiers`
--
ALTER TABLE `sys_customer_tiers`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `sys_lead_sources`
--
ALTER TABLE `sys_lead_sources`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `target_assignments`
--
ALTER TABLE `target_assignments`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `tasks`
--
ALTER TABLE `tasks`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `activities`
--
ALTER TABLE `activities`
  ADD CONSTRAINT `fk_act_user` FOREIGN KEY (`performed_by`) REFERENCES `users` (`id`);

--
-- Constraints for table `attachments`
--
ALTER TABLE `attachments`
  ADD CONSTRAINT `fk_attach_user` FOREIGN KEY (`uploaded_by`) REFERENCES `users` (`id`);

--
-- Constraints for table `contacts`
--
ALTER TABLE `contacts`
  ADD CONSTRAINT `fk_contact_cust` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `contracts`
--
ALTER TABLE `contracts`
  ADD CONSTRAINT `fk_contract_cust` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_contracts_template` FOREIGN KEY (`template_id`) REFERENCES `document_templates` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `customers`
--
ALTER TABLE `customers`
  ADD CONSTRAINT `fk_cust_assign` FOREIGN KEY (`assigned_to`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_cust_parent` FOREIGN KEY (`parent_id`) REFERENCES `customers` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `customer_addresses`
--
ALTER TABLE `customer_addresses`
  ADD CONSTRAINT `fk_addr_cust` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `feedbacks`
--
ALTER TABLE `feedbacks`
  ADD CONSTRAINT `fk_fb_assign` FOREIGN KEY (`assigned_to`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_fb_cust` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `invoices`
--
ALTER TABLE `invoices`
  ADD CONSTRAINT `fk_inv_cust` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_invoices_template` FOREIGN KEY (`template_id`) REFERENCES `document_templates` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `kpi_targets`
--
ALTER TABLE `kpi_targets`
  ADD CONSTRAINT `fk_kpit_conf` FOREIGN KEY (`kpi_config_id`) REFERENCES `kpi_configs` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `leads`
--
ALTER TABLE `leads`
  ADD CONSTRAINT `fk_lead_assign` FOREIGN KEY (`assigned_to`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_lead_conv_cust` FOREIGN KEY (`converted_customer_id`) REFERENCES `customers` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_lead_org` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_leads_campaign` FOREIGN KEY (`campaign_id`) REFERENCES `campaigns` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_leads_province` FOREIGN KEY (`province_id`) REFERENCES `provinces` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `lead_product_interests`
--
ALTER TABLE `lead_product_interests`
  ADD CONSTRAINT `fk_lpi_lead` FOREIGN KEY (`lead_id`) REFERENCES `leads` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_lpi_prod` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `menus`
--
ALTER TABLE `menus`
  ADD CONSTRAINT `fk_menu_parent` FOREIGN KEY (`parent_id`) REFERENCES `menus` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `notes`
--
ALTER TABLE `notes`
  ADD CONSTRAINT `fk_note_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `opportunities`
--
ALTER TABLE `opportunities`
  ADD CONSTRAINT `fk_opp_cust` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`),
  ADD CONSTRAINT `fk_opp_loss` FOREIGN KEY (`loss_reason_id`) REFERENCES `loss_reasons` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_opp_stage` FOREIGN KEY (`stage_id`) REFERENCES `pipeline_stages` (`id`);

--
-- Constraints for table `orders`
--
ALTER TABLE `orders`
  ADD CONSTRAINT `fk_order_cust` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`);

--
-- Constraints for table `organizations`
--
ALTER TABLE `organizations`
  ADD CONSTRAINT `fk_org_parent` FOREIGN KEY (`parent_id`) REFERENCES `organizations` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `pipeline_stages`
--
ALTER TABLE `pipeline_stages`
  ADD CONSTRAINT `fk_stage_pipe` FOREIGN KEY (`pipeline_id`) REFERENCES `pipelines` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `products`
--
ALTER TABLE `products`
  ADD CONSTRAINT `fk_prod_cat` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `product_prices`
--
ALTER TABLE `product_prices`
  ADD CONSTRAINT `fk_price_prod` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `quotes`
--
ALTER TABLE `quotes`
  ADD CONSTRAINT `fk_quote_cust` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_quotes_template` FOREIGN KEY (`template_id`) REFERENCES `document_templates` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `quote_line_items`
--
ALTER TABLE `quote_line_items`
  ADD CONSTRAINT `fk_qli_prod` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_qli_quote` FOREIGN KEY (`quote_id`) REFERENCES `quotes` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `role_menu_permissions`
--
ALTER TABLE `role_menu_permissions`
  ADD CONSTRAINT `role_menu_permissions_ibfk_1` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `role_menu_permissions_ibfk_2` FOREIGN KEY (`menu_id`) REFERENCES `menus` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `stage_checklists`
--
ALTER TABLE `stage_checklists`
  ADD CONSTRAINT `fk_check_stage` FOREIGN KEY (`stage_id`) REFERENCES `pipeline_stages` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `target_assignments`
--
ALTER TABLE `target_assignments`
  ADD CONSTRAINT `fk_ta_conf` FOREIGN KEY (`kpi_config_id`) REFERENCES `kpi_configs` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_ta_org` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_ta_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `tasks`
--
ALTER TABLE `tasks`
  ADD CONSTRAINT `fk_task_assignee` FOREIGN KEY (`assigned_to`) REFERENCES `users` (`id`),
  ADD CONSTRAINT `fk_task_assigner` FOREIGN KEY (`assigned_by`) REFERENCES `users` (`id`),
  ADD CONSTRAINT `fk_tasks_contact` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `users`
--
ALTER TABLE `users`
  ADD CONSTRAINT `fk_user_org` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`),
  ADD CONSTRAINT `fk_user_role` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
