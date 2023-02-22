CREATE OR REPLACE PROCEDURE KSHF_ITQA.PRC_INCDNT_PROCESS(P_INCDNT_DT        VARCHAR2,
                                               P_CLNT_SEQ         NUMBER, --3800042057
                                               P_INCDNT_TYP       NUMBER, --302180
                                               P_INCDNT_CTGRY     NUMBER, -- 302144
                                               P_INCDNT_EFFECTEE  NUMBER, -- 302154 
                                               P_INCDNT_CAUSE     VARCHAR2,
                                               P_INCDNT_CMNTS     VARCHAR2,
                                               P_INCDNT_REF       NUMBER,
                                               P_INCDNT_REF_RMRKS VARCHAR2,
                                               P_INCDNT_USER      VARCHAR2,
                                               P_INCDNT_RVRSE     NUMBER DEFAULT 0,
                                               P_INCDNT_RTN_MSG   OUT VARCHAR2) AS
  V_INCDNT_DT              DATE;
  V_NOM                    NUMBER := 0;
  V_CLNT_TAG               VARCHAR2(100);
  V_OD_COUNT               NUMBER;
  V_UNPOSTED_RECOVERY      NUMBER;
  V_INCDNT_ENTRY_FOUND     NUMBER := 0;
  V_BRNCH_SEQ              MW_BRNCH.BRNCH_SEQ%TYPE;
  V_PRNT_LOAN_APP_SEQ      MW_LOAN_APP.PRNT_LOAN_APP_SEQ%TYPE;
  V_CNIC_NUM               MW_CLNT.CNIC_NUM%TYPE;
  P_INCDNT_RTN_RCV_MSG     VARCHAR2(500);
  P_INCDNT_RTN_MSGCALC     VARCHAR2(500);
  V_RVRSE_ALL_ADV          NUMBER := 0;
  V_RVRSE_ALL_EXPT_SM_MNTH NUMBER := 0;
  V_DED_AMT                NUMBER := 0;
  V_DED_AMT_TOT            NUMBER := 0;
  V_INC_PRIMUM_AMT         NUMBER := 0;
  V_UNIQUE_NUMBER          NUMBER := PSC_DEF_UNIQUE_NUM_SEQ.NEXTVAL;
  V_INCDNT_REF             NUMBER := 0;
  ---------------  FOR REVERSAL ------------------
  V_JV_HDR_SEQ_REV     NUMBER;
  V_RCVRY_TRX_SEQ_RVSL NUMBER;
  V_JV_HDR_SEQ_RESL    NUMBER;
  V_JV_HDR_SEQ_FUN     NUMBER;
  V_JV_HDR_SEQ_REC     NUMBER;
  V_INCIDENT_STS       VARCHAR2(40);
  P_INCDNT_RTN_MSG_DEF VARCHAR2(500);
  -----------------  CURSOR TO GET INCDNT SETUP INFORMATION -----------------
 /* CURSOR CR_STP_INCDNT(P_INCDNT_TYP      NUMBER,
                       P_INCDNT_CTGRY    NUMBER,
                       P_INCDNT_EFFECTEE NUMBER,
                       P_INCDNT_CHRG     VARCHAR2) IS
    SELECT STP.INCDNT_STP_SEQ,
           STP.INCDNT_TYP,
           (SELECT VL.REF_CD_DSCR
              FROM MW_REF_CD_VAL VL
             WHERE VL.REF_CD_SEQ = STP.INCDNT_TYP
               AND VL.CRNT_REC_FLG = 1) INCDNT_TYPE_DESC,
           STP.INCDNT_CTGRY,
           (SELECT VL.REF_CD_DSCR
              FROM MW_REF_CD_VAL VL
             WHERE VL.REF_CD_SEQ = STP.INCDNT_CTGRY
               AND VL.CRNT_REC_FLG = 1) INCDNT_CTGRY_DESC,
           STP.INCDNT_EFFECTEE,
           (SELECT VL.REF_CD_DSCR
              FROM MW_REF_CD_VAL VL
             WHERE VL.REF_CD_SEQ = STP.INCDNT_EFFECTEE
               AND VL.CRNT_REC_FLG = 1) INCDNT_EFFECTEE_DESC,
           STP.PRD_CHRG,
           (SELECT VL.REF_CD
              FROM MW_REF_CD_VAL VL
             WHERE VL.REF_CD_SEQ = STP.PRD_CHRG
               AND VL.CRNT_REC_FLG = 1) PRD_CHRG_CD,
           (SELECT VL.REF_CD_DSCR
              FROM MW_REF_CD_VAL VL
             WHERE VL.REF_CD_SEQ = STP.PRD_CHRG
               AND VL.CRNT_REC_FLG = 1) PRD_CHRG_DESC,
           STP.FXD_PRMUM,
           (SELECT VL.REF_CD_DSCR
              FROM MW_REF_CD_VAL VL
             WHERE VL.REF_CD_SEQ = STP.FXD_PRMUM
               AND VL.CRNT_REC_FLG = 1) FXD_PRMUM_DESC,
           STP.RVRSE_ALL_ADV,
           STP.RVRSE_ALL_EXPT_SM_MNTH,
           STP.DED_SM_MNTH,
           STP.DED_BASE,
           (SELECT CASE
                     WHEN VL.REF_CD_DSCR =
                          'Based on current 12 installments bucket' THEN
                      1
                     WHEN VL.REF_CD_DSCR =
                          'Based on current 6 installments bucket' THEN
                      2
                     WHEN VL.REF_CD_DSCR =
                          'Based on current 18 installments bucket' THEN
                      3
                     WHEN VL.REF_CD_DSCR =
                          'Based on current 24 installments bucket' THEN
                      4
                     WHEN VL.REF_CD_DSCR = 'Deduct all installment' THEN
                      5
                   END
              FROM MW_REF_CD_VAL VL
             WHERE VL.REF_CD_SEQ = STP.DED_BASE
               AND VL.CRNT_REC_FLG = 1) DED_BASE_DESC,
           STP.DED_APLD_ON,
           (SELECT CASE
                     WHEN VL.REF_CD_DSCR =
                          'First disbursed product along with associate product' THEN
                      1
                     ELSE
                      0
                   END
              FROM MW_REF_CD_VAL VL
             WHERE VL.REF_CD_SEQ = STP.DED_APLD_ON
               AND VL.CRNT_REC_FLG = 1) DED_APLD_ON_DESC
      FROM MW_STP_INCDNT STP
     WHERE STP.INCDNT_TYP = P_INCDNT_TYP
       AND STP.INCDNT_CTGRY = P_INCDNT_CTGRY
       AND STP.INCDNT_EFFECTEE = P_INCDNT_EFFECTEE
       AND (SELECT VL.REF_CD_DSCR
              FROM MW_REF_CD_VAL VL
             WHERE VL.REF_CD_SEQ = STP.PRD_CHRG
               AND VL.CRNT_REC_FLG = 1) = P_INCDNT_CHRG
       AND STP.CRNT_REC_FLG = 1;*/
