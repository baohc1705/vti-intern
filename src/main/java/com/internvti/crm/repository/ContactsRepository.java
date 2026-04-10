package com.internvti.crm.repository;

import com.internvti.crm.model.Contacts;
import jakarta.transaction.Transactional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ContactsRepository extends JpaRepository<Contacts, Long> {

    @Modifying
    @Transactional
    @Query("UPDATE Contacts c SET c.isActive = false, c.deletedAt = CURRENT_TIMESTAMP WHERE c.id IN :ids")
    int softDeleteByIds(@Param("ids") List<Long> ids);

    @Query("""
        SELECT c FROM Contacts c
        JOIN c.customer kh
        WHERE (:keyword = ''
               OR LOWER(c.fullName) LIKE LOWER(CONCAT('%', :keyword, '%'))
               OR LOWER(c.email)    LIKE LOWER(CONCAT('%', :keyword, '%')))
        AND c.isActive = true
        ORDER BY c.updatedAt DESC
    """)
    Page<Contacts> search(@Param("keyword") String keyword, Pageable pageable);
}
