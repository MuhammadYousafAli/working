CREATE OR REPLACE PROCEDURE PRC_ADJUST_CLAIM_PYMT_SCHDL (
    P_AMT          NUMBER,
    P_CLNT         NUMBER,
    P_EXPNS_SEQ    NUMBER,
    P_USER         VARCHAR2,
    P_INCDNT_TYP   VARCHAR2,
    P_POST_FLG     NUMBER)
AS
    V_COUNT                NUMBER := 0;
    V_RCVRY_TRX_SEQ        NUMBER := 0;
    V_AMT                  NUMBER := P_AMT;
    V_HDR_SEQ              NUMBER := 0;
    V_JV_HDR_DESC          VARCHAR2 (500);
    V_RCVRY_PYMT_AMT       NUMBER := 0;
    V_PYMT_STS_KEY         NUMBER;
    V_NARRATION            VARCHAR2(200);

    V_CRD_GL_ACCT          VARCHAR2 (30);
    V_DBT_GL_ACCT          VARCHAR2 (30);
    V_PRC_STS              VARCHAR2 (50);

    V_CHRG_TYP_KEY         MW_TYPS.TYP_SEQ%TYPE := 0;

    --Added by Areeba
    V_RCVRY_TYP_SEQ        NUMBER := 0;
    V_CLNT_NM              VARCHAR2 (200);
    V_PYMT_TYP_STR         VARCHAR2 (100);

    --
    V_DTH_RPT_SEQ          MW_DTH_RPT.DTH_RPT_SEQ%TYPE := 0;
    V_DT_OF_DTH            MW_DTH_RPT.DT_OF_DTH%TYPE;
    V_FUNERAL_CHARGE_AMT   MW_DTH_RPT.AMT%TYPE := 0;
    V_AMT_ADJUSTED         MW_DTH_RPT.AMT%TYPE := 0;
    --
    V_ERROR_MSG            VARCHAR2 (500);
