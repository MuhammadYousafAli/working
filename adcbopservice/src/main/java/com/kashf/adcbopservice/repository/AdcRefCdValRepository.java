package com.kashf.adcbopservice.repository;


import com.kashf.adcbopservice.domain.AdcRefCdVal;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AdcRefCdValRepository extends JpaRepository<AdcRefCdVal, Long> {

    AdcRefCdVal findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(Boolean crntRecFlg,
                                                                       String refCdGrp,
                                                                       String refCdVal);

    List<AdcRefCdVal> findAdcRefCdValByCrntRecFlgAndRefCdGrpCode(Boolean crntRecFlg,
                                                                 String refCdGrp);

    AdcRefCdVal findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValShrtDesc(Boolean crntRecFlg,
                                                                           String refCdGrp,
                                                                           String shrtDesc);

    AdcRefCdVal findAdcRefCdValByCrntRecFlgAndRefCdValSeq(Boolean crntRecFlg, Long refCdValSeq);
}
