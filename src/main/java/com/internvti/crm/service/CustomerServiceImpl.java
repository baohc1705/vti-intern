package com.internvti.crm.service;

import com.internvti.crm.model.Customer;
import com.internvti.crm.repository.CustomerRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class CustomerServiceImpl implements CustomerService {
    private final CustomerRepository customerRepository;

    @Override
    public List<Customer> findAll() {
        return customerRepository.findAll()
                .stream().map(x -> x.builder()
                        .id(x.getId())
                        .name(x.getName())
                        .phone(x.getPhone())
                        .email(x.getEmail())
                        .build())
                .toList();
    }
}
