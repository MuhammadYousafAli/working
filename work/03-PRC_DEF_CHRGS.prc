CREATE OR REPLACE PROCEDURE KSHF_ITQA.PRC_DEF_CHRGS (
    P_INST_NUM           IN     NUMBER,
    P_LOAN_APP_SEQ        IN     NUMBER,
    P_USER_ID            IN     VARCHAR2,
    P_INCDNT_RTN_MSG_DEF      OUT VARCHAR2,
    P_INCDNT_CHRG_CD      IN     NUMBER,
    P_UNIQUE_NUMBER         NUMBER)
AS
    V_DEF_AMT            NUMBER;
    V_DSBMT_HDR_SEQ       MW_DSBMT_VCHR_HDR.DSBMT_HDR_SEQ%TYPE;
    V_GL_ACCT_NUM         MW_HLTH_INSR_PLAN.GL_ACCT_NUM%TYPE;
    V_DEF_ACCT_NUM        MW_HLTH_INSR_PLAN.DFRD_ACCT_NUM%TYPE;
    V_BRNCH_SEQ          MW_LOAN_APP.BRNCH_SEQ%TYPE;
    V_CLNT_SEQ           MW_LOAN_APP.CLNT_SEQ%TYPE;
    V_PYMT_SCHED_HDR_SEQ   MW_PYMT_SCHED_HDR.PYMT_SCHED_HDR_SEQ%TYPE;
    V_GL_ACCT_NUMMISC     MW_TYPS.GL_ACCT_NUM%TYPE;
    V_DEF_ACCT_NUMMISC    MW_TYPS.DFRD_ACCT_NUM%TYPE;
    V_PRD_SEQ            MW_LOAN_APP.PRD_SEQ%TYPE;
    V_UNIQUE             NUMBER;
