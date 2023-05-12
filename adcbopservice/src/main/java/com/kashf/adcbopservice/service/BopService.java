package com.kashf.adcbopservice.service;

import com.kashf.adcbopservice.domain.AdcInquiries;
import com.kashf.adcbopservice.domain.AdcRefCdVal;
import com.kashf.adcbopservice.domain.AdcTransactions;
import com.kashf.adcbopservice.dto.BillInquiryDto;
import com.kashf.adcbopservice.dto.BillPaymentDto;
import com.kashf.adcbopservice.repository.AdcInquiriesRepository;
import com.kashf.adcbopservice.repository.AdcRefCdValRepository;
import com.kashf.adcbopservice.repository.AdcTransactionsRepository;
import com.kashf.adcbopservice.util.AESEncryptionDecryption;
import com.kashf.adcbopservice.util.CommonFunctions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.env.Environment;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.persistence.EntityManager;
import javax.persistence.ParameterMode;
import javax.persistence.StoredProcedureQuery;
import java.sql.Clob;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

@Service
public class BopService {
    private final Logger logger = LoggerFactory.getLogger(BopService.class);
    // LogManager.getLogger(CommonService.class);

    @Autowired
    AdcRefCdValRepository adcRefCdValRepository;

    @Autowired
    AdcInquiriesRepository adcInquiriesRepository;

    @Autowired
    AdcTransactionsRepository adcTransactionsRepository;

    @Autowired
    private EntityManager em;

    @Autowired
    private Environment env;

    AESEncryptionDecryption aesEncryptionDecryption;
    //
    CommonFunctions commonFunctions = new CommonFunctions();

    @Autowired
    CommonService commonService;

    //

    @Transactional
    public Map<String, Object> getInquiry(String billInquiryDto, String rmteAddrs, String[] userCred) {
        Map<String, Object> mapResp = new HashMap<>();

        // DB SCHEMA
        String db_schema = env.getProperty("mwx.db.schema");
        //
        StoredProcedureQuery storedProcedure = null;
        String prcResponse = null;
        String jsonStr = "";

        logger.info(db_schema + "PRC_ADC_DSB_INTEGRATION execution started.");
        try{
            // Procedure Call
            storedProcedure = em.createStoredProcedureQuery(db_schema + "PRC_ADC_DSB_INTEGRATION");
            storedProcedure.registerStoredProcedureParameter("P_PRC_CALL", String.class, ParameterMode.IN);
            storedProcedure.registerStoredProcedureParameter("P_JSON", String.class, ParameterMode.IN);
            storedProcedure.registerStoredProcedureParameter("P_RMT_ADDR", String.class, ParameterMode.IN);
            storedProcedure.registerStoredProcedureParameter("P_USER", String.class, ParameterMode.IN);
            storedProcedure.registerStoredProcedureParameter("P_USERPASS", String.class, ParameterMode.IN);
            // OUT Parameters
            storedProcedure.registerStoredProcedureParameter("P_RSP_JSON", String.class, ParameterMode.OUT);
            storedProcedure.registerStoredProcedureParameter("P_RTN_MSG", String.class, ParameterMode.OUT);
            // Set Parameters
            storedProcedure.setParameter("P_PRC_CALL", "INQUIRY");
            storedProcedure.setParameter("P_JSON", billInquiryDto);
            storedProcedure.setParameter("P_RMT_ADDR", rmteAddrs);
            storedProcedure.setParameter("P_USER", userCred[0]);
            storedProcedure.setParameter("P_USERPASS", userCred[1]);

            logger.error("Response (PRC_ADC_DSB_INTEGRATION): " + billInquiryDto);
            logger.error("Response (PRC_ADC_DSB_INTEGRATION): " + rmteAddrs);
            logger.error("Response (PRC_ADC_DSB_INTEGRATION): " + userCred[0]);
            logger.error("Response (PRC_ADC_DSB_INTEGRATION): " + userCred[1]);

            // execute SP
            storedProcedure.execute();

            prcResponse = (String) storedProcedure.getOutputParameterValue("P_RSP_JSON");
            prcResponse = prcResponse.substring(1, prcResponse.length()-1);
            //prcResponse = prcResponse.replaceAll("^\"", "");
            prcResponse = prcResponse.replace("\"","");
           // prcResponse = prcResponse.replace("null","");

            String[] keyValuePairs = prcResponse.split(",");

            for(String pair : keyValuePairs)
            {
                String[] entry = pair.split(":");

                logger.error("Response (PRC_ADC_DSB_INTEGRATION) entry[0].trim(): " + entry[0].trim());
                logger.error("Response (PRC_ADC_DSB_INTEGRATION) entry[1].trim(): " + entry[1].trim());
                entry[1] = entry[1].replace("null","");
                logger.error("Response (PRC_ADC_DSB_INTEGRATION) entry[1].trim(): After" + entry[1].trim());
                mapResp.put(entry[0].trim(), entry[1].trim());
            }

            String prcRtnMsg = (String) storedProcedure.getOutputParameterValue("P_RTN_MSG");

            logger.error("Response (PRC_ADC_DSB_INTEGRATION): " + mapResp);

        } catch( Exception ex ){
            logger.error("Error (PRC_ADC_DSB_INTEGRATION): " + ex.getMessage());
        }
        //

        return mapResp;
    }

