package com.kashf.adcbopservice.service;

import com.kashf.adcbopservice.domain.AdcRefCdVal;
import com.kashf.adcbopservice.domain.AdcUsers;
import com.kashf.adcbopservice.dto.BillInquiryDto;
import com.kashf.adcbopservice.dto.BillPaymentDto;
import com.kashf.adcbopservice.repository.AdcInquiriesRepository;
import com.kashf.adcbopservice.repository.AdcRefCdValRepository;
import com.kashf.adcbopservice.repository.AdcUsersRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.env.Environment;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.stereotype.Service;

import javax.persistence.EntityManager;
import javax.persistence.ParameterMode;
import javax.persistence.StoredProcedureQuery;
import java.sql.Clob;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

@Service
@EnableScheduling
public class CommonService {

    private final Logger logger = LoggerFactory.getLogger(CommonService.class);

    @Autowired
    private EntityManager em;

    @Autowired
    private Environment env;

    @Autowired
    AdcRefCdValRepository adcRefCdValRepository;

    @Autowired
    AdcUsersRepository adcUsersRepository;

    @Autowired
    AdcInquiriesRepository adcInquiriesRepository;

    // Validate Credentials
    public boolean verifyCredentials(String consumer, String username, String password) {
        //
        AdcUsers adcUsers = null;

        // Vendor Details - Grp: Vendor
        AdcRefCdVal refCdValVndr = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValShrtDesc(
                true, "0011", consumer);
        // User Type will be Primary
        AdcRefCdVal refCdValUsrTyp = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(
                true, "0002", "0001");
        //
        try{
            adcUsers = adcUsersRepository.findAllByCrntRecFlgAndRefCdVndrSeqAndRefCdUsrTypSeqAndUsernameAndUserPass(
                    true, refCdValVndr != null ? refCdValVndr.getRefCdValSeq() : 0L,
                    refCdValUsrTyp != null ? refCdValUsrTyp.getRefCdValSeq() : 0L,
                    username, password
            );
        } catch(Exception ex){
            logger.error(ex.getMessage());
        }

        boolean objFlg = adcUsers != null ? true : false;
        logger.info("Verifying Credentials: " + username + " || " + password
                + " || " + objFlg);
        if (adcUsers != null) {
            return true;
        }

        return false;
    }

