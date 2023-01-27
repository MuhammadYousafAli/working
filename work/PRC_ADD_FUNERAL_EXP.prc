CREATE OR REPLACE PROCEDURE PRC_ADD_FUNERAL_EXP (
    P_CLNT_SEQ           NUMBER, --3520173413482
    P_BRNCH_SEQ          NUMBER,
    P_INST_NUM           VARCHAR2,
    P_FUNERAL_AMT        NUMBER, 
    P_USER_ID            VARCHAR2,
    P_PYMT_TYP_SEQ       NUMBER,
    P_REMARKS            VARCHAR2,
    P_POST_FLG           NUMBER,
    P_INCDNT_DT          VARCHAR2,
    P_PYMT_RCT_FLG       NUMBER,
    P_INCDNT_TYP         VARCHAR2, ---302203
    P_INCDNT_REF         NUMBER,
    P_RTN_MSG        OUT VARCHAR2)
AS
    V_INCDNT_DT        DATE;
    V_FNRL_ALREADY_ENTERED  NUMBER;
    V_INCDNT_TYP       NUMBER;
    V_INCDNT_CTGRY     NUMBER;
    V_INCDNT_EFFECTEE  NUMBER;
    V_FXD_PRMUM        NUMBER;
    V_FXD_PRMUM_AMT    NUMBER;
    V_FUNERAL_AMT_REC  NUMBER;
    V_CLNT_TAG         VARCHAR2 (100);
    V_COUNT            NUMBER := 0;
    V_RCVRY_TRX_SEQ    NUMBER;
    V_NARRATION        VARCHAR2 (200);
    V_EXP_SEQ          NUMBER;
    V_PYMT_STS_KEY     NUMBER;
    V_INCDNT_REF       NUMBER := P_INCDNT_REF;
    V_DBT_GL_ACCT      MW_TYPS.GL_ACCT_NUM%TYPE;
    V_CRT_GL_ACCT      MW_TYPS.GL_ACCT_NUM%TYPE;
    V_AMT              NUMBER := P_FUNERAL_AMT;
    V_CHRG_TYP_KEY     NUMBER;
    V_RCVRY_PYMT_AMT   NUMBER;
    V_CLNT_NM          VARCHAR2 (200);
    V_JV_HDR_DESC      VARCHAR2 (500);