BEGIN

    IF P_POST_FLG = 0
    THEN

        FOR I
            IN (SELECT PSC.PYMT_SCHED_CHRG_SEQ,
                       PSC.PYMT_SCHED_DTL_SEQ,
                       PSC.CHRG_TYPS_SEQ,
                       PSD.PYMT_STS_KEY,
                       PSC.AMT,
                       LA.CLNT_SEQ,
                       MP.BRNCH_SEQ,
                       NVL (
                             PSC.AMT
                           - (SELECT NVL (SUM (MRD.PYMT_AMT), 0)
                                FROM MW_RCVRY_TRX MRT, MW_RCVRY_DTL MRD
                               WHERE     MRT.RCVRY_TRX_SEQ = MRD.RCVRY_TRX_SEQ
                                     AND MRT.CRNT_REC_FLG = 1
                                     AND MRT.PYMT_REF = LA.CLNT_SEQ
                                     AND MRD.PYMT_SCHED_DTL_SEQ =
                                         PSD.PYMT_SCHED_DTL_SEQ
                                     AND MRD.CRNT_REC_FLG = 1
                                     AND MRD.CHRG_TYP_KEY = PSC.CHRG_TYPS_SEQ),
                           0)
                           REC,
                       LA.LOAN_APP_SEQ,
                       LA.PRNT_LOAN_APP_SEQ,
                       LA.PRD_SEQ,
                       PRD.PRD_GRP_SEQ
                  FROM MW_LOAN_APP         LA,
                       MW_PYMT_SCHED_HDR   PSH,
                       MW_PYMT_SCHED_DTL   PSD,
                       MW_PYMT_SCHED_CHRG  PSC,
                       MW_PORT             MP,
                       MW_PRD              PRD
                 WHERE     LA.CLNT_SEQ = P_CLNT
                       AND LA.CRNT_REC_FLG = 1
                       AND LA.LOAN_APP_STS IN (703, 1305)
                       AND LA.PORT_SEQ = MP.PORT_SEQ
                       AND MP.CRNT_REC_FLG = 1
                       AND PRD.PRD_SEQ = LA.PRD_SEQ
                       AND PRD.CRNT_REC_FLG = 1
                       AND LA.LOAN_APP_SEQ = PSH.LOAN_APP_SEQ
                       AND PSH.CRNT_REC_FLG = 1
                       AND PSH.PYMT_SCHED_HDR_SEQ = PSD.PYMT_SCHED_HDR_SEQ
                       AND PSD.CRNT_REC_FLG = 1
                       AND PSD.PYMT_SCHED_DTL_SEQ = PSC.PYMT_SCHED_DTL_SEQ(+)
                       AND PSC.CHRG_TYPS_SEQ IN
                               (  SELECT PSC1.CHRG_TYPS_SEQ
                                    FROM MW_PYMT_SCHED_CHRG PSC1
                                   WHERE     PSC1.PYMT_SCHED_DTL_SEQ =
                                             PSD.PYMT_SCHED_DTL_SEQ
                                         AND PSC.CRNT_REC_FLG = 1
                                GROUP BY PSC1.CHRG_TYPS_SEQ)
                       AND PSC.CRNT_REC_FLG = 1)
        LOOP
        
        IF (I.REC > 0 AND V_AMT > 0)
        THEN
            IF V_COUNT = 0
            THEN
                SELECT RCVRY_TRX_SEQ.NEXTVAL INTO V_RCVRY_TRX_SEQ FROM DUAL;

                IF P_INCDNT_TYP = 'DEATH'
                THEN
                    V_NARRATION := 'CASH FUNERAL ADJUSTMENT';
                    V_JV_HDR_DESC :=
                           'FUNERAL Receivable is collected from Client '
                        || V_CLNT_NM
                        || ' through CASH';
                    V_PYMT_STS_KEY := 1500;

                    SELECT GL_ACCT_NUM
                      INTO V_DBT_GL_ACCT
                      FROM MW_TYPS MT
                     WHERE     MT.TYP_ID = '0424'
                           AND MT.TYP_CTGRY_KEY = 2
                           AND MT.CRNT_REC_FLG = 1
                           AND MT.DEL_FLG = 0;
                ELSIF P_INCDNT_TYP = 'DISABILITY'
                THEN
                    V_NARRATION := 'CASH DISABILITY ADJUSTMENT';
                    V_JV_HDR_DESC :=
                           'DISABILITY Receivable is collected from Client '
                        || V_CLNT_NM
                        || ' through CASH';
                    V_PYMT_STS_KEY := 2080;

                    SELECT GL_ACCT_NUM
                      INTO V_DBT_GL_ACCT
                      FROM MW_TYPS MT
                     WHERE     MT.TYP_ID = '0423'
                           AND MT.TYP_CTGRY_KEY = 2
                           AND MT.CRNT_REC_FLG = 1
                           AND MT.DEL_FLG = 0;
                ELSIF P_INCDNT_TYP = 'UPFRONT_CASH'
                THEN
                    V_NARRATION := 'CASH UP-FRONT ADJUSTMENT';
                    V_JV_HDR_DESC :=
                           'UP-FRONT Receivable is collected from Client '
                        || V_CLNT_NM
                        || ' through CASH';
                    V_PYMT_STS_KEY := 2140;

                    SELECT GL_ACCT_NUM
                      INTO V_DBT_GL_ACCT
                      FROM MW_TYPS MT
                     WHERE     MT.TYP_ID = '0001'
                           AND MT.TYP_CTGRY_KEY = 2
                           AND MT.CRNT_REC_FLG = 1
                           AND MT.DEL_FLG = 0;
                END IF;

                INSERT INTO MW_RCVRY_TRX (RCVRY_TRX_SEQ,
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
                                          CHNG_RSN_CMNT)
                         VALUES (
                             V_RCVRY_TRX_SEQ,
                             SYSDATE,
                             V_NARRATION,
                             TO_DATE (SYSDATE),
                             V_AMT,
                             CASE WHEN P_INCDNT_TYP = 'DEATH' THEN 750 ELSE 161 END,
                             NULL,
                             0,
                             P_USER,
                             SYSDATE,
                             P_USER,
                             SYSDATE,
                             0,
                             SYSDATE,
                             1,
                             TO_CHAR (I.CLNT_SEQ),
                             0,
                             NULL,
                             CASE
                                 WHEN P_EXPNS_SEQ IS NOT NULL
                                 THEN
                                     'EXP_SEQ:' || P_EXPNS_SEQ
                                 ELSE
                                     V_NARRATION
                             END);

                /*
                PRC_JV ('HDR',            -- INSERTION TYPE: HDR/DTL, HDR, DTL
                        V_RCVRY_TRX_SEQ,           -- EXPENSE/RECOVERY/ANY SEQ
                        0,                                           -- AMOUNT
                        V_JV_HDR_DESC,                       -- JV DESCRIPTION
                        'Recovery',                              -- ENTRY TYPE
                        '',                               -- CREDIT GL ACCOUNT
                        '',                                -- DEBIT GL ACCOUNT
                        0, -- JV HEADER SEQ WILL BE USED FOR DTL INSERTION ONLY
                        I.BRNCH_SEQ,                             -- BRANCH SEQ
                        P_USER,                      -- CURRENT LOGGED IN USER
                        V_PRC_STS,
                        P_CLNT);
                  */
                V_COUNT := 1;
            END IF;

            IF P_INCDNT_TYP = 'UPFRONT_CASH'
            THEN                        -- ZOHAIB ASIM - DATED 28-09-22 - KSWK
                --
                IF I.REC >= V_AMT
                THEN
                    V_RCVRY_PYMT_AMT := V_AMT;
                ELSE
                    V_RCVRY_PYMT_AMT := I.REC;
                END IF;

                --IN CASE OF KSWK LOAN
                IF I.PRD_GRP_SEQ IN (22)
                THEN
                    V_CHRG_TYP_KEY := 20069;
                ELSE
                    V_CHRG_TYP_KEY := I.CHRG_TYPS_SEQ;
                END IF;

                --
                INSERT INTO MW_RCVRY_DTL (RCVRY_CHRG_SEQ,
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
                                          PYMT_SCHED_DTL_SEQ)
                     VALUES (RCVRY_CHRG_SEQ.NEXTVAL,
                             SYSDATE,
                             V_RCVRY_TRX_SEQ,
                             V_CHRG_TYP_KEY,
                             V_RCVRY_PYMT_AMT,
                             P_USER,
                             SYSDATE,
                             P_USER,
                             SYSDATE,
                             0,
                             NULL,
                             1,
                             I.PYMT_SCHED_DTL_SEQ);
            ELSE
                V_RCVRY_PYMT_AMT := I.REC;
                
                INSERT INTO MW_RCVRY_DTL (RCVRY_CHRG_SEQ,
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
                                          PYMT_SCHED_DTL_SEQ)
                     VALUES (RCVRY_CHRG_SEQ.NEXTVAL,
                             SYSDATE,
                             V_RCVRY_TRX_SEQ,
                             I.CHRG_TYPS_SEQ,
                             V_RCVRY_PYMT_AMT,
                             P_USER,
                             SYSDATE,
                             P_USER,
                             SYSDATE,
                             0,
                             NULL,
                             1,
                             I.PYMT_SCHED_DTL_SEQ);
            END IF;

            UPDATE MW_PYMT_SCHED_DTL PSD
               SET PSD.PYMT_STS_KEY = V_PYMT_STS_KEY
             WHERE PSD.PYMT_SCHED_DTL_SEQ = I.PYMT_SCHED_DTL_SEQ;

            /*SELECT (CASE
                        WHEN I.CHRG_TYPS_SEQ = -2
                        THEN
                            (SELECT HIP.GL_ACCT_NUM     GL_ACCT_NUM
                               FROM MW_CLNT_HLTH_INSR  CHI
                                    JOIN MW_HLTH_INSR_PLAN HIP
                                        ON     HIP.HLTH_INSR_PLAN_SEQ =
                                               CHI.HLTH_INSR_PLAN_SEQ
                                           AND HIP.CRNT_REC_FLG IN (1, 0)
                                    JOIN MW_PYMT_SCHED_HDR HDR
                                        ON     HDR.LOAN_APP_SEQ =
                                               CHI.LOAN_APP_SEQ
                                           AND HDR.CRNT_REC_FLG = 1
                                    JOIN MW_PYMT_SCHED_DTL DTL
                                        ON     DTL.PYMT_SCHED_HDR_SEQ =
                                               HDR.PYMT_SCHED_HDR_SEQ
                                           AND DTL.CRNT_REC_FLG = 1
                              WHERE     CHI.CRNT_REC_FLG = 1
                                    AND HIP.PLAN_ID != '1223'
                                    AND DTL.PYMT_SCHED_DTL_SEQ =
                                        I.PYMT_SCHED_DTL_SEQ)
                        ELSE
                            (SELECT GL_ACCT_NUM
                               FROM MW_TYPS MT
                              WHERE     MT.TYP_CTGRY_KEY = 1
                                    AND MT.CRNT_REC_FLG = 1
                                    AND MT.DEL_FLG = 0
                                    AND MT.TYP_SEQ = I.CHRG_TYPS_SEQ)
                    END)
              INTO V_CRD_GL_ACCT
              FROM DUAL;

            PRC_JV ('DTL',                -- INSERTION TYPE: HDR/DTL, HDR, DTL
                    0,                             -- EXPENSE/RECOVERY/ANY SEQ
                    V_RCVRY_PYMT_AMT,                                -- AMOUNT
                    '',                                      -- JV DESCRIPTION
                    '',                                          -- ENTRY TYPE
                    V_CRD_GL_ACCT,                        -- CREDIT GL ACCOUNT
                    V_DBT_GL_ACCT,                         -- DEBIT GL ACCOUNT
                    V_PRC_STS, -- JV HEADER SEQ WILL BE USED FOR DTL INSERTION ONLY
                    I.BRNCH_SEQ,                                 -- BRANCH SEQ
                    P_USER,                          -- CURRENT LOGGED IN USER
                    V_PRC_STS);
            */
            V_AMT := V_AMT - I.REC;
        -- DEBIT GL ACCOUNT
        --                IF P_DIFF = 'DEFERED'
        --                THEN
        --                    -- MODIFIED BY ZOHAIB ASIM - 29-03-2021
        --                    -- INSURANCE PLAN : 1243 CONDITION ADDED AS IT IS MARKED IN-ACTIVE
        --                    SELECT HIP.DFRD_ACCT_NUM     GL_ACCT_NUM
        --                      INTO V_DBT_GL_ACCT
        --                      FROM MW_CLNT_HLTH_INSR  CHI
        --                           JOIN MW_HLTH_INSR_PLAN HIP
        --                               ON     HIP.HLTH_INSR_PLAN_SEQ =
        --                                      CHI.HLTH_INSR_PLAN_SEQ
        --                                  AND (   HIP.CRNT_REC_FLG = 1
        --                                       OR (    HIP.HLTH_INSR_PLAN_SEQ = 1243
        --                                           AND HIP.CRNT_REC_FLG = 0))
        --                           JOIN MW_PYMT_SCHED_HDR HDR
        --                               ON     HDR.LOAN_APP_SEQ = CHI.LOAN_APP_SEQ
        --                                  AND HDR.CRNT_REC_FLG = 1
        --                           JOIN MW_PYMT_SCHED_DTL DTL
        --                               ON     DTL.PYMT_SCHED_HDR_SEQ =
        --                                      HDR.PYMT_SCHED_HDR_SEQ
        --                                  AND DTL.CRNT_REC_FLG = 1
        --                     WHERE     CHI.CRNT_REC_FLG = 1
        --                           AND HIP.PLAN_ID != '1223'
        --                           AND DTL.PYMT_SCHED_DTL_SEQ = I.PYMT_SCHED_DTL_SEQ;
        --
        --                END IF;

        END IF;
    END LOOP;
