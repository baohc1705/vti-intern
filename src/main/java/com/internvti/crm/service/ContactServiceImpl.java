package com.internvti.crm.service;
import com.internvti.crm.model.Contacts;
import com.internvti.crm.repository.ContactsRepository;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
@Service
@RequiredArgsConstructor
public class ContactServiceImpl implements ContactsService {
    private final ContactsRepository contactsRepository;

    @Override
    public List<Contacts> findAll() {

        return contactsRepository.findAll()
                .stream()
                .filter(x -> x.isActive() & x.getDeletedAt() == null)
                .toList();
    }

    @Override
    @Transactional
    public Contacts Create(Contacts contacts) {
        contacts.setCreatedAt(Timestamp.valueOf(LocalDateTime.now()));
        contacts.setCreatedBy(1L);
        contacts.setUpdatedAt(Timestamp.valueOf(LocalDateTime.now()));
        contacts.setActive(true);
        return contactsRepository.save(contacts);
    }

    @Override
    public int SoftRemoveRange(List<Long> id) {
        try {
            return contactsRepository.softDeleteByIds(id);
        }catch (RuntimeException e) {
            return -1;
        }
    }

    @Override
    public void Delete(Long id) {
        contactsRepository.deleteById(id);
    }

    @Override
    public Contacts findById(Long id) {
        return contactsRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Not found"));
    }

    @Override
    public void Update(Contacts contacts) {
        contacts.setUpdatedAt(Timestamp.valueOf(LocalDateTime.now()));
        contactsRepository.save(contacts);
    }

    @Override
    public Page<Contacts> search(String keyword, Pageable pageable) {
        return contactsRepository.search(
                keyword == null ? "" : keyword.trim(),
                pageable
        );
    }
}
