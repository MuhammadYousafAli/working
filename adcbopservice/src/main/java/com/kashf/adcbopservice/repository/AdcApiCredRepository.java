package com.kashf.adcbopservice.repository;

import com.kashf.adcbopservice.domain.AdcApiCred;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AdcApiCredRepository extends JpaRepository<AdcApiCred, Long> {

    public AdcApiCred findAllByRefCdVndrSeqAndCrntRecFlg(Long userId, Boolean crntRecFlg);

}