    @Transactional
    public Map<String, Object> getInquiry1(BillInquiryDto billInquiryDto, String rmteAddrs) {
        //
        Map<String, Object> mapResp = new HashMap<>();
        // Response Status
        AdcRefCdVal refCdValRespSts = null;
        Long loanAppSeq = -1L;
        Long brnchSeq = -1L;

        // Inquires Object
        AdcInquiries adcInquiries = new AdcInquiries();

        // Vendor Details - BOP ETC
        AdcRefCdVal refCdValVndr = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(
                true, "0001", "0011");   // for BOP

        // In Case Vendor Not Found
        if (refCdValVndr == null) {
            refCdValRespSts = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(
                    true, "0003", "0004");  // invalid data
            mapResp = getEmptyBillingInquiry(refCdValRespSts.getRefCdValCode().substring(2));
            // Save Inquiry
            adcInquiries.setClntSeq(Long.parseLong(billInquiryDto.getReference_no()));
            adcInquiries.setLoanAppSeq(loanAppSeq);
            adcInquiries.setRefCdRespStsSeq(refCdValRespSts.getRefCdValSeq());
            adcInquiries.setAdcRequest(billInquiryDto.toJSONString());
            adcInquiries.setAdcResponse(mapResp.toString());
            adcInquiries.setRefCdVndrSeq(refCdValVndr.getRefCdValSeq());
            adcInquiries.setCrntRecFlg(true);
            adcInquiries.setCrtdBy(refCdValVndr.getRefCdValShrtDesc());
            adcInquiries.setCrtdDt(new Date());
            adcInquiries.setRemarks("BOP Disbursement Inquiry: Vendor Missing");
            adcInquiries.setRemoteAddrs(rmteAddrs);
            adcInquiries.setBrnchSeq(brnchSeq);

            adcInquiriesRepository.save(adcInquiries);
            logger.info("Recovery Inquiry: Vendor Missing");

            return mapResp;
        }

        // Procedure Parameters
        Map<String, String> parmPrcdre = new HashMap<>();
        parmPrcdre.put("P_PRC_CALL", "INQUIRY");
        parmPrcdre.put("P_CLNT_SEQ", billInquiryDto.getReference_no());
        parmPrcdre.put("P_AGENT_TYPE_ID", "0005");
        parmPrcdre.put("P_PYMT_AMT", "0");
        parmPrcdre.put("P_PYMT_DT", " ");
        parmPrcdre.put("P_PYMT_INSTR_NUM", "");

        // Execute Procedure
        StoredProcedureQuery storedProcedure = commonService.callPrcClntIquiryPymt(parmPrcdre);

        String execSts = null;
        if (storedProcedure != null) {
            // Procedure Execution Status Parameter
            execSts = (String) storedProcedure.getOutputParameterValue("OP_EXEC_STS");
            logger.info("Procedure Executed with '" + execSts + "'.");

            // If result set found, system will fetch only 1st record
            if (execSts != null && execSts.contains("SUCCESS")) {
                // Remaining Output Parameters
                String clntName = (String) storedProcedure.getOutputParameterValue("OP_CLNT_NM");
                brnchSeq = (Long) storedProcedure.getOutputParameterValue("OP_CLNT_BRNCH_SEQ");
                loanAppSeq = (Long) storedProcedure.getOutputParameterValue("OP_LOAN_APP_SEQ");
                Long dueAmt = (Long) storedProcedure.getOutputParameterValue("OP_DUE_AMT");
                // Total Length 14 including +
                String frmtdDueAmt = "+" + commonFunctions.appendLeftRightZerosToLong(dueAmt, 13, 11);
                Date dueDt = (Date) storedProcedure.getOutputParameterValue("OP_DUE_DT");
                String frmtdDueDt = new SimpleDateFormat("yyyyMMdd").format(dueDt);
                // String frmtdMnthStrtDueDt = new SimpleDateFormat("yyyyMM").format(dueDt) + "01";
                String billingMonth = new SimpleDateFormat("yyMM").format(dueDt);
                Long instlNo = (Long) storedProcedure.getOutputParameterValue("OP_INSTL_NUM");

                Long ttlInstls = (Long) storedProcedure.getOutputParameterValue("OP_TTL_INSTLS");
                Long ttlOstAmt = (Long) storedProcedure.getOutputParameterValue("OP_TTL_OST_AMT");

                Long pymtStsKey = (Long) storedProcedure.getOutputParameterValue("OP_PYMT_STS_KEY");
                Long paidAmt = (Long) storedProcedure.getOutputParameterValue("OP_PAID_AMT");
                Date paidDt = new Date();
                String frmtdPaidDt = "";
                if (storedProcedure.getOutputParameterValue("OP_PAID_DT") != null) {
                    try {
                        paidDt = (Date) new SimpleDateFormat("dd-MMM-yy").parse(
                                storedProcedure.getOutputParameterValue("OP_PAID_DT").toString()
                        );

                        frmtdPaidDt = new SimpleDateFormat("yyyyMMdd").format(paidDt);
                    } catch (ParseException prex) {
                        prex.printStackTrace();
                    } catch (Exception ex) {
                        ex.printStackTrace();
                    }
                }
                String agentName = (String) storedProcedure.getOutputParameterValue("OP_AGENT_NM");
                Long agentSeq = (Long) storedProcedure.getOutputParameterValue("OP_AGENT_SEQ");

                // Response Status
                refCdValRespSts = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(
                        true, "0003", "0000");

                mapResp.put("Response_code", refCdValRespSts.getRefCdValCode().substring(2));
                mapResp.put("Consumer_Detail", clntName);
                mapResp.put("Bill_Status", "U");
                mapResp.put("Due_Date", frmtdDueDt);
                mapResp.put("Amount_Within_DueDate", frmtdDueAmt);
                mapResp.put("Amount_After_DueDate", frmtdDueAmt);
                mapResp.put("Billing_Month", billingMonth);
                mapResp.put("Date_Paid", frmtdPaidDt);
                mapResp.put("Amount_Paid", paidAmt == 0 ? "" : paidAmt);
                mapResp.put("Tran_Auth_Id", ""); //0
                mapResp.put("Reserved", ""); // execSts
            } else {
                // In-Valid Data
                refCdValRespSts = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(
                        true, "0003", "0001");
                mapResp = getEmptyBillingInquiry(refCdValRespSts.getRefCdValCode().substring(2));
                mapResp.put("Reserved", ""); // execSts
            }
        }

        // Save Inquiry
        adcInquiries.setClntSeq(Long.parseLong(billInquiryDto.getReference_no()));
        adcInquiries.setLoanAppSeq(loanAppSeq);
        adcInquiries.setRefCdRespStsSeq(refCdValRespSts.getRefCdValSeq());
        adcInquiries.setAdcRequest(billInquiryDto.toJSONString());
        adcInquiries.setAdcResponse(mapResp.toString());
        adcInquiries.setRefCdVndrSeq(refCdValVndr.getRefCdValSeq());
        adcInquiries.setCrntRecFlg(true);
        adcInquiries.setCrtdBy(refCdValVndr.getRefCdValShrtDesc());
        adcInquiries.setCrtdDt(new Date());
        adcInquiries.setRemarks("EasyPaisa Recovery Inquiry: " + execSts);
        adcInquiries.setRemoteAddrs(rmteAddrs);
        adcInquiries.setBrnchSeq(brnchSeq);

        adcInquiriesRepository.save(adcInquiries);

        return mapResp;
    }

