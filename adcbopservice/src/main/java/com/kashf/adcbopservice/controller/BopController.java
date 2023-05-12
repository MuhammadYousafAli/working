package com.kashf.adcbopservice.controller;

import com.fasterxml.jackson.core.JsonEncoding;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.kashf.adcbopservice.domain.AdcRefCdVal;
import com.kashf.adcbopservice.dto.BillInquiryDto;
import com.kashf.adcbopservice.dto.BillPaymentDto;
import com.kashf.adcbopservice.repository.AdcRefCdValRepository;
import com.kashf.adcbopservice.service.BopService;
import com.kashf.adcbopservice.service.CommonService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import com.kashf.adcbopservice.util.AESEncryptionDecryption;
import org.springframework.core.env.Environment;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.servlet.http.HttpServletRequest;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/bop")
public class BopController {

        private final Logger logger = LoggerFactory.getLogger(BopController.class);

        @Autowired
        BopService bopService;

        AESEncryptionDecryption aesEncryptionDecryption;

        @Autowired
        CommonService commonService;

        @Autowired
        private Environment env;

        @Autowired
        AdcRefCdValRepository adcRefCdValRepository;

        @GetMapping("/")
        public String getResponse(){ return "API Calls received by BOP"; }

        @PostMapping("/bop-inquiry")
        public ResponseEntity<Map> getInquiryDetail(HttpServletRequest httpServletRequest,
                                                    @RequestHeader("authorization") String parmBasicAuth,
                                                    @RequestBody Map<String, Object> parmMapObj) {
            Map<String, Object> mapRespObj = new HashMap<>();
            Long LoanAppSeq = 0L;
            boolean validLoanAppSeq = false;
            // IP Address
            String rmteAddrs = httpServletRequest.getRemoteAddr();

            // For Password Encryption
            aesEncryptionDecryption = new AESEncryptionDecryption();

            // Validate Credentials
            if (parmBasicAuth != null && !parmBasicAuth.isEmpty()) {
                //
                String base64Credentials = parmBasicAuth.substring("Basic".length()).trim();
                byte[] credDecoded = Base64.getDecoder().decode(base64Credentials);
                String credentials = new String(credDecoded, StandardCharsets.UTF_8);
                final String[] userCred = credentials.split(":", 2);

                logger.info("BOP- httpServletRequest.getHeader: " + httpServletRequest.getAuthType());
                logger.info("BOP- authorization: " + parmBasicAuth);
                logger.info("BOP- authorization USER Name: " + userCred[0]);
                logger.info("BOP- authorization PASSOWRD: " + userCred[1]);
                logger.info("BOP- authorization PASSOWRD: " + aesEncryptionDecryption.encrypt(userCred[1], "BOP"));
                logger.info("Bop-RemoteAddress: " + rmteAddrs);
                logger.info("Bop Inquiry-JSON: " + parmMapObj);

                BillInquiryDto billInquiryDto = new ObjectMapper().convertValue(parmMapObj, BillInquiryDto.class);
                mapRespObj = bopService.getInquiry(billInquiryDto.toJSONString(), rmteAddrs, userCred);

            } else {
                logger.warn("BOP: Basic Authentication invalid.");
                // Response Status -------  0003 INVALID USER/PASSWORD
                AdcRefCdVal refCdValRespSts = adcRefCdValRepository.findDistinctByCrntRecFlgAndRefCdGrpCodeAndRefCdValCode(true, "0009", "0003");
                mapRespObj = bopService.getEmptyBillingInquiry(refCdValRespSts.getRefCdValCode());
            }
            logger.warn("BOP: SSFSFSFSFSDFSF." + mapRespObj);
            return ResponseEntity.ok().body(mapRespObj);
        }

        @PostMapping("/bop-payment")
        public ResponseEntity<Map> getPaymentDetail(HttpServletRequest httpServletRequest,
                @RequestBody Map<String, Object> parmMapObj) {
            Map<String, Object> mapRespObj = new HashMap<>();
            Long clntSeq = 0L;
            boolean validClntSeq = false;
            // IP Address
            String rmteAddrs = httpServletRequest.getRemoteAddr();

        logger.info("BOP-RemoteAddress: " + rmteAddrs);

        // Body should have Inquiry Details
        if (parmMapObj.containsKey("BillPayment") && env.getProperty("telenor.tunnel.ip").contains(rmteAddrs)) {
            BillPaymentDto billPaymentDto = new ObjectMapper().convertValue(parmMapObj.get("BillPayment"), BillPaymentDto.class);

            try{
                clntSeq = Long.parseLong(billPaymentDto.getReference_no());
                validClntSeq = true;
            }catch(NumberFormatException nfex){
                logger.info("Non Numeric Conversion: " + nfex.getMessage());
            }catch(Exception ex){
                logger.info("Excepion: " + ex.getMessage());
            }

            // Verify Crenditals
            if ( validClntSeq == true && billPaymentDto.getBranch_code().equals("KASHFON1") &&
                    commonService.verifyCredentials("BoP",
                            billPaymentDto.getReference_no(), billPaymentDto.getReference_no())) {
                mapRespObj.put("GetBillPaymentRes",
                        bopService.applyPayment(billPaymentDto, rmteAddrs));
            } else {
                // Invalid Data
                mapRespObj.put("GetBillPaymentRes", bopService.getEmptyBillingInquiry("04"));
                logger.info("EP-GetBillPaymentRes invalid data. " + parmMapObj.toString());
            }
        } else {
            // Processing Failed
            mapRespObj.put("GetBillPaymentRes", bopService.getEmptyBillingInquiry("04"));
            logger.info("EP-GetBillPaymentRes invalid data. " + parmMapObj.toString());
        }

        return ResponseEntity.ok().body(mapRespObj);

    }
}
