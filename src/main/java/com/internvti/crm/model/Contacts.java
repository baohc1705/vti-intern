package com.internvti.crm.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;
import org.springframework.format.annotation.DateTimeFormat;

import java.sql.Timestamp;
import java.time.LocalDate;

@Entity
@Table(name = "contacts")
@NoArgsConstructor
@AllArgsConstructor
@Getter
@Setter
@Builder
public class Contacts {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @NotBlank(message = "Họ và tên không được để trống")
    @Size(min = 2, max = 50, message = "Họ và tên phải từ 2 đến 50 ký tự")
    @Pattern(regexp = "^[\\p{L} ]+$", message = "Họ và tên không được chứa số hoặc ký tự đặc biệt")
    @Column(name = "full_name")
    private String fullName;

    @NotBlank(message = "Chức vụ không được để trống")
    @Size(max = 100, message = "Chức vụ tối đa 100 ký tự")
    @Column(name = "position")
    private String position;

    @NotBlank(message = "Số điện thoại không được để trống")
    @Size(max = 10, message = "Số điện thoại tối đa 10 ký tự")
    @Pattern(regexp = "^(\\+84|0084|0)(3[2-9]|5[25689]|7[06-9]|8[1-9]|9[0-9])\\d{7}$",
            message = "Số điện thoại Việt Nam không đúng định dạng")
    @Column(name = "phone")
    private String phone;

    @NotBlank(message = "Email không được để trống")
    @Size(max = 100, message = "Email tối đa 100 ký tự")
    @Email(message = "Email không đúng định dạng")
    @Column(name = "email")
    private String email;

    @Size(max = 500, message = "Địa chỉ tối đa 500 ký tự")
    @Column(name = "address")
    private String address;

    @Past(message = "Ngày sinh không thể là ngày trong tương lai")
    @DateTimeFormat(pattern = "yyyy-MM-dd")
    @Column(name = "dob")
    private LocalDate dob;

    @Column(name = "notes")
    @Size(max = 500, message = "Ghi chú tối đa 500 ký tự")
    private String notes;

    @Column(name = "is_primary")
    private boolean isPrimary;

    @Column(name = "created_by")
    private Long createdBy;

    @Column(name = "updated_by")
    private Long updatedBy;

    @Column(name = "created_at")
    private Timestamp createdAt;

    @Column(name = "updated_at")
    private Timestamp updatedAt;

    @Column(name = "is_active")
    private boolean isActive = true;

    @Column(name = "deleted_at")
    private Timestamp deletedAt;

    @ManyToOne
    @JoinColumn(name = "customer_id")
    private Customer customer;
}
