CREATE OR REPLACE PROCEDURE PRC_INCDNT_RVRSE_RCVRY (
    P_CLNT_SEQ              NUMBER,
    P_INCDNT_DT             DATE,
    P_RCVRY_RVRSL_FLG       NUMBER,
    P_USER_ID               VARCHAR2,
    P_INCDNT_RTN_MSG    OUT VARCHAR2)
AS
    V_BRNCH_SEQ           MW_BRNCH.BRNCH_SEQ%TYPE;
    V_JV_HDR_SEQ          MW_JV_HDR.JV_HDR_SEQ%TYPE;
    V_FOUND               NUMBER;
    V_JV_HDR_SEQ1         MW_JV_HDR.JV_HDR_SEQ%TYPE;
    V_JV_DT               DATE;
    V_JV_DTLSEQ           MW_JV_DTL.JV_DTL_SEQ%TYPE;
    V_RCVRY_TRX_SEQ       MW_RCVRY_TRX.RCVRY_TRX_SEQ%TYPE;
    V_DUE_AMT             NUMBER := 0;
    V_COUNTER             NUMBER := 0;
    V_UNIQUE_NO           NUMBER := NULL;

    V_CRDT_ACCT_HEAD      MW_TYPS.GL_ACCT_NUM%TYPE;
    V_DBT_ACCT_HEAD       MW_TYPS.GL_ACCT_NUM%TYPE;

    P_INCDNT_RTN_JV_MSG   VARCHAR2 (500);
    
    V_RVRSL_JV_FOUND       NUMBER;
    V_RVRSL_RCV_FOUND      NUMBER;
    V_EXCESS_RCV_FOUND     NUMBER;
