CREATE OR REPLACE PROCEDURE PRC_DEF_REVERSAL_CHRGES (P_CLNT_SEQ   IN NUMBER,
                                                   P_USER       IN VARCHAR2,
                                                   P_INCDNT_RTN_MSG OUT VARCHAR2)
AS
    P_MSG_OUT          NUMBER := 0;
    V_LOAN_APP_SEQ     MW_LOAN_APP.LOAN_APP_SEQ%TYPE;
    V_DSBMT_DT         DATE;
    V_JV_HDR_SEQ_KTK   MW_JV_HDR.JV_HDR_SEQ%TYPE;
    V_BRNCH_SEQ        MW_LOAN_APP.BRNCH_SEQ%TYPE;
    V_DSBMT_HDR_SEQ    MW_DSBMT_VCHR_HDR.DSBMT_HDR_SEQ%TYPE;
    
BEGIN

    BEGIN
        SELECT AP.LOAN_APP_SEQ, AP.BRNCH_SEQ
          INTO V_LOAN_APP_SEQ, V_BRNCH_SEQ
          FROM MW_LOAN_APP AP
         WHERE     AP.CLNT_SEQ = P_CLNT_SEQ
               AND AP.LOAN_APP_STS = 703
               AND AP.CRNT_REC_FLG = 1
               AND AP.PRD_SEQ = 51;
    EXCEPTION WHEN NO_DATA_FOUND
    THEN
        V_LOAN_APP_SEQ := NULL;
    END;

    IF V_LOAN_APP_SEQ IS NOT NULL                       --------- FOR KTK LOAN
    THEN
        ------------------------------------------------
        BEGIN
            SELECT JV_HDR_SEQ.NEXTVAL INTO V_JV_HDR_SEQ_KTK FROM DUAL;

            INSERT INTO MW_JV_HDR
                SELECT *
                  FROM (     SELECT V_JV_HDR_SEQ_KTK,
                                    MJH.PRNT_VCHR_REF,
                                    V_JV_HDR_SEQ_KTK     V_JV_HDR_SEQ_KTK1,
                                    MJH.JV_DT,
                                    MJH.JV_DSCR,
                                    MJH.JV_TYP_KEY,
                                    MJH.ENTY_SEQ,
                                    MJH.ENTY_TYP,
                                    MJH.CRTD_BY,
                                    MJH.POST_FLG,
                                    MJH.RCVRY_TRX_SEQ,
                                    MJH.BRNCH_SEQ,
                                    MJH.CLNT_SEQ,
                                    MJH.INSTR_NUM,
                                    SYSDATE,
                                    MJH.PYMT_MODE,
                                    MJH.TOT_DBT,
                                    MJH.TOT_CRDT,
                                    MJH.ERP_INTEGRATION_FLG,
                                    MJH.ERP_INTEGRATION_DT
                               FROM MW_JV_HDR MJH
                                    JOIN MW_DSBMT_VCHR_HDR DSH
                                        ON     DSH.DSBMT_HDR_SEQ = MJH.ENTY_SEQ
                                           AND DSH.CRNT_REC_FLG = 1
                              WHERE     MJH.ENTY_TYP = 'Disbursement'
                                    AND DSH.LOAN_APP_SEQ = V_LOAN_APP_SEQ
                                    AND MJH.JV_DSCR LIKE
                                            'KTK KSZB POLICY PREMIUM OF THE CLNT%'
                           ORDER BY MJH.JV_HDR_SEQ DESC
                        FETCH FIRST 1 ROW ONLY);

            INSERT INTO MW_JV_DTL (JV_DTL_SEQ,
                                   JV_HDR_SEQ,
                                   CRDT_DBT_FLG,
                                   AMT,
                                   GL_ACCT_NUM,
                                   DSCR,
                                   LN_ITM_NUM)
                SELECT JV_DTL_SEQ.NEXTVAL,
                       V_JV_HDR_SEQ_KTK,
                       MJD.CRDT_DBT_FLG,
                       MJD.AMT,
                       MJD.GL_ACCT_NUM,
                       MJD.DSCR,
                       MJD.LN_ITM_NUM
                  FROM MW_JV_HDR  MJH
                       JOIN MW_DSBMT_VCHR_HDR DSH
                           ON DSH.DSBMT_HDR_SEQ = MJH.ENTY_SEQ
                       JOIN MW_JV_DTL MJD
                           ON     MJD.JV_HDR_SEQ = MJH.JV_HDR_SEQ
                              AND DSH.CRNT_REC_FLG = 1
                 WHERE     MJH.ENTY_TYP = 'Disbursement'
                       AND DSH.LOAN_APP_SEQ = V_LOAN_APP_SEQ
                       AND MJH.JV_HDR_SEQ != V_JV_HDR_SEQ_KTK
                       AND MJH.JV_DSCR LIKE
                               'KTK KSZB POLICY PREMIUM OF THE CLNT%';

            INSERT INTO MW_PYMT_SCHED_CHRG (PYMT_SCHED_CHRG_SEQ,
                                            EFF_START_DT,
                                            PYMT_SCHED_DTL_SEQ,
                                            AMT,
                                            CRTD_BY,
                                            CRTD_DT,
                                            LAST_UPD_BY,
                                            LAST_UPD_DT,
                                            DEL_FLG,
                                            EFF_END_DT,
                                            CRNT_REC_FLG,
                                            CHRG_TYPS_SEQ,
                                            SYNC_FLG,
                                            STP_VAL_EID_SEQ,
                                            REMARKS)
                SELECT PYMT_SCHED_CHRG_SEQ.NEXTVAL,
                       CHRG.EFF_START_DT,
                       CHRG.PYMT_SCHED_DTL_SEQ,
                       CHRG.AMT,
                       CHRG.CRTD_BY,
                       CHRG.CRTD_DT,
                       CHRG.LAST_UPD_BY,
                       CHRG.LAST_UPD_DT,
                       0,
                       CHRG.EFF_END_DT,
                       1,
                       CHRG.CHRG_TYPS_SEQ,
                       CHRG.SYNC_FLG,
                       CHRG.STP_VAL_EID_SEQ,
                       CHRG.REMARKS
                  FROM MW_PYMT_SCHED_HDR  PSH
                       JOIN MW_PYMT_SCHED_DTL PSD
                           ON     PSD.PYMT_SCHED_HDR_SEQ =
                                  PSH.PYMT_SCHED_HDR_SEQ
                              AND PSD.CRNT_REC_FLG = 1
                       JOIN MW_PYMT_SCHED_CHRG CHRG
                           ON     CHRG.PYMT_SCHED_DTL_SEQ =
                                  PSD.PYMT_SCHED_DTL_SEQ
                              AND CHRG.CRNT_REC_FLG = 0
                              AND CHRG.DEL_FLG = 1
                 WHERE     PSH.LOAN_APP_SEQ = V_LOAN_APP_SEQ
                       AND PSH.CRNT_REC_FLG = 1;
        EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            P_INCDNT_RTN_MSG :=
                   'PRC_DEF_REVERSAL_CHRGES ==> GENERIC ERROR IN KTK BLOCK => LINE NO: '
                || $$PLSQL_LINE
                || CHR (10)
                || 'CLNT_SEQ:'
                || P_CLNT_SEQ
                || ' ERROR CODE: '
                || SQLCODE
                || ' ERROR MESSAGE: '
                || SQLERRM
                || 'TRACE: '
                || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            KASHF_REPORTING.PRO_LOG_MSG ('PRC_DEF_REVERSAL_CHRGES', P_INCDNT_RTN_MSG);
            P_INCDNT_RTN_MSG := 'Issue in KTK (Deffered) charges reversal..-0001';
            RETURN;
        END;
    ------------------------------------------------
    ELSE
        FOR I
            IN (  SELECT CHRG.PYMT_SCHED_CHRG_SEQ,
                         CHRG.EFF_START_DT,
                         CHRG.PYMT_SCHED_DTL_SEQ,
                         CHRG.AMT,
                         CHRG.CRTD_BY,
                         CHRG.CRTD_DT,
                         CHRG.LAST_UPD_BY,
                         CHRG.LAST_UPD_DT,
                         CHRG.DEL_FLG,
                         CHRG.EFF_END_DT,
                         CHRG.CRNT_REC_FLG,
                         CHRG.CHRG_TYPS_SEQ,
                         CHRG.SYNC_FLG,
                         CHRG.STP_VAL_EID_SEQ,
                         CHRG.REMARKS
                    FROM MW_LOAN_APP AP
                     JOIN MW_PYMT_SCHED_HDR PSH
                         ON PSH.LOAN_APP_SEQ = AP.LOAN_APP_SEQ AND PSH.CRNT_REC_FLG = 1
                     JOIN MW_PYMT_SCHED_DTL PSD
                         ON     PSD.PYMT_SCHED_HDR_SEQ = PSH.PYMT_SCHED_HDR_SEQ
                            AND PSD.CRNT_REC_FLG = 1
                     JOIN MW_PYMT_SCHED_CHRG CHRG
                         ON     CHRG.PYMT_SCHED_DTL_SEQ = PSD.PYMT_SCHED_DTL_SEQ
                            AND CHRG.CRNT_REC_FLG = 0
                            AND CHRG.DEL_FLG = 1
               WHERE AP.CLNT_SEQ = P_CLNT_SEQ         
                     AND CHRG.CRTD_BY =
                         (SELECT MAX (CHRG1.CRTD_BY)
                            FROM MW_PYMT_SCHED_CHRG CHRG1
                           WHERE     CHRG1.PYMT_SCHED_DTL_SEQ = CHRG.PYMT_SCHED_DTL_SEQ
                                 AND CHRG1.DEL_FLG = 1)
                GROUP BY CHRG.PYMT_SCHED_CHRG_SEQ,
                         CHRG.EFF_START_DT,
                         CHRG.PYMT_SCHED_DTL_SEQ,
                         CHRG.AMT,
                         CHRG.CRTD_BY,
                         CHRG.CRTD_DT,
                         CHRG.LAST_UPD_BY,
                         CHRG.LAST_UPD_DT,
                         CHRG.DEL_FLG,
                         CHRG.EFF_END_DT,
                         CHRG.CRNT_REC_FLG,
                         CHRG.CHRG_TYPS_SEQ,
                         CHRG.SYNC_FLG,
                         CHRG.STP_VAL_EID_SEQ,
                         CHRG.REMARKS
                ORDER BY 1)
        LOOP
            INSERT INTO MW_PYMT_SCHED_CHRG (PYMT_SCHED_CHRG_SEQ,
                                            EFF_START_DT,
                                            PYMT_SCHED_DTL_SEQ,
                                            AMT,
                                            CRTD_BY,
                                            CRTD_DT,
                                            LAST_UPD_BY,
                                            LAST_UPD_DT,
                                            DEL_FLG,
                                            EFF_END_DT,
                                            CRNT_REC_FLG,
                                            CHRG_TYPS_SEQ,
                                            SYNC_FLG,
                                            STP_VAL_EID_SEQ,
                                            REMARKS)
                 VALUES (PYMT_SCHED_CHRG_SEQ.NEXTVAL,
                         SYSDATE,
                         I.PYMT_SCHED_DTL_SEQ,
                         I.AMT,
                         P_USER,
                         SYSDATE,
                         P_USER,
                         SYSDATE,
                         0,
                         NULL,
                         1,
                         I.CHRG_TYPS_SEQ,
                         I.SYNC_FLG,
                         I.STP_VAL_EID_SEQ,
                         I.REMARKS);

            --P_MSG_OUT := 1;
        END LOOP;



        FOR J
            IN (  SELECT MJH.JV_HDR_SEQ,
                         MJH.PRNT_VCHR_REF,
                         MJH.JV_ID,
                         MJH.JV_DT,
                         MJH.JV_DSCR,
                         MJH.JV_TYP_KEY,
                         MJH.ENTY_SEQ,
                         MJH.ENTY_TYP,
                         MJH.CRTD_BY,
                         MJH.POST_FLG,
                         MJH.RCVRY_TRX_SEQ,
                         MJH.BRNCH_SEQ,
                         MJH.CLNT_SEQ,
                         MJH.INSTR_NUM,
                         MJH.TRNS_DT,
                         MJH.PYMT_MODE,
                         MJH.TOT_DBT,
                         MJH.TOT_CRDT,
                         MJH.ERP_INTEGRATION_FLG,
                         MJH.ERP_INTEGRATION_DT
                    FROM MW_JV_HDR MJH
                         JOIN MW_JV_DTL MJD ON MJD.JV_HDR_SEQ = MJH.JV_HDR_SEQ
                   WHERE     MJD.CRDT_DBT_FLG = 1
                         AND MJH.JV_DSCR = 'DEFFERED ENTRY DUE TO CLIENT DEATH'
                         AND MJH.CLNT_SEQ = P_CLNT_SEQ
                         AND NOT EXISTS (
                            SELECT 1 FROM MW_JV_HDR MJ WHERE MJ.PRNT_VCHR_REF = MJH.JV_HDR_SEQ 
                            AND MJ.CLNT_SEQ = P_CLNT_SEQ
                         )
                GROUP BY MJH.JV_HDR_SEQ,
                         MJH.PRNT_VCHR_REF,
                         MJH.JV_ID,
                         MJH.JV_DT,
                         MJH.JV_DSCR,
                         MJH.JV_TYP_KEY,
                         MJH.ENTY_SEQ,
                         MJH.ENTY_TYP,
                         MJH.CRTD_BY,
                         MJH.POST_FLG,
                         MJH.RCVRY_TRX_SEQ,
                         MJH.BRNCH_SEQ,
                         MJH.CLNT_SEQ,
                         MJH.INSTR_NUM,
                         MJH.TRNS_DT,
                         MJH.PYMT_MODE,
                         MJH.TOT_DBT,
                         MJH.TOT_CRDT,
                         MJH.ERP_INTEGRATION_FLG,
                         MJH.ERP_INTEGRATION_DT
                ORDER BY 1)
        LOOP
            INSERT INTO MW_JV_HDR (JV_HDR_SEQ,
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
                 VALUES (JV_HDR_SEQ.NEXTVAL,
                         J.JV_HDR_SEQ,
                         JV_HDR_SEQ.CURRVAL,
                         SYSDATE,
                         'REVERSAL OF DEFFERED ENTRY DUE TO CLIENT DEATH',
                         NULL,
                         J.ENTY_SEQ,
                         'DISBURSEMENT',
                         P_USER,
                         0,
                         J.ENTY_SEQ,
                         J.BRNCH_SEQ,
                         J.CLNT_SEQ,
                         NULL,
                         SYSDATE,
                         NULL,
                         0,
                         0,
                         0,
                         NULL);


            FOR K
                IN (  SELECT MJD1.JV_DTL_SEQ,
                             MJD1.JV_HDR_SEQ,
                             MJD1.CRDT_DBT_FLG,
                             MJD1.AMT,
                             MJD1.GL_ACCT_NUM,
                             MJD1.DSCR,
                             MJD1.LN_ITM_NUM
                        FROM MW_JV_DTL MJD1
                       WHERE MJD1.JV_HDR_SEQ = J.JV_HDR_SEQ                                                             
                    GROUP BY MJD1.JV_DTL_SEQ,
                             MJD1.JV_HDR_SEQ,
                             MJD1.CRDT_DBT_FLG,
                             MJD1.AMT,
                             MJD1.GL_ACCT_NUM,
                             MJD1.DSCR,
                             MJD1.LN_ITM_NUM
                    ORDER BY 1)
            LOOP
                INSERT INTO MW_JV_DTL (JV_DTL_SEQ,
                                       JV_HDR_SEQ,
                                       CRDT_DBT_FLG,
                                       AMT,
                                       GL_ACCT_NUM,
                                       DSCR,
                                       LN_ITM_NUM)
                         VALUES (
                             JV_DTL_SEQ.NEXTVAL,
                             JV_HDR_SEQ.CURRVAL,
                             CASE WHEN K.CRDT_DBT_FLG = 0 THEN 1 ELSE 0 END,
                             K.AMT,
                             K.GL_ACCT_NUM,
                             CASE
                                 WHEN K.CRDT_DBT_FLG = 0 THEN 'Debit'
                                 ELSE 'Credit'
                             END,
                             1);
            END LOOP;
        END LOOP;
    END IF;
    P_INCDNT_RTN_MSG := 'SUCCESS';
EXCEPTION
    WHEN OTHERS
    THEN
        ROLLBACK;
        P_INCDNT_RTN_MSG :=
               'PRC_DEF_REVERSAL_CHRGES ==> GENERIC ERROR => LINE NO: '
            || $$PLSQL_LINE
            || CHR (10)
            || 'CLNT_SEQ:'
            || P_CLNT_SEQ
            || ' ERROR CODE: '
            || SQLCODE
            || ' ERROR MESSAGE: '
            || SQLERRM
            || 'TRACE: '
            || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        KASHF_REPORTING.PRO_LOG_MSG ('PRC_DEF_REVERSAL_CHRGES', P_INCDNT_RTN_MSG);
        P_INCDNT_RTN_MSG := 'Generic Error Deffered reversal..-0001';
        RETURN;
END;
/