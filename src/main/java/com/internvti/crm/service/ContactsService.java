package com.internvti.crm.service;

import com.internvti.crm.model.Contacts;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.List;

public interface ContactsService {
    List<Contacts> findAll();

    Contacts Create(Contacts contacts);

    void Delete(Long id);

    Contacts findById(Long id);

    int SoftRemoveRange(List<Long> id);

    Page<Contacts> search(String keyword, Pageable pageable);

    void  Update(Contacts contacts);
}
