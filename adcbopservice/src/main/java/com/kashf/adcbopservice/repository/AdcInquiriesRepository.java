package com.kashf.adcbopservice.repository;

import com.kashf.adcbopservice.domain.AdcInquiries;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AdcInquiriesRepository extends JpaRepository<AdcInquiries, Long> {
}