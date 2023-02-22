CREATE OR REPLACE PROCEDURE KSHF_ITQA.PRC_KTK_KSZB_POLICY_RECEIVABLE_RVSL (
    P_LOAN_APP_SEQ       MW_LOAN_APP.LOAN_APP_SEQ%TYPE,
    V_USER               VARCHAR2,
    P_MSG_OUT        OUT VARCHAR2)
AS
    V_CLNT_SEQ             MW_CLNT.CLNT_SEQ%TYPE;
    V_PRD_SEQ              MW_PRD.PRD_SEQ%TYPE;
    V_LOAN_APP_SEQ         MW_LOAN_APP.LOAN_APP_SEQ%TYPE;
    V_PYMT_SCHED_HDR_SEQ   MW_PYMT_SCHED_HDR.PYMT_SCHED_HDR_SEQ%TYPE;
    V_DSBMT_DT             MW_DSBMT_VCHR_HDR.DSBMT_DT%TYPE;
    V_DSBMT_HDR_SEQ        MW_DSBMT_VCHR_HDR.DSBMT_HDR_SEQ%TYPE;
    V_BRNCH_SEQ            MW_LOAN_APP.BRNCH_SEQ%TYPE;
    V_CREDIT               MW_HLTH_INSR_PLAN.GL_ACCT_NUM%TYPE;
    V_DEBIT                MW_HLTH_INSR_PLAN.GL_ACCT_NUM%TYPE;
    V_JV_HDR_SEQ1          MW_JV_HDR.JV_HDR_SEQ%TYPE;
    V_JV_HDR_SEQ           MW_JV_HDR.JV_HDR_SEQ%TYPE;
    V_JV_DTL_SEQ           MW_JV_DTL.JV_DTL_SEQ%TYPE;


    V_ALREADY_ADDED        NUMBER := 0;
    V_ALREADY_ADDED_REV    NUMBER := 0;
    V_ACTIVE_LOANS         NUMBER := 0;
    V_JV_DT                DATE;
    V_CHRG_AMT             NUMBER := 0;