    // Get Client Inquiry and Payment
    // Usage: Easy Paisa / Munsalik
    public StoredProcedureQuery callPrcClntIquiryPymt(Map<String, String> parmMapList){

        Map<String, Object> mapRespObj = new HashMap<>();
        // DB SCHEMA
        String db_schema = env.getProperty("mwx.db.schema");
        //
        StoredProcedureQuery storedProcedure = null;

        logger.info(db_schema + "PRC_ADC_CLNT_INQRY_PYMT execution started.");

        try{
            // Procedure Call
            storedProcedure = em.createStoredProcedureQuery(db_schema + "PRC_ADC_CLNT_INQRY_PYMT");
            storedProcedure.registerStoredProcedureParameter("P_PRC_CALL", String.class, ParameterMode.IN);
            storedProcedure.registerStoredProcedureParameter("P_CLNT_SEQ", Long.class, ParameterMode.IN);
            storedProcedure.registerStoredProcedureParameter("P_AGENT_TYPE_ID", String.class, ParameterMode.IN);
            storedProcedure.registerStoredProcedureParameter("P_PYMT_AMT", Long.class, ParameterMode.IN);
            storedProcedure.registerStoredProcedureParameter("P_PYMT_DT", String.class, ParameterMode.IN);
            storedProcedure.registerStoredProcedureParameter("P_PYMT_INSTR_NUM", String.class, ParameterMode.IN);

            storedProcedure.registerStoredProcedureParameter("OP_CLNT_NM", String.class, ParameterMode.OUT);
            storedProcedure.registerStoredProcedureParameter("OP_CLNT_BRNCH_SEQ", Long.class, ParameterMode.OUT);
            storedProcedure.registerStoredProcedureParameter("OP_LOAN_APP_SEQ", Long.class, ParameterMode.OUT);
            storedProcedure.registerStoredProcedureParameter("OP_DUE_AMT", Long.class, ParameterMode.OUT);
            storedProcedure.registerStoredProcedureParameter("OP_DUE_DT", Date.class, ParameterMode.OUT);
            storedProcedure.registerStoredProcedureParameter("OP_INSTL_NUM", Long.class, ParameterMode.OUT);
            storedProcedure.registerStoredProcedureParameter("OP_TTL_INSTLS", Long.class, ParameterMode.OUT);
            storedProcedure.registerStoredProcedureParameter("OP_TTL_OST_AMT", Long.class, ParameterMode.OUT);
            storedProcedure.registerStoredProcedureParameter("OP_PYMT_STS_KEY", Long.class, ParameterMode.OUT);
            storedProcedure.registerStoredProcedureParameter("OP_PAID_AMT", Long.class, ParameterMode.OUT);
            storedProcedure.registerStoredProcedureParameter("OP_PAID_DT", String.class, ParameterMode.OUT);
            storedProcedure.registerStoredProcedureParameter("OP_AGENT_NM", String.class, ParameterMode.OUT);
            storedProcedure.registerStoredProcedureParameter("OP_AGENT_SEQ", Long.class, ParameterMode.OUT);
            storedProcedure.registerStoredProcedureParameter("OP_EXEC_STS", String.class, ParameterMode.OUT);

            // Set Parameters
            storedProcedure.setParameter("P_PRC_CALL", parmMapList.get("P_PRC_CALL"));
            storedProcedure.setParameter("P_CLNT_SEQ", Long.parseLong(parmMapList.get("P_CLNT_SEQ")));
            storedProcedure.setParameter("P_AGENT_TYPE_ID", parmMapList.get("P_AGENT_TYPE_ID"));
            storedProcedure.setParameter("P_PYMT_AMT", Long.parseLong(parmMapList.get("P_PYMT_AMT")));
            storedProcedure.setParameter("P_PYMT_DT", parmMapList.get("P_PYMT_DT"));
            storedProcedure.setParameter("P_PYMT_INSTR_NUM", parmMapList.get("P_PYMT_INSTR_NUM"));

            // execute SP
            storedProcedure.execute();

        } catch( Exception ex ){
            logger.error("Error (PRC_ADC_CLNT_INQRY_PYMT): " + ex.getMessage());
        }
        //
        return storedProcedure;
    }

    public Boolean verifyInquiryMandatoryFields(BillInquiryDto parmInquiryDto) {
        if (
                parmInquiryDto.getReference_no() != null && (parmInquiryDto.getReference_no().length() >= 9 || parmInquiryDto.getReference_no().length() <= 22)
                && parmInquiryDto.getTransaction_date() != null && parmInquiryDto.getTransaction_date().length() == 8
                && parmInquiryDto.getTransaction_time() != null && parmInquiryDto.getTransaction_time().length() == 16
                && parmInquiryDto.getBranch_code() != null && (parmInquiryDto.getBranch_code().length() > 0 || parmInquiryDto.getBranch_code().length() <= 10)
        )
            return true;

        return false;
    }

    public Boolean verifyPaymentMandatoryFields(BillPaymentDto parmPaymentDto) {
        if (
                parmPaymentDto.getReference_no() != null && (parmPaymentDto.getReference_no().length() >= 9 && parmPaymentDto.getReference_no().length() <= 22)
                && parmPaymentDto.getTransaction_date() != null && parmPaymentDto.getTransaction_date().length() == 8
                && parmPaymentDto.getTransaction_time() != null && parmPaymentDto.getTransaction_time().length() == 16
                && parmPaymentDto.getAmount() != null && parmPaymentDto.getAmount().length() == 12
                && parmPaymentDto.getBranch_code() != null && (parmPaymentDto.getBranch_code().length() > 0 && parmPaymentDto.getBranch_code().length() <= 10)
                && parmPaymentDto.getClient_no() != null && (parmPaymentDto.getClient_no() >= 9 && parmPaymentDto.getClient_no() <= 22)
            )
            return true;

        return false;
    }

    public String convertClobToString(Clob clobInData) {
        String stringClob = "";

        try {
            if (clobInData != null) {
                long i = 1;
                int clobLength = (int) clobInData.length();
                stringClob = clobInData.getSubString(i, clobLength);
            }
        } catch (Exception e) {
            stringClob = "";
        }

        return stringClob;
    }

    //&& parmPaymentDto.getClient_no() != null && (parmPaymentDto.getClient_no() >= 9 || parmPaymentDto.getClient_no() <= 22)
}

