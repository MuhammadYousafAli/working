package com.kashf.adcbopservice.repository;

import com.kashf.adcbopservice.domain.AdcTransactions;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AdcTransactionsRepository extends JpaRepository<AdcTransactions, Long> {

    List<AdcTransactions> findAdcTransactionsByRefSeqOrderByTrxSeqDesc(Long refSeq);

}