BEGIN
    P_INCDNT_RTN_MSG_DEF := NULL;

    BEGIN
          SELECT SUM (NVL (PSC.AMT, 0)),
                 DSH.DSBMT_HDR_SEQ,
                 NVL (PLN.GL_ACCT_NUM, MT.GL_ACCT_NUM),
                 NVL (PLN.DFRD_ACCT_NUM, MT.DFRD_ACCT_NUM),
                 LA.BRNCH_SEQ,
                 LA.CLNT_SEQ,
                 PSH.PYMT_SCHED_HDR_SEQ,
                 MT.GL_ACCT_NUM,
                 MT.DFRD_ACCT_NUM,
                 LA.PRD_SEQ
            INTO V_DEF_AMT,
                 V_DSBMT_HDR_SEQ,
                 V_GL_ACCT_NUM,
                 V_DEF_ACCT_NUM,
                 V_BRNCH_SEQ,
                 V_CLNT_SEQ,
                 V_PYMT_SCHED_HDR_SEQ,
                 V_GL_ACCT_NUMMISC,
                 V_DEF_ACCT_NUMMISC,
                 V_PRD_SEQ
            FROM MW_LOAN_APP LA
                 JOIN MW_PYMT_SCHED_HDR PSH
                     ON     LA.LOAN_APP_SEQ = PSH.LOAN_APP_SEQ
                        AND PSH.CRNT_REC_FLG = 1
                 JOIN MW_PYMT_SCHED_DTL PSD
                     ON     PSH.PYMT_SCHED_HDR_SEQ = PSD.PYMT_SCHED_HDR_SEQ
                        AND PSD.CRNT_REC_FLG = 1
                 JOIN MW_PYMT_SCHED_CHRG PSC
                     ON     PSD.PYMT_SCHED_DTL_SEQ = PSC.PYMT_SCHED_DTL_SEQ
                        AND PSC.CRNT_REC_FLG = 1
                        AND PSC.CHRG_TYPS_SEQ = P_INCDNT_CHRG_CD
                 JOIN MW_DSBMT_VCHR_HDR DSH
                     ON     DSH.LOAN_APP_SEQ = LA.LOAN_APP_SEQ
                        AND DSH.CRNT_REC_FLG = 1
                 LEFT JOIN MW_CLNT_HLTH_INSR INSR
                     ON     INSR.LOAN_APP_SEQ = LA.LOAN_APP_SEQ
                        AND INSR.CRNT_REC_FLG = 1
                 LEFT JOIN MW_HLTH_INSR_PLAN PLN
                     ON     PLN.HLTH_INSR_PLAN_SEQ = INSR.HLTH_INSR_PLAN_SEQ
                        AND PLN.CRNT_REC_FLG = 1
                 LEFT JOIN MW_TYPS MT
                     ON MT.TYP_SEQ = PSC.CHRG_TYPS_SEQ AND MT.CRNT_REC_FLG = 1
           WHERE     LA.LOAN_APP_SEQ = P_LOAN_APP_SEQ
                 AND LA.CRNT_REC_FLG = 1
                 AND LA.LOAN_APP_STS = 703
                 AND PSD.INST_NUM > P_INST_NUM
        GROUP BY DSH.DSBMT_HDR_SEQ,
                 PLN.GL_ACCT_NUM,
                 PLN.DFRD_ACCT_NUM,
                 MT.GL_ACCT_NUM,
                 MT.DFRD_ACCT_NUM,
                 LA.BRNCH_SEQ,
                 LA.CLNT_SEQ,
                 PSH.PYMT_SCHED_HDR_SEQ,
                 LA.PRD_SEQ;
    EXCEPTION
    WHEN OTHERS
    THEN            
        V_DEF_AMT := 0;
        V_DSBMT_HDR_SEQ := NULL;
        P_INCDNT_RTN_MSG_DEF := 'SUCCESS';
        RETURN;
    END;

    IF P_INCDNT_RTN_MSG_DEF IS NULL
    THEN
        BEGIN
            UPDATE MW_PYMT_SCHED_CHRG CHRG
               SET CHRG.LAST_UPD_DT = SYSDATE,
                   CHRG.LAST_UPD_BY = P_USER_ID,
                   CHRG.DEL_FLG = 1,
                   CHRG.CRNT_REC_FLG = 0,
                   CHRG.CRTD_BY = P_UNIQUE_NUMBER
             WHERE     CHRG.PYMT_SCHED_DTL_SEQ IN
                           (SELECT PYMT_SCHED_DTL_SEQ
                              FROM MW_PYMT_SCHED_DTL PSD
                             WHERE     PSD.PYMT_SCHED_HDR_SEQ =
                                       V_PYMT_SCHED_HDR_SEQ
                                   AND PSD.INST_NUM > P_INST_NUM
                                   AND PSD.CRNT_REC_FLG = 1)
                   AND CHRG.CHRG_TYPS_SEQ = P_INCDNT_CHRG_CD
                   AND CHRG.CRNT_REC_FLG = 1;