BEGIN
    BEGIN
        SELECT ap.CLNT_SEQ,
               ap.PRD_SEQ,
               psh.LOAN_APP_SEQ,
               psd.PYMT_SCHED_HDR_SEQ,
               TRUNC (dsh.DSBMT_DT),
               dsh.DSBMT_HDR_SEQ,
               ap.BRNCH_SEQ,
               pln.GL_ACCT_NUM,
               pln.DFRD_ACCT_NUM
          INTO V_CLNT_SEQ,
               V_PRD_SEQ,
               V_LOAN_APP_SEQ,
               V_PYMT_SCHED_HDR_SEQ,
               V_DSBMT_DT,
               V_DSBMT_HDR_SEQ,
               V_BRNCH_SEQ,
               V_DEBIT,
               V_CREDIT
          FROM mw_loan_app  ap
               JOIN MW_PYMT_SCHED_HDR psh
                   ON     psh.LOAN_APP_SEQ = ap.LOAN_APP_SEQ
                      AND psh.CRNT_REC_FLG = 1
               JOIN MW_PYMT_SCHED_DTL psd
                   ON     psd.PYMT_SCHED_HDR_SEQ = psh.PYMT_SCHED_HDR_SEQ
                      AND psd.CRNT_REC_FLG = 1
               JOIN MW_PYMT_SCHED_CHRG chrg
                   ON     chrg.PYMT_SCHED_DTL_SEQ = psd.PYMT_SCHED_DTL_SEQ
                      AND chrg.CRNT_REC_FLG = 1
               JOIN MW_DSBMT_VCHR_HDR dsh
                   ON     dsh.LOAN_APP_SEQ = ap.LOAN_APP_SEQ
                      AND dsh.CRNT_REC_FLG = 1
               JOIN MW_CLNT_HLTH_INSR insr
                   ON     insr.LOAN_APP_SEQ = ap.LOAN_APP_SEQ
                      AND insr.CRNT_REC_FLG = 1
               JOIN MW_HLTH_INSR_PLAN pln
                   ON     pln.HLTH_INSR_PLAN_SEQ = insr.HLTH_INSR_PLAN_SEQ
                      AND pln.CRNT_REC_FLG = 1
         WHERE     ap.PRD_SEQ = 51
               AND ap.CRNT_REC_FLG = 1
               AND ap.LOAN_APP_STS = 703
               AND psh.LOAN_APP_SEQ = P_LOAN_APP_SEQ
               AND psd.INST_NUM = 7
               AND chrg.CHRG_TYPS_SEQ = -2;
    EXCEPTION
        WHEN OTHERS
        THEN
            V_CLNT_SEQ := NULL;
            V_PRD_SEQ := NULL;
            V_LOAN_APP_SEQ := NULL;
            V_PYMT_SCHED_HDR_SEQ := NULL;
            V_DSBMT_HDR_SEQ := NULL;
    END;

    IF (    V_PRD_SEQ = 51
        AND V_CLNT_SEQ IS NOT NULL
        AND V_DSBMT_HDR_SEQ IS NOT NULL)
    THEN
        BEGIN
              SELECT COUNT (1), JV_HDR_SEQ, MJH.JV_DT
                INTO V_ALREADY_ADDED, V_JV_HDR_SEQ1, V_JV_DT
                FROM MW_JV_HDR MJH
               WHERE     MJH.ENTY_SEQ = V_DSBMT_HDR_SEQ
                     AND UPPER (MJH.ENTY_TYP) = UPPER ('Disbursement')
                     AND MJH.BRNCH_SEQ = V_BRNCH_SEQ
                     AND MJH.JV_HDR_SEQ =
                         (SELECT MAX (JVH1.JV_HDR_SEQ)
                            FROM MW_JV_HDR JVH1
                           WHERE     JVH1.ENTY_SEQ = V_DSBMT_HDR_SEQ
                                 AND JVH1.PRNT_VCHR_REF IS NULL)
                     AND MJH.JV_DSCR LIKE
                             'KTK KSZB POLICY PREMIUM OF THE CLNT%'
                     AND MJH.PRNT_VCHR_REF IS NULL
            GROUP BY JV_HDR_SEQ, MJH.JV_DT;
        EXCEPTION
            WHEN OTHERS
            THEN
                P_MSG_OUT :=
                       'PRC_KTK_KSZB_POLICY_RECEIVABLE_RVSL ==> ERROR IN GETTING JV NOT FOUND-KTK KSZB POLICY PREMIUM => LINE NO: '
                    || $$PLSQL_LINE
                    || CHR (10)
                    || ' ERROR CODE: '
                    || SQLCODE
                    || ' ERROR MESSAGE: '
                    || SQLERRM
                    || 'TRACE: '
                    || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
                KASHF_REPORTING.PRO_LOG_MSG (
                    'PRC_KTK_KSZB_POLICY_RECEIVABLE_RVSL',
                    P_MSG_OUT);
                P_MSG_OUT := 'Issue in getting KTK JVs -0001';
                RETURN;
        END;