BEGIN

      SELECT BRNCH_SEQ
        INTO V_BRNCH_SEQ
        FROM MW_LOAN_APP AP
       WHERE     AP.CLNT_SEQ = P_CLNT_SEQ
             AND AP.CRNT_REC_FLG = 1
             AND AP.LOAN_APP_STS = 703
    GROUP BY BRNCH_SEQ;

    FOR REC
        IN (  SELECT RD.RCVRY_CHRG_SEQ,
                     RD.RCVRY_TRX_SEQ,
                     RD.CHRG_TYP_KEY,
                     RD.PYMT_SCHED_DTL_SEQ,
                     RD.PYMT_AMT DTL_AMT,
                     RT.PYMT_AMT
                FROM MW_RCVRY_TRX RT
                     JOIN MW_RCVRY_DTL RD
                         ON     RD.RCVRY_TRX_SEQ = RT.RCVRY_TRX_SEQ
                            AND RD.CRNT_REC_FLG = 1
                     JOIN MW_PYMT_SCHED_DTL PSD
                         ON     PSD.PYMT_SCHED_DTL_SEQ = RD.PYMT_SCHED_DTL_SEQ
                            AND PSD.CRNT_REC_FLG = 1
               WHERE     RT.CRNT_REC_FLG = 1
                     AND RT.PYMT_REF = P_CLNT_SEQ
                     AND RCVRY_TYP_SEQ NOT IN (454,453)
                     AND TRUNC(PSD.DUE_DT) >= CASE WHEN P_RCVRY_RVRSL_FLG = 2 THEN TO_DATE(LAST_DAY(TO_DATE (P_INCDNT_DT))+1) ELSE TO_DATE (P_INCDNT_DT) END ---------  INCIDENT DATE
                     AND TRUNC(RT.PYMT_DT) >= CASE WHEN P_RCVRY_RVRSL_FLG = 2 THEN TO_DATE(LAST_DAY(TO_DATE (P_INCDNT_DT))+1) ELSE TO_DATE (P_INCDNT_DT) END ---------  INCIDENT DATE
            ORDER BY RD.RCVRY_CHRG_SEQ DESC)
    LOOP
        -------------  REVERSE RECOVERY --------------
        IF V_COUNTER = 0
        THEN
            V_UNIQUE_NO := REC.RCVRY_TRX_SEQ;
        END IF;

        UPDATE MW_RCVRY_DTL DTL
           SET DTL.DEL_FLG = 1,
               DTL.CRNT_REC_FLG = 0,
               DTL.LAST_UPD_BY = P_USER_ID,
               DTL.LAST_UPD_DT = SYSDATE
         WHERE     DTL.RCVRY_TRX_SEQ = REC.RCVRY_TRX_SEQ
               AND DTL.CRNT_REC_FLG = 1
               AND DTL.RCVRY_CHRG_SEQ = REC.RCVRY_CHRG_SEQ;

        UPDATE MW_RCVRY_TRX RCH
           SET RCH.DEL_FLG = 1,
               RCH.CRNT_REC_FLG = 0,
               RCH.LAST_UPD_BY = P_USER_ID,
               RCH.LAST_UPD_DT = SYSDATE,
               RCH.CHNG_RSN_CMNT =
                      'REVERSE DUE TO INCIDENT PROCESS DATED: '|| TO_DATE (SYSDATE)||V_UNIQUE_NO
         WHERE RCH.RCVRY_TRX_SEQ = REC.RCVRY_TRX_SEQ AND RCH.CRNT_REC_FLG = 1;


        SELECT   NVL (PSD.PPAL_AMT_DUE, 0)
               + NVL (PSD.TOT_CHRG_DUE, 0)
               + NVL (
                     (  SELECT SUM (PSC.AMT)
                          FROM MW_PYMT_SCHED_CHRG PSC
                         WHERE     PSC.PYMT_SCHED_DTL_SEQ =
                                   PSD.PYMT_SCHED_DTL_SEQ
                               AND PSC.CRNT_REC_FLG = 1
                      GROUP BY PSC.PYMT_SCHED_DTL_SEQ),
                     0)
          INTO V_DUE_AMT
          FROM MW_PYMT_SCHED_DTL PSD
         WHERE     PSD.PYMT_SCHED_DTL_SEQ = REC.PYMT_SCHED_DTL_SEQ
               AND PSD.CRNT_REC_FLG = 1;

        -----------  UPDATE PYMT STS ------------------
        IF V_DUE_AMT <= REC.PYMT_AMT
        THEN
            UPDATE MW_PYMT_SCHED_DTL PSD
               SET PSD.PYMT_STS_KEY = 945,
                   PSD.LAST_UPD_BY = P_USER_ID,
                   PSD.LAST_UPD_DT = SYSDATE
             WHERE     PSD.PYMT_SCHED_DTL_SEQ = REC.PYMT_SCHED_DTL_SEQ
                   AND PSD.CRNT_REC_FLG = 1
                   AND PSD.PYMT_STS_KEY != 945;
        ELSE
            UPDATE MW_PYMT_SCHED_DTL PSD
               SET PSD.PYMT_STS_KEY = 1145,
                   PSD.LAST_UPD_BY = P_USER_ID,
                   PSD.LAST_UPD_DT = SYSDATE
             WHERE     PSD.PYMT_SCHED_DTL_SEQ = REC.PYMT_SCHED_DTL_SEQ
                   AND PSD.CRNT_REC_FLG = 1
                   AND PSD.PYMT_STS_KEY != 1145;
        END IF;
        V_COUNTER := 1;
    END LOOP;

    ---------------  TO ADD REVERSAL AND EXCESS JV's  ---------------
    FOR RCV
        IN (  SELECT TRX.RCVRY_TRX_SEQ, TRX.RCVRY_TYP_SEQ, TRX.PYMT_AMT
                FROM MW_RCVRY_TRX TRX
               WHERE     TRX.CRNT_REC_FLG = 0
                     AND TRUNC (TRX.LAST_UPD_DT) = TO_DATE (SYSDATE)
                     AND TRX.DEL_FLG = 1
                     AND TRX.PYMT_REF = P_CLNT_SEQ
                     AND TRX.CHNG_RSN_CMNT =
                            'REVERSE DUE TO INCIDENT PROCESS DATED: '
                         || TO_DATE (SYSDATE)||V_UNIQUE_NO
            ORDER BY 1 DESC)
    LOOP
        BEGIN
              SELECT COUNT (1), JV_HDR_SEQ, MJH.JV_DT
                INTO V_FOUND, V_JV_HDR_SEQ1, V_JV_DT
                FROM MW_JV_HDR MJH
               WHERE     MJH.ENTY_SEQ = RCV.RCVRY_TRX_SEQ
                     AND UPPER (MJH.ENTY_TYP) = UPPER ('RECOVERY')
                     AND MJH.BRNCH_SEQ = V_BRNCH_SEQ
                     AND MJH.PRNT_VCHR_REF IS NULL
            GROUP BY JV_HDR_SEQ, MJH.JV_DT;
        EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            P_INCDNT_RTN_MSG :=
                   'ERROR PRC_INCDNT_RVRSE_RCVRY => JV NOT FOUND-FOR INCIDENT REVERSAL ==> P_CLNT_SEQ='
                || P_CLNT_SEQ
                ||'  LINE NO: '
                || $$PLSQL_LINE
                ||'--RCVRY_TRX_SEQ'||RCV.RCVRY_TRX_SEQ||'--'
                || SQLERRM;
            KASHF_REPORTING.PRO_LOG_MSG (
                'PRC_INCDNT_RVRSE_RCVRY',
                   P_INCDNT_RTN_MSG);
            RETURN;
        END;
        
        -----------  IF REVERSAL JV CREATED  ----------        
        SELECT COUNT (1)
            INTO V_RVRSL_JV_FOUND
            FROM MW_JV_HDR MJH
           WHERE     MJH.ENTY_SEQ = RCV.RCVRY_TRX_SEQ
                 AND UPPER (MJH.ENTY_TYP) = UPPER ('RECOVERY')
                 AND MJH.BRNCH_SEQ = V_BRNCH_SEQ
                 AND TRUNC (MJH.JV_DT) = TO_DATE (SYSDATE)
                 AND MJH.PRNT_VCHR_REF IS NOT NULL;
                 
        IF V_FOUND = 0
        THEN
            ROLLBACK;
            P_INCDNT_RTN_MSG :=
                   'ERROR PRC_INCDNT_RVRSE_RCVRY => JV NOT FOUND-FOR REVERSAL JV CREATED  ==> P_CLNT_SEQ='
                || P_CLNT_SEQ
                ||'  LINE NO: '
                || $$PLSQL_LINE
                ||'--RCVRY_TRX_SEQ'||RCV.RCVRY_TRX_SEQ||'--'
                || SQLERRM;
            KASHF_REPORTING.PRO_LOG_MSG (
                'PRC_INCDNT_RVRSE_RCVRY',P_INCDNT_RTN_MSG);
            
            RETURN;
        ELSE
            IF V_RVRSL_JV_FOUND = 0 ----- IF REVERSAL JV CREATED ALREADY
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
                               SYSDATE,
                               'REVERSAL ' || JV_DSCR,
                               ENTY_SEQ,
                               ENTY_TYP,
                               P_USER_ID,
                               POST_FLG,
                               RCVRY_TRX_SEQ,
                               BRNCH_SEQ,
                               P_CLNT_SEQ
                          FROM MW_JV_HDR MJH
                         WHERE     MJH.ENTY_SEQ = RCV.RCVRY_TRX_SEQ
                               AND UPPER (MJH.ENTY_TYP) = UPPER ('RECOVERY')
                               AND MJH.BRNCH_SEQ = V_BRNCH_SEQ
                               AND MJH.PRNT_VCHR_REF IS NULL;

                    INSERT INTO MW_JV_DTL (JV_DTL_SEQ,
                                           JV_HDR_SEQ,
                                           CRDT_DBT_FLG,
                                           AMT,
                                           GL_ACCT_NUM,
                                           DSCR,
                                           LN_ITM_NUM)
                        SELECT JV_DTL_SEQ.NEXTVAL,
                               V_JV_HDR_SEQ,
                               CASE WHEN DTL.CRDT_DBT_FLG = 1 THEN 0 ELSE 1 END,
                               AMT,
                               GL_ACCT_NUM,
                               CASE
                                   WHEN DSCR = 'CREDIT' THEN 'DEBIT'
                                   ELSE 'CREDIT'
                               END,
                               LN_ITM_NUM
                          FROM MW_JV_DTL DTL
                         WHERE JV_HDR_SEQ = V_JV_HDR_SEQ1;
                EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;
                     P_INCDNT_RTN_MSG :=
                           'ERROR PRC_INCDNT_RVRSE_RCVRY => ISSUE IN JV CREATION CLNT==> P_CLNT_SEQ='
                        || P_CLNT_SEQ
                        ||'--'
                        || SQLERRM;                        
                    KASHF_REPORTING.PRO_LOG_MSG (
                        'PRC_INCDNT_RVRSE_RCVRY',
                           P_INCDNT_RTN_MSG);
                   
                    RETURN;
                END;
            END IF;
        END IF;

        ------------  CREATE EXCESS RECOVERIES ------------------
        
        -----------  IF  REVERSAL ENTERED----------        
        SELECT COUNT (1)
            INTO V_EXCESS_RCV_FOUND
            FROM MW_RCVRY_TRX TRX
         WHERE     TRX.RCVRY_TRX_SEQ = RCV.RCVRY_TRX_SEQ
               AND TRX.CRNT_REC_FLG = 1
               AND TRUNC (TRX.LAST_UPD_DT) = TO_DATE (SYSDATE)
               AND TRX.DEL_FLG = 0
               AND TRX.CHNG_RSN_CMNT =
                      'EXCESS CREATED DUE TO INCIDENT PROCESS DATED: '
                   || TO_DATE (SYSDATE)
               AND TRX.PYMT_REF = P_CLNT_SEQ;
               
        IF V_EXCESS_RCV_FOUND = 0
        THEN
            BEGIN
                SELECT RCVRY_TRX_SEQ.NEXTVAL INTO V_RCVRY_TRX_SEQ FROM DUAL;

                INSERT INTO MW_RCVRY_TRX
                    SELECT V_RCVRY_TRX_SEQ,
                           SYSDATE,
                           INSTR_NUM,
                           SYSDATE,
                           PYMT_AMT,
                           RCVRY_TYP_SEQ,
                           PYMT_MOD_KEY,
                           PYMT_STS_KEY,
                           P_USER_ID,
                           SYSDATE,
                           P_USER_ID,
                           SYSDATE,
                           0,
                           NULL,
                           1,
                           PYMT_REF,
                           POST_FLG,
                           CHNG_RSN_KEY,
                              'EXCESS CREATED DUE TO INCIDENT PROCESS DATED: '
                           || TO_DATE (SYSDATE),
                           RCVRY_TRX_SEQ,
                           DPST_SLP_DT,
                           PRNT_LOAN_APP_SEQ
                      FROM MW_RCVRY_TRX TRX
                     WHERE     TRX.RCVRY_TRX_SEQ = RCV.RCVRY_TRX_SEQ
                           AND TRX.CRNT_REC_FLG = 0
                           AND TRUNC (TRX.LAST_UPD_DT) = TO_DATE (SYSDATE)
                           AND TRX.DEL_FLG = 1
                           AND TRX.CHNG_RSN_CMNT =
                                  'REVERSE DUE TO INCIDENT PROCESS DATED: '
                               || TO_DATE (SYSDATE)||V_UNIQUE_NO
                           AND TRX.PYMT_REF = P_CLNT_SEQ;

                INSERT INTO MW_RCVRY_DTL
                    SELECT RCVRY_CHRG_SEQ.NEXTVAL,
                           SYSDATE,
                           V_RCVRY_TRX_SEQ,
                           241,
                           PYMT_AMT,
                           P_USER_ID,
                           SYSDATE,
                           P_USER_ID,
                           SYSDATE,
                           0,
                           NULL,
                           1,
                           -1,
                           NULL
                      FROM MW_RCVRY_TRX TRX
                     WHERE     TRX.RCVRY_TRX_SEQ = RCV.RCVRY_TRX_SEQ
                           AND TRX.CRNT_REC_FLG = 0
                           AND TRUNC (TRX.LAST_UPD_DT) = TO_DATE (SYSDATE)
                           AND TRX.DEL_FLG = 1
                           AND TRX.CHNG_RSN_CMNT =
                                  'REVERSE DUE TO INCIDENT PROCESS DATED: '
                               || TO_DATE (SYSDATE)||V_UNIQUE_NO
                           AND TRX.PYMT_REF = P_CLNT_SEQ;


                SELECT GL_ACCT_NUM
                  INTO V_CRDT_ACCT_HEAD
                  FROM MW_TYPS MT
                 WHERE MT.TYP_SEQ = 241 AND MT.CRNT_REC_FLG = 1;

                SELECT GL_ACCT_NUM
                  INTO V_DBT_ACCT_HEAD
                  FROM MW_TYPS MT
                 WHERE MT.TYP_SEQ = RCV.RCVRY_TYP_SEQ AND MT.CRNT_REC_FLG = 1;

                PRC_JV (
                    'HDR/DTL',
                    V_RCVRY_TRX_SEQ,
                    RCV.PYMT_AMT,
                       'EXCESS RECOVERY CREATED DUE TO INCIDENT CLIENT : '
                    || P_CLNT_SEQ,
                    'EXCESS RECOVERY',
                    V_CRDT_ACCT_HEAD,
                    V_DBT_ACCT_HEAD,
                    0,
                    V_BRNCH_SEQ,
                    P_USER_ID,
                    P_INCDNT_RTN_JV_MSG,
                    P_CLNT_SEQ);

                IF P_INCDNT_RTN_JV_MSG LIKE '%EXCEPTION%'
                THEN
                    ROLLBACK;
                    KASHF_REPORTING.PRO_LOG_MSG (
                        'PRC_INCDNT_RVRSE_RCVRY',
                           'JV ISSUE IN EXCESS RECOVERY CREATED DUE TO INCIDENT CLIENT:  CLNT==> P_CLNT_SEQ='
                        || P_CLNT_SEQ
                        || SQLERRM);
                    P_INCDNT_RTN_MSG :=
                           'ERROR PRC_INCDNT_RVRSE_RCVRY => JV ISSUE IN EXCESS RECOVERY CREATED DUE TO INCIDENT CLIENT:  CLNT==> P_CLNT_SEQ='
                        || P_CLNT_SEQ;
                    RETURN;
                END IF;
            
            EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK;
                KASHF_REPORTING.PRO_LOG_MSG (
                    'PRC_INCDNT_RVRSE_RCVRY',
                       'ISSUE IN EXCESS RECOVERY CREATED DUE TO INCIDENT CLIENT:  CLNT==> P_CLNT_SEQ='
                    || P_CLNT_SEQ
                    || SQLERRM);
                P_INCDNT_RTN_MSG :=
                       'ERROR PRC_INCDNT_RVRSE_RCVRY => ISSUE IN EXCESS RECOVERY CREATED DUE TO INCIDENT CLIENT:  CLNT==> P_CLNT_SEQ='
                    || P_CLNT_SEQ;
                RETURN;
            END;
        END IF; -----------  V_EXCESS_RCV_FOUND---------------------  END EXCESS RECOVERIES  ------------------------------
    END LOOP;

    P_INCDNT_RTN_MSG := 'SUCCESS';
EXCEPTION
    WHEN OTHERS
    THEN
        ROLLBACK;
        P_INCDNT_RTN_MSG :=
              'ISSUE IN RECOVERY REVERSAL: LINE NO: '
            || $$PLSQL_LINE
            || CHR (10)
            ||' P_CLNT_SEQ='
            || P_CLNT_SEQ
            || SQLERRM
            || 'TRACE: '
            || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        KASHF_REPORTING.PRO_LOG_MSG ('PRC_INCDNT_RVRSE_RCVRY',P_INCDNT_RTN_MSG);
        
        RETURN;
END;
/