BEGIN
    V_INCDNT_DT := TO_DATE (P_INCDNT_DT, 'DD-MON-RRRR');
    V_INCDNT_DT := '30-NOV-2022';    ------------- P_INCDNT_DT ---------------
    V_INCDNT_REF := 36501021862549401;
    ----------------  TO CHECK IF FUNERAL ADDED ALREADY ---------
    BEGIN
        SELECT COUNT(1)
            INTO V_FNRL_ALREADY_ENTERED
          FROM MW_INCDNT_RPT INC
        WHERE INC.INCDNT_STS IN
               (SELECT VL.REF_CD_SEQ
                  FROM MW_REF_CD_VAL  VL
                       JOIN MW_REF_CD_GRP GRP
                           ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                              AND GRP.CRNT_REC_FLG = 1
                 WHERE GRP.REF_CD_GRP = '0425' AND VL.REF_CD != '0001')
           AND INC.CLNT_SEQ = P_CLNT_SEQ
           AND INC.CRNT_REC_FLG = 1;
           
        IF V_FNRL_ALREADY_ENTERED <> 0
        THEN
            P_RTN_MSG := 'FAILED: FUNERAL IS ADDED ALREADY';
            RETURN;
        END IF;
    END;

    ------------  CHECK FOR NACTA TAGGED -------------------------
    SELECT FN_FIND_CLNT_TAGGED ('AML', P_CLNT_SEQ, NULL)
      INTO V_CLNT_TAG
      FROM DUAL;

    IF V_CLNT_TAG LIKE 'SUCCESS:%'
    THEN
        P_RTN_MSG :=
            'FAILED: NACTA Matched. Client and other individual/s (Nominee/CO borrower/Next of Kin) cannot be Adjusted';
        RETURN;
    END IF;        
    
    BEGIN
        SELECT INC.INCDNT_TYP, INC.INCDNT_CTGRY, INC.INCDNT_EFFECTEE
            INTO V_INCDNT_TYP, V_INCDNT_CTGRY, V_INCDNT_EFFECTEE
          FROM MW_INCDNT_RPT INC
         WHERE     INC.INCDNT_STS =
                   (SELECT VL.REF_CD_SEQ
                      FROM MW_REF_CD_VAL  VL
                           JOIN MW_REF_CD_GRP GRP
                               ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                                  AND GRP.CRNT_REC_FLG = 1
                     WHERE GRP.REF_CD_GRP = '0425' AND VL.REF_CD = '0001')
               AND INC.CLNT_SEQ = P_CLNT_SEQ
               AND INC.CRNT_REC_FLG = 1
               GROUP BY INC.INCDNT_TYP, INC.INCDNT_CTGRY, INC.INCDNT_EFFECTEE;
        
        SELECT STP.FXD_PRMUM, TO_NUMBER(VL.REF_CD_DSCR) FXD_PRMUM_AMT
             INTO V_FXD_PRMUM, V_FXD_PRMUM_AMT
          FROM MW_STP_INCDNT STP
            JOIN MW_REF_CD_VAL VL ON VL.REF_CD_SEQ = STP.FXD_PRMUM AND VL.CRNT_REC_FLG = 1
         WHERE     STP.INCDNT_TYP = V_INCDNT_TYP
               AND STP.INCDNT_CTGRY = V_INCDNT_CTGRY
               AND STP.INCDNT_EFFECTEE = V_INCDNT_EFFECTEE
               AND STP.CRNT_REC_FLG = 1
            GROUP BY STP.FXD_PRMUM, VL.REF_CD_DSCR; 
        
        V_FUNERAL_AMT_REC := ABS(NVL(V_FXD_PRMUM_AMT,0) - NVL(V_AMT,0));
    EXCEPTION
    WHEN OTHERS
    THEN
        ROLLBACK;
        P_RTN_MSG :=
               'PRC_ADD_FUNERAL_EXP ==> ERROR IN GETTING FUNERAL AMOUNT => LINE NO: '
            || $$PLSQL_LINE
            || CHR (10)
            || ' ERROR CODE: '
            || SQLCODE
            || ' ERROR MESSAGE: '
            || SQLERRM
            || 'TRACE: '
            || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        KASHF_REPORTING.PRO_LOG_MSG ('PRC_ADD_FUNERAL_EXP', P_RTN_MSG);
        RETURN;
    END;
    
    IF (V_FUNERAL_AMT_REC = 0 AND P_PYMT_RCT_FLG = 1)
    THEN
        SELECT EXP_SEQ.NEXTVAL INTO V_EXP_SEQ FROM DUAL;
        ---------------  TO ADD EXP ENTRY -----------
        INSERT INTO MW_EXP (EXP_SEQ,
                            EFF_START_DT,
                            BRNCH_SEQ,
                            EXPNS_STS_KEY,
                            EXPNS_ID,
                            EXPNS_DSCR,
                            INSTR_NUM,
                            EXPNS_AMT,
                            EXPNS_TYP_SEQ,
                            CRTD_BY,
                            CRTD_DT,
                            LAST_UPD_BY,
                            LAST_UPD_DT,
                            DEL_FLG,
                            EFF_END_DT,
                            CRNT_REC_FLG,
                            PYMT_TYP_SEQ,
                            POST_FLG,
                            EXP_REF,
                            PYMT_RCT_FLG,
                            EXPNS_SYS_GEN_FLG,
                            RMRKS)
             VALUES (V_EXP_SEQ,
                     SYSDATE,
                     P_BRNCH_SEQ,
                     200,
                     EXP_SEQ.CURRVAL,
                     'FUNERAL CHARGES',
                     P_INST_NUM,
                     V_AMT,
                     424,
                     P_USER_ID,
                     SYSDATE,
                     P_USER_ID,
                     SYSDATE,
                     0,
                     NULL,
                     1,
                     P_PYMT_TYP_SEQ,
                     0,
                     CASE WHEN V_INCDNT_REF != 0 THEN V_INCDNT_REF ELSE P_CLNT_SEQ END,
                     P_PYMT_RCT_FLG,
                     0,
                     P_REMARKS);
                     
        UPDATE MW_INCDNT_RPT INC
       SET INC.INCDNT_STS =
               (SELECT VL.REF_CD_SEQ
                  FROM MW_REF_CD_VAL  VL
                       JOIN MW_REF_CD_GRP GRP
                           ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                              AND GRP.CRNT_REC_FLG = 1
                 WHERE GRP.REF_CD_GRP = '0425' AND VL.REF_CD = '0004'),
           INC.LAST_UPD_DT = SYSDATE,
           INC.LAST_UPD_BY = P_USER_ID
     WHERE     INC.CLNT_SEQ = P_CLNT_SEQ
           AND INC.DT_OF_INCDNT = V_INCDNT_DT
           AND INC.CRNT_REC_FLG = 1;

        P_RTN_MSG := 'SUCCESS';
        RETURN;
    END IF;    
    
    
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
             WHERE     LA.CLNT_SEQ = P_CLNT_SEQ
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
                
                IF P_PYMT_RCT_FLG = 1
                THEN
                    SELECT EXP_SEQ.NEXTVAL INTO V_EXP_SEQ FROM DUAL;
                    ---------------  TO ADD EXP ENTRY -----------
                    INSERT INTO MW_EXP (EXP_SEQ,
                                        EFF_START_DT,
                                        BRNCH_SEQ,
                                        EXPNS_STS_KEY,
                                        EXPNS_ID,
                                        EXPNS_DSCR,
                                        INSTR_NUM,
                                        EXPNS_AMT,
                                        EXPNS_TYP_SEQ,
                                        CRTD_BY,
                                        CRTD_DT,
                                        LAST_UPD_BY,
                                        LAST_UPD_DT,
                                        DEL_FLG,
                                        EFF_END_DT,
                                        CRNT_REC_FLG,
                                        PYMT_TYP_SEQ,
                                        POST_FLG,
                                        EXP_REF,
                                        PYMT_RCT_FLG,
                                        EXPNS_SYS_GEN_FLG,
                                        RMRKS)
                         VALUES (V_EXP_SEQ,
                                 SYSDATE,
                                 P_BRNCH_SEQ,
                                 200,
                                 EXP_SEQ.CURRVAL,
                                 'FUNERAL CHARGES',
                                 P_INST_NUM,
                                 V_AMT,
                                 424,
                                 P_USER_ID,
                                 SYSDATE,
                                 P_USER_ID,
                                 SYSDATE,
                                 0,
                                 NULL,
                                 1,
                                 P_PYMT_TYP_SEQ,
                                 0,
                                 CASE WHEN V_INCDNT_REF != 0 THEN V_INCDNT_REF ELSE P_CLNT_SEQ END,
                                 P_PYMT_RCT_FLG,
                                 0,
                                 P_REMARKS);
                END IF;

                SELECT RCVRY_TRX_SEQ.NEXTVAL INTO V_RCVRY_TRX_SEQ FROM DUAL;

                
                IF P_INCDNT_TYP = 'DISABILITY'
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
                ELSE 
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
                             V_FUNERAL_AMT_REC,
                             CASE
                                 WHEN P_INCDNT_TYP = 'DEATH' THEN 750
                                 ELSE 161
                             END,
                             NULL,
                             1001,    -- TO IDENTIFY INCIDENT CASES
                             P_USER_ID,
                             SYSDATE,
                             P_USER_ID,
                             SYSDATE,
                             0,
                             SYSDATE,
                             1,
                             TO_CHAR (I.CLNT_SEQ),
                             0,
                             NULL,
                             CASE
                                 WHEN V_EXP_SEQ IS NOT NULL
                                 THEN
                                     'EXP_SEQ:' || V_EXP_SEQ
                                 ELSE
                                     V_NARRATION
                             END);

                V_COUNT := 1;
            END IF;                                      --------  V_COUNT = 0

            IF P_INCDNT_TYP = 'UPFRONT_CASH'
            THEN                        -- ZOHAIB ASIM - DATED 28-09-22 - KSWK
                --
                IF I.REC >= V_FUNERAL_AMT_REC
                THEN
                    V_RCVRY_PYMT_AMT := V_FUNERAL_AMT_REC;
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
                             P_USER_ID,
                             SYSDATE,
                             P_USER_ID,
                             SYSDATE,
                             0,
                             NULL,
                             1,
                             I.PYMT_SCHED_DTL_SEQ);
            ELSE             --------  ELSE PART P_INCDNT_TYP = 'UPFRONT_CASH'
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
                             P_USER_ID,
                             SYSDATE,
                             P_USER_ID,
                             SYSDATE,
                             0,
                             NULL,
                             1,
                             I.PYMT_SCHED_DTL_SEQ);
            END IF;                          ----P_INCDNT_TYP = 'UPFRONT_CASH'

            UPDATE MW_PYMT_SCHED_DTL PSD
               SET PSD.PYMT_STS_KEY = V_PYMT_STS_KEY
             WHERE PSD.PYMT_SCHED_DTL_SEQ = I.PYMT_SCHED_DTL_SEQ
             AND PSD.CRNT_REC_FLG = 1;

            V_FUNERAL_AMT_REC := V_FUNERAL_AMT_REC - I.REC;
        END IF;
    END LOOP;

    UPDATE MW_INCDNT_RPT INC
       SET INC.INCDNT_STS =
               (SELECT VL.REF_CD_SEQ
                  FROM MW_REF_CD_VAL  VL
                       JOIN MW_REF_CD_GRP GRP
                           ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                              AND GRP.CRNT_REC_FLG = 1
                 WHERE GRP.REF_CD_GRP = '0425' AND VL.REF_CD = '0004'),
           INC.LAST_UPD_DT = SYSDATE,
           INC.LAST_UPD_BY = P_USER_ID
     WHERE     INC.CLNT_SEQ = P_CLNT_SEQ
           AND INC.DT_OF_INCDNT = V_INCDNT_DT
           AND INC.CRNT_REC_FLG = 1;

    P_RTN_MSG := 'SUCCESS';
EXCEPTION
    WHEN OTHERS
    THEN
        ROLLBACK;
        P_RTN_MSG :=
               'PRC_ADD_FUNERAL_EXP ==> GENERIC ISSUE => LINE NO: '
            || $$PLSQL_LINE
            || CHR (10)
            || ' ERROR CODE: '
            || SQLCODE
            || ' ERROR MESSAGE: '
            || SQLERRM
            || 'TRACE: '
            || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        KASHF_REPORTING.PRO_LOG_MSG ('PRC_ADD_FUNERAL_EXP', P_RTN_MSG);
        RETURN;       
END;