--            UPDATE MW_PYMT_SCHED_DTL PSD1
--               SET PSD1.PYMT_STS_KEY = 945,
--                   PSD1.LAST_UPD_DT = SYSDATE,
--                   PSD1.LAST_UPD_BY = P_USER_ID
--             WHERE     PSD1.PYMT_SCHED_HDR_SEQ = V_PYMT_SCHED_HDR_SEQ
--                   AND PSD1.PYMT_STS_KEY IN (947, 1145)
--                   AND PSD1.CRNT_REC_FLG = 1
--                   AND NOT EXISTS
--                           (SELECT PSD.PYMT_SCHED_DTL_SEQ
--                              FROM MW_LOAN_APP  LA
--                                   JOIN MW_PYMT_SCHED_HDR PSH
--                                       ON     LA.LOAN_APP_SEQ =
--                                              PSH.LOAN_APP_SEQ
--                                          AND PSH.CRNT_REC_FLG = 1
--                                   JOIN MW_PYMT_SCHED_DTL PSD
--                                       ON     PSH.PYMT_SCHED_HDR_SEQ =
--                                              PSD.PYMT_SCHED_HDR_SEQ
--                                          AND PSD.CRNT_REC_FLG = 1
--                                   JOIN MW_PYMT_SCHED_CHRG PSC
--                                       ON     PSD.PYMT_SCHED_DTL_SEQ =
--                                              PSC.PYMT_SCHED_DTL_SEQ
--                                          AND PSC.CRNT_REC_FLG = 1
--                                   LEFT OUTER JOIN MW_RCVRY_DTL RD
--                                       ON     RD.PYMT_SCHED_DTL_SEQ =
--                                              PSD.PYMT_SCHED_DTL_SEQ
--                                          AND RD.CHRG_TYP_KEY =
--                                              PSC.CHRG_TYPS_SEQ
--                                          AND RD.CRNT_REC_FLG = 1
--                                   JOIN MW_RCVRY_TRX RT
--                                       ON     RT.RCVRY_TRX_SEQ =
--                                              RD.RCVRY_TRX_SEQ
--                                          AND RT.CRNT_REC_FLG = 1
--                             WHERE     PSD.PYMT_SCHED_DTL_SEQ =
--                                       PSD1.PYMT_SCHED_DTL_SEQ
--                                   AND LA.CRNT_REC_FLG = 1
--                                   AND LA.LOAN_APP_STS = 703);
        EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            P_INCDNT_RTN_MSG_DEF :=
                   'PRC_DEF_CHRGS ==> ISSUE IN UPDATING PYMT_CHRG/DTL => LINE NO: '
                || $$PLSQL_LINE
                || CHR (10)
                || ' ERROR CODE: '
                || SQLCODE
                || ' ERROR MESSAGE: '
                || SQLERRM
                || 'TRACE: '
                || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            KASHF_REPORTING.PRO_LOG_MSG ('PRC_DEF_CHRGS',
                                         P_INCDNT_RTN_MSG_DEF);
            P_INCDNT_RTN_MSG_DEF := 'Issue in updating pymt charges / pymt dtl -0001';                             
            RETURN;
        END;

        IF V_PRD_SEQ != 51     ----  NO JV IN CASE OF TOPUP
        THEN
            BEGIN
                PRC_JV ('HDR/DTL',
                        V_DSBMT_HDR_SEQ,
                        V_DEF_AMT,
                        'DEFFERED ENTRY DUE TO CLIENT DEATH',
                        'DISBURSEMENT',
                        CASE
                            WHEN P_INCDNT_CHRG_CD IN (4,
                                                   5,
                                                   382,
                                                   20069,
                                                   427)
                            THEN
                                V_GL_ACCT_NUMMISC
                            ELSE
                                V_GL_ACCT_NUM
                        END,
                        CASE
                            WHEN P_INCDNT_CHRG_CD IN (4,
                                                   5,
                                                   382,
                                                   20069,
                                                   427)
                            THEN
                                V_DEF_ACCT_NUMMISC
                            ELSE
                                V_DEF_ACCT_NUM
                        END,
                        NULL,
                        V_BRNCH_SEQ,
                        P_USER_ID,
                        P_INCDNT_RTN_MSG_DEF,
                        V_CLNT_SEQ);
            EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK;
                P_INCDNT_RTN_MSG_DEF :=
                       'PRC_DEF_CHRGS ==> ISSUE IN JV CREATION => LINE NO: '
                    || $$PLSQL_LINE
                    || CHR (10)
                    || ' ERROR CODE: '
                    || SQLCODE
                    || ' ERROR MESSAGE: '
                    || SQLERRM
                    || 'TRACE: '
                    || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
                KASHF_REPORTING.PRO_LOG_MSG ('PRC_DEF_CHRGS',
                                             P_INCDNT_RTN_MSG_DEF);
                P_INCDNT_RTN_MSG_DEF := 'Issue in JV Creation -00101';                             
                RETURN;
            END;
        END IF;
    END IF;

    P_INCDNT_RTN_MSG_DEF := 'SUCCESS';
    
EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            P_INCDNT_RTN_MSG_DEF :=
                   'PRC_DEF_CHRGS ==> GENERIC ERROR IN PRC_DEF_CHRGS => LINE NO: '
                || $$PLSQL_LINE
                || CHR (10)
                || ' ERROR CODE: '
                || SQLCODE
                || ' ERROR MESSAGE: '
                || SQLERRM
                || 'TRACE: '
                || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            KASHF_REPORTING.PRO_LOG_MSG ('PRC_DEF_CHRGS',
                                         P_INCDNT_RTN_MSG_DEF);
            P_INCDNT_RTN_MSG_DEF := 'Generic Error in PRC_DEF_CHRGS-0001';                             
            RETURN;
        END;    
END;
/