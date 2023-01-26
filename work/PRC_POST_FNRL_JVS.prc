/* Formatted on 26/01/2023 3:10:14 pm (QP5 v5.326) */
CREATE OR REPLACE PROCEDURE PRC_POST_FNRL_JVS (P_CLNT_SEQ        NUMBER,
                                               P_EXPNS_SEQ       NUMBER,
                                               P_RCVRY_SEQ       NUMBER, --59839447
                                               P_BRNCH_SEQ       NUMBER,
                                               P_USER_ID         VARCHAR2,
                                               V_RTN_STS     OUT VARCHAR2)
AS
    V_COUNT             NUMBER := 0;
    V_ERROR_MSG         VARCHAR2 (500);
    V_EXPNS_TYP_SEQ     NUMBER;
    V_PYMT_TYP_SEQ      NUMBER;
    V_CLNT_SEQ          NUMBER;
    V_EXP_FOUND         NUMBER := 0;
    V_EXPNS_AMT         NUMBER;
    V_PYMT_RCT_FLG      NUMBER;
    V_EXPNS_TYP_STR     VARCHAR2 (200);
    V_DBT_GL_ACCT_NUM   MW_TYPS.GL_ACCT_NUM%TYPE;
    V_EXPNS_BR_SEQ      NUMBER;
    V_CLNT_NM           VARCHAR2 (100);
    V_PYMT_TYP_STR      VARCHAR2 (200);
    V_CRD_GL_ACCT_NUM   MW_TYPS.GL_ACCT_NUM%TYPE;
    V_EXPNS_DSCR        VARCHAR2 (200);
    V_JV_HDR_DESC       VARCHAR2 (200);
    V_ENTRY_TYP         VARCHAR2 (100);
