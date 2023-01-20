CREATE OR REPLACE PROCEDURE ADJUST_CLAIM_PYMT_SCHDL (P_AMT          NUMBER,
                                                     P_CLNT         NUMBER,
                                                     P_EXPNS_SEQ    NUMBER,
                                                     P_DIFF         VARCHAR2,
                                                     P_USER         VARCHAR2,
                                                     P_INCDNT_TYP   VARCHAR2)
AS
    --
    V_ACTV_FLG             NUMBER := 1;
    V_INACTV_FLG           NUMBER := 0;
    V_ACTV_LOAN_APP_STS    MW_LOAN_APP.LOAN_APP_STS%TYPE := 703;
    --
    V_COUNT                NUMBER := 0;
    V_RCVRY_TRX_SEQ        NUMBER := 0;
    V_AMT                  NUMBER := P_AMT;
    V_HDR_SEQ              NUMBER := 0;
    V_JV_HDR_DESC          VARCHAR2 (500);
    V_RCVRY_PYMT_AMT       NUMBER := 0;

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
                                 AND MRT.CRNT_REC_FLG = V_ACTV_FLG
                                 AND MRT.PYMT_REF = LA.CLNT_SEQ
                                 AND MRD.PYMT_SCHED_DTL_SEQ =
                                     PSD.PYMT_SCHED_DTL_SEQ
                                 AND MRD.CRNT_REC_FLG = V_ACTV_FLG
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
                   AND LA.CRNT_REC_FLG = V_ACTV_FLG
                   AND LA.LOAN_APP_STS = V_ACTV_LOAN_APP_STS
                   AND LA.PORT_SEQ = MP.PORT_SEQ
                   AND MP.CRNT_REC_FLG = V_ACTV_FLG
                   AND PRD.PRD_SEQ = LA.PRD_SEQ
                   AND PRD.CRNT_REC_FLG = V_ACTV_FLG
                   AND LA.LOAN_APP_SEQ = PSH.LOAN_APP_SEQ
                   AND PSH.CRNT_REC_FLG = V_ACTV_FLG
                   AND PSH.PYMT_SCHED_HDR_SEQ = PSD.PYMT_SCHED_HDR_SEQ
                   AND PSD.CRNT_REC_FLG = V_ACTV_FLG
                   AND PSD.PYMT_SCHED_DTL_SEQ = PSC.PYMT_SCHED_DTL_SEQ(+)
                   AND PSC.CHRG_TYPS_SEQ IN
                           (  SELECT PSC1.CHRG_TYPS_SEQ
                                FROM MW_PYMT_SCHED_CHRG PSC1
                               WHERE     PSC1.PYMT_SCHED_DTL_SEQ =
                                         PSD.PYMT_SCHED_DTL_SEQ
                                     AND PSC.CRNT_REC_FLG = V_ACTV_FLG
                            GROUP BY PSC1.CHRG_TYPS_SEQ)
                   AND PSC.CRNT_REC_FLG = V_ACTV_FLG)
    LOOP
        DBMS_OUTPUT.PUT_LINE (
            'ADJUST_CLAIM -> : (SELECT)CHRGE_AMT - RCVRY_AMT: ' || I.REC);
        DBMS_OUTPUT.PUT_LINE ('ADJUST_CLAIM -> : PARAMETER AMT: ' || V_AMT);

        IF (I.REC > 0 AND V_AMT > 0)
        THEN
            IF V_COUNT = 0
            THEN
                SELECT RCVRY_TRX_SEQ.NEXTVAL INTO V_RCVRY_TRX_SEQ FROM DUAL;

                --SELECT JV_HDR_SEQ.NEXTVAL INTO V_HDR_SEQ FROM DUAL;

                DBMS_OUTPUT.PUT_LINE (
                    'ADJUST_CLAIM -> RCVRY TRX SEQ: ' || V_RCVRY_TRX_SEQ);

                IF P_INCDNT_TYP = 'DEATH'
                THEN
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
                         VALUES (V_RCVRY_TRX_SEQ,
                                 SYSDATE,
                                 'CASH FUNERAL ADJUSTMENT',
                                 TO_DATE (SYSDATE),
                                 V_AMT,
                                 750,
                                 NULL,
                                 0,
                                 P_USER,
                                 SYSDATE,
                                 P_USER,
                                 SYSDATE,
                                 0,
                                 SYSDATE,
                                 V_ACTV_FLG,
                                 TO_CHAR (I.CLNT_SEQ),
                                 1,
                                 NULL,
                                 'EXP_SEQ:' || P_EXPNS_SEQ);
                ELSIF P_INCDNT_TYP = 'DISABILITY'           -- Added by Areeba
                THEN
                    SELECT TYP_SEQ
                      INTO V_RCVRY_TYP_SEQ
                      FROM MW_TYPS
                     WHERE     TYP_ID = '0001'
                           AND CRNT_REC_FLG = V_ACTV_FLG
                           AND TYP_CTGRY_KEY = 4;

                    INSERT INTO MW_RCVRY_TRX (RCVRY_TRX_SEQ,
                                              EFF_START_DT,
                                              INSTR_NUM,
                                              PYMT_DT,
                                              PYMT_AMT,
                                              RCVRY_TYP_SEQ,   --cash 124 hard
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
                         VALUES (V_RCVRY_TRX_SEQ,
                                 SYSDATE,
                                 'CASH DISABILITY ADJUSTMENT',
                                 TO_DATE (SYSDATE),
                                 V_AMT,
                                 V_RCVRY_TYP_SEQ,
                                 NULL,
                                 0,
                                 P_USER,
                                 SYSDATE,
                                 P_USER,
                                 SYSDATE,
                                 0,
                                 SYSDATE,
                                 V_ACTV_FLG,
                                 TO_CHAR (I.CLNT_SEQ),
                                 1,
                                 NULL,
                                 NULL);
                ELSIF P_INCDNT_TYP = 'UPFRONT_CASH' -- ZOHAIB ASIM - DATED 28-09-22 - KSWK
                THEN
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
                         VALUES (V_RCVRY_TRX_SEQ,
                                 SYSDATE,
                                 'CASH UP-FRONT ADJUSTMENT',
                                 TO_DATE (SYSDATE),
                                 V_AMT,
                                 161,
                                 NULL,
                                 0,
                                 P_USER,
                                 SYSDATE,
                                 P_USER,
                                 SYSDATE,
                                 0,
                                 SYSDATE,
                                 V_ACTV_FLG,
                                 TO_CHAR (I.CLNT_SEQ),
                                 1,
                                 NULL,
                                 'CASH UP-FRONT ADJUSTMENT');
                END IF;

                --Added by Areeba
                IF P_INCDNT_TYP = 'DISABILITY'
                THEN
                    SELECT CLNT.FRST_NM || ' ' || CLNT.LAST_NM
                      INTO V_CLNT_NM
                      FROM MW_CLNT CLNT
                     WHERE     CLNT.CLNT_SEQ = P_CLNT
                           AND CLNT.CRNT_REC_FLG = V_ACTV_FLG;

                    SELECT TY.TYP_STR
                      INTO V_PYMT_TYP_STR
                      FROM MW_TYPS  TY
                           JOIN MW_EXP EX
                               ON     EX.PYMT_TYP_SEQ = TY.TYP_SEQ
                                  AND EX.CRNT_REC_FLG = V_ACTV_FLG
                     WHERE TY.CRNT_REC_FLG = 1 AND EX.EXP_SEQ = P_EXPNS_SEQ;

                    V_JV_HDR_DESC :=
                           'Disability Receivable is collected from Client '
                        || V_CLNT_NM
                        || ' through '
                        || V_PYMT_TYP_STR;
                ELSIF P_DIFF = 'DEFERED' AND P_INCDNT_TYP = 'DEATH'
                THEN
                    V_JV_HDR_DESC :=
                        'Reversal of KC premium due to client death';
                ELSIF P_DIFF = 'DEFERED' AND P_INCDNT_TYP = 'DISABILITY' -- Added by Areeba
                THEN
                    V_JV_HDR_DESC :=
                        'Reversal of KC premium due to client disability';
                ELSIF P_INCDNT_TYP = 'UPFRONT_CASH' -- ZOHAIB ASIM - DATED 28-09-22 - KSWK
                THEN
                    V_JV_HDR_DESC :=
                           'Funeral charges paid to client '
                        || V_CLNT_NM
                        || ' through bank/cash';
                ELSE
                    V_JV_HDR_DESC := 'Recovery';
                END IF;

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
                        V_PRC_STS);

                DBMS_OUTPUT.PUT_LINE ('Recovery - HDR: ' || V_PRC_STS);

                V_COUNT := 1;
            END IF;

            DBMS_OUTPUT.PUT_LINE (
                   'ADJUST_CLAIM -> REC_AMT <= PARM_AMT: '
                || I.REC
                || '<='
                || V_AMT);

            -- IN CASE DUE AMOUNT IS LESS THEN AVAILABLE ADJUSTMENT AMOUNT
            IF (I.REC <= V_AMT OR I.REC >= V_AMT)
            THEN
                IF P_INCDNT_TYP = 'UPFRONT_CASH'
                THEN                    -- ZOHAIB ASIM - DATED 28-09-22 - KSWK
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
                                 V_ACTV_FLG,
                                 I.PYMT_SCHED_DTL_SEQ);
                ELSE
                    V_RCVRY_PYMT_AMT := I.REC;

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
                                 I.CHRG_TYPS_SEQ,
                                 V_RCVRY_PYMT_AMT,
                                 P_USER,
                                 SYSDATE,
                                 P_USER,
                                 SYSDATE,
                                 0,
                                 NULL,
                                 V_ACTV_FLG,
                                 I.PYMT_SCHED_DTL_SEQ);
                END IF;



                DBMS_OUTPUT.PUT_LINE (
                       'ADJUST_CLAIM -> REC_AMT <= PARM_AMT -> RECOVERY DTL: '
                    || I.PYMT_SCHED_DTL_SEQ);

                IF P_INCDNT_TYP = 'DEATH'
                THEN
                    UPDATE MW_PYMT_SCHED_DTL PSD
                       SET PSD.PYMT_STS_KEY =
                               (SELECT REF_CD_SEQ
                                  FROM MW_REF_CD_VAL VL
                                 WHERE     VL.REF_CD_GRP_KEY = 179
                                       AND VL.REF_CD = '1500'
                                       AND VL.CRNT_REC_FLG = V_ACTV_FLG)
                     WHERE PSD.PYMT_SCHED_DTL_SEQ = I.PYMT_SCHED_DTL_SEQ;
                ELSIF P_INCDNT_TYP = 'DISABILITY'           -- Added by Areeba
                THEN
                    UPDATE MW_PYMT_SCHED_DTL PSD
                       SET PSD.PYMT_STS_KEY =
                               (SELECT REF_CD_SEQ
                                  FROM MW_REF_CD_VAL VL
                                 WHERE     VL.REF_CD_GRP_KEY = 179
                                       AND VL.REF_CD = '0951'
                                       AND VL.CRNT_REC_FLG = V_ACTV_FLG)
                     WHERE PSD.PYMT_SCHED_DTL_SEQ = I.PYMT_SCHED_DTL_SEQ;
                ELSIF P_INCDNT_TYP = 'UPFRONT_CASH'
                THEN
                    UPDATE MW_PYMT_SCHED_DTL PSD
                       SET PSD.PYMT_STS_KEY =
                               (SELECT REF_CD_SEQ
                                  FROM MW_REF_CD_VAL VL
                                 WHERE     VL.REF_CD_GRP_KEY = 179
                                       AND VL.REF_CD = '2140'
                                       AND VL.CRNT_REC_FLG = V_ACTV_FLG)
                     WHERE PSD.PYMT_SCHED_DTL_SEQ = I.PYMT_SCHED_DTL_SEQ;
                END IF;

                DBMS_OUTPUT.PUT_LINE (
                       'ADJUST_CLAIM -> REC_AMT <= PARM_AMT -> UPDATE PYMT_SCHED_DTL: '
                    || I.PYMT_SCHED_DTL_SEQ);

                /*  MODIFIED BY ZOHAIB ASIM - DATED 13-01-2020
                    GENERIC INTEGRATION FOR JV INSERTION
                */

                DBMS_OUTPUT.PUT_LINE (
                       'I.CHRG_TYPS_SEQ:'
                    || I.CHRG_TYPS_SEQ
                    || ', I.PYMT_SCHED_DTL_SEQ:'
                    || I.PYMT_SCHED_DTL_SEQ
                    || ', I.CHRG_TYPS_SEQ: '
                    || I.CHRG_TYPS_SEQ);

                -- CREDIT GL ACCOUNT
                SELECT (CASE
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
                                               AND HDR.CRNT_REC_FLG =
                                                   V_ACTV_FLG
                                        JOIN MW_PYMT_SCHED_DTL DTL
                                            ON     DTL.PYMT_SCHED_HDR_SEQ =
                                                   HDR.PYMT_SCHED_HDR_SEQ
                                               AND DTL.CRNT_REC_FLG =
                                                   V_ACTV_FLG
                                  WHERE     CHI.CRNT_REC_FLG = V_ACTV_FLG
                                        AND HIP.PLAN_ID != '1223'
                                        AND DTL.PYMT_SCHED_DTL_SEQ =
                                            I.PYMT_SCHED_DTL_SEQ)
                            ELSE
                                (SELECT GL_ACCT_NUM
                                   FROM MW_TYPS MT
                                  WHERE     MT.TYP_CTGRY_KEY = 1
                                        AND MT.CRNT_REC_FLG = V_ACTV_FLG
                                        AND MT.DEL_FLG = 0
                                        AND MT.TYP_SEQ = I.CHRG_TYPS_SEQ)
                        END)
                  INTO V_CRD_GL_ACCT
                  FROM DUAL;

                DBMS_OUTPUT.PUT_LINE (
                       'ADJUST_CLAIM -> REC_AMT <= PARM_AMT -> CREDIT-GL A/C: '
                    || V_CRD_GL_ACCT);

                -- DEBIT GL ACCOUNT
                IF P_DIFF = 'DEFERED'
                THEN
                    -- MODIFIED BY ZOHAIB ASIM - 29-03-2021
                    -- INSURANCE PLAN : 1243 CONDITION ADDED AS IT IS MARKED IN-ACTIVE
                    SELECT HIP.DFRD_ACCT_NUM     GL_ACCT_NUM
                      INTO V_DBT_GL_ACCT
                      FROM MW_CLNT_HLTH_INSR  CHI
                           JOIN MW_HLTH_INSR_PLAN HIP
                               ON     HIP.HLTH_INSR_PLAN_SEQ =
                                      CHI.HLTH_INSR_PLAN_SEQ
                                  AND (   HIP.CRNT_REC_FLG = V_ACTV_FLG
                                       OR (    HIP.HLTH_INSR_PLAN_SEQ = 1243
                                           AND HIP.CRNT_REC_FLG = 0))
                           JOIN MW_PYMT_SCHED_HDR HDR
                               ON     HDR.LOAN_APP_SEQ = CHI.LOAN_APP_SEQ
                                  AND HDR.CRNT_REC_FLG = V_ACTV_FLG
                           JOIN MW_PYMT_SCHED_DTL DTL
                               ON     DTL.PYMT_SCHED_HDR_SEQ =
                                      HDR.PYMT_SCHED_HDR_SEQ
                                  AND DTL.CRNT_REC_FLG = V_ACTV_FLG
                     WHERE     CHI.CRNT_REC_FLG = V_ACTV_FLG
                           AND HIP.PLAN_ID != '1223'
                           AND DTL.PYMT_SCHED_DTL_SEQ = I.PYMT_SCHED_DTL_SEQ;
                ELSE
                    IF P_INCDNT_TYP = 'DEATH'
                    THEN
                        SELECT GL_ACCT_NUM
                          INTO V_DBT_GL_ACCT
                          FROM MW_TYPS MT
                         WHERE     MT.TYP_ID = '0424'
                               AND MT.TYP_CTGRY_KEY = 2
                               AND MT.CRNT_REC_FLG = V_ACTV_FLG
                               AND MT.DEL_FLG = 0;
                    ELSIF P_INCDNT_TYP = 'DISABILITY'       -- Added by Areeba
                    THEN
                        SELECT GL_ACCT_NUM
                          INTO V_DBT_GL_ACCT
                          FROM MW_TYPS MT
                         WHERE     MT.TYP_ID = '0423'
                               AND MT.TYP_CTGRY_KEY = 2
                               AND MT.CRNT_REC_FLG = V_ACTV_FLG
                               AND MT.DEL_FLG = 0;
                    ELSIF P_INCDNT_TYP = 'UPFRONT_CASH' -- ZOHAIB ASIM - DATED 28-09-22 - KSWK
                    THEN
                        SELECT GL_ACCT_NUM
                          INTO V_DBT_GL_ACCT
                          FROM MW_TYPS MT
                         WHERE     MT.TYP_ID = '0001'
                               AND MT.TYP_CTGRY_KEY = 4
                               AND MT.CRNT_REC_FLG = V_ACTV_FLG
                               AND MT.DEL_FLG = 0;
                    END IF;
                END IF;

                DBMS_OUTPUT.PUT_LINE (
                       'ADJUST_CLAIM -> REC_AMT <= PARM_AMT -> DEBIT-GL A/C: '
                    || V_DBT_GL_ACCT);

                --
                --                DBMS_OUTPUT.PUT_LINE (
                --                       'ADJUST_CLAIM -> REC_AMT <= PARM_AMT -> PRC-STS: '
                --                    || V_PRC_STS);

                IF V_PRC_STS IS NOT NULL AND V_PRC_STS > 0
                THEN
                    PRC_JV ('DTL',        -- INSERTION TYPE: HDR/DTL, HDR, DTL
                            0,                     -- EXPENSE/RECOVERY/ANY SEQ
                            V_RCVRY_PYMT_AMT,                        -- AMOUNT
                            '',                              -- JV DESCRIPTION
                            '',                                  -- ENTRY TYPE
                            V_CRD_GL_ACCT,                -- CREDIT GL ACCOUNT
                            V_DBT_GL_ACCT,                 -- DEBIT GL ACCOUNT
                            V_PRC_STS, -- JV HEADER SEQ WILL BE USED FOR DTL INSERTION ONLY
                            I.BRNCH_SEQ,                         -- BRANCH SEQ
                            P_USER,                  -- CURRENT LOGGED IN USER
                            V_PRC_STS);
                END IF;

                DBMS_OUTPUT.PUT_LINE ('Recovery - DTL: ' || V_PRC_STS);
            END IF;

            V_AMT := V_AMT - I.REC;
        END IF;
    END LOOP;

    V_PRC_STS := 'SUCCESS';

    --
    IF P_INCDNT_TYP = 'UPFRONT_CASH'
    THEN
        -- GET CLIENT DEATH REPORTED DATE
        BEGIN
            SELECT DR.INCDNT_RPT_SEQ, DR.DT_OF_INCDNT, DR.AMT
              INTO V_DTH_RPT_SEQ, V_DT_OF_DTH, V_AMT_ADJUSTED
              FROM MW_INCDNT_RPT  DR
                   JOIN MW_LOAN_APP LA
                       ON     LA.CLNT_SEQ = DR.CLNT_SEQ
                          AND LA.CRNT_REC_FLG = V_ACTV_FLG
                          AND LA.LOAN_APP_STS = V_ACTV_LOAN_APP_STS
                   JOIN MW_DSBMT_VCHR_HDR DVH
                       ON     DVH.LOAN_APP_SEQ = LA.LOAN_APP_SEQ
                          AND DVH.CRNT_REC_FLG = V_ACTV_FLG
             WHERE     DR.CLNT_SEQ = P_CLNT
                   AND DR.CRNT_REC_FLG = V_ACTV_FLG
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
                       AND DR.CRNT_REC_FLG = V_ACTV_FLG;
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

    UPDATE MW_INCDNT_RPT RPT
       SET RPT.INCDNT_STS =
               (SELECT REF_CD_SEQ
                  FROM MW_REF_CD_VAL  VL
                       JOIN MW_REF_CD_GRP GRP
                           ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                              AND GRP.CRNT_REC_FLG = 1
                 WHERE     VL.CRNT_REC_FLG = 1
                       AND GRP.REF_CD_GRP = 425
                       AND VL.REF_CD = '0004')
     WHERE     RPT.CLNT_SEQ = P_CLNT
           AND RPT.CRNT_REC_FLG = 1
           AND RPT.INCDNT_STS =
               (SELECT REF_CD_SEQ
                  FROM MW_REF_CD_VAL  VL
                       JOIN MW_REF_CD_GRP GRP
                           ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                              AND GRP.CRNT_REC_FLG = 1
                 WHERE     VL.CRNT_REC_FLG = 1
                       AND GRP.REF_CD_GRP = 425
                       AND VL.REF_CD = '0001');
    --
    IF V_PRC_STS = 'SUCCESS'
    THEN
        COMMIT;
    ELSE
        ROLLBACK;
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