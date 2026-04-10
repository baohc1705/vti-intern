# Báo cáo task: CRUD Contact
## Thời gian : thứ 4, 05/04/2026
---
## Tổng quan

Module này cho phép quản lý toàn bộ thông tin người liên hệ gắn với khách hàng trong hệ thống CRM. Mỗi khách hàng có thể có một hoặc nhiều người liên hệ, đảm bảo đội ngũ kinh doanh luôn có thông tin liên lạc chính xác để giao tiếp và chăm sóc khách hàng hiệu quả.

---

## Danh Sách Task Hoàn Thành

| # | Task | Chi tiết triển khai | Trạng thái |
|---|----------------|----------------------|------------|
| 1 | **Xem danh sách** | Hiển thị bảng thông tin người liên hệ , phân trang (5/10/20/50). | ✅ Done |
| 2 | **Tìm kiếm** | Tìm kiếm theo tên và email | ✅ Done |
| 3 | **Thêm mới** | Valition dữ liệu ở 2 nơi frontend và backend.| ✅ Done |
| 4 | **Xem chi tiết** | Trả về thông tin chi tiết của liên hệ | ✅ Done |
| 5 | **Chỉnh sửa** | Cho phép cập nhật thông tin và bắt lỗi dữ liệu | ✅ Done |
| 6 | **Xóa liên hệ** | Thực hiện xóa mềm (cập nhật is_active=false) | ✅ Done |

---
## Chi tiết chức năng
### 1. Xem danh sách

![Danh sách liên hệ](link here)

### 2. Tìm kiếm
Tìm kiếm thành công

![Tìm kiếm thành công](link here)

Tìm kiếm thất bại

![TÌm kiếm thất bại](link here)

### 3. Thêm mới
![Bắt lỗi](link here)

### 4. Xóa liên hệ
![Xóa nhiều](link here)

### 5. Xem chi tiết và chỉnh sửa thông tin 
![Xem chi tiết](link here)

## Cấu trúc cơ sở dữ liệu
![Database](link here)



## Công Nghệ Sử Dụng

* **Core:** Java 21, Spring 4
* **Data Access:** Spring Data JPA / Hibernate, JDBC
* **Database:** MySQL
* **Build tool:** Maven

---

## Cài Đặt & Chạy Dự Án

### Yêu cầu hệ thống

- Java 21
- Maven 3.8+
- MySql
- Git

### Hướng dẫn chạy môi trường Local

**Bước 1 — Clone repository**
```bash
git clone https://github.com/baohc1705/vti-intern.git
```
**Bước 2 — Cấu hình Database**

Tạo database và cập nhật file application.yaml:
```
  datasource:
    url: "jdbc:mysql://localhost:3306/your_name_db"
    username: "your_username"
    password: "your_password"
```

**Bước 3 — Build & Chạy**
```
  mvn clean install
  mvn spring-boot:run
```





