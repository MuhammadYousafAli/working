/* Formatted on 20/01/2023 12:53:27 pm (QP5 v5.326) */
CREATE OR REPLACE PROCEDURE PRC_INCDNT_PROCESS1 (
    P_INCDNT_DT              VARCHAR2,
    P_CLNT_SEQ               NUMBER,
    P_INCDNT_TYP             NUMBER,  --302296, 302176 -- 302178 302185 302190
    P_INCDNT_CTGRY           NUMBER,                         -- 302301, 302180
    P_INCDNT_EFFECTEE        NUMBER,                         -- 302311, 302190
    P_INCDNT_CAUSE           VARCHAR2,
    P_INCDNT_CMNTS           VARCHAR2,
    P_INCDNT_REF             NUMBER,
    P_INCDNT_REF_RMRKS       VARCHAR2,
    P_INCDNT_USER            VARCHAR2,
    P_INCDNT_RVRSE           NUMBER DEFAULT 0,
    P_INCDNT_RTN_MSG     OUT VARCHAR2)
AS
    V_INCDNT_DT                DATE;
    V_BRNCH_SEQ                MW_BRNCH.BRNCH_SEQ%TYPE;
    V_PRNT_LOAN_APP_SEQ        MW_LOAN_APP.PRNT_LOAN_APP_SEQ%TYPE;
    V_CNIC_NUM                 MW_CLNT.CNIC_NUM%TYPE;
    P_INCDNT_RTN_RCV_MSG       VARCHAR2 (500);
    P_INCDNT_RTN_MSGCALC       VARCHAR2 (500);
    V_RVRSE_ALL_ADV            NUMBER := 0;
    V_RVRSE_ALL_EXPT_SM_MNTH   NUMBER := 0;
    V_DED_AMT                  NUMBER := 0;
    V_DED_AMT_TOT              NUMBER := 0;
    V_INC_PRIMUM_AMT           NUMBER := 0;
    
    ---------------  FOR REVERSAL ------------------
    V_JV_HDR_SEQ_REV           NUMBER;

    -----------------  CURSOR TO GET INCDNT SETUP INFORMATION -----------------
    CURSOR CR_STP_INCDNT (P_INCDNT_TYP        NUMBER,
                          P_INCDNT_CTGRY      NUMBER,
                          P_INCDNT_EFFECTEE   NUMBER,
                          P_INCDNT_CHRG       VARCHAR2)
    IS
        SELECT STP.INCDNT_STP_SEQ,
               STP.INCDNT_TYP,
               (SELECT VL.REF_CD_DSCR
                  FROM MW_REF_CD_VAL VL
                 WHERE VL.REF_CD_SEQ = STP.INCDNT_TYP AND VL.CRNT_REC_FLG = 1)
                   INCDNT_TYPE_DESC,
               STP.INCDNT_CTGRY,
               (SELECT VL.REF_CD_DSCR
                  FROM MW_REF_CD_VAL VL
                 WHERE     VL.REF_CD_SEQ = STP.INCDNT_CTGRY
                       AND VL.CRNT_REC_FLG = 1)
                   INCDNT_CTGRY_DESC,
               STP.INCDNT_EFFECTEE,
               (SELECT VL.REF_CD_DSCR
                  FROM MW_REF_CD_VAL VL
                 WHERE     VL.REF_CD_SEQ = STP.INCDNT_EFFECTEE
                       AND VL.CRNT_REC_FLG = 1)
                   INCDNT_EFFECTEE_DESC,
               STP.PRD_CHRG,
               (SELECT VL.REF_CD
                  FROM MW_REF_CD_VAL VL
                 WHERE VL.REF_CD_SEQ = STP.PRD_CHRG AND VL.CRNT_REC_FLG = 1)
                   PRD_CHRG_CD,
               (SELECT VL.REF_CD_DSCR
                  FROM MW_REF_CD_VAL VL
                 WHERE VL.REF_CD_SEQ = STP.PRD_CHRG AND VL.CRNT_REC_FLG = 1)
                   PRD_CHRG_DESC,
               STP.FXD_PRMUM,
               (SELECT VL.REF_CD_DSCR
                  FROM MW_REF_CD_VAL VL
                 WHERE VL.REF_CD_SEQ = STP.FXD_PRMUM AND VL.CRNT_REC_FLG = 1)
                   FXD_PRMUM_DESC,
               STP.RVRSE_ALL_ADV,
               STP.RVRSE_ALL_EXPT_SM_MNTH,
               STP.DED_SM_MNTH,
               STP.DED_BASE,
               (SELECT CASE
                           WHEN VL.REF_CD_DSCR =
                                'Based on current 12 installments bucket'
                           THEN
                               1
                           WHEN VL.REF_CD_DSCR =
                                'Based on current 6 installments bucket'
                           THEN
                               2
                           WHEN VL.REF_CD_DSCR =
                                'Based on current 18 installments bucket'
                           THEN
                               3
                           WHEN VL.REF_CD_DSCR =
                                'Based on current 24 installments bucket'
                           THEN
                               4
                           WHEN VL.REF_CD_DSCR = 'Deduct all installment'
                           THEN
                               5
                       END
                  FROM MW_REF_CD_VAL VL
                 WHERE VL.REF_CD_SEQ = STP.DED_BASE AND VL.CRNT_REC_FLG = 1)
                   DED_BASE_DESC,
               STP.DED_APLD_ON,
               (SELECT CASE
                           WHEN VL.REF_CD_DSCR =
                                'First disbursed product along with associate product'
                           THEN
                               1
                           ELSE
                               0
                       END
                  FROM MW_REF_CD_VAL VL
                 WHERE     VL.REF_CD_SEQ = STP.DED_APLD_ON
                       AND VL.CRNT_REC_FLG = 1)
                   DED_APLD_ON_DESC
          FROM MW_STP_INCDNT STP
         WHERE     STP.INCDNT_TYP = P_INCDNT_TYP
               AND STP.INCDNT_CTGRY = P_INCDNT_CTGRY
               AND STP.INCDNT_EFFECTEE = P_INCDNT_EFFECTEE
               AND (SELECT VL.REF_CD_DSCR
                      FROM MW_REF_CD_VAL VL
                     WHERE     VL.REF_CD_SEQ = STP.PRD_CHRG
                           AND VL.CRNT_REC_FLG = 1) =
                   P_INCDNT_CHRG
               AND STP.CRNT_REC_FLG = 1;
