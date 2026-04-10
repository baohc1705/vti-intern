package com.internvti.crm.controller;

import com.internvti.crm.model.Contacts;
import com.internvti.crm.service.ContactsService;
import com.internvti.crm.service.CustomerService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.util.List;

@Controller
@RequiredArgsConstructor
@RequestMapping("/contacts")
public class ContactsController {

    private final ContactsService contactsService;
    private final CustomerService customerService;
    @GetMapping("/all")
    public String getContacts(Model model) {
        List<Contacts> contacts = contactsService.findAll();
        model.addAttribute("contacts", contacts);
        return "contacts";
    }

    @GetMapping("/create")
    public String viewCreateForm(Model model) {
        model.addAttribute("contact", new Contacts());
        model.addAttribute("customers",customerService.findAll());
        return "create-contact";
    }

    @PostMapping("/save")
    public String save(@Valid @ModelAttribute Contacts contacts,
                       BindingResult result,
                       RedirectAttributes redirectAttributes) {
        try {
            if (result.hasErrors()) {
                return "create-contact";
            }
            contactsService.Create(contacts);
            redirectAttributes.addFlashAttribute("success", "Thành công!");
        } catch (Exception e) {
            redirectAttributes.addFlashAttribute("error", "Thất bại!");
        }
        return "redirect:/contacts";
    }

    @GetMapping("/delete/{id}")
    public String deleteById(@PathVariable("id") Long id,
                             RedirectAttributes redirectAttributes) {
        try {
            contactsService.Delete(id);
            redirectAttributes.addFlashAttribute("success", "Xóa liên hệ thành công!");
        } catch (Exception e) {
            redirectAttributes.addFlashAttribute("error", "Xóa thất bại!");
        }
        return "redirect:/contacts";
    }

    @GetMapping("/edit/{id}")
    public String edit(@PathVariable Long id, Model model) {
        Contacts contact = contactsService.findById(id);
        model.addAttribute("contact",   contact);
        model.addAttribute("customers", customerService.findAll());
        return "create-contact";
    }

    @PostMapping("/update/{id}")
    public String update(@PathVariable Long id,
                         @Valid @ModelAttribute("contact") Contacts contact,
                         BindingResult result,
                         Model model,
                         RedirectAttributes redirectAttributes) {
        if (result.hasErrors()) {
            model.addAttribute("customers",customerService.findAll());
            return "contact-form";
        }

        contact.setId(id);
        contactsService.Update(contact);
        redirectAttributes.addFlashAttribute("success", "Cập nhật liên hệ thành công!");
        return "redirect:/contacts";
    }

    @PostMapping("/remove-range")
    public String SoftRemoveRange(@RequestBody List<Long> ids) {
         contactsService.SoftRemoveRange(ids);
         return "redirect:/contacts";
    }

    @GetMapping
    public String index(
            @RequestParam(defaultValue = "") String keyword,
            @RequestParam(defaultValue = "0")  int page,
            @RequestParam(defaultValue = "5") int size,
            Model model) {

        Page<Contacts> result = contactsService.search(keyword, PageRequest.of(page, size));

        model.addAttribute("contacts", result.getContent());
        model.addAttribute("currentPage", result.getNumber());
        model.addAttribute("totalPages", result.getTotalPages());
        model.addAttribute("totalItems", result.getTotalElements());
        model.addAttribute("keyword", keyword);
        model.addAttribute("size", size);
        model.addAttribute("pageSizes", List.of(5, 10, 20, 50));
        return "contacts";
    }
}
