package com.kashf.adcbopservice.repository;

import com.kashf.adcbopservice.domain.AdcUsers;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AdcUsersRepository extends JpaRepository<AdcUsers, Long> {

    public AdcUsers findAllByCrntRecFlgAndRefCdVndrSeqAndRefCdUsrTypSeq(Boolean crntRecFlg,
                                                                        Long refCdVndrSeq,
                                                                        Long refCdUsrTypSeq);

    public AdcUsers findAllByCrntRecFlgAndRefCdVndrSeqAndRefCdUsrTypSeqAndUsernameAndUserPass(
            Boolean crntRecFlg,
            Long refCdVndrSeq,
            Long refCdUsrTyp,
            String user,
            String pass);

}
