/* Formatted on 11/05/2023 1:05:48 pm (QP5 v5.326) */
CREATE OR REPLACE PROCEDURE PRC_ADC_DSB_INTEGRATION (
    P_PRC_CALL   IN     VARCHAR2,                       ---- INQUIRY / PAYMENT
    P_JSON       IN     VARCHAR2,                            ---- REQUEST JSON
    P_RMT_ADDR   IN     VARCHAR2,           ---- REQUESTIG USER REMOTE ADDRESS
    P_USER       IN     VARCHAR2,                         ---- REQUESTING USER
    P_USERPASS   IN     VARCHAR2,                ---- REQUESTING USER PASSWORD
    P_RSP_JSON      OUT VARCHAR2,                           ---- RESPONSE JSON
    P_RTN_MSG       OUT VARCHAR2                           ---- RETURN MESSAGE
                                )
--    P_REFERENCE_NO      IN     NUMBER,      ---- XPIN/LOANAPPSEQ
--    P_CLNT_SEQ          IN     NUMBER,      ---- CLIENT ID/ CLIENT SEQ
--    P_AGENT_TYPE_ID     IN     VARCHAR2,    ---- OUR ASSIGNED ADC CODE/ BANK CODE
--    P_DSB_AMT           IN     NUMBER,      ---- DSB AMOUT
--    P_DT                IN     VARCHAR2,    ---- INQUIRY DATE/ PAYMENT DATE
--    P_TIME              IN     VARCHAR2,    ---- INQUIRY TIME/ PAYMENT TIME
--    P_PYMT_INSTR_NUM    IN     VARCHAR2,    ---- TRANSACTION NO/ ADC REFERANCE NUMBER
--    P_BANK_ADC          IN     VARCHAR2,    ---- BANK CODE/ ADC CODE SEND BY VENDOR
--    P_RESERVED          IN     VARCHAR2,    ---- RESERVED FIELD FOR INQUIRY OR PAYMENT
------------  OUT PARAMETERS  ---------------------
--    OP_CLNT_BRNCH_SEQ      OUT NUMBER,      ---- CLIENTS'S BRANCH SEQ
--    OP_CLNT_BRNCH_NM       OUT VARCHAR2,    ---- CLIENTS'S BRANCH NAM
--    OP_CLNT_SEQ            OUT NUMBER,      ---- CLIENTS SEQ
--    OP_CLNT_NM             OUT VARCHAR2,    ---- CLIENT NAME
--    OP_LOAN_APP_SEQ        OUT NUMBER,      ---- CLIENTS'S LOAN APP SEQ
--    OP_CLNT_CNIC           OUT NUMBER,      ---- CLIENTS'S CNIC
--    OP_DSB_AMT             OUT NUMBER,      ---- AMOUNT OF DISBURSEMENT
--    OP_DSB_DT              OUT DATE,        ---- EFFECTIVE DATE
--    OP_PYMT_STS            OUT CHAR,        ---- U � Unpaid /P � Paid/ R � Reversed/ I � Invalid
--    OP_TRANS_STS           OUT VARCHAR2,    ---- 0000 In case of valid consumer number that exists in the system/database of MFI.
--                                            ---- 0001 In case of invalid consumer number that does not exists.
--                                            ---- 0002 In case of Exception/Error.
--                                            ---- 0003 In case of Invalid username/password.
--                                            ---- 0004 Invalid Data
--                                            ---- 0005 Processing Failed*/
--    OP_RESERVED            OUT VARCHAR2,
--    OP_EXEC_STS            OUT VARCHAR2)
/******************************************************************************
   NAME:       PRC_ADC_CLNT_INQRY_PYMT
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        08/05/2023  YOUSAF.ALI       1. THIS PROCEDURE WILL BE USED:
                                                 A. TO RESPONSE DISBURRSEMENT INQUIRIES.
                                                 B. TO RESPONSE DISBURSMSNT TRANSACTIONS.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     PRC_ADC_DSB_INTEGRATION
      Sysdate:         08/05/2023
      Date and Time:   008/05/2023, 11:37:54 am, and 08/05/2023 11:37:54 am
      Username:        Yousaf.ali (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/
AS
    json_body      CLOB := P_JSON;
    -------  INQUIRY DECLARATIONS -------
    reference_no   NUMBER := NULL;
    transaction_date varchar2(20) := null;
    transaction_time VARCHAR2(20) := NULL;
    branch_code VARCHAR2(20) := NULL;
    stan NUMBER := NULL;
    reserved VARCHAR2(200) := NULL; 
    
    V_VENDOR_FOUND NUMBER := NULL;
    V_USER_FOUND  NUMBER := NULL;
    V_LOAN_APP_FOUND    NUMBER := NULL;
BEGIN
    -------  BASIC AUTHENTICATION ---------------------
    
    BEGIN
        SELECT VL.REF_CD_VAL_SEQ INTO V_VENDOR_FOUND
        FROM ADC.ADC_REF_CD_VAL VL
        WHERE VL.CRNT_REC_FLG = 1
        AND VL.REF_CD_GRP_CODE = '0001'
        AND VL.REF_CD_VAL_SHRT_DESC = 'BOP-DSB';
    EXCEPTION WHEN NO_DATA_FOUND
    THEN   
        SELECT PRC_BOP_EMPTY_RSP('0005') INTO P_RSP_JSON FROM DUAL;
        P_RTN_MSG := 'BOP: Vendor Entry Missing';
        KASHF_REPORTING.PRO_LOG_MSG ('PRC_ADC_DSB_INTEGRATION', P_RTN_MSG);
        RETURN;
    WHEN OTHERS
    THEN   
        SELECT PRC_BOP_EMPTY_RSP('0005') INTO P_RSP_JSON FROM DUAL;
        P_RTN_MSG := 'BOP: Generic Issue while getting Vendor Entry';
        KASHF_REPORTING.PRO_LOG_MSG ('PRC_ADC_DSB_INTEGRATION', P_RTN_MSG);
        RETURN;
    END;     
    
    -------  VARIFY USER/PASSWORD ---------
    
    SELECT COUNT(1) INTO V_USER_FOUND
    FROM ADC.ADC_USERS USR
    WHERE USR.REF_CD_VNDR_SEQ = V_VENDOR_FOUND
    and usr.crnt_rec_flg = 1
    AND USR.REF_CD_USR_TYP_SEQ = 6;   ---------  6 PRIMARY USER AND 7 FOR SECONDAY USER 
    
    IF V_USER_FOUND = 0
    THEN
        SELECT PRC_BOP_EMPTY_RSP('0003') INTO P_RSP_JSON FROM DUAL;
        P_RTN_MSG := 'BOP: User or Password not found against this Vendor';
        KASHF_REPORTING.PRO_LOG_MSG ('PRC_ADC_DSB_INTEGRATION', P_RTN_MSG);
        RETURN;
    END IF;
    

    --------------  FOR INQUIRY CALL ------------------
    IF P_PRC_CALL = 'INQUIRY'
    THEN
        SELECT TO_NUMBER (reference_no_), transaction_date_, transaction_time_, branch_code_, TO_NUMBER(stan_), reserved_
          INTO reference_no, transaction_date, transaction_time, branch_code, stan, reserved          
          FROM JSON_TABLE (
                   json_body FORMAT JSON,
                   '$[*]'
                   COLUMNS (
                       reference_no_ VARCHAR (2000) PATH '$.reference_no',
                       transaction_date_ VARCHAR (2000)
                           PATH '$.transaction_date',
                       transaction_time_ VARCHAR (2000)
                           PATH '$.transaction_time',
                       branch_code_ VARCHAR (2000) PATH '$.branch_code',
                       stan_ VARCHAR (2000) PATH '$.stan',
                       reserved_ VARCHAR (200) PATH '$.reserved'));

        IF (LENGTH(reference_no) < 9 OR  LENGTH(reference_no) > 20 OR 
            LENGTH(transaction_date) != 8 OR LENGTH(transaction_time) != 6 OR 
            LENGTH(branch_code) != 10 
            )
           THEN
            SELECT PRC_BOP_EMPTY_RSP('0004') INTO P_RSP_JSON FROM DUAL;
            P_RTN_MSG := 'BOP: Invalid data/ Data is not according to Document';
            KASHF_REPORTING.PRO_LOG_MSG ('PRC_ADC_DSB_INTEGRATION', P_RTN_MSG);
            RETURN;
        END IF;  
        
        SELECT COUNT(1)
            INTO V_LOAN_APP_FOUND
        FROM MW_LOAN_APP AP
        JOIN MW_DSBMT_VCHR_HDR DSH ON DSH.LOAN_APP_SEQ = AP.LOAN_APP_SEQ AND DSH.CRNT_REC_FLG = 1
        WHERE AP.LOAN_APP_SEQ = reference_no
        AND AP.LOAN_APP_STS IN (703,1305);
        
        IF V_LOAN_APP_FOUND = 0
        THEN
        -----------  TO CHECK IF CANCEL/REVERSED/ETC -----------
            SELECT COUNT(1)
            INTO V_LOAN_APP_FOUND
            FROM MW_LOAN_APP AP
            JOIN MW_DSBMT_VCHR_HDR DSH ON DSH.LOAN_APP_SEQ = AP.LOAN_APP_SEQ
            WHERE AP.LOAN_APP_SEQ = reference_no
            AND AP.LOAN_APP_STS IN (1107,1285);
            
            IF V_LOAN_APP_FOUND != 0
            THEN
                -- UPDATE QUE /TRX TABLES TO CANCEL.
                NULL;
            END IF;            
            
            SELECT PRC_BOP_EMPTY_RSP('0001') INTO P_RSP_JSON FROM DUAL;
            P_RTN_MSG := 'BOP: Loan App Seq/ reference_no not found/ or not active loan';
            KASHF_REPORTING.PRO_LOG_MSG ('PRC_ADC_DSB_INTEGRATION', P_RTN_MSG);
            RETURN;
        END IF;
        
        /*
        SELECT JSON_OBJECT ('status' VALUE P_RSP_CODE,
                            'reference_no' VALUE NULL,
                            'client_no' VALUE NULL,
                            'client_name' VALUE NULL,
                            'client_cnic' VALUE NULL,
                            'kashf_branch' VALUE NULL,
                            'loan_date' VALUE NULL,
                            'payment_status' VALUE NULL,
                            'amount' VALUE NULL,
                            'reserved' VALUE NULL)
                   AS json_body
          FROM DUAL;
          
        SELECT JSON_OBJECT (                             
                             KEY 'reference_no' IS LA.LOAN_APP_SEQ,
                             KEY 'client_no' IS LA.CLNT_SEQ,
                             KEY 'client_name' IS CLNT.FRST_NM ||' '||CLNT.LAST_NM,
                             KEY 'client_cnic' IS CLNT.CNIC_NUM,
                             KEY 'kashf_branch' IS BRNCH.BRNCH_NM,
                             KEY 'loan_date' IS TO_CHAR(ADQ.DSBMT_STS_DT,'RRRRMMDD'),
                             KEY 'payment_status' IS 'U',
                             KEY 'amount' IS LPAD(TO_CHAR(DVD.AMT)||'00',12,'0'),
                             KEY 'status' IS '0000',
                             KEY 'reserved' IS null)
                             AS json_body
                    FROM MW_ADC_DSBMT_QUE ADQ
                         JOIN MW_DSBMT_VCHR_DTL DVD
                             ON     DVD.DSBMT_DTL_KEY = ADQ.DSBMT_DTL_KEY
                                AND DVD.CRNT_REC_FLG = 1
                         JOIN MW_DSBMT_VCHR_HDR DVH
                             ON     DVH.DSBMT_HDR_SEQ = ADQ.DSBMT_HDR_SEQ
                                AND DVH.CRNT_REC_FLG = 1
                         JOIN MW_LOAN_APP LA
                             ON     LA.LOAN_APP_SEQ = DVH.LOAN_APP_SEQ
                                AND LA.CRNT_REC_FLG = 1
                         JOIN MW_CLNT CLNT
                             ON     CLNT.CLNT_SEQ = LA.CLNT_SEQ
                                AND CLNT.CRNT_REC_FLG = 1
                         JOIN MW_BRNCH BRNCH
                             ON     BRNCH.BRNCH_SEQ = LA.BRNCH_SEQ
                                AND BRNCH.CRNT_REC_FLG = 1
                   WHERE ADQ.CRNT_REC_FLG = 1 AND ADQ.IS_PROCESSED = 0
                ORDER BY ADQ.DSBMT_DTL_KEY)
         WHERE ROWNUM <= 1000;
        
        
        */
        
        P_RTN_MSG :=
               'P_PRC_CALL : '
            || P_PRC_CALL
            || CHR (10)
            || 'P_JSON : '
            || P_JSON
            || CHR (10)
            || 'P_RMT_ADDR : '
            || P_RMT_ADDR
            || CHR (10)
            || 'P_USER : '
            || P_USER
            || CHR (10)
            || 'P_USERPASS : '
            || P_USERPASS
            || CHR (10)
            || 'P_RSP_JSON : '
            || P_RSP_JSON
            || CHR (10)
            || 'reference_no :'
            || reference_no;

        KASHF_REPORTING.PRO_LOG_MSG ('PRC_ADC_DSB_INTEGRATION', P_RTN_MSG);
        COMMIT;
    END IF;
END;
/
