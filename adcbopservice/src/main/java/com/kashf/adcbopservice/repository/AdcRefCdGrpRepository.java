package com.kashf.adcbopservice.repository;

import com.kashf.adcbopservice.domain.AdcRefCdGrp;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AdcRefCdGrpRepository extends JpaRepository<AdcRefCdGrp, Long> {
}
