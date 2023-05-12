--
-- Create Schema Script
--   Database Version            : 19.0.0.0.0
--   Database Compatible Level   : 19.0.0
--   Script Compatible Level     : 19.0.0
--   Toad Version                : 13.0.0.80
--   DB Connect String           : 192.168.7.75:1521/DEVQA
--   Schema                      : MWX_KASHF_DEV
--   Script Created by           : MWX_KASHF_DEV
--   Script Created at           : 12/05/2023 11:25:01 am
--   Notes                       : 
--

-- Object Counts: 
--   Triggers: 1 


CREATE OR REPLACE TRIGGER TRG_MW_LOAN_APP_DSBMT
    AFTER UPDATE OF LOAN_APP_STS
    ON MW_LOAN_APP
    FOR EACH ROW
DECLARE
    /******************************************************************************
       NAME:       TRG_MW_LOAN_APP_DSBMT
       PURPOSE:

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        07/06/2022      Zohaib.Asim       1. Created this trigger.
       2.0        07/06/2022      Yousaf.Ali        1. Add BOP Disbursements.

       NOTES:

       Automatically available Auto Replace Keywords:
          Object Name:     TRG_MW_LOAN_APP_DSBMT
          Sysdate:         07/06/2022
          Date and Time:   07/06/2022, 4:53:54 pm, and 07/06/2022 4:53:54 pm
          Username:        Zohaib.Asim (set in TOAD Options, Proc Templates)
          Table Name:       (set in the "New PL/SQL Object" dialog)
          Trigger Options:  AFTER UPDATE ON MW_LOAN_APP
    FOR EACH ROW
     (set in the "New PL/SQL Object" dialog)
    ******************************************************************************/
    V_MCB_DSBMT_FLG   BOOLEAN := TRUE;
    --
    V_EXPNS_TYP_ID    MW_EXP.EXPNS_TYP_SEQ%TYPE;
    V_PYMT_TYP_ID     MW_EXP.PYMT_TYP_SEQ%TYPE;
    --
    V_COUNT_REC       NUMBER (10) := 0;