END IF; -----------------POST FLG 
    V_PRC_STS := 'SUCCESS';

    /*IF P_INCDNT_TYP = 'UPFRONT_CASH'
    THEN
        -- GET CLIENT DEATH REPORTED DATE
        BEGIN
            SELECT DR.INCDNT_RPT_SEQ, DR.DT_OF_INCDNT, DR.AMT
              INTO V_DTH_RPT_SEQ, V_DT_OF_DTH, V_AMT_ADJUSTED
              FROM MW_INCDNT_RPT  DR
                   JOIN MW_LOAN_APP LA
                       ON     LA.CLNT_SEQ = DR.CLNT_SEQ
                          AND LA.CRNT_REC_FLG = 1
                          AND LA.LOAN_APP_STS IN (703,1305)
                   JOIN MW_DSBMT_VCHR_HDR DVH
                       ON     DVH.LOAN_APP_SEQ = LA.LOAN_APP_SEQ
                          AND DVH.CRNT_REC_FLG = 1
             WHERE     DR.CLNT_SEQ = P_CLNT
                   AND DR.CRNT_REC_FLG = 1
                   AND TRUNC (DR.DT_OF_INCDNT) >= TRUNC (DVH.DSBMT_DT);

            --
            SELECT FN_CALC_FUNERAL_CHARGES (
                       'REPORT DEATH',
                       P_CLNT,
                       TO_CHAR (V_DT_OF_DTH, 'DD-MM-YYYY)'),
                       P_USER)
              INTO V_FUNERAL_CHARGE_AMT
              FROM DUAL;

            IF V_FUNERAL_CHARGE_AMT = 5000 AND V_AMT_ADJUSTED < 0
            THEN
                UPDATE MW_INCDNT_RPT DR
                   SET DR.AMT = 0,
                       DR.CMNT =
                              DR.CMNT
                           || ' - '
                           || 'DEATH AMOUNT UPDATED TO 0, AFTER COLLECTING '
                           || 'CASH FROM CLIENT OF Rs:'
                           || ABS (V_AMT_ADJUSTED),
                       DR.LAST_UPD_BY = P_USER,
                       DR.LAST_UPD_DT = SYSDATE
                 WHERE     DR.INCDNT_RPT_SEQ = V_DTH_RPT_SEQ
                       AND DR.CRNT_REC_FLG = 1;
            END IF;

            V_PRC_STS := 'SUCCESS';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                V_PRC_STS := 'FAILED';

                V_ERROR_MSG :=
                       ' LINE NO: '
                    || $$PLSQL_LINE
                    || CHR (10)
                    || ' ERROR CODE: '
                    || SQLCODE
                    || ' ERROR MESSAGE: '
                    || SQLERRM
                    || 'TRACE: '
                    || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            WHEN OTHERS
            THEN
                V_PRC_STS := 'FAILED';

                V_ERROR_MSG :=
                       ' LINE NO: '
                    || $$PLSQL_LINE
                    || CHR (10)
                    || ' ERROR CODE: '
                    || SQLCODE
                    || ' ERROR MESSAGE: '
                    || SQLERRM
                    || 'TRACE: '
                    || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        END;
    END IF;
    */

    IF V_PRC_STS != 'SUCCESS'
    THEN
        ROLLBACK;
        V_ERROR_MSG :=
               ' LINE NO: '
            || $$PLSQL_LINE
            || CHR (10)
            || ' ERROR CODE: '
            || SQLCODE
            || ' ERROR MESSAGE: '
            || SQLERRM
            || 'TRACE: '
            || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        KASHF_REPORTING.PRO_LOG_MSG ('ADJUST_CLAIM_PYMT_SCHDL', V_ERROR_MSG);
        RETURN;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND
    THEN
        ROLLBACK;
        V_ERROR_MSG :=
               ' LINE NO: '
            || $$PLSQL_LINE
            || CHR (10)
            || ' ERROR CODE: '
            || SQLCODE
            || ' ERROR MESSAGE: '
            || SQLERRM
            || 'TRACE: '
            || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        KASHF_REPORTING.PRO_LOG_MSG ('ADJUST_CLAIM_PYMT_SCHDL', V_ERROR_MSG);
    WHEN OTHERS
    THEN
        ROLLBACK;
        V_ERROR_MSG :=
               ' LINE NO: '
            || $$PLSQL_LINE
            || CHR (10)
            || ' ERROR CODE: '
            || SQLCODE
            || ' ERROR MESSAGE: '
            || SQLERRM
            || 'TRACE: '
            || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        KASHF_REPORTING.PRO_LOG_MSG ('ADJUST_CLAIM_PYMT_SCHDL', V_ERROR_MSG);
        RAISE;
END;
/