    // Empty Result Set In Case, Not a valid (DATA)
    public Map<String, Object> getEmptyBillingInquiry(String respCode) {
        Map<String, Object> mapResp = new HashMap<>();
        mapResp.put("status”:", respCode);
        mapResp.put("reference_no", "");
        mapResp.put("client_no", "");
        mapResp.put("client_name", ""); // U
        mapResp.put("client_cnic", ""); // 00000000
        mapResp.put("kashf_branch", ""); //+0000000000000
        mapResp.put("loan_date", ""); //+0000000000000
        mapResp.put("payment_status", ""); //0000
        mapResp.put("amount", ""); //00000000
        mapResp.put("reserved", ""); //+00000000000
        return mapResp;
    }

    //
    @Transactional
    public synchronized Map applyPayment(BillPaymentDto billPaymentDto, String rmteAddrs) {
        Map<String, Object> mapRespObj = new HashMap<>();
        // DB SCHEMA
        String db_schema = env.getProperty("mwx.db.schema");
        Long loanAppSeq = -1L;
        Long refSeq = -1L;
        String agentId = "0005";
        Long brnchSeq = -1L;

        // Response Status
        AdcRefCdVal refCdValRespSts = null;
        //
        AdcTransactions adcTransactions = new AdcTransactions();

        // Vendor Details - EasyPaisa
        AdcRefCdVal refCdValVndr = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(
                true, "0001", "0001");

        // Payment made for Recovery
        AdcRefCdVal refCdValPymtTyp = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(
                true, "0004", "0001");
        //
        Long pymtAmt = Long.parseLong(billPaymentDto.getAmount().substring(0,
                billPaymentDto.getAmount().length() - 2));

        // In Case Vendor Not Found
        if (refCdValVndr == null) {
            refCdValRespSts = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(
                    true, "0007", "0004");
            mapRespObj = getEmptyBillingInquiry(refCdValRespSts.getRefCdValCode().substring(2));

            // Save Transaction
            adcTransactions.setLoanAppSeq(loanAppSeq);
            adcTransactions.setRefCdRespStsSeq(refCdValRespSts.getRefCdValSeq());
            adcTransactions.setAdcRequest(billPaymentDto.toJSONString());
            adcTransactions.setAdcResponse(mapRespObj.toString());
            adcTransactions.setRefCdVndrSeq(refCdValVndr.getRefCdValSeq());
            adcTransactions.setCrntRecFlg(true);
            adcTransactions.setCrtdBy(refCdValVndr.getRefCdValShrtDesc());
            adcTransactions.setCrtdDt(new Date());
            adcTransactions.setRemarks("BoP Disbursement Payment: Vendor Missing");
            adcTransactions.setRemoteAddrs(rmteAddrs);
            adcTransactions.setBrnchSeq(brnchSeq);

            adcTransactionsRepository.save(adcTransactions);
            logger.info("Disbursement Payment: Vendor Missing");

            return mapRespObj;
        }

        // Procedure Parameters
        Map<String, String> parmPrcdre = new HashMap<>();
        parmPrcdre.put("P_PRC_CALL", "PAYMENT");
        parmPrcdre.put("P_CLNT_SEQ", billPaymentDto.getClient_no().toString());
        parmPrcdre.put("P_AGENT_TYPE_ID", agentId);
        parmPrcdre.put("P_PYMT_AMT", pymtAmt.toString());
        parmPrcdre.put("P_PYMT_DT", billPaymentDto.getTransaction_date().toString() + billPaymentDto.getTransaction_time().toString());
        parmPrcdre.put("P_PYMT_INSTR_NUM", billPaymentDto.getStan().toString());

        // Execute Procedure
        StoredProcedureQuery storedProcedure = commonService.callPrcClntIquiryPymt(parmPrcdre);
       //
        String execSts = null;
        if (storedProcedure != null) {
            // Procedure Execution Status Parameter
            execSts = (String) storedProcedure.getOutputParameterValue("OP_EXEC_STS");
            logger.info("Procedure Executed with '" + execSts + "'.");

            if (execSts != null && execSts.contains("SUCCESS")) {
                // Remaining Output Parameters
                String clntName = (String) storedProcedure.getOutputParameterValue("OP_CLNT_NM");
                brnchSeq = (Long) storedProcedure.getOutputParameterValue("OP_CLNT_BRNCH_SEQ");
                loanAppSeq = (Long) storedProcedure.getOutputParameterValue("OP_LOAN_APP_SEQ");
                Long dueAmt = (Long) storedProcedure.getOutputParameterValue("OP_DUE_AMT");
                // Total Length 14 including +
                String frmtdDueAmt = "+" + commonFunctions.appendLeftRightZerosToLong(dueAmt, 13, 11);
                Date dueDt = (Date) storedProcedure.getOutputParameterValue("OP_DUE_DT");
                String frmtdDueDt = new SimpleDateFormat("yyyyMMdd").format(dueDt);
                String billingMonth = new SimpleDateFormat("yyMM").format(dueDt);
                Long instlNo = (Long) storedProcedure.getOutputParameterValue("OP_INSTL_NUM");
                Long ttlInstls = (Long) storedProcedure.getOutputParameterValue("OP_TTL_INSTLS");
                Long pymtStsKey = (Long) storedProcedure.getOutputParameterValue("OP_PYMT_STS_KEY");
                Long paidAmt = (Long) storedProcedure.getOutputParameterValue("OP_PAID_AMT");
                Date paidDt = new Date();
                String frmtdPaidDt = "";
                if (storedProcedure.getOutputParameterValue("OP_PAID_DT") != null) {
                    try {
                        paidDt = (Date) new SimpleDateFormat("dd-MMM-yy").parse(
                                storedProcedure.getOutputParameterValue("OP_PAID_DT").toString()
                        );

                        frmtdPaidDt = new SimpleDateFormat("yyyyMMdd").format(paidDt);
                    } catch (ParseException prex) {
                        prex.printStackTrace();
                    } catch (Exception ex) {
                        ex.printStackTrace();
                    }
                }
                String agentName = (String) storedProcedure.getOutputParameterValue("OP_AGENT_NM");
                Long agentSeq = (Long) storedProcedure.getOutputParameterValue("OP_AGENT_SEQ");

                // Procedure Response (Instruction No / Transaction No)
                String[] strPrcResp = execSts.split("#");
                String[] strInstrNoTrxNo = strPrcResp[1].split("/");
                refSeq = Long.parseLong(strInstrNoTrxNo[1].trim());

                // Response Status
                refCdValRespSts = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(
                        true, "0007", "0000");
            } else if (execSts != null && execSts.contains("FAILED")) {
                // 0001: PLEASE CHECK CLIENT HAS BEEN MARKED DEATH.
                // 0002: PLEASE CHECK CLIENT LOAN HAS BEEN COMPLETED OR IN-VALID BRANCH.
                // 0003: DUPLICATE CLIENT/INSTRUCTION NO./PAYMENT DATE.
                // 0004: RECOVERY AMOUNT AND PAYMENT AMOUNT ARE DIFFERENT.
                if (execSts.contains("0004")) {
                    // Response Status
                    refCdValRespSts = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(
                            true, "0007", "0004");
                } else if (execSts.contains("0002")) {
                    refCdValRespSts = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(
                            true, "0007", "0002");
                } else if (execSts.contains("0003")) {
                    refCdValRespSts = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(
                            true, "0007", "0003");
                } else if (execSts.contains("0001")) {
                    // Response Status
                    refCdValRespSts = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(
                            true, "0007", "0001");
                } else {
                    // Response Status
                    refCdValRespSts = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(
                            true, "0007", "0004");
                }
            } else {
                // Response Status
                refCdValRespSts = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(
                        true, "0007", "0002");
            }
        }

        // API Response
        mapRespObj.put("Response_code", refCdValRespSts.getRefCdValCode().substring(2));
        mapRespObj.put("Identification_Parameter", "");
        mapRespObj.put("Reserved", "");

        // Save Transaction
        adcTransactions.setCrntRecFlg(true);
        adcTransactions.setRemarks("Recovery Payment: " + execSts);
        adcTransactions.setAdcRequest(billPaymentDto.toJSONString());
        adcTransactions.setAdcResponse(mapRespObj.toString());
        adcTransactions.setRefCdVndrSeq(refCdValVndr.getRefCdValSeq());
        adcTransactions.setCrtdBy(refCdValVndr.getRefCdValShrtDesc());
        adcTransactions.setCrtdDt(new Date());
        adcTransactions.setLoanAppSeq(loanAppSeq);
        adcTransactions.setClntSeq(billPaymentDto.getClient_no());
        adcTransactions.setRefCdPymtTypSeq(refCdValPymtTyp == null ? 0L : refCdValPymtTyp.getRefCdValSeq());
        adcTransactions.setRefSeq(refSeq);
        adcTransactions.setRefCdRespStsSeq(refCdValRespSts.getRefCdValSeq());   // Object Value
        adcTransactions.setRemoteAddrs(rmteAddrs);
        adcTransactions.setBrnchSeq(brnchSeq);

        adcTransactionsRepository.save(adcTransactions);

        return mapRespObj;
    }


}