--        SELECT COUNT (1)
--          INTO V_ALREADY_ADDED_REV
--          FROM MW_JV_HDR MJH
--         WHERE     MJH.ENTY_SEQ = V_DSBMT_HDR_SEQ
--               AND UPPER (MJH.ENTY_TYP) = UPPER ('Disbursement')
--               AND MJH.BRNCH_SEQ = V_BRNCH_SEQ
--               AND MJH.JV_DSCR LIKE
--                       'REVERSAL KTK KSZB POLICY PREMIUM OF THE CLNT%'
--               AND MJH.PRNT_VCHR_REF IS NOT NULL;

        SELECT COUNT (1)
          INTO V_ACTIVE_LOANS
          FROM mw_loan_app ap
         WHERE     ap.clnt_seq = V_CLNT_SEQ
               AND ap.crnt_Rec_flg = 1
               AND ap.prd_seq IN (4, 51)
               AND ap.loan_app_sts = 703;

        IF (V_ALREADY_ADDED >= 1 AND V_ACTIVE_LOANS = 2)
        THEN
            BEGIN
                SELECT JV_HDR_SEQ.NEXTVAL INTO V_JV_HDR_SEQ FROM DUAL;

                -- INSERTION: JV HEADER
                INSERT INTO MW_JV_HDR (JV_HDR_SEQ,
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
                    SELECT V_JV_HDR_SEQ,
                           JV_HDR_SEQ,
                           V_JV_HDR_SEQ,
                           V_JV_DT,
                           'REVERSAL ' || JV_DSCR,
                           ENTY_SEQ,
                           ENTY_TYP,
                           V_USER,
                           POST_FLG,
                           RCVRY_TRX_SEQ,
                           BRNCH_SEQ,
                           CLNT_SEQ
                      FROM MW_JV_HDR MJH
                     WHERE     MJH.ENTY_SEQ = V_DSBMT_HDR_SEQ
                           AND UPPER (MJH.ENTY_TYP) = UPPER ('Disbursement')
                           AND MJH.BRNCH_SEQ = V_BRNCH_SEQ
                           AND MJH.PRNT_VCHR_REF IS NULL
                            AND MJH.JV_HDR_SEQ =
                         (SELECT MAX (JVH1.JV_HDR_SEQ)
                            FROM MW_JV_HDR JVH1
                           WHERE     JVH1.ENTY_SEQ = V_DSBMT_HDR_SEQ
                                 AND JVH1.PRNT_VCHR_REF IS NULL)
                           AND MJH.JV_DSCR LIKE
                                   'KTK KSZB POLICY PREMIUM OF THE CLNT%';

                -- INSERTION: JV DETAIL - CREDIT
                --JV DETAIL SEQUENCE

                SELECT JV_DTL_SEQ.NEXTVAL INTO V_JV_DTL_SEQ FROM DUAL;

                INSERT INTO MW_JV_DTL (JV_DTL_SEQ,
                                       JV_HDR_SEQ,
                                       CRDT_DBT_FLG,
                                       AMT,
                                       GL_ACCT_NUM,
                                       DSCR,
                                       LN_ITM_NUM)
                    SELECT V_JV_DTL_SEQ,
                           V_JV_HDR_SEQ,
                           0,
                           AMT,
                           GL_ACCT_NUM,
                           'Credit',
                           LN_ITM_NUM
                      FROM MW_JV_DTL DTL
                     WHERE     JV_HDR_SEQ = V_JV_HDR_SEQ1
                           AND DTL.CRDT_DBT_FLG = 1;

                -- INSERTION: JV DETAIL - DEBIT
                --JV DETAIL SEQUENCE
                SELECT JV_DTL_SEQ.NEXTVAL INTO V_JV_DTL_SEQ FROM DUAL;

                INSERT INTO MW_JV_DTL (JV_DTL_SEQ,
                                       JV_HDR_SEQ,
                                       CRDT_DBT_FLG,
                                       AMT,
                                       GL_ACCT_NUM,
                                       DSCR,
                                       LN_ITM_NUM)
                    SELECT V_JV_DTL_SEQ,
                           V_JV_HDR_SEQ,
                           1,
                           AMT,
                           GL_ACCT_NUM,
                           'Debit',
                           LN_ITM_NUM
                      FROM MW_JV_DTL DTL
                     WHERE     JV_HDR_SEQ = V_JV_HDR_SEQ1
                           AND DTL.CRDT_DBT_FLG = 0;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;
                    P_MSG_OUT :=
                           'PRC_KTK_KSZB_POLICY_RECEIVABLE_RVSL ==> JV NOT CREATED KTK KSZB POLICY PREMIUM => LINE NO: '
                        || $$PLSQL_LINE
                        || CHR (10)
                        || ' ERROR CODE: '
                        || SQLCODE
                        || ' ERROR MESSAGE: '
                        || SQLERRM
                        || 'TRACE: '
                        || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
                    KASHF_REPORTING.PRO_LOG_MSG (
                        'PRC_KTK_KSZB_POLICY_RECEIVABLE_RVSL',
                        P_MSG_OUT);
                    P_MSG_OUT := 'JV not created (KTK KSZB Policy) -0001';
                    RETURN;
            END;
        END IF;
    END IF;

    P_MSG_OUT := 'SUCCESS';
    COMMIT;
EXCEPTION
    WHEN OTHERS
    THEN
        ROLLBACK;
        P_MSG_OUT :=
               'PRC_KTK_KSZB_POLICY_RECEIVABLE_RVSL ==> JV NOT CREATED KTK KSZB POLICY PREMIUM => LINE NO: '
            || $$PLSQL_LINE
            || CHR (10)
            || ' ERROR CODE: '
            || SQLCODE
            || ' ERROR MESSAGE: '
            || SQLERRM
            || 'TRACE: '
            || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        KASHF_REPORTING.PRO_LOG_MSG ('PRC_KTK_KSZB_POLICY_RECEIVABLE_RVSL',
                                     P_MSG_OUT);
        P_MSG_OUT := 'Generic Error in (KTK KSZB Policy) -0001';
        RETURN;
END;
/