BEGIN
    IF P_INCDNT_RVRSE = 0
    THEN
        V_INCDNT_DT := TO_DATE (P_INCDNT_DT, 'DD-MON-RRRR');

        V_INCDNT_DT := '30-NOV-2022'; ------------- P_INCDNT_DT ---------------

            SELECT BRNCH_SEQ, AP.PRNT_LOAN_APP_SEQ
              INTO V_BRNCH_SEQ, V_PRNT_LOAN_APP_SEQ
              FROM MW_LOAN_APP AP
             WHERE     AP.CLNT_SEQ = P_CLNT_SEQ
                   AND AP.CRNT_REC_FLG = 1
                   AND AP.LOAN_APP_STS IN (703, 1305)
          ORDER BY 2 DESC
        FETCH NEXT 1 ROWS ONLY;

        SELECT CNIC_NUM
          INTO V_CNIC_NUM
          FROM MW_CLNT MC
         WHERE MC.CLNT_SEQ = P_CLNT_SEQ AND MC.CRNT_REC_FLG = 1;

        -----------  SAVE DATA INTO INCENT REPORT TABLE -----------------
        INSERT INTO MW_INCDNT_RPT (INCDNT_RPT_SEQ,
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
             VALUES (INCDNT_RPT_SEQ.NEXTVAL,
                     P_CLNT_SEQ,
                     P_INCDNT_EFFECTEE,
                     P_INCDNT_TYP,
                     P_INCDNT_CTGRY,
                     V_INCDNT_DT,
                     P_INCDNT_CAUSE,
                     P_INCDNT_REF,
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

        INSERT INTO MW_CLNT_TAG_LIST (CLNT_TAG_LIST_SEQ,
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
             VALUES (CLNT_TAG_LIST_SEQ.NEXTVAL,
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
               WHERE     STP.INCDNT_TYP = P_INCDNT_TYP
                     AND STP.INCDNT_CTGRY = P_INCDNT_CTGRY
                     AND STP.INCDNT_EFFECTEE = P_INCDNT_EFFECTEE
                     AND STP.CRNT_REC_FLG = 1
            GROUP BY STP.RVRSE_ALL_ADV, STP.RVRSE_ALL_EXPT_SM_MNTH;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK;
                P_INCDNT_RTN_MSG :=
                       'PRC_INCDNT_PROCESS ==> ERROR IN RECOVERY REVERSAL => LINE NO: '
                    || $$PLSQL_LINE
                    || CHR (10)
                    || ' ERROR CODE: '
                    || SQLCODE
                    || ' ERROR MESSAGE: '
                    || SQLERRM
                    || 'TRACE: '
                    || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
                KASHF_REPORTING.PRO_LOG_MSG ('PRC_INCDNT_PROCESS',
                                             P_INCDNT_RTN_MSG);
                RETURN;
        END;

        IF V_RVRSE_ALL_ADV = 1 ------------  IF ALL RECOVERIES REVERSAL IN CASE OF INCIDENT
        THEN
            ---------  CALL ADVANCE RECVERY REVERSAL, EXCESS PAID -----------------
            PRC_INCDNT_RVRSE_RCVRY (P_CLNT_SEQ,
                                    V_INCDNT_DT,
                                    1, ----------------   ALL RECOVERIES REVERSAL
                                    P_INCDNT_USER,
                                    P_INCDNT_RTN_RCV_MSG);

            IF P_INCDNT_RTN_RCV_MSG != 'SUCCESS'
            THEN
                ROLLBACK;
                KASHF_REPORTING.PRO_LOG_MSG (
                    'PRC_INCDNT_PROCESS',
                    P_INCDNT_RTN_RCV_MSG || P_CLNT_SEQ || SQLERRM);
                P_INCDNT_RTN_MSG :=
                       'ERROR PRC_INCDNT_PROCESS => P_INCDNT_RTN_RCV_MSG '
                    || P_INCDNT_RTN_RCV_MSG;
                RETURN;
            END IF;
        ELSIF V_RVRSE_ALL_EXPT_SM_MNTH = 1
        THEN
            ---------  CALL ADVANCE RECVERY REVERSAL, EXCESS PAID -----------------
            PRC_INCDNT_RVRSE_RCVRY (P_CLNT_SEQ,
                                    V_INCDNT_DT,
                                    2, ----------------   ALL RECOVERIES REVERSAL EXCEPT SAME MONTH
                                    P_INCDNT_USER,
                                    P_INCDNT_RTN_RCV_MSG);

            IF P_INCDNT_RTN_RCV_MSG != 'SUCCESS'
            THEN
                ROLLBACK;
                KASHF_REPORTING.PRO_LOG_MSG (
                    'PRC_INCDNT_PROCESS',
                    P_INCDNT_RTN_RCV_MSG || P_CLNT_SEQ || SQLERRM);
                P_INCDNT_RTN_MSG :=
                       'ERROR PRC_INCDNT_PROCESS => P_INCDNT_RTN_RCV_MSG '
                    || P_INCDNT_RTN_RCV_MSG;
                RETURN;
            END IF;
        END IF;

        ----------------  FOR LOOP (SELECT ALL THE CHARGES OF A CLNT) -----------------
        FOR CHRGS
            IN (  SELECT INCDNT_TYP,
                         INCDNT_CTGRY,
                         INCDNT_CHRG,
                         INCDNT_EFFECTEE
                    FROM (SELECT IRP.INCDNT_TYP,
                                 IRP.INCDNT_CTGRY,
                                 CASE
                                     WHEN     PSC.CHRG_TYPS_SEQ = -2
                                          AND PRD.PRD_GRP_SEQ NOT IN (6,
                                                                      24,
                                                                      13,
                                                                      5766,
                                                                      22)
                                     THEN
                                         'KSZB'
                                     WHEN     PSC.CHRG_TYPS_SEQ = -2
                                          AND PRD.PRD_GRP_SEQ IN (13, 5766, 22)
                                     THEN
                                         'KC'
                                     WHEN     PSC.CHRG_TYPS_SEQ = -2
                                          AND PRD.PRD_GRP_SEQ IN (6, 24)
                                     THEN
                                         'KST'
                                     WHEN PSC.CHRG_TYPS_SEQ != -2
                                     THEN
                                         (SELECT MT.TYP_STR
                                            FROM MW_TYPS MT
                                           WHERE     MT.TYP_SEQ =
                                                     PSC.CHRG_TYPS_SEQ
                                                 AND MT.CRNT_REC_FLG = 1)
                                 END
                                     INCDNT_CHRG,
                                 IRP.INCDNT_EFFECTEE,
                                 AP.CRTD_DT
                            FROM MW_INCDNT_RPT IRP
                                 JOIN MW_LOAN_APP AP
                                     ON     AP.CLNT_SEQ = IRP.CLNT_SEQ
                                        AND AP.CRNT_REC_FLG = 1
                                        AND AP.LOAN_APP_SEQ =
                                            AP.PRNT_LOAN_APP_SEQ
                                 JOIN MW_PRD PRD
                                     ON     PRD.PRD_SEQ = AP.PRD_SEQ
                                        AND PRD.CRNT_REC_FLG = 1
                                 JOIN MW_DSBMT_VCHR_HDR DSH
                                     ON     DSH.LOAN_APP_SEQ = AP.LOAN_APP_SEQ
                                        AND DSH.CRNT_REC_FLG = 1
                                 JOIN MW_PYMT_SCHED_HDR PSH
                                     ON     PSH.LOAN_APP_SEQ = DSH.LOAN_APP_SEQ
                                        AND PSH.CRNT_REC_FLG = 1
                                 JOIN MW_PYMT_SCHED_DTL PSD
                                     ON     PSD.PYMT_SCHED_HDR_SEQ =
                                            PSH.PYMT_SCHED_HDR_SEQ
                                        AND PSD.CRNT_REC_FLG = 1
                                 LEFT OUTER JOIN MW_PYMT_SCHED_CHRG PSC
                                     ON     PSC.PYMT_SCHED_DTL_SEQ =
                                            PSD.PYMT_SCHED_DTL_SEQ
                                        AND PSC.CRNT_REC_FLG = 1
                           WHERE     IRP.CLNT_SEQ = P_CLNT_SEQ
                                 AND IRP.CRNT_REC_FLG = 1
                                 AND AP.LOAN_APP_STS = 703
                                 AND TRUNC (IRP.DT_OF_INCDNT) >=
                                     TRUNC (DSH.DSBMT_DT))
                GROUP BY INCDNT_TYP,
                         INCDNT_CTGRY,
                         INCDNT_CHRG,
                         INCDNT_EFFECTEE,
                         CRTD_DT
                ORDER BY CRTD_DT)
        LOOP
            V_DED_AMT := 0;

            IF CHRGS.INCDNT_CHRG IS NOT NULL
            THEN
                ------------  FETCH INCIDENT SETUP CURSOR DATA -----------
                FOR STP IN CR_STP_INCDNT (CHRGS.INCDNT_TYP,
                                          CHRGS.INCDNT_CTGRY,
                                          CHRGS.INCDNT_EFFECTEE,
                                          CHRGS.INCDNT_CHRG)
                LOOP
                    BEGIN
                        -----------  CALL FUNERAL CHARGES CALCULATION procedure ----------------
                        PRC_CALC_FNRL_CHRGS (P_CLNT_SEQ,
                                             V_INCDNT_DT,
                                             P_INCDNT_USER,
                                             CHRGS.INCDNT_CHRG,
                                             STP.PRD_CHRG_CD,
                                             STP.DED_SM_MNTH,
                                             STP.DED_BASE_DESC,
                                             STP.DED_APLD_ON_DESC,
                                             TO_NUMBER (STP.FXD_PRMUM_DESC),
                                             P_INCDNT_RTN_MSGCALC,
                                             V_DED_AMT);

                        V_DED_AMT_TOT :=
                            NVL (V_DED_AMT_TOT, 0) + NVL (V_DED_AMT, 0); --------  SUM ALL THE CHARGES TO BE DEDUCT
                    END;

                    V_INC_PRIMUM_AMT :=
                        NVL (TO_NUMBER (STP.FXD_PRMUM_DESC), 0); -----  SET FUNERAL PERMIUM AMOUT FROM SETUP
                END LOOP;                                 ----------  STP LOOP
            END IF;
        END LOOP;                                ---------  CLNTS CHARGES LOOP

        ------  UPDATE DEDUCTION AMOUT AND INCIDENT STATUS -----------
        UPDATE MW_INCDNT_RPT INC
           SET INC.AMT = (NVL (V_INC_PRIMUM_AMT, 0) - NVL (V_DED_AMT_TOT, 0)),
               INC.INCDNT_STS =
                   (SELECT VL.REF_CD_SEQ
                      FROM MW_REF_CD_VAL  VL
                           JOIN MW_REF_CD_GRP GRP
                               ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                                  AND GRP.CRNT_REC_FLG = 1
                     WHERE GRP.REF_CD_GRP = '0425' AND VL.REF_CD = '0001'),
               INC.LAST_UPD_DT = SYSDATE,
               INC.LAST_UPD_BY = P_INCDNT_USER
         WHERE     INC.CLNT_SEQ = P_CLNT_SEQ
               AND INC.DT_OF_INCDNT = V_INCDNT_DT
               AND INC.CRNT_REC_FLG = 1;
    ELSE                         -----------  FOR INCIDENT REVERSAL ----------    
        ----------REVERSE EXCESS IF ANY ------------
        FOR RVSL_EX
            IN (  SELECT RCH.RCVRY_TRX_SEQ
                    FROM MW_RCVRY_TRX RCH
                         JOIN MW_RCVRY_DTL RCD
                             ON     RCD.RCVRY_TRX_SEQ = RCH.RCVRY_TRX_SEQ
                                AND RCD.CRNT_REC_FLG = 1
                   WHERE     RCH.PYMT_REF = P_CLNT_SEQ
                         AND RCH.CHNG_RSN_CMNT LIKE
                                 ('%EXCESS CREATED DUE TO INCIDENT PROCESS DATED:%')
                         AND RCH.CRNT_REC_FLG = 1
                    GROUP BY RCH.RCVRY_TRX_SEQ
                ORDER BY 1 DESC)
        LOOP
            
            UPDATE MW_RCVRY_TRX RCH
                SET RCH.CRNT_REC_FLG = 0,
                  RCH.DEL_FLG = 1,
                RCH.LAST_UPD_BY = P_INCDNT_USER,
                RCH.LAST_UPD_DT = SYSDATE
              WHERE RCH.RCVRY_TRX_SEQ = RVSL_EX.RCVRY_TRX_SEQ
              AND RCH.PYMT_REF = P_CLNT_SEQ
              AND RCH.CRNT_REC_FLG = 1;
        
            UPDATE MW_RCVRY_DTL RCD
                SET RCD.CRNT_REC_FLG = 0,
                  RCD.DEL_FLG = 1,
                RCD.LAST_UPD_BY = P_INCDNT_USER,
                RCD.LAST_UPD_DT = SYSDATE
              WHERE RCD.RCVRY_TRX_SEQ = RVSL_EX.RCVRY_TRX_SEQ              
              AND RCD.CRNT_REC_FLG = 1;
              
            SELECT JV_HDR_SEQ.NEXTVAL INTO V_JV_HDR_SEQ_REV FROM DUAL;  
              
            Insert into MW_JV_HDR
               (JV_HDR_SEQ, PRNT_VCHR_REF, JV_ID, JV_DT, JV_DSCR, 
                JV_TYP_KEY, ENTY_SEQ, ENTY_TYP, CRTD_BY, POST_FLG, 
                RCVRY_TRX_SEQ, BRNCH_SEQ, CLNT_SEQ, INSTR_NUM, TRNS_DT, 
                PYMT_MODE, TOT_DBT, TOT_CRDT, ERP_INTEGRATION_FLG, ERP_INTEGRATION_DT)
            SELECT V_JV_HDR_SEQ_REV, JV_HDR_SEQ, JV_ID, TO_DATE(SYSDATE), 'REVERSAL OF '||JV_DSCR, 
                JV_TYP_KEY, ENTY_SEQ, ENTY_TYP, P_INCDNT_USER, POST_FLG, 
                RCVRY_TRX_SEQ, BRNCH_SEQ, CLNT_SEQ, INSTR_NUM, SYSDATE, 
                PYMT_MODE, TOT_DBT, TOT_CRDT, 0, NULL
            FROM MW_JV_HDR JVH
             WHERE JVH.ENTY_SEQ = RVSL_EX.RCVRY_TRX_SEQ;

            Insert into MW_JV_DTL
               (JV_DTL_SEQ, JV_HDR_SEQ, CRDT_DBT_FLG, AMT, GL_ACCT_NUM, 
                DSCR, LN_ITM_NUM)
             SELECT JV_DTL_SEQ.NEXTVAL, V_JV_HDR_SEQ_REV, CASE WHEN CRDT_DBT_FLG = 0 THEN 1 ELSE 0 END, AMT, GL_ACCT_NUM, 
                CASE WHEN DSCR = 'Credit' THEN 'Debit' ELSE 'Credit' END , LN_ITM_NUM
              FROM MW_JV_DTL JVD
              WHERE JVD.JV_HDR_SEQ IN (
                SELECT MAX(JV_HDR_SEQ)
                FROM MW_JV_HDR JVH
                 WHERE JVH.ENTY_SEQ = RVSL_EX.RCVRY_TRX_SEQ
                 AND JVH.PRNT_VCHR_REF IS NOT NULL
                );
        
        END LOOP; ----------  REVERSE EXCESS RECOVERY ----------
        
        ---------- ENTER RECOVERY AGAIN IF ANY ------------
        FOR RVSL_REC
            IN (  SELECT RCH.RCVRY_TRX_SEQ
                    FROM MW_RCVRY_TRX RCH
                         JOIN MW_RCVRY_DTL RCD
                             ON     RCD.RCVRY_TRX_SEQ = RCH.RCVRY_TRX_SEQ
                                AND RCD.CRNT_REC_FLG = 0
                   WHERE     RCH.PYMT_REF = 3520150930712
                         AND RCH.CHNG_RSN_CMNT LIKE
                                 ('%REVERSE DUE TO INCIDENT PROCESS DATED:%')
                         AND RCH.CRNT_REC_FLG = 0
                GROUP BY RCH.RCVRY_TRX_SEQ
                ORDER BY 1)
        LOOP
            NULL;
        END LOOP;
        
        
    END IF;

    P_INCDNT_RTN_MSG := 'SUCCESS';
EXCEPTION
    WHEN OTHERS
    THEN
        ROLLBACK;
        P_INCDNT_RTN_MSG :=
               'PRC_INCDNT_PROCESS ==> GENERIC ERROR => LINE NO: '
            || $$PLSQL_LINE
            || CHR (10)
            || ' ERROR CODE: '
            || SQLCODE
            || ' ERROR MESSAGE: '
            || SQLERRM
            || 'TRACE: '
            || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        KASHF_REPORTING.PRO_LOG_MSG ('PRC_INCDNT_PROCESS', P_INCDNT_RTN_MSG);
        RETURN;
END;
/