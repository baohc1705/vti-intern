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
## hình ảnh chức năng
### 1. Xem danh sách

![Danh sách liên hệ](https://github.com/baohc1705/vti-intern/blob/main/Screenshot/giao-dien-danh-sach.png)

Thông tin hiển thị:

- Họ và tên người liên hệ, Chức vụ
- Số điện thoại chính, Email chính
- Tên khách hàng, thời gian cập nhật
  
Điều kiện nghiệp vụ:

- Phân trang mặc định 5 dòng/trang, tùy chỉnh 5 / 10 / 20 / 50


### 2. Tìm kiếm
Tìm kiếm thành công

![Tìm kiếm thành công](https://github.com/baohc1705/vti-intern/blob/main/Screenshot/giao-dien-tim-kiem.png)


Tìm kiếm thất bại

![TÌm kiếm thất bại](https://github.com/baohc1705/vti-intern/blob/main/Screenshot/giao-dien-tim-kiem-khong-thay.png)

Các tiêu chí tìm kiếm:

- Họ và tên - tìm kiếm gần đúng, không phân biệt hoa thường
- Email - tìm kiếm chính xác hoặc gần đúng

### 3. Thêm liên hệ mới

Form thêm mới

![Form thêm](https://github.com/baohc1705/vti-intern/blob/main/Screenshot/giao-dien-them-sua-xem-chi-tiet.png)

Hiển thị lỗi

![Bắt lỗi](https://github.com/baohc1705/vti-intern/blob/main/Screenshot/giao-dien-bat-loai.png)

Thông tin nhập liệu

| # | Trường dữ liệu | Bắt buộc | Ghi chú |
|---|----------------|----------------------|------------|
| 1 | **Tên khách hàng** | Có | Hiển thị danh sách cho người dùng chọn, và hỗ trợ tìm kiếm |
| 2 | **Họ và tên** | Có | Bắt lỗi đang lúc nhập nếu vượt quá 50|
| 3 | **Chức vụ** | Có | Bắt lỗi đang lúc nhập nếu vượt quá 100 |
| 4 | **Liên hệ chính** | Không | Đánh dấu là liên hệ chính của khách hàng |
| 5 | **Số điện thoại** | Có | Bắt lỗi đang lúc nhập nếu số vượt 10, không có ký tự và chữ |
| 6 | **Email** | Có | bắt lỗi nếu không đúng dạng email |
| 7 | **Địa chỉ** | Không | Có thể lấy API sau này |
| 8 | **Ngày sinh** | Không | bắt lỗi nếu lớn hơn này hiện tại, đủ 18 tuổi |
| 9 | **Ghi chú** | Không | Bắt lỗi nếu vượt 500 ký tự |

### 4. Xóa liên hệ
![Xóa nhiều](https://github.com/baohc1705/vti-intern/blob/main/Screenshot/giao-dien-xoa-hang-loat.png)

Chọn vào checkbox các liên hệ muốn xóa sao đó sẽ thực hiện xóa mềm.

### 5. Xem chi tiết và chỉnh sửa thông tin 
![Xem chi tiết](https://github.com/baohc1705/vti-intern/blob/main/Screenshot/giao-dien-bat-loai-luc-dang-nhap.png)

---

## Cấu trúc bảng cơ sở dữ liệu
![Database](https://github.com/baohc1705/vti-intern/blob/main/Screenshot/db.png)

---

## Công Nghệ Sử Dụng

* **Core:** Java 21, Spring Boot MVC
* **Data Access:** Spring Data JPA
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