BEGIN
    ----------------------------------------------------------------------------
    ----------------------------------------------------------------------------
    -- Added by Zohaib Asim - Dated 13-04-2022
    -- MCB REMITTENCE DISBURSEMENTS
    -- 30 - KASUR-02
    -- 38 - QANCHI

    -- 27 - KASUR-01
    -- 28 - MUSTAFA ABAD
    -- 29 - RAIWIND
    -- 37 - KHUDIAN
    -- 376 - KOT RADHA KISHAN
    IF                 -- (:NEW.BRNCH_SEQ IN (27, 28, 29, 30, 37, 38, 376) AND
       :OLD.LOAN_APP_STS IN (702, 1077) AND :NEW.LOAN_APP_STS IN (703, 1305)
    THEN
        -- 0501 - SALE-01
        -- 1 - TYP_CTGRY_KEY AND 0 - BRANCH
        FOR IND
            IN (SELECT DVH.DSBMT_HDR_SEQ,
                       DVD.DSBMT_DTL_KEY,
                       DVD.PYMT_TYPS_SEQ
                  FROM MW_DSBMT_VCHR_DTL  DVD
                       JOIN MW_DSBMT_VCHR_HDR DVH
                           ON     DVH.DSBMT_HDR_SEQ = DVD.DSBMT_HDR_SEQ
                              AND DVH.CRNT_REC_FLG = 1
                 WHERE     DVH.LOAN_APP_SEQ = :NEW.LOAN_APP_SEQ
                       AND DVD.CRNT_REC_FLG = 1
                       AND DVD.PYMT_TYPS_SEQ IN
                               (SELECT TYPS.TYP_SEQ
                                  FROM MW_TYPS TYPS
                                 WHERE     TYPS.TYP_CTGRY_KEY IN (1, 3)
                                       AND TYPS.TYP_ID IN ('0501', '0007','0004') -- 0501:advance, 0007:MCB, 0004:BOP
                                       AND TYPS.CRNT_REC_FLG = 1
                                       AND TYPS.BRNCH_SEQ IN
                                               (0, :NEW.BRNCH_SEQ)))
        LOOP
            
             V_PYMT_TYP_ID := IND.PYMT_TYPS_SEQ;
             
            -- SALE-01           
            
            IF :NEW.LOAN_APP_STS = 1305 --- advance/sale-01
            THEN
                V_MCB_DSBMT_FLG := FALSE;

                --
                SELECT EXPNS_TYP.TYP_ID, PYMT_TYP.TYP_ID
                  INTO V_EXPNS_TYP_ID, V_PYMT_TYP_ID
                  FROM MW_EXP  ME
                       JOIN MW_TYPS EXPNS_TYP
                           ON     EXPNS_TYP.TYP_SEQ = ME.EXPNS_TYP_SEQ
                              AND EXPNS_TYP.CRNT_REC_FLG = 1
                       JOIN MW_TYPS PYMT_TYP
                           ON     PYMT_TYP.TYP_SEQ = ME.PYMT_TYP_SEQ
                              AND PYMT_TYP.CRNT_REC_FLG = 1
                 WHERE     ME.EXP_REF = TO_CHAR (:NEW.LOAN_APP_SEQ)
                       AND ME.CRNT_REC_FLG = 1;

                IF V_PYMT_TYP_ID IN ('0007','0004')
                THEN
                    V_MCB_DSBMT_FLG := TRUE;                    
                END IF;
            END IF;

            -- IN CASE RECOVERY POSTED FOR THIS LOAN
            SELECT COUNT (RT.RCVRY_TRX_SEQ)
              INTO V_COUNT_REC
              FROM MW_RCVRY_TRX       RT,
                   MW_RCVRY_DTL       RD,
                   MW_PYMT_SCHED_DTL  PSD,
                   MW_PYMT_SCHED_HDR  PSH
             WHERE     RT.RCVRY_TRX_SEQ = RD.RCVRY_TRX_SEQ
                   AND RD.PYMT_SCHED_DTL_SEQ = PSD.PYMT_SCHED_DTL_SEQ
                   AND PSD.PYMT_SCHED_HDR_SEQ = PSH.PYMT_SCHED_HDR_SEQ
                   AND PSH.LOAN_APP_SEQ = :NEW.LOAN_APP_SEQ
                   AND RT.CRNT_REC_FLG = 1
                   AND RD.CRNT_REC_FLG = 1
                   AND PSD.CRNT_REC_FLG = 1
                   AND PSH.CRNT_REC_FLG = 1;

            IF V_COUNT_REC > 0
            THEN
                V_MCB_DSBMT_FLG := FALSE;
            END IF;

            --
            V_COUNT_REC := 0;

            -- IN CASE DISBURSEMENT ALREADY POSTED TO MCB
            SELECT COUNT (ADQ.DSBMT_DTL_KEY)
              INTO V_COUNT_REC
              FROM MW_ADC_DSBMT_QUE ADQ
             WHERE     ADQ.DSBMT_HDR_SEQ = IND.DSBMT_HDR_SEQ
                   AND ADQ.DSBMT_DTL_KEY = IND.DSBMT_DTL_KEY
                   AND ADQ.CRNT_REC_FLG = 1;

            IF V_COUNT_REC > 0
            THEN
                V_MCB_DSBMT_FLG := FALSE;
            END IF;

            --
            V_COUNT_REC := 0;

            -- IN CASE DISBURSEMENT ALREADY POSTED TO MCB AGAINST LOAN NO
            SELECT COUNT (ADQ.LOAN_APP_SEQ)
              INTO V_COUNT_REC
              FROM MW_ADC_DSBMT_QUE ADQ
             WHERE     ADQ.LOAN_APP_SEQ = :OLD.LOAN_APP_SEQ
                   AND ADQ.CRNT_REC_FLG = 1;

            IF V_COUNT_REC > 0
            THEN
                V_MCB_DSBMT_FLG := FALSE;
            END IF;

            --
            IF V_MCB_DSBMT_FLG = TRUE
            THEN
                --
                INSERT INTO MW_ADC_DSBMT_QUE (DSBMT_DTL_KEY,
                                              DSBMT_HDR_SEQ,
                                              DSBMT_STS_SEQ,
                                              DSBMT_STS_DT,
                                              ADC_STS_SEQ,
                                              ADC_STS_DT,
                                              REMARKS,
                                              IS_PROCESSED,
                                              CRNT_REC_FLG,
                                              CRTD_DT,
                                              CRTD_BY,
                                              LAST_UPD_DT,
                                              LAST_UPD_BY,
                                              LOAN_APP_SEQ,
                                              PYMT_MODE)
                         VALUES (
                             IND.DSBMT_DTL_KEY,
                             IND.DSBMT_HDR_SEQ,
                             (SELECT RCV.REF_CD_SEQ
                                FROM MW_REF_CD_VAL  RCV
                                     JOIN MW_REF_CD_GRP RCG
                                         ON     RCG.REF_CD_GRP_SEQ =
                                                RCV.REF_CD_GRP_KEY
                                            AND RCG.CRNT_REC_FLG =
                                                RCV.CRNT_REC_FLG
                                            AND RCG.REF_CD_GRP = '0040'
                               WHERE     RCV.CRNT_REC_FLG = 1
                                     AND RCV.REF_CD = '0001'),
                             SYSDATE,
                             (SELECT RCV.REF_CD_SEQ
                                FROM MW_REF_CD_VAL  RCV
                                     JOIN MW_REF_CD_GRP RCG
                                         ON     RCG.REF_CD_GRP_SEQ =
                                                RCV.REF_CD_GRP_KEY
                                            AND RCG.CRNT_REC_FLG =
                                                RCV.CRNT_REC_FLG
                                            AND RCG.REF_CD_GRP = '0040'
                               WHERE     RCV.CRNT_REC_FLG = 1
                                     AND RCV.REF_CD = '0003'),
                             SYSDATE,
                             NULL,
                             0,
                             1,
                             SYSDATE,
                             :OLD.LAST_UPD_BY,
                             NULL,
                             NULL,
                             :OLD.LOAN_APP_SEQ,
                             V_PYMT_TYP_ID);
            END IF;
        END LOOP;
    END IF;
EXCEPTION
    WHEN OTHERS
    THEN
        -- Consider logging the error and then re-raise
        RAISE_APPLICATION_ERROR (
            -20001,
               'EXCEPTION AT '
            || ' LINE NO: '
            || $$PLSQL_LINE
            || CHR (10)
            || ' ERROR CODE: '
            || SQLCODE
            || ' ERROR MESSAGE: '
            || SQLERRM
            || 'TRACE: '
            || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
END TRG_MW_LOAN_APP_DSBMT;
/
SHOW ERRORS;
/