BEGIN
  V_INCDNT_DT := TO_DATE(P_INCDNT_DT, 'DD-MON-RRRR');
  --V_INCDNT_DT := '01-JAN-2023';    ------------- P_INCDNT_DT ---------------
  V_INCDNT_REF := P_INCDNT_REF;
  -- V_INCDNT_REF := 120100000125344494;
  ------------  CHECK FOR NACTA TAGGED -------------------------
  SELECT FN_FIND_CLNT_TAGGED('AML', P_CLNT_SEQ, NULL)
    INTO V_CLNT_TAG
    FROM DUAL;
  IF V_CLNT_TAG LIKE 'SUCCESS:%' THEN
    P_INCDNT_RTN_MSG := 'FAILED: NACTA Matched. Client and other individual/s (Nominee/CO borrower/Next of Kin) cannot be Adjusted';
    RETURN;
  END IF;
  ----------  CHECK OD --------------
  SELECT COUNT(1)
    INTO V_OD_COUNT
    FROM MW_PYMT_SCHED_DTL DTL
    JOIN MW_PYMT_SCHED_HDR HDR
      ON HDR.PYMT_SCHED_HDR_SEQ = DTL.PYMT_SCHED_HDR_SEQ
     AND HDR.CRNT_REC_FLG = 1
    JOIN MW_LOAN_APP APP
      ON APP.LOAN_APP_SEQ = HDR.LOAN_APP_SEQ
     AND APP.CRNT_REC_FLG = 1
   WHERE APP.CLNT_SEQ = P_CLNT_SEQ
     AND APP.LOAN_APP_STS IN (703, 1305)
     AND DTL.DUE_DT < V_INCDNT_DT
     AND APP.OD_CHK_FLG = 0
     AND DTL.PYMT_STS_KEY IN (945, 1145);
  IF V_OD_COUNT > 0 THEN
    P_INCDNT_RTN_MSG := 'FAILED: OD CHECK. Client has OD Amount';
    RETURN;
  END IF;
  SELECT BRNCH_SEQ, AP.PRNT_LOAN_APP_SEQ
    INTO V_BRNCH_SEQ, V_PRNT_LOAN_APP_SEQ
    FROM MW_LOAN_APP AP
   WHERE AP.CLNT_SEQ = P_CLNT_SEQ
     AND AP.CRNT_REC_FLG = 1
     AND AP.LOAN_APP_STS IN (703, 1305)
   ORDER BY 2 DESC FETCH NEXT 1 ROWS ONLY;
  IF P_INCDNT_RVRSE = 0 ----------  FOR INCIDENT ENTRY
   THEN
    ---------------------  TO CHECK IF NOMIEE ---------------------------------------
    SELECT COUNT(1)
      INTO V_NOM
      FROM MW_REF_CD_VAL VL
      JOIN MW_REF_CD_GRP GRP
        ON GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
       AND GRP.CRNT_REC_FLG = 1
     WHERE VL.REF_CD_SEQ = P_INCDNT_EFFECTEE
       AND VL.CRNT_REC_FLG = 1
       AND VL.REF_CD = 1
       AND GRP.REF_CD_GRP = '0418';
    IF V_NOM <> 0 THEN
      SELECT MAX(MRL.CNIC_NUM)
        INTO V_CNIC_NUM
        FROM MW_LOAN_APP AP
        JOIN MW_CLNT_REL MRL
          ON MRL.LOAN_APP_SEQ = AP.LOAN_APP_SEQ
         AND MRL.CRNT_REC_FLG = 1
         AND MRL.REL_TYP_FLG = 1
       WHERE AP.LOAN_APP_STS IN (703, 1305)
         AND AP.LOAN_APP_SEQ = AP.PRNT_LOAN_APP_SEQ
         AND AP.CLNT_SEQ = P_CLNT_SEQ;
    ELSE
      SELECT CNIC_NUM
        INTO V_CNIC_NUM
        FROM MW_CLNT MC
       WHERE MC.CLNT_SEQ = P_CLNT_SEQ
         AND MC.CRNT_REC_FLG = 1;
    END IF;
    ------ CHECK IF INCDNT REPORTED ALREADY -----------
    SELECT COUNT(1)
      INTO V_INCDNT_ENTRY_FOUND
      FROM MW_INCDNT_RPT INC
     WHERE INC.CLNT_SEQ = P_CLNT_SEQ
       AND INC.CRNT_REC_FLG = 1
       AND INC.INCDNT_STS IN (SELECT VL.REF_CD_SEQ
                                FROM MW_REF_CD_VAL VL
                                JOIN MW_REF_CD_GRP GRP
                                  ON GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                                 AND GRP.CRNT_REC_FLG = 1
                               WHERE GRP.REF_CD_GRP = '0425'
                                 AND VL.REF_CD != '0003');
    IF V_INCDNT_ENTRY_FOUND > 0 THEN
      P_INCDNT_RTN_MSG := 'FAILED: INCIDENT ENTRY IS IN PROCESS ALREADY....';
      RETURN;
    END IF;
    -----------  UNPOSTED RECOVERY CHECK --------
    SELECT COUNT(1)
      INTO V_UNPOSTED_RECOVERY
      FROM MW_RCVRY_TRX RCH
     WHERE RCH.PYMT_REF = P_CLNT_SEQ
       AND RCH.POST_FLG = 0
       AND RCH.CRNT_REC_FLG = 1;
    IF V_UNPOSTED_RECOVERY > 0 THEN
      P_INCDNT_RTN_MSG := 'FAILED: UNPOSTED RECOVERY. Client has Unposted recovery';
      RETURN;
    END IF;
    -----------  SAVE DATA INTO INCENT REPORT TABLE -----------------
    INSERT INTO MW_INCDNT_RPT
      (INCDNT_RPT_SEQ,
       CLNT_SEQ,
       INCDNT_EFFECTEE,
       INCDNT_TYP,
       INCDNT_CTGRY,
       DT_OF_INCDNT,
       CAUSE_OF_INCDNT,
       INCDNT_REF,
       INCDNT_REF_RMRKS,
       CRTD_BY,
       CRTD_DT,
       LAST_UPD_BY,
       LAST_UPD_DT,
       DEL_FLG,
       EFF_END_DT,
       CRNT_REC_FLG,
       AMT,
       CMNT,
       CLM_STS,
       INCDNT_STS)
    VALUES
      (INCDNT_RPT_SEQ.NEXTVAL,
       P_CLNT_SEQ,
       P_INCDNT_EFFECTEE,
       P_INCDNT_TYP,
       P_INCDNT_CTGRY,
       V_INCDNT_DT,
       P_INCDNT_CAUSE,
       V_INCDNT_REF,
       P_INCDNT_REF_RMRKS,
       P_INCDNT_USER,
       SYSDATE,
       P_INCDNT_USER,
       SYSDATE,
       0,
       NULL,
       1,
       0,
       P_INCDNT_CMNTS,
       NULL,
       -1);
    ---------  SAVE DATA IN TAG VALIDATION TO STOP IN CNIC VALIDATION--------
    INSERT INTO MW_CLNT_TAG_LIST
      (CLNT_TAG_LIST_SEQ,
       EFF_START_DT,
       CNIC_NUM,
       TAGS_SEQ,
       CRTD_BY,
       CRTD_DT,
       LAST_UPD_BY,
       LAST_UPD_DT,
       EFF_END_DT,
       DEL_FLG,
       TAG_FROM_DT,
       TAG_TO_DT,
       RMKS,
       SYNC_FLG,
       LOAN_APP_SEQ,
       CRNT_REC_FLG)
    VALUES
      (CLNT_TAG_LIST_SEQ.NEXTVAL,
       SYSDATE,
       V_CNIC_NUM,
       5,
       P_INCDNT_USER,
       SYSDATE,
       P_INCDNT_USER,
       SYSDATE,
       NULL,
       0,
       SYSDATE,
       NULL,
       'Death',
       NULL,
       V_PRNT_LOAN_APP_SEQ,
       1);
    ------------  GET RECOVERY REVERSAL STP DATA ---------
    BEGIN
      SELECT STP.RVRSE_ALL_ADV, STP.RVRSE_ALL_EXPT_SM_MNTH
        INTO V_RVRSE_ALL_ADV, V_RVRSE_ALL_EXPT_SM_MNTH
        FROM MW_STP_INCDNT STP
       WHERE STP.INCDNT_TYP = P_INCDNT_TYP
         AND STP.INCDNT_CTGRY = P_INCDNT_CTGRY
         AND STP.INCDNT_EFFECTEE = P_INCDNT_EFFECTEE
         AND STP.CRNT_REC_FLG = 1
       GROUP BY STP.RVRSE_ALL_ADV, STP.RVRSE_ALL_EXPT_SM_MNTH;
    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        P_INCDNT_RTN_MSG := 'PRC_INCDNT_PROCESS ==> ERROR IN GETTING VALUES FROM MW_STP_INCDNT => LINE NO: ' ||
                            $$PLSQL_LINE || CHR(10) || ' ERROR CODE: ' ||
                            SQLCODE || ' ERROR MESSAGE: ' || SQLERRM ||
                            'TRACE: ' ||
                            SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        KASHF_REPORTING.PRO_LOG_MSG('PRC_INCDNT_PROCESS', P_INCDNT_RTN_MSG);
        P_INCDNT_RTN_MSG := 'Issue in getting Incident Setup Values -0001';
        RETURN;
    END;
    IF V_RVRSE_ALL_ADV = 1 ------------  IF ALL RECOVERIES REVERSAL IN CASE OF INCIDENT
     THEN
      ---------  CALL ADVANCE RECVERY REVERSAL, EXCESS PAID -----------------
      PRC_INCDNT_RVRSE_RCVRY(P_CLNT_SEQ,
                             V_INCDNT_DT,
                             1, ----------------   ALL RECOVERIES REVERSAL
                             P_INCDNT_USER,
                             P_INCDNT_RTN_RCV_MSG);
      IF P_INCDNT_RTN_RCV_MSG != 'SUCCESS' THEN
        ROLLBACK;
        P_INCDNT_RTN_MSG := 'PRC_INCDNT_PROCESS ==> ERROR IN PRC_INCDNT_RVRSE_RCVRY => LINE NO: ' ||
                            $$PLSQL_LINE || CHR(10) || ' ERROR CODE: ' ||
                            SQLCODE || ' ERROR MESSAGE: ' || SQLERRM ||
                            'TRACE: ' ||
                            SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        KASHF_REPORTING.PRO_LOG_MSG('PRC_INCDNT_PROCESS', P_INCDNT_RTN_MSG);
        P_INCDNT_RTN_MSG := 'Issue in Recovery Reversal -0001';
        RETURN;
      END IF;
    ELSIF V_RVRSE_ALL_EXPT_SM_MNTH = 1 THEN
      ---------  CALL ADVANCE RECVERY REVERSAL, EXCESS PAID -----------------
      PRC_INCDNT_RVRSE_RCVRY(P_CLNT_SEQ,
                             V_INCDNT_DT,
                             2, ----------------   ALL RECOVERIES REVERSAL EXCEPT SAME MONTH
                             P_INCDNT_USER,
                             P_INCDNT_RTN_RCV_MSG);
      IF P_INCDNT_RTN_RCV_MSG != 'SUCCESS' THEN
        ROLLBACK;
        P_INCDNT_RTN_MSG := 'PRC_INCDNT_PROCESS ==> ERROR IN PRC_INCDNT_RVRSE_RCVRY => LINE NO: ' ||
                            $$PLSQL_LINE || CHR(10) || ' ERROR CODE: ' ||
                            SQLCODE || ' ERROR MESSAGE: ' || SQLERRM ||
                            'TRACE: ' ||
                            SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        KASHF_REPORTING.PRO_LOG_MSG('PRC_INCDNT_PROCESS', P_INCDNT_RTN_MSG);
        P_INCDNT_RTN_MSG := 'Issue in Recovery Reversal -0002';
        RETURN;
      END IF;
    END IF;
    ----------------  FOR LOOP (SELECT ALL THE CHARGES OF A CLNT) -----------------
    FOR CHRGS IN (SELECT INCDNT_TYP,
                         INCDNT_CTGRY,
                         INCDNT_CHRG,
                         INCDNT_EFFECTEE
                    FROM (SELECT IRP.INCDNT_TYP,
                                 IRP.INCDNT_CTGRY,
                                 CASE
                                   WHEN PSC.CHRG_TYPS_SEQ = -2 AND
                                        PRD.PRD_GRP_SEQ NOT IN
                                        (6, 24, 13, 5766, 22) THEN
                                    'KSZB'
                                   WHEN PSC.CHRG_TYPS_SEQ = -2 AND
                                        PRD.PRD_GRP_SEQ IN (13, 5766, 22) THEN
                                    'KC'
                                   WHEN PSC.CHRG_TYPS_SEQ = -2 AND
                                        PRD.PRD_GRP_SEQ IN (6, 24) THEN
                                    'KST'
                                   WHEN PSC.CHRG_TYPS_SEQ != -2 THEN
                                    (SELECT MT.TYP_STR
                                       FROM MW_TYPS MT
                                      WHERE MT.TYP_SEQ = PSC.CHRG_TYPS_SEQ
                                        AND MT.CRNT_REC_FLG = 1)
                                   ELSE
                                    'NO CHARGE'
                                 END INCDNT_CHRG,
                                 IRP.INCDNT_EFFECTEE,
                                 AP.CRTD_DT
                            FROM MW_INCDNT_RPT IRP
                            JOIN MW_LOAN_APP AP
                              ON AP.CLNT_SEQ = IRP.CLNT_SEQ
                             AND AP.CRNT_REC_FLG = 1
                             AND AP.LOAN_APP_SEQ = AP.PRNT_LOAN_APP_SEQ
                            JOIN MW_PRD PRD
                              ON PRD.PRD_SEQ = AP.PRD_SEQ
                             AND PRD.CRNT_REC_FLG = 1
                            JOIN MW_DSBMT_VCHR_HDR DSH
                              ON DSH.LOAN_APP_SEQ = AP.LOAN_APP_SEQ
                             AND DSH.CRNT_REC_FLG = 1
                            JOIN MW_PYMT_SCHED_HDR PSH
                              ON PSH.LOAN_APP_SEQ = DSH.LOAN_APP_SEQ
                             AND PSH.CRNT_REC_FLG = 1
                            JOIN MW_PYMT_SCHED_DTL PSD
                              ON PSD.PYMT_SCHED_HDR_SEQ =
                                 PSH.PYMT_SCHED_HDR_SEQ
                             AND PSD.CRNT_REC_FLG = 1
                            LEFT OUTER JOIN MW_PYMT_SCHED_CHRG PSC
                              ON PSC.PYMT_SCHED_DTL_SEQ =
                                 PSD.PYMT_SCHED_DTL_SEQ
                             AND PSC.CRNT_REC_FLG = 1
                           WHERE IRP.CLNT_SEQ = P_CLNT_SEQ
                             AND IRP.CRNT_REC_FLG = 1
                             AND AP.LOAN_APP_STS IN (703, 1305)
                             AND TRUNC(IRP.DT_OF_INCDNT) >=
                                 TRUNC(DSH.DSBMT_DT)
                           ORDER BY AP.CRTD_DT)
                   GROUP BY INCDNT_TYP,
                            INCDNT_CTGRY,
                            INCDNT_CHRG,
                            INCDNT_EFFECTEE
                   ORDER BY INCDNT_CHRG) LOOP
      V_DED_AMT := 0;
      IF CHRGS.INCDNT_CHRG IS NOT NULL THEN
        ------------  FETCH INCIDENT SETUP CURSOR DATA -----------
        FOR STP IN (SELECT STP.INCDNT_STP_SEQ,
                           STP.INCDNT_TYP,
                           (SELECT VL.REF_CD_DSCR
                              FROM MW_REF_CD_VAL VL
                             WHERE VL.REF_CD_SEQ = STP.INCDNT_TYP
                               AND VL.CRNT_REC_FLG = 1) INCDNT_TYPE_DESC,
                           STP.INCDNT_CTGRY,
                           (SELECT VL.REF_CD_DSCR
                              FROM MW_REF_CD_VAL VL
                             WHERE VL.REF_CD_SEQ = STP.INCDNT_CTGRY
                               AND VL.CRNT_REC_FLG = 1) INCDNT_CTGRY_DESC,
                           STP.INCDNT_EFFECTEE,
                           (SELECT VL.REF_CD_DSCR
                              FROM MW_REF_CD_VAL VL
                             WHERE VL.REF_CD_SEQ = STP.INCDNT_EFFECTEE
                               AND VL.CRNT_REC_FLG = 1) INCDNT_EFFECTEE_DESC,
                           STP.PRD_CHRG,
                           (SELECT VL.REF_CD
                              FROM MW_REF_CD_VAL VL
                             WHERE VL.REF_CD_SEQ = STP.PRD_CHRG
                               AND VL.CRNT_REC_FLG = 1) PRD_CHRG_CD,
                           (SELECT VL.REF_CD_DSCR
                              FROM MW_REF_CD_VAL VL
                             WHERE VL.REF_CD_SEQ = STP.PRD_CHRG
                               AND VL.CRNT_REC_FLG = 1) PRD_CHRG_DESC,
                           STP.FXD_PRMUM,
                           (SELECT VL.REF_CD_DSCR
                              FROM MW_REF_CD_VAL VL
                             WHERE VL.REF_CD_SEQ = STP.FXD_PRMUM
                               AND VL.CRNT_REC_FLG = 1) FXD_PRMUM_DESC,
                           STP.RVRSE_ALL_ADV,
                           STP.RVRSE_ALL_EXPT_SM_MNTH,
                           STP.DED_SM_MNTH,
                           STP.DED_BASE,
                           (SELECT CASE
                                     WHEN VL.REF_CD_DSCR = 'Based on current 12 installments bucket' THEN
                                      1
                                     WHEN VL.REF_CD_DSCR = 'Based on current 6 installments bucket' THEN
                                      2
                                     WHEN VL.REF_CD_DSCR = 'Based on current 18 installments bucket' THEN
                                      3
                                     WHEN VL.REF_CD_DSCR = 'Based on current 24 installments bucket' THEN
                                      4
                                     WHEN VL.REF_CD_DSCR = 'Deduct all installment' THEN
                                      5
                                   END
                              FROM MW_REF_CD_VAL VL
                             WHERE VL.REF_CD_SEQ = STP.DED_BASE
                               AND VL.CRNT_REC_FLG = 1) DED_BASE_DESC,
                           STP.DED_APLD_ON,
                           (SELECT CASE
                                     WHEN VL.REF_CD_DSCR =
                                          'First disbursed product along with associate product' THEN
                                      1
                                     ELSE
                                      0
                                   END
                              FROM MW_REF_CD_VAL VL
                             WHERE VL.REF_CD_SEQ = STP.DED_APLD_ON
                               AND VL.CRNT_REC_FLG = 1) DED_APLD_ON_DESC
                      FROM MW_STP_INCDNT STP
                     WHERE STP.INCDNT_TYP = CHRGS.INCDNT_TYP
                       AND STP.INCDNT_CTGRY = CHRGS.INCDNT_CTGRY
                       AND STP.INCDNT_EFFECTEE = CHRGS.INCDNT_EFFECTEE
                       AND (SELECT VL.REF_CD_DSCR
                              FROM MW_REF_CD_VAL VL
                             WHERE VL.REF_CD_SEQ = STP.PRD_CHRG
                               AND VL.CRNT_REC_FLG = 1) = CHRGS.INCDNT_CHRG
                       AND STP.CRNT_REC_FLG = 1) LOOP
          IF CHRGS.INCDNT_CHRG != 'NO CHARGE' --------  IF CLIENT WITH NO ANY CHARGES
           THEN
              -----------  CALL FUNERAL CHARGES CALCULATION procedure ----------------
              --         V_UNIQUE_NUMBER PSC_DEF_UNIQUE_NUM_SEQ.NEXTVAL;
              --
              PRC_CALC_FNRL_CHRGS(P_CLNT_SEQ,
                                  V_INCDNT_DT,
                                  P_INCDNT_USER,
                                  CHRGS.INCDNT_CHRG,
                                  STP.PRD_CHRG_CD,
                                  STP.DED_SM_MNTH,
                                  STP.DED_BASE_DESC,
                                  STP.DED_APLD_ON_DESC,
                                  TO_NUMBER(STP.FXD_PRMUM_DESC),
                                  P_INCDNT_RTN_MSGCALC,
                                  V_DED_AMT,
                                  V_UNIQUE_NUMBER);
              /*PRC_CALC_FNRL_CHRGS(P_CLNT_SEQ,
                                  V_INCDNT_DT,
                                  P_INCDNT_USER,
                                  CHRGS.INCDNT_CHRG,
                                  STP.PRD_CHRG_CD,
                                  STP.DED_SM_MNTH,
                                  STP.DED_BASE_DESC,
                                  STP.DED_APLD_ON_DESC,
                                  TO_NUMBER(STP.FXD_PRMUM_DESC),
                                  P_INCDNT_RTN_MSGCALC,
                                  V_DED_AMT,
                                  V_UNIQUE_NUMBER);*/
              V_DED_AMT_TOT := NVL(V_DED_AMT_TOT, 0) + NVL(V_DED_AMT, 0); --------  SUM ALL THE CHARGES TO BE DEDUCT
          ELSE
            V_DED_AMT_TOT := 0;
          END IF;
          V_INC_PRIMUM_AMT := NVL(TO_NUMBER(STP.FXD_PRMUM_DESC), 0); -----  SET FUNERAL PERMIUM AMOUT FROM SETUP
        END LOOP; ----------  STP LOOP
      END IF;
    END LOOP; ---------  CLNTS CHARGES LOOP
    ------  UPDATE DEDUCTION AMOUT AND INCIDENT STATUS -----------
    UPDATE MW_INCDNT_RPT INC
       SET INC.AMT        =
           (NVL(V_INC_PRIMUM_AMT, 0) - NVL(V_DED_AMT_TOT, 0)),
           INC.INCDNT_STS =
           (SELECT VL.REF_CD_SEQ
              FROM MW_REF_CD_VAL VL
              JOIN MW_REF_CD_GRP GRP
                ON GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
               AND GRP.CRNT_REC_FLG = 1
             WHERE GRP.REF_CD_GRP = '0425'
               AND VL.REF_CD = '0001'),
           INC.LAST_UPD_DT = SYSDATE,
           INC.LAST_UPD_BY = P_INCDNT_USER
     WHERE INC.CLNT_SEQ = P_CLNT_SEQ
       AND INC.DT_OF_INCDNT = V_INCDNT_DT
       AND INC.CRNT_REC_FLG = 1;
    IF V_INCDNT_REF <> 0 THEN
      UPDATE MW_ANML_RGSTR RG
         SET RG.ANML_STS   =
             (SELECT TO_NUMBER(VL.REF_CD)
                FROM MW_REF_CD_VAL VL
                JOIN MW_REF_CD_GRP GRP
                  ON GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                 AND GRP.CRNT_REC_FLG = 1
               WHERE GRP.REF_CD_GRP = '0415'
                 AND VL.REF_CD_SEQ = P_INCDNT_CTGRY),
             RG.LAST_UPD_BY = P_INCDNT_USER,
             RG.LAST_UPD_DT = SYSDATE
       WHERE RG.ANML_RGSTR_SEQ = V_INCDNT_REF;
    END IF;
  ELSE
    -----------  FOR INCIDENT REVERSAL ----------
    BEGIN
      SELECT VL.REF_CD_DSCR
        INTO V_INCIDENT_STS
        FROM MW_INCDNT_RPT INC
        JOIN MW_REF_CD_VAL VL
          ON VL.REF_CD_SEQ = INC.INCDNT_STS
         AND VL.CRNT_REC_FLG = 1
        JOIN MW_REF_CD_GRP GRP
          ON GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
         AND GRP.CRNT_REC_FLG = 1
         AND GRP.REF_CD_GRP = '0425'
       WHERE INC.CLNT_SEQ = P_CLNT_SEQ
         AND INC.DT_OF_INCDNT =
             (SELECT INC1.DT_OF_INCDNT
                FROM MW_INCDNT_RPT INC1
               WHERE INC1.CLNT_SEQ = P_CLNT_SEQ
                 AND INC1.CRNT_REC_FLG = 1
                 AND (INC1.INCDNT_STS =
                     (SELECT VL.REF_CD_SEQ
                         FROM MW_REF_CD_VAL VL
                         JOIN MW_REF_CD_GRP GRP
                           ON GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                          AND GRP.CRNT_REC_FLG = 1
                        WHERE GRP.REF_CD_GRP = '0425'
                          AND VL.REF_CD = '0001') OR
                     INC1.INCDNT_STS =
                     (SELECT VL.REF_CD_SEQ
                         FROM MW_REF_CD_VAL VL
                         JOIN MW_REF_CD_GRP GRP
                           ON GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                          AND GRP.CRNT_REC_FLG = 1
                        WHERE GRP.REF_CD_GRP = '0425'
                          AND VL.REF_CD = '0004') OR
                     INC1.INCDNT_STS =
                     (SELECT VL.REF_CD_SEQ
                         FROM MW_REF_CD_VAL VL
                         JOIN MW_REF_CD_GRP GRP
                           ON GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                          AND GRP.CRNT_REC_FLG = 1
                        WHERE GRP.REF_CD_GRP = '0425'
                          AND VL.REF_CD = '0002') OR
                     INC1.INCDNT_STS =
                     (SELECT VL.REF_CD_SEQ
                         FROM MW_REF_CD_VAL VL
                         JOIN MW_REF_CD_GRP GRP
                           ON GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                          AND GRP.CRNT_REC_FLG = 1
                        WHERE GRP.REF_CD_GRP = '0425'
                          AND VL.REF_CD = '0003')))
         AND INC.CRNT_REC_FLG = 1;
    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        P_INCDNT_RTN_MSG := 'PRC_INCDNT_PROCESS ==> ISSUE IN GETTING INCIDENT STATUSES FOR REVERSAL.. => LINE NO: ' ||
                            $$PLSQL_LINE || CHR(10) || 'CLNT_SEQ:' ||
                            P_CLNT_SEQ || ' ERROR CODE: ' || SQLCODE ||
                            ' ERROR MESSAGE: ' || SQLERRM || 'TRACE: ' ||
                            SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        KASHF_REPORTING.PRO_LOG_MSG('PRC_INCDNT_PROCESS', P_INCDNT_RTN_MSG);
        P_INCDNT_RTN_MSG := 'Issue in getting Incident Statuses - 0002';
        RETURN;
    END;
    IF V_INCIDENT_STS = 'INCIDENT REPORTED' THEN
      ----------REVERSE EXCESS IF ANY ------------
      FOR RVSL_EX IN (SELECT RCH.RCVRY_TRX_SEQ
                        FROM MW_RCVRY_TRX RCH
                        JOIN MW_RCVRY_DTL RCD
                          ON RCD.RCVRY_TRX_SEQ = RCH.RCVRY_TRX_SEQ
                         AND RCD.CRNT_REC_FLG = 1
                       WHERE RCH.PYMT_REF = P_CLNT_SEQ
                         AND RCH.CHNG_RSN_CMNT LIKE
                             ('%EXCESS CREATED DUE TO INCIDENT PROCESS DATED:%')
                         AND RCH.CRNT_REC_FLG = 1
                       GROUP BY RCH.RCVRY_TRX_SEQ
                       ORDER BY 1 DESC) LOOP
        UPDATE MW_RCVRY_TRX RCH
           SET RCH.CRNT_REC_FLG = 0,
               RCH.DEL_FLG      = 1,
               RCH.LAST_UPD_BY  = P_INCDNT_USER,
               RCH.LAST_UPD_DT  = SYSDATE
         WHERE RCH.RCVRY_TRX_SEQ = RVSL_EX.RCVRY_TRX_SEQ
           AND RCH.PYMT_REF = P_CLNT_SEQ
           AND RCH.CRNT_REC_FLG = 1;
        UPDATE MW_RCVRY_DTL RCD
           SET RCD.CRNT_REC_FLG = 0,
               RCD.DEL_FLG      = 1,
               RCD.LAST_UPD_BY  = P_INCDNT_USER,
               RCD.LAST_UPD_DT  = SYSDATE
         WHERE RCD.RCVRY_TRX_SEQ = RVSL_EX.RCVRY_TRX_SEQ
           AND RCD.CRNT_REC_FLG = 1;
        SELECT JV_HDR_SEQ.NEXTVAL INTO V_JV_HDR_SEQ_REV FROM DUAL;
        INSERT INTO MW_JV_HDR
          (JV_HDR_SEQ,
           PRNT_VCHR_REF,
           JV_ID,
           JV_DT,
           JV_DSCR,
           JV_TYP_KEY,
           ENTY_SEQ,
           ENTY_TYP,
           CRTD_BY,
           POST_FLG,
           RCVRY_TRX_SEQ,
           BRNCH_SEQ,
           CLNT_SEQ,
           INSTR_NUM,
           TRNS_DT,
           PYMT_MODE,
           TOT_DBT,
           TOT_CRDT,
           ERP_INTEGRATION_FLG,
           ERP_INTEGRATION_DT)
          SELECT V_JV_HDR_SEQ_REV,
                 JV_HDR_SEQ,
                 V_JV_HDR_SEQ_REV,
                 TO_DATE(SYSDATE),
                 'REVERSAL OF ' || JV_DSCR,
                 JV_TYP_KEY,
                 ENTY_SEQ,
                 ENTY_TYP,
                 P_INCDNT_USER,
                 POST_FLG,
                 RCVRY_TRX_SEQ,
                 BRNCH_SEQ,
                 CLNT_SEQ,
                 INSTR_NUM,
                 SYSDATE,
                 PYMT_MODE,
                 TOT_DBT,
                 TOT_CRDT,
                 0,
                 NULL
            FROM MW_JV_HDR JVH
           WHERE JVH.ENTY_SEQ = RVSL_EX.RCVRY_TRX_SEQ;
        INSERT INTO MW_JV_DTL
          (JV_DTL_SEQ,
           JV_HDR_SEQ,
           CRDT_DBT_FLG,
           AMT,
           GL_ACCT_NUM,
           DSCR,
           LN_ITM_NUM)
          SELECT JV_DTL_SEQ.NEXTVAL,
                 V_JV_HDR_SEQ_REV,
                 CASE
                   WHEN CRDT_DBT_FLG = 0 THEN
                    1
                   ELSE
                    0
                 END,
                 AMT,
                 GL_ACCT_NUM,
                 CASE
                   WHEN DSCR = 'Credit' THEN
                    'Debit'
                   ELSE
                    'Credit'
                 END,
                 LN_ITM_NUM
            FROM MW_JV_DTL JVD
           WHERE JVD.JV_HDR_SEQ IN
                 (SELECT MAX(JV_HDR_SEQ)
                    FROM MW_JV_HDR JVH
                   WHERE JVH.ENTY_SEQ = RVSL_EX.RCVRY_TRX_SEQ
                     AND JVH.PRNT_VCHR_REF IS NULL);
      END LOOP; ---------- END LOOP REVERSE EXCESS RECOVERY ----------
      ---------- ENTER RECOVERY AGAIN IF ANY ------------
      FOR RVSL_REC IN (SELECT RCH.RCVRY_TRX_SEQ
                         FROM MW_RCVRY_TRX RCH
                         JOIN MW_RCVRY_DTL RCD
                           ON RCD.RCVRY_TRX_SEQ = RCH.RCVRY_TRX_SEQ
                          AND RCD.CRNT_REC_FLG = 0
                        WHERE RCH.PYMT_REF = P_CLNT_SEQ
                          AND RCH.CHNG_RSN_CMNT =
                              (SELECT MAX(RCH1.CHNG_RSN_CMNT)
                                 FROM MW_RCVRY_TRX RCH1
                                WHERE RCH1.PYMT_REF = P_CLNT_SEQ
                                  AND RCH1.CHNG_RSN_CMNT LIKE
                                      'REVERSE DUE TO INCIDENT PROCESS DATED%'
                                  AND RCH1.CRNT_REC_FLG = 0)
                          AND RCH.CRNT_REC_FLG = 0
                          AND RCH.CHNG_RSN_CMNT LIKE
                              'REVERSE DUE TO INCIDENT PROCESS DATED%'
                        GROUP BY RCH.RCVRY_TRX_SEQ
                        ORDER BY 1) LOOP
        SELECT RCVRY_TRX_SEQ.NEXTVAL INTO V_RCVRY_TRX_SEQ_RVSL FROM DUAL;
        INSERT INTO MW_RCVRY_TRX
          (RCVRY_TRX_SEQ,
           EFF_START_DT,
           INSTR_NUM,
           PYMT_DT,
           PYMT_AMT,
           RCVRY_TYP_SEQ,
           PYMT_MOD_KEY,
           PYMT_STS_KEY,
           CRTD_BY,
           CRTD_DT,
           LAST_UPD_BY,
           LAST_UPD_DT,
           DEL_FLG,
           EFF_END_DT,
           CRNT_REC_FLG,
           PYMT_REF,
           POST_FLG,
           CHNG_RSN_KEY,
           CHNG_RSN_CMNT,
           PRNT_RCVRY_REF,
           DPST_SLP_DT,
           PRNT_LOAN_APP_SEQ)
          SELECT V_RCVRY_TRX_SEQ_RVSL,
                 SYSDATE,
                 INSTR_NUM,
                 PYMT_DT,
                 PYMT_AMT,
                 RCVRY_TYP_SEQ,
                 PYMT_MOD_KEY,
                 PYMT_STS_KEY,
                 P_INCDNT_USER,
                 SYSDATE,
                 P_INCDNT_USER,
                 SYSDATE,
                 0,
                 NULL,
                 1,
                 PYMT_REF,
                 POST_FLG,
                 CHNG_RSN_KEY,
                 NULL,
                 PRNT_RCVRY_REF,
                 DPST_SLP_DT,
                 PRNT_LOAN_APP_SEQ
            FROM MW_RCVRY_TRX RCH
           WHERE RCH.RCVRY_TRX_SEQ = RVSL_REC.RCVRY_TRX_SEQ
             AND RCH.CRNT_REC_FLG = 0;
        INSERT INTO MW_RCVRY_DTL
          (RCVRY_CHRG_SEQ,
           EFF_START_DT,
           RCVRY_TRX_SEQ,
           CHRG_TYP_KEY,
           PYMT_AMT,
           CRTD_BY,
           CRTD_DT,
           LAST_UPD_BY,
           LAST_UPD_DT,
           DEL_FLG,
           EFF_END_DT,
           CRNT_REC_FLG,
           PYMT_SCHED_DTL_SEQ,
           ETL_FLAG)
          SELECT RCVRY_CHRG_SEQ.NEXTVAL,
                 SYSDATE,
                 V_RCVRY_TRX_SEQ_RVSL,
                 CHRG_TYP_KEY,
                 PYMT_AMT,
                 P_INCDNT_USER,
                 SYSDATE,
                 P_INCDNT_USER,
                 SYSDATE,
                 0,
                 NULL,
                 1,
                 PYMT_SCHED_DTL_SEQ,
                 NULL
            FROM MW_RCVRY_DTL RCD
           WHERE RCD.RCVRY_TRX_SEQ = RVSL_REC.RCVRY_TRX_SEQ
             AND RCD.CRNT_REC_FLG = 0;
        SELECT JV_HDR_SEQ.NEXTVAL INTO V_JV_HDR_SEQ_RESL FROM DUAL;
        INSERT INTO MW_JV_HDR
          (JV_HDR_SEQ,
           PRNT_VCHR_REF,
           JV_ID,
           JV_DT,
           JV_DSCR,
           JV_TYP_KEY,
           ENTY_SEQ,
           ENTY_TYP,
           CRTD_BY,
           POST_FLG,
           RCVRY_TRX_SEQ,
           BRNCH_SEQ,
           CLNT_SEQ,
           INSTR_NUM,
           TRNS_DT,
           PYMT_MODE,
           TOT_DBT,
           TOT_CRDT,
           ERP_INTEGRATION_FLG,
           ERP_INTEGRATION_DT)
          SELECT V_JV_HDR_SEQ_RESL,
                 NULL,
                 V_JV_HDR_SEQ_RESL,
                 JV_DT,
                 JV_DSCR,
                 JV_TYP_KEY,
                 V_RCVRY_TRX_SEQ_RVSL,
                 ENTY_TYP,
                 P_INCDNT_USER,
                 POST_FLG,
                 RCVRY_TRX_SEQ,
                 BRNCH_SEQ,
                 CLNT_SEQ,
                 INSTR_NUM,
                 SYSDATE,
                 PYMT_MODE,
                 TOT_DBT,
                 TOT_CRDT,
                 0,
                 NULL
            FROM MW_JV_HDR JVH
           WHERE JVH.ENTY_SEQ = RVSL_REC.RCVRY_TRX_SEQ
             AND JVH.PRNT_VCHR_REF IS NULL;
        INSERT INTO MW_JV_DTL
          (JV_DTL_SEQ,
           JV_HDR_SEQ,
           CRDT_DBT_FLG,
           AMT,
           GL_ACCT_NUM,
           DSCR,
           LN_ITM_NUM)
          SELECT JV_DTL_SEQ.NEXTVAL,
                 V_JV_HDR_SEQ_RESL,
                 CRDT_DBT_FLG,
                 AMT,
                 GL_ACCT_NUM,
                 DSCR,
                 LN_ITM_NUM
            FROM MW_JV_DTL JVD
           WHERE JVD.JV_HDR_SEQ IN
                 (SELECT MAX(JV_HDR_SEQ)
                    FROM MW_JV_HDR JVH
                   WHERE JVH.ENTY_SEQ = RVSL_REC.RCVRY_TRX_SEQ
                     AND JVH.PRNT_VCHR_REF IS NULL);
        UPDATE MW_PYMT_SCHED_DTL PSD
           SET PSD.PYMT_STS_KEY = 947,
               PSD.LAST_UPD_BY  = P_INCDNT_USER,
               PSD.LAST_UPD_DT  = SYSDATE
         WHERE PSD.PYMT_SCHED_DTL_SEQ IN
               (SELECT RCD.PYMT_SCHED_DTL_SEQ
                  FROM MW_RCVRY_DTL RCD
                 WHERE RCD.RCVRY_TRX_SEQ = RVSL_REC.RCVRY_TRX_SEQ
                   AND RCD.CRNT_REC_FLG = 0
                 GROUP BY RCD.PYMT_SCHED_DTL_SEQ);
      END LOOP;
      BEGIN
        PRC_DEF_REVERSAL_CHRGES(P_CLNT_SEQ,
                                P_INCDNT_USER,
                                P_INCDNT_RTN_MSG_DEF);
        IF P_INCDNT_RTN_MSG_DEF != 'SUCCESS' THEN
          ROLLBACK;
          P_INCDNT_RTN_MSG := 'PRC_INCDNT_PROCESS ==> DEFFERED NOT GENERATED SUCCESSFULLY => LINE NO: ' ||
                              $$PLSQL_LINE || CHR(10) || 'CLNT_SEQ:' ||
                              P_CLNT_SEQ || ' ERROR CODE: ' || SQLCODE ||
                              ' ERROR MESSAGE: ' || SQLERRM || 'TRACE: ' ||
                              SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
          KASHF_REPORTING.PRO_LOG_MSG('PRC_INCDNT_PROCESS',
                                      P_INCDNT_RTN_MSG);
          P_INCDNT_RTN_MSG := 'Issue in generation of Deffered Reversal-0001';
          RETURN;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          P_INCDNT_RTN_MSG := 'PRC_INCDNT_PROCESS ==> DEFFERED NOT GENERATED SUCCESSFULLY => LINE NO: ' ||
                              $$PLSQL_LINE || CHR(10) || 'CLNT_SEQ:' ||
                              P_CLNT_SEQ || ' ERROR CODE: ' || SQLCODE ||
                              ' ERROR MESSAGE: ' || SQLERRM || 'TRACE: ' ||
                              SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
          KASHF_REPORTING.PRO_LOG_MSG('PRC_INCDNT_PROCESS',
                                      P_INCDNT_RTN_MSG);
          P_INCDNT_RTN_MSG := 'Issue in generation of Deffered Reversal-0002';
          RETURN;
      END;
      -------------  REVERSE TAG LIST AND DEATH -----------------------
      UPDATE MW_CLNT_TAG_LIST TG
         SET TG.CRNT_REC_FLG = 0,
             TG.DEL_FLG      = 0,
             TG.LAST_UPD_BY  = P_INCDNT_USER,
             TG.LAST_UPD_DT  = SYSDATE
       WHERE TG.CNIC_NUM = V_CNIC_NUM
         AND TG.TAGS_SEQ = 5;
      UPDATE MW_INCDNT_RPT RPT
         SET RPT.CRNT_REC_FLG = 0,
             RPT.DEL_FLG      = 1,
             RPT.LAST_UPD_BY  = P_INCDNT_USER,
             RPT.LAST_UPD_DT  = SYSDATE
       WHERE RPT.CLNT_SEQ = P_CLNT_SEQ
         AND RPT.INCDNT_STS = (SELECT VL.REF_CD_SEQ
                                 FROM MW_REF_CD_VAL VL
                                 JOIN MW_REF_CD_GRP GRP
                                   ON GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                                  AND GRP.CRNT_REC_FLG = 1
                                WHERE GRP.REF_CD_GRP = '0425'
                                  AND VL.REF_CD = '0001')
         AND RPT.CRNT_REC_FLG = 1;
      IF V_INCDNT_REF <> 0 THEN
        UPDATE MW_ANML_RGSTR RG
           SET RG.ANML_STS    = -1,
               RG.LAST_UPD_BY = P_INCDNT_USER,
               RG.LAST_UPD_DT = SYSDATE
         WHERE RG.ANML_RGSTR_SEQ = V_INCDNT_REF;
      END IF;
    ELSIF V_INCIDENT_STS = 'FUNERAL SAVED' THEN
      UPDATE MW_EXP EX
         SET EX.DEL_FLG      = 1,
             EX.CRNT_REC_FLG = 0,
             EX.LAST_UPD_BY  = P_INCDNT_USER,
             EX.LAST_UPD_DT  = SYSDATE
       WHERE EX.EXP_REF = P_CLNT_SEQ
         AND EX.EXPNS_TYP_SEQ IN (424, 423)
         AND EX.POST_FLG = 0
         AND EX.DEL_FLG = 0;
      UPDATE MW_PYMT_SCHED_DTL PSD
         SET PSD.PYMT_STS_KEY = 945
       WHERE PSD.CRNT_REC_FLG = 1
         AND PSD.PYMT_SCHED_DTL_SEQ IN
             (SELECT RCD.PYMT_SCHED_DTL_SEQ
                FROM MW_RCVRY_DTL RCD
               WHERE RCD.RCVRY_TRX_SEQ =
                     (SELECT MAX(RCH.RCVRY_TRX_SEQ)
                        FROM MW_RCVRY_TRX RCH
                       WHERE RCH.PYMT_REF = P_CLNT_SEQ
                         AND RCH.POST_FLG = 0
                         AND RCH.PYMT_STS_KEY = 1001
                         AND RCH.CRNT_REC_FLG = 1));
      UPDATE MW_RCVRY_DTL RCD
         SET RCD.CRNT_REC_FLG = 0,
             RCD.DEL_FLG      = 1,
             RCD.LAST_UPD_BY  = P_INCDNT_USER,
             RCD.LAST_UPD_DT  = SYSDATE
       WHERE RCD.RCVRY_TRX_SEQ =
             (SELECT MAX(RCH.RCVRY_TRX_SEQ)
                FROM MW_RCVRY_TRX RCH
               WHERE RCH.PYMT_REF = P_CLNT_SEQ
                 AND RCH.POST_FLG = 0
                 AND RCH.PYMT_STS_KEY = 1001
                 AND RCH.CRNT_REC_FLG = 1);
      UPDATE MW_RCVRY_TRX RC
         SET RC.CRNT_REC_FLG = 0,
             RC.DEL_FLG      = 1,
             RC.LAST_UPD_BY  = P_INCDNT_USER,
             RC.LAST_UPD_DT  = SYSDATE
       WHERE RC.RCVRY_TRX_SEQ =
             (SELECT MAX(RCH.RCVRY_TRX_SEQ)
                FROM MW_RCVRY_TRX RCH
               WHERE RCH.PYMT_REF = P_CLNT_SEQ
                 AND RCH.POST_FLG = 0
                 AND RCH.PYMT_STS_KEY = 1001
                 AND RCH.CRNT_REC_FLG = 1);
      UPDATE MW_INCDNT_RPT INC
         SET INC.INCDNT_STS =
             (SELECT VL.REF_CD_SEQ
                FROM MW_REF_CD_VAL VL
                JOIN MW_REF_CD_GRP GRP
                  ON GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                 AND GRP.CRNT_REC_FLG = 1
               WHERE GRP.REF_CD_GRP = '0425'
                 AND VL.REF_CD = '0001'),
             INC.LAST_UPD_DT = SYSDATE,
             INC.LAST_UPD_BY = P_INCDNT_USER
       WHERE INC.CLNT_SEQ = P_CLNT_SEQ
         AND INC.CRNT_REC_FLG = 1
         AND INC.INCDNT_STS = (SELECT VL.REF_CD_SEQ
                                 FROM MW_REF_CD_VAL VL
                                 JOIN MW_REF_CD_GRP GRP
                                   ON GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                                  AND GRP.CRNT_REC_FLG = 1
                                WHERE GRP.REF_CD_GRP = '0425'
                                  AND VL.REF_CD = '0004');
    ELSIF V_INCIDENT_STS IN ('FUNERAL PAID') THEN
      SELECT JV_HDR_SEQ.NEXTVAL INTO V_JV_HDR_SEQ_FUN FROM DUAL;
      -- INSERTION: JV HEADER
      INSERT INTO MW_JV_HDR
        (JV_HDR_SEQ,
         PRNT_VCHR_REF,
         JV_ID,
         JV_DT,
         JV_DSCR,
         ENTY_SEQ,
         ENTY_TYP,
         CRTD_BY,
         POST_FLG,
         RCVRY_TRX_SEQ,
         BRNCH_SEQ,
         CLNT_SEQ)
        SELECT V_JV_HDR_SEQ_FUN,
               JV_HDR_SEQ,
               V_JV_HDR_SEQ_FUN,
               SYSDATE,
               'REVERSAL ' || JV_DSCR,
               ENTY_SEQ,
               ENTY_TYP,
               P_INCDNT_USER,
               POST_FLG,
               RCVRY_TRX_SEQ,
               BRNCH_SEQ,
               P_CLNT_SEQ
          FROM MW_JV_HDR MJH
         WHERE UPPER(MJH.ENTY_TYP) = UPPER('EXPENSE')
           AND MJH.BRNCH_SEQ = V_BRNCH_SEQ
           AND MJH.PRNT_VCHR_REF IS NULL
           AND MJH.ENTY_SEQ =
               (SELECT MAX(EX.EXP_SEQ)
                  FROM MW_EXP EX
                 WHERE (EX.EXP_REF = P_CLNT_SEQ OR EX.EXP_REF = V_INCDNT_REF)
                   AND EX.EXPNS_TYP_SEQ IN (424, 423)
                   AND EX.POST_FLG = 1
                   AND EX.DEL_FLG = 0);
      INSERT INTO MW_JV_DTL
        (JV_DTL_SEQ,
         JV_HDR_SEQ,
         CRDT_DBT_FLG,
         AMT,
         GL_ACCT_NUM,
         DSCR,
         LN_ITM_NUM)
        SELECT JV_DTL_SEQ.NEXTVAL,
               V_JV_HDR_SEQ_FUN,
               CASE
                 WHEN DTL.CRDT_DBT_FLG = 1 THEN
                  0
                 ELSE
                  1
               END,
               AMT,
               GL_ACCT_NUM,
               CASE
                 WHEN DSCR = 'CREDIT' THEN
                  'DEBIT'
                 ELSE
                  'CREDIT'
               END,
               LN_ITM_NUM
          FROM MW_JV_DTL DTL
         WHERE JV_HDR_SEQ IN
               (SELECT JV_HDR_SEQ
                  FROM MW_JV_HDR MJH
                 WHERE UPPER(MJH.ENTY_TYP) = UPPER('EXPENSE')
                   AND MJH.BRNCH_SEQ = V_BRNCH_SEQ
                   AND MJH.PRNT_VCHR_REF IS NULL
                   AND MJH.ENTY_SEQ = (SELECT MAX(EX.EXP_SEQ)
                                         FROM MW_EXP EX
                                        WHERE (EX.EXP_REF = P_CLNT_SEQ OR
                                              EX.EXP_REF = V_INCDNT_REF)
                                          AND EX.EXPNS_TYP_SEQ IN (424, 423)
                                          AND EX.POST_FLG = 1
                                          AND EX.DEL_FLG = 0));
      UPDATE MW_EXP EX
         SET EX.DEL_FLG     = 1,
             EX.LAST_UPD_BY = P_INCDNT_USER,
             EX.LAST_UPD_DT = SYSDATE
       WHERE (EX.EXP_REF = P_CLNT_SEQ OR EX.EXP_REF = V_INCDNT_REF)
         AND EX.EXPNS_TYP_SEQ IN (424, 423)
         AND EX.DEL_FLG = 0;
      SELECT JV_HDR_SEQ.NEXTVAL INTO V_JV_HDR_SEQ_REC FROM DUAL;
      -- INSERTION: JV HEADER
      INSERT INTO MW_JV_HDR
        (JV_HDR_SEQ,
         PRNT_VCHR_REF,
         JV_ID,
         JV_DT,
         JV_DSCR,
         ENTY_SEQ,
         ENTY_TYP,
         CRTD_BY,
         POST_FLG,
         RCVRY_TRX_SEQ,
         BRNCH_SEQ,
         CLNT_SEQ)
        SELECT V_JV_HDR_SEQ_REC,
               JV_HDR_SEQ,
               V_JV_HDR_SEQ_REC,
               SYSDATE,
               'REVERSAL ' || JV_DSCR,
               ENTY_SEQ,
               ENTY_TYP,
               P_INCDNT_USER,
               POST_FLG,
               RCVRY_TRX_SEQ,
               BRNCH_SEQ,
               P_CLNT_SEQ
          FROM MW_JV_HDR MJH
         WHERE UPPER(MJH.ENTY_TYP) = UPPER('RECOVERY')
           AND MJH.BRNCH_SEQ = V_BRNCH_SEQ
           AND MJH.PRNT_VCHR_REF IS NULL
           AND MJH.ENTY_SEQ IN
               (SELECT MAX(RCH.RCVRY_TRX_SEQ)
                  FROM MW_RCVRY_TRX RCH
                 WHERE RCH.PYMT_REF = P_CLNT_SEQ
                   AND RCH.POST_FLG = 1
                   AND RCH.PYMT_STS_KEY = 1001
                   AND RCH.CRNT_REC_FLG = 1);
      INSERT INTO MW_JV_DTL
        (JV_DTL_SEQ,
         JV_HDR_SEQ,
         CRDT_DBT_FLG,
         AMT,
         GL_ACCT_NUM,
         DSCR,
         LN_ITM_NUM)
        SELECT JV_DTL_SEQ.NEXTVAL,
               V_JV_HDR_SEQ_REC,
               CASE
                 WHEN DTL.CRDT_DBT_FLG = 1 THEN
                  0
                 ELSE
                  1
               END,
               AMT,
               GL_ACCT_NUM,
               CASE
                 WHEN DSCR = 'CREDIT' THEN
                  'DEBIT'
                 ELSE
                  'CREDIT'
               END,
               LN_ITM_NUM
          FROM MW_JV_DTL DTL
         WHERE JV_HDR_SEQ IN
               (SELECT JV_HDR_SEQ
                  FROM MW_JV_HDR MJH
                 WHERE UPPER(MJH.ENTY_TYP) = UPPER('RECOVERY')
                   AND MJH.BRNCH_SEQ = V_BRNCH_SEQ
                   AND MJH.PRNT_VCHR_REF IS NULL
                   AND MJH.ENTY_SEQ IN
                       (SELECT MAX(RCH.RCVRY_TRX_SEQ)
                          FROM MW_RCVRY_TRX RCH
                         WHERE RCH.PYMT_REF = P_CLNT_SEQ
                           AND RCH.POST_FLG = 1
                           AND RCH.PYMT_STS_KEY = 1001
                           AND RCH.CRNT_REC_FLG = 1));
      UPDATE MW_PYMT_SCHED_DTL PSD
         SET PSD.PYMT_STS_KEY = 945,
             PSD.LAST_UPD_BY  = P_INCDNT_USER,
             PSD.LAST_UPD_DT  = SYSDATE
       WHERE PSD.CRNT_REC_FLG = 1
         AND PSD.PYMT_SCHED_DTL_SEQ IN
             (SELECT RCD.PYMT_SCHED_DTL_SEQ
                FROM MW_RCVRY_DTL RCD
               WHERE RCD.RCVRY_TRX_SEQ =
                     (SELECT MAX(RCH.RCVRY_TRX_SEQ)
                        FROM MW_RCVRY_TRX RCH
                       WHERE RCH.PYMT_REF = P_CLNT_SEQ
                         AND RCH.POST_FLG = 1
                         AND RCH.PYMT_STS_KEY = 1001
                         AND RCH.CRNT_REC_FLG = 1)
               GROUP BY RCD.PYMT_SCHED_DTL_SEQ);
      UPDATE MW_RCVRY_DTL RCD
         SET RCD.CRNT_REC_FLG = 0,
             RCD.DEL_FLG      = 1,
             RCD.LAST_UPD_BY  = P_INCDNT_USER,
             RCD.LAST_UPD_DT  = SYSDATE
       WHERE RCD.RCVRY_TRX_SEQ =
             (SELECT MAX(RCH.RCVRY_TRX_SEQ)
                FROM MW_RCVRY_TRX RCH
               WHERE RCH.PYMT_REF = P_CLNT_SEQ
                 AND RCH.PYMT_STS_KEY = 1001
                 AND RCH.CRNT_REC_FLG = 1);
      UPDATE MW_RCVRY_TRX RC
         SET RC.CRNT_REC_FLG = 0,
             RC.DEL_FLG      = 1,
             RC.LAST_UPD_BY  = P_INCDNT_USER,
             RC.LAST_UPD_DT  = SYSDATE
       WHERE RC.RCVRY_TRX_SEQ =
             (SELECT MAX(RCH.RCVRY_TRX_SEQ)
                FROM MW_RCVRY_TRX RCH
               WHERE RCH.PYMT_REF = P_CLNT_SEQ
                 AND RCH.PYMT_STS_KEY = 1001
                 AND RCH.CRNT_REC_FLG = 1);
      UPDATE MW_INCDNT_RPT INC
         SET INC.INCDNT_STS =
             (SELECT VL.REF_CD_SEQ
                FROM MW_REF_CD_VAL VL
                JOIN MW_REF_CD_GRP GRP
                  ON GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                 AND GRP.CRNT_REC_FLG = 1
               WHERE GRP.REF_CD_GRP = '0425'
                 AND VL.REF_CD = '0001'),
             INC.LAST_UPD_DT = SYSDATE,
             INC.LAST_UPD_BY = P_INCDNT_USER
       WHERE INC.CLNT_SEQ = P_CLNT_SEQ
         AND INC.CRNT_REC_FLG = 1
         AND (INC.INCDNT_STS =
             (SELECT VL.REF_CD_SEQ
                 FROM MW_REF_CD_VAL VL
                 JOIN MW_REF_CD_GRP GRP
                   ON GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                  AND GRP.CRNT_REC_FLG = 1
                WHERE GRP.REF_CD_GRP = '0425'
                  AND VL.REF_CD = '0002') OR
             INC.INCDNT_STS =
             (SELECT VL.REF_CD_SEQ
                 FROM MW_REF_CD_VAL VL
                 JOIN MW_REF_CD_GRP GRP
                   ON GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                  AND GRP.CRNT_REC_FLG = 1
                WHERE GRP.REF_CD_GRP = '0425'
                  AND VL.REF_CD = '0004'
                   OR INC.INCDNT_STS =
                      (SELECT VL.REF_CD_SEQ
                         FROM MW_REF_CD_VAL VL
                         JOIN MW_REF_CD_GRP GRP
                           ON GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                          AND GRP.CRNT_REC_FLG = 1
                        WHERE GRP.REF_CD_GRP = '0425'
                          AND VL.REF_CD = '0003')));
    END IF; ----  V_INCIDENT_STS
  END IF; -------  P_INCDNT_RVRSE
  P_INCDNT_RTN_MSG := 'SUCCESS';
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    P_INCDNT_RTN_MSG := 'PRC_INCDNT_PROCESS ==> GENERIC ERROR => LINE NO: ' ||
                        $$PLSQL_LINE || CHR(10) || ' ERROR CODE: ' ||
                        SQLCODE || ' ERROR MESSAGE: ' || SQLERRM ||
                        'TRACE: ' ||
                        SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
    KASHF_REPORTING.PRO_LOG_MSG('PRC_INCDNT_PROCESS', P_INCDNT_RTN_MSG);
    P_INCDNT_RTN_MSG := 'Generic Error in PRC_INCDNT_PROCESS Proc..' ||
                        P_INCDNT_RTN_MSG;
    RETURN;
END;
/