BEGIN
    ------------  TO POST EXPENSE ----------------
    IF P_EXPNS_SEQ <> 0
    THEN
        BEGIN
            SELECT EX.EXPNS_TYP_SEQ,
                   EX.PYMT_TYP_SEQ,
                   EX.EXPNS_AMT,
                   EX.PYMT_RCT_FLG,
                   TY.TYP_STR,
                   TY.GL_ACCT_NUM,
                   EX.BRNCH_SEQ
              INTO V_EXPNS_TYP_SEQ,
                   V_PYMT_TYP_SEQ,
                   V_EXPNS_AMT,
                   V_PYMT_RCT_FLG,
                   V_EXPNS_TYP_STR,
                   V_DBT_GL_ACCT_NUM,
                   V_EXPNS_BR_SEQ
              FROM MW_EXP  EX
                   JOIN MW_TYPS TY
                       ON     TY.TYP_SEQ = EX.EXPNS_TYP_SEQ
                          AND TY.CRNT_REC_FLG = EX.CRNT_REC_FLG
             WHERE     EX.CRNT_REC_FLG = 1
                   AND EX.EXP_SEQ = P_EXPNS_SEQ
                   AND EX.POST_FLG = 0;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK;
                V_RTN_STS :=
                       'PRC_POST_FNRL_JVS ==> EXPENSE ALREADY POSTED OR NOT FOUND => LINE NO: '
                    || $$PLSQL_LINE
                    || CHR (10)
                    || ' ERROR CODE: '
                    || SQLCODE
                    || ' ERROR MESSAGE: '
                    || SQLERRM
                    || 'TRACE: '
                    || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
                KASHF_REPORTING.PRO_LOG_MSG ('PRC_POST_FNRL_JVS', V_RTN_STS);
                RETURN;
        END;

        BEGIN
            SELECT COUNT (1)
              INTO V_EXP_FOUND
              FROM MW_EXP ME
             WHERE     ME.EXP_REF = P_CLNT_SEQ
                   AND ME.CRNT_REC_FLG = 1
                   AND ME.DEL_FLG = 0;

            IF V_EXP_FOUND <> 0
            THEN
                    SELECT CLNT_SEQ
                      INTO V_CLNT_SEQ
                      FROM MW_EXP ME
                           JOIN MW_ANML_RGSTR RG
                               ON     RG.ANML_RGSTR_SEQ = ME.EXP_REF
                                  AND RG.CRNT_REC_FLG = 1
                           JOIN MW_LOAN_APP AP
                               ON     AP.LOAN_APP_SEQ = RG.LOAN_APP_SEQ
                                  AND AP.CRNT_REC_FLG = 1
                                  AND AP.LOAN_APP_STS = 703
                     WHERE RG.ANML_RGSTR_SEQ = P_CLNT_SEQ
                  ORDER BY 1 DESC
                FETCH NEXT 1 ROWS ONLY;

                    SELECT CLNT.FRST_NM || ' ' || CLNT.LAST_NM
                      INTO V_CLNT_NM
                      FROM MW_CLNT CLNT
                           JOIN MW_LOAN_APP LA
                               ON     LA.CLNT_SEQ = CLNT.CLNT_SEQ
                                  AND LA.CRNT_REC_FLG = 1
                                  AND LA.LOAN_APP_STS = 703
                     WHERE CLNT.CRNT_REC_FLG = 1 AND CLNT.CLNT_SEQ = V_CLNT_SEQ
                  GROUP BY CLNT.FRST_NM || ' ' || CLNT.LAST_NM
                  ORDER BY 1 DESC
                FETCH NEXT 1 ROWS ONLY;
            ELSE
                    SELECT CLNT.CLNT_SEQ, CLNT.FRST_NM || ' ' || CLNT.LAST_NM
                      INTO V_CLNT_SEQ, V_CLNT_NM
                      FROM MW_CLNT CLNT
                           JOIN MW_LOAN_APP LA
                               ON     LA.CLNT_SEQ = CLNT.CLNT_SEQ
                                  AND LA.CRNT_REC_FLG = 1
                                  AND LA.LOAN_APP_STS = 703
                     WHERE CLNT.CRNT_REC_FLG = 1 AND CLNT.CLNT_SEQ = P_CLNT_SEQ
                  GROUP BY CLNT.FRST_NM || ' ' || CLNT.LAST_NM
                  ORDER BY 1 DESC
                FETCH NEXT 1 ROWS ONLY;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK;
                V_RTN_STS :=
                       'PRC_POST_FNRL_JVS ==> ERROR IN GETTING CLNT NAME => LINE NO: '
                    || $$PLSQL_LINE
                    || CHR (10)
                    || ' ERROR CODE: '
                    || SQLCODE
                    || ' ERROR MESSAGE: '
                    || SQLERRM
                    || 'TRACE: '
                    || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
                KASHF_REPORTING.PRO_LOG_MSG ('PRC_POST_FNRL_JVS', V_RTN_STS);
                RETURN;
        END;

        BEGIN
            SELECT TY.TYP_STR,
                   TY.GL_ACCT_NUM,
                   EX.PYMT_RCT_FLG,
                   EX.EXPNS_DSCR
              INTO V_PYMT_TYP_STR,
                   V_CRD_GL_ACCT_NUM,
                   V_PYMT_RCT_FLG,
                   V_EXPNS_DSCR
              FROM MW_TYPS  TY
                   JOIN MW_EXP EX
                       ON     EX.PYMT_TYP_SEQ = TY.TYP_SEQ
                          AND EX.CRNT_REC_FLG = 1
             WHERE TY.CRNT_REC_FLG = 1 AND EX.EXP_SEQ = P_EXPNS_SEQ;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK;
                V_RTN_STS :=
                       'PRC_POST_FNRL_JVS ==> ERROR IN GETTING MW_EXP TYPS => LINE NO: '
                    || $$PLSQL_LINE
                    || CHR (10)
                    || ' ERROR CODE: '
                    || SQLCODE
                    || ' ERROR MESSAGE: '
                    || SQLERRM
                    || 'TRACE: '
                    || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
                KASHF_REPORTING.PRO_LOG_MSG ('PRC_POST_FNRL_JVS', V_RTN_STS);
                RETURN;
        END;

        IF V_EXPNS_TYP_SEQ IS NOT NULL
        THEN
            V_JV_HDR_DESC :=
                   'Funeral Charges is paid to Client '
                || V_CLNT_NM
                || ' through '
                || V_PYMT_TYP_STR;

            V_ENTRY_TYP := 'Expense';
        END IF;

        IF V_EXPNS_AMT > 0
        THEN
            PRC_JV ('HDR/DTL',
                    P_EXPNS_SEQ,
                    V_EXPNS_AMT,
                    V_JV_HDR_DESC,
                    V_ENTRY_TYP,
                    V_CRD_GL_ACCT_NUM,
                    V_DBT_GL_ACCT_NUM,
                    0,
                    V_EXPNS_BR_SEQ,
                    P_USER_ID,
                    V_RTN_STS,
                    V_CLNT_SEQ);

            IF V_RTN_STS != 'SUCCESS'
            THEN
                ROLLBACK;
                V_RTN_STS :=
                       'PRC_POST_FNRL_JVS ==> '
                    || V_RTN_STS
                    || ' LINE NO: '
                    || $$PLSQL_LINE
                    || CHR (10)
                    || ' ERROR CODE: '
                    || SQLCODE
                    || ' ERROR MESSAGE: '
                    || SQLERRM
                    || 'TRACE: '
                    || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
                KASHF_REPORTING.PRO_LOG_MSG ('PRC_POST_FNRL_JVS', V_RTN_STS);
                RETURN;
            END IF;
        END IF;

        UPDATE MW_EXP ME
           SET ME.POST_FLG = 1,
               ME.LAST_UPD_BY = P_USER_ID,
               ME.LAST_UPD_DT = SYSDATE
         WHERE     ME.EXP_SEQ = P_EXPNS_SEQ
               AND ME.CRNT_REC_FLG = 1
               AND ME.POST_FLG = 0;
    END IF;

    IF P_RCVRY_SEQ <> 0
    THEN
        FOR REC
            IN (  SELECT RCH.PYMT_REF,
                         (SELECT TYP_STR
                            FROM MW_TYPS MT
                           WHERE     MT.TYP_SEQ = RCH.RCVRY_TYP_SEQ
                                 AND MT.CRNT_REC_FLG = 1)
                             RCVRY_TYP_DESC,
                         RCH.RCVRY_TYP_SEQ,
                         RCH.INSTR_NUM,
                         RCD.PYMT_SCHED_DTL_SEQ,
                         RCD.PYMT_AMT,
                         RCD.CHRG_TYP_KEY
                    FROM MW_RCVRY_TRX RCH
                         JOIN MW_RCVRY_DTL RCD
                             ON     RCD.RCVRY_TRX_SEQ = RCH.RCVRY_TRX_SEQ
                                AND RCD.CRNT_REC_FLG = 1
                   WHERE     RCH.CRNT_REC_FLG = 1
                         AND RCH.POST_FLG = 0
                         AND RCH.RCVRY_TRX_SEQ = P_RCVRY_SEQ
                ORDER BY 4)
        LOOP
            IF V_COUNT = 0
            THEN
                V_JV_HDR_DESC :=
                       'Due to Incident Receivable is collected from Client '
                    || P_CLNT_SEQ
                    || ' through '
                    || REC.RCVRY_TYP_DESC;

                PRC_JV ('HDR',            -- INSERTION TYPE: HDR/DTL, HDR, DTL
                        P_RCVRY_SEQ,               -- EXPENSE/RECOVERY/ANY SEQ
                        0,                                           -- AMOUNT
                        V_JV_HDR_DESC,                       -- JV DESCRIPTION
                        'Recovery',                              -- ENTRY TYPE
                        '',                               -- CREDIT GL ACCOUNT
                        '',                                -- DEBIT GL ACCOUNT
                        0, -- JV HEADER SEQ WILL BE USED FOR DTL INSERTION ONLY
                        P_BRNCH_SEQ,                             -- BRANCH SEQ
                        P_USER_ID,                   -- CURRENT LOGGED IN USER
                        V_RTN_STS,
                        P_CLNT_SEQ);

                IF V_RTN_STS LIKE '%EXCEPTION%'
                THEN
                    ROLLBACK;
                    V_RTN_STS :=
                           'PRC_POST_FNRL_JVS ==> '
                        || V_RTN_STS
                        || ' LINE NO: '
                        || $$PLSQL_LINE
                        || CHR (10)
                        || ' ERROR CODE: '
                        || SQLCODE
                        || ' ERROR MESSAGE: '
                        || SQLERRM
                        || 'TRACE: '
                        || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
                    KASHF_REPORTING.PRO_LOG_MSG ('PRC_POST_FNRL_JVS',
                                                 V_RTN_STS);
                    RETURN;
                END IF;

                V_COUNT := 1;
            END IF;

            IF REC.CHRG_TYP_KEY = -2
            THEN
                BEGIN
                    SELECT HIP.GL_ACCT_NUM     GL_ACCT_NUM
                      INTO V_DBT_GL_ACCT_NUM
                      FROM MW_CLNT_HLTH_INSR  CHI
                           JOIN MW_HLTH_INSR_PLAN HIP
                               ON     HIP.HLTH_INSR_PLAN_SEQ =
                                      CHI.HLTH_INSR_PLAN_SEQ
                                  AND (   HIP.CRNT_REC_FLG = 1
                                       OR (    HIP.HLTH_INSR_PLAN_SEQ = 1243
                                           AND HIP.CRNT_REC_FLG = 0))
                           JOIN MW_PYMT_SCHED_HDR HDR
                               ON     HDR.LOAN_APP_SEQ = CHI.LOAN_APP_SEQ
                                  AND HDR.CRNT_REC_FLG = 1
                           JOIN MW_PYMT_SCHED_DTL DTL
                               ON     DTL.PYMT_SCHED_HDR_SEQ =
                                      HDR.PYMT_SCHED_HDR_SEQ
                                  AND DTL.CRNT_REC_FLG = 1
                     WHERE     CHI.CRNT_REC_FLG = 1
                           AND HIP.PLAN_ID != '1223'
                           AND DTL.PYMT_SCHED_DTL_SEQ =
                               REC.PYMT_SCHED_DTL_SEQ;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ROLLBACK;
                        V_RTN_STS :=
                               'PRC_POST_FNRL_JVS ==> ERROR IN GETTING KSZB/KST/KC GL CODE => LINE NO: '
                            || $$PLSQL_LINE
                            || CHR (10)
                            || ' ERROR CODE: '
                            || SQLCODE
                            || ' ERROR MESSAGE: '
                            || SQLERRM
                            || 'TRACE: '
                            || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
                        KASHF_REPORTING.PRO_LOG_MSG ('PRC_POST_FNRL_JVS',
                                                     V_RTN_STS);
                        RETURN;
                END;
            ELSE
                SELECT GL_ACCT_NUM
                  INTO V_DBT_GL_ACCT_NUM
                  FROM MW_TYPS MT
                 WHERE     MT.TYP_SEQ = REC.CHRG_TYP_KEY
                       AND MT.CRNT_REC_FLG = 1
                       AND MT.DEL_FLG = 0;
            END IF;

            SELECT GL_ACCT_NUM
              INTO V_CRD_GL_ACCT_NUM
              FROM MW_TYPS MT
             WHERE MT.TYP_SEQ = REC.RCVRY_TYP_SEQ AND MT.CRNT_REC_FLG = 1;

            PRC_JV ('DTL',                -- INSERTION TYPE: HDR/DTL, HDR, DTL
                    0,                             -- EXPENSE/RECOVERY/ANY SEQ
                    REC.PYMT_AMT,                                    -- AMOUNT
                    '',                                      -- JV DESCRIPTION
                    '',                                          -- ENTRY TYPE
                    V_CRD_GL_ACCT_NUM,                    -- CREDIT GL ACCOUNT
                    V_DBT_GL_ACCT_NUM,                     -- DEBIT GL ACCOUNT
                    V_RTN_STS, -- JV HEADER SEQ WILL BE USED FOR DTL INSERTION ONLY
                    P_BRNCH_SEQ,                                 -- BRANCH SEQ
                    P_USER_ID,                       -- CURRENT LOGGED IN USER
                    V_RTN_STS);

            IF V_RTN_STS LIKE '%EXCEPTION%'
            THEN
                ROLLBACK;
                V_RTN_STS :=
                       'PRC_POST_FNRL_JVS ==> '
                    || V_RTN_STS
                    || ' LINE NO: '
                    || $$PLSQL_LINE
                    || CHR (10)
                    || ' ERROR CODE: '
                    || SQLCODE
                    || ' ERROR MESSAGE: '
                    || SQLERRM
                    || 'TRACE: '
                    || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
                KASHF_REPORTING.PRO_LOG_MSG ('PRC_POST_FNRL_JVS', V_RTN_STS);
                RETURN;
            END IF;
        END LOOP;                                          --------------  REC
    END IF;                                 ---------  P_RCVRY_SEQ IS NOT NULL

    UPDATE MW_RCVRY_TRX RCH
       SET RCH.POST_FLG = 1,
           RCH.LAST_UPD_BY = P_USER_ID,
           RCH.LAST_UPD_DT = SYSDATE
     WHERE     RCH.RCVRY_TRX_SEQ = P_RCVRY_SEQ
           AND RCH.POST_FLG = 0
           AND RCH.CRNT_REC_FLG = 1;

    UPDATE MW_INCDNT_RPT INC
       SET INC.INCDNT_STS =
               (SELECT VL.REF_CD_SEQ
                  FROM MW_REF_CD_VAL  VL
                       JOIN MW_REF_CD_GRP GRP
                           ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                              AND GRP.CRNT_REC_FLG = 1
                 WHERE GRP.REF_CD_GRP = '0425' AND VL.REF_CD = '0002'),
           INC.LAST_UPD_DT = SYSDATE,
           INC.LAST_UPD_BY = P_USER_ID
     WHERE     INC.CLNT_SEQ = P_CLNT_SEQ
           AND INC.INCDNT_STS =
               (SELECT VL.REF_CD_SEQ
                  FROM MW_REF_CD_VAL  VL
                       JOIN MW_REF_CD_GRP GRP
                           ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                              AND GRP.CRNT_REC_FLG = 1
                 WHERE GRP.REF_CD_GRP = '0425' AND VL.REF_CD = '0004')
           AND INC.CRNT_REC_FLG = 1;

    V_RTN_STS := 'SUCCESS';
EXCEPTION
    WHEN NO_DATA_FOUND
    THEN
        ROLLBACK;
        V_RTN_STS :=
               'PRC_POST_FNRL_JVS ==> ISSUE IN FUNERAL POSTING NO DATA FOUND => LINE NO: '
            || $$PLSQL_LINE
            || CHR (10)
            || ' ERROR CODE: '
            || SQLCODE
            || ' ERROR MESSAGE: '
            || SQLERRM
            || 'TRACE: '
            || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        KASHF_REPORTING.PRO_LOG_MSG ('PRC_POST_FNRL_JVS', V_RTN_STS);
        RETURN;
    WHEN OTHERS
    THEN
        ROLLBACK;
        V_RTN_STS :=
               'PRC_POST_FNRL_JVS ==> ISSUE IN FUNERAL POSTING OTHER => LINE NO: '
            || $$PLSQL_LINE
            || CHR (10)
            || ' ERROR CODE: '
            || SQLCODE
            || ' ERROR MESSAGE: '
            || SQLERRM
            || 'TRACE: '
            || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        KASHF_REPORTING.PRO_LOG_MSG ('PRC_POST_FNRL_JVS', V_RTN_STS);
        RETURN;
END;
/