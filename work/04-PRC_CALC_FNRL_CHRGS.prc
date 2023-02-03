CREATE OR REPLACE PROCEDURE PRC_CALC_FNRL_CHRGS (
    P_CLNT_SEQ                NUMBER,
    P_INCDNT_DT               DATE,
    P_USER_ID                 VARCHAR2,
    P_INCDNT_CHRG             VARCHAR2,
    P_INCDNT_CHRGCD           NUMBER,
    P_DED_SM_MNTH              NUMBER,
    P_DED_BASE                NUMBER,
    P_DED_APPLD_ON             NUMBER,
    P_INC_PRIMUM_AMT           NUMBER,
    P_INCDNT_RTN_MSG_CALC   OUT VARCHAR2,
    V_DED_AMT OUT NUMBER)
AS
    V_LOAN_INST                NUMBER;
    V_TOT_CHRG_PD_AMT            NUMBER := 0;
    V_INST_NO_PAID              NUMBER := 0;
    P_BUCKET                  NUMBER := 0;
    V_INST_NO_DED               NUMBER := 0;
    V_INCDNT_RTN_MSG_DEFF        VARCHAR2 (500);
    V_TOT_CHRGS_TO_BE_DEDUCT      NUMBER := 0;
    V_TOT_CHRGS_TO_BE_DEDUCTSUM   NUMBER := 0;
    V_TOT_CHRGS_TO_BE_DEDUCTSUMTOT NUMBER := 0;
    
    V_SM_MNTH_CHRGS             NUMBER := 0;
    V_SM_MNTH_SCHED_DTL_SEQ       MW_PYMT_SCHED_DTL.PYMT_SCHED_DTL_SEQ%TYPE;
    V_MX_INST_NUMBER            NUMBER := 0;
    
BEGIN
    FOR RNK
        IN (  SELECT LA.LOAN_APP_SEQ,
                     LA.PRD_SEQ,
                     RANK ()
                         OVER (
                             PARTITION BY CLNT_SEQ
                             ORDER BY
                                 TO_NUMBER (
                                     TO_CHAR (LA.EFF_START_DT, 'RRRRMMDD')))
                         RANK
                FROM MW_LOAN_APP LA
               WHERE     LA.CLNT_SEQ = P_CLNT_SEQ
                     AND LA.CRNT_REC_FLG = 1
                     AND LA.LOAN_APP_STS = 703
                     AND LA.LOAN_APP_SEQ = LA.PRNT_LOAN_APP_SEQ
            ORDER BY TO_NUMBER (TO_CHAR (LA.EFF_START_DT, 'RRRRMMDD')))
    LOOP
        V_LOAN_INST := 0;
        V_TOT_CHRGS_TO_BE_DEDUCT := 0;
        V_TOT_CHRGS_TO_BE_DEDUCTSUM := 0;
        V_SM_MNTH_CHRGS := 0;

        IF RNK.RANK = 1
        THEN           
            ---- =============  Same month Charges ======--------
            BEGIN
                SELECT NVL(SUM (NVL (DUE, 0)) - SUM (NVL (REC, 0)),0) CHRGS,
                   LISTAGG (PYMT_SCHED_DTL_SEQ, ', ') WITHIN GROUP (ORDER BY PYMT_SCHED_DTL_SEQ) SCHD_DTL,
                   MAX (INST_NUM) V_MAX_INST_NUMBER
                 INTO V_SM_MNTH_CHRGS, V_SM_MNTH_SCHED_DTL_SEQ, V_MX_INST_NUMBER -- CURRENT MONTH REMAINING CHARGES
              FROM (SELECT PSC.AMT DUE,
                       NVL (
                           (SELECT SUM (
                                       NVL (RD.PYMT_AMT,
                                            0))
                              FROM MW_RCVRY_DTL RD
                             WHERE     RD.PYMT_SCHED_DTL_SEQ =
                                       PSD.PYMT_SCHED_DTL_SEQ
                                   AND RD.CHRG_TYP_KEY = P_INCDNT_CHRGCD -------  FOR KC AND KSZB AND VAHECLE LOAN
                                   AND RD.CRNT_REC_FLG = 1),
                           0)
                           REC,
                       PSD.PYMT_SCHED_DTL_SEQ,
                       PSD.INST_NUM
                  FROM MW_PYMT_SCHED_HDR  PSH
                       JOIN MW_PYMT_SCHED_DTL PSD
                           ON     PSD.PYMT_SCHED_HDR_SEQ = PSH.PYMT_SCHED_HDR_SEQ
                              AND PSD.CRNT_REC_FLG = 1
                       JOIN MW_PYMT_SCHED_CHRG PSC
                           ON     PSC.PYMT_SCHED_DTL_SEQ = PSD.PYMT_SCHED_DTL_SEQ
                              AND PSC.CRNT_REC_FLG = 1
                 WHERE     PSH.LOAN_APP_SEQ = RNK.LOAN_APP_SEQ
                       AND TO_NUMBER (
                               TO_CHAR (PSD.DUE_DT,
                                        'RRRRMM')) =
                           TO_NUMBER (
                               TO_CHAR (
                                   TO_DATE (P_INCDNT_DT,
                                            'DD-MM-RRRR'),
                                   'RRRRMM'))
                       AND PSH.CRNT_REC_FLG = 1
                       AND PSC.CHRG_TYPS_SEQ = P_INCDNT_CHRGCD);
            EXCEPTION WHEN OTHERS
            THEN
                V_SM_MNTH_CHRGS := 0;
                V_SM_MNTH_SCHED_DTL_SEQ := NULL;
                V_MX_INST_NUMBER := 0;
            END;
            
            ---- ========================================--------
        
            /*
            P_DED_SM_MNTH = 0  MEANS NO SAME MONTH DEDUCTION
            P_DED_SM_MNTH = 1  MEANS SAME MONTH DEDUCTION
            */
            
           
            
            IF P_DED_SM_MNTH = 1
            THEN
                BEGIN
                    PRC_DEF_CHRGS (V_MX_INST_NUMBER,
                                   RNK.LOAN_APP_SEQ,
                                   P_USER_ID,
                                   V_INCDNT_RTN_MSG_DEFF,
                                   P_INCDNT_CHRGCD); -- CHARGES ABOVE CURRENT TENURE WILL BE DEFFFERED
                EXCEPTION WHEN OTHERS
                THEN
                    NULL;  -----------  pass
                END;
            END IF;
               
            BEGIN
                  SELECT COALESCE (SUM (SUM (NVL (RD.PYMT_AMT, 0))), 0),
                         COALESCE (MAX (MAX (NVL (PSD.INST_NUM, 0))), 0)
                    INTO V_TOT_CHRG_PD_AMT, V_INST_NO_PAID
                    FROM MW_LOAN_APP LA
                         JOIN MW_PYMT_SCHED_HDR PSH
                             ON     LA.LOAN_APP_SEQ = PSH.LOAN_APP_SEQ
                                AND LA.CRNT_REC_FLG = PSH.CRNT_REC_FLG
                         JOIN MW_PYMT_SCHED_DTL PSD
                             ON     PSH.PYMT_SCHED_HDR_SEQ =
                                    PSD.PYMT_SCHED_HDR_SEQ
                                AND PSH.CRNT_REC_FLG = PSD.CRNT_REC_FLG
                         JOIN MW_PYMT_SCHED_CHRG PSC
                             ON     PSD.PYMT_SCHED_DTL_SEQ =
                                    PSC.PYMT_SCHED_DTL_SEQ
                                AND PSD.CRNT_REC_FLG = PSC.CRNT_REC_FLG
                         LEFT OUTER JOIN MW_RCVRY_DTL RD
                             ON     RD.PYMT_SCHED_DTL_SEQ =
                                    PSD.PYMT_SCHED_DTL_SEQ
                                AND RD.CHRG_TYP_KEY = PSC.CHRG_TYPS_SEQ
                                AND RD.CRNT_REC_FLG = PSC.CRNT_REC_FLG
                         LEFT JOIN MW_RCVRY_TRX RT
                             ON     RT.RCVRY_TRX_SEQ = RD.RCVRY_TRX_SEQ
                                AND RT.CRNT_REC_FLG = RD.CRNT_REC_FLG
                   WHERE     LA.LOAN_APP_SEQ = RNK.LOAN_APP_SEQ
                         AND LA.CRNT_REC_FLG = 1
                         AND LA.LOAN_APP_STS = 703
                         AND RD.CHRG_TYP_KEY = P_INCDNT_CHRGCD
                GROUP BY PSC.CHRG_TYPS_SEQ;
            EXCEPTION
                WHEN OTHERS
                THEN                    -------------  NO PAID INSTALLMENT
                    V_TOT_CHRG_PD_AMT := 0;
                    V_INST_NO_PAID := 0;
            END;
            
            /*
            P_DED_BASE = 1  Based on current 12 installments bucket
            P_DED_BASE = 2  Based on current 6 installments bucket
            P_DED_BASE = 3  Based on current 18 installments bucket
            P_DED_BASE = 4  Based on current 24 installments bucket
            P_DED_BASE = 5  Deduct all installment
            */

            IF P_DED_BASE = 1
            THEN
                P_BUCKET := 12;
            ELSIF P_DED_BASE = 2
            THEN
                P_BUCKET := 6;
            ELSIF P_DED_BASE = 3
            THEN
                P_BUCKET := 18;
            ELSIF P_DED_BASE = 4
            THEN
                P_BUCKET := 24;
            ELSIF P_DED_BASE = 5
            THEN
                P_BUCKET := 0;
            END IF;

            IF (P_BUCKET != 0 AND V_INST_NO_PAID != 0)
            THEN
                IF (V_INST_NO_PAID / P_BUCKET) <= 1
                THEN
                    V_INST_NO_DED := P_BUCKET;
                ELSIF (V_INST_NO_PAID / P_BUCKET) <= 2
                THEN
                    V_INST_NO_DED := P_BUCKET * 2;
                ELSIF (V_INST_NO_PAID / P_BUCKET) <= 3
                THEN
                    V_INST_NO_DED := P_BUCKET * 3;
                ELSIF (V_INST_NO_PAID / P_BUCKET) <= 4
                THEN
                    V_INST_NO_DED := P_BUCKET * 4;
                ELSIF (V_INST_NO_PAID / P_BUCKET) <= 5
                THEN
                    V_INST_NO_DED := P_BUCKET * 5;
                ELSIF (V_INST_NO_PAID / P_BUCKET) <= 6
                THEN
                    V_INST_NO_DED := P_BUCKET * 6;
                END IF;
            ELSE
                V_INST_NO_DED := 0;        --------------  DEDUCT ALL CHARGES
            END IF;

            IF V_INST_NO_DED >= 6
            THEN
                BEGIN
                    PRC_DEF_CHRGS (V_INST_NO_DED,
                                   RNK.LOAN_APP_SEQ,
                                   P_USER_ID,
                                   V_INCDNT_RTN_MSG_DEFF,
                                   P_INCDNT_CHRGCD); -- CHARGES ABOVE CURRENT TENURE WILL BE DEFFFERED
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;     -----------  pass
                END;
            END IF;
            
            BEGIN
                SELECT   NVL (SUM (NVL (PSC.AMT, 0)), 0)
                       - NVL (
                             SUM (
                                 (SELECT SUM (NVL (RD.PYMT_AMT, 0))
                                    FROM MW_RCVRY_DTL RD
                                   WHERE     RD.PYMT_SCHED_DTL_SEQ =
                                             PSD.PYMT_SCHED_DTL_SEQ
                                         AND RD.CHRG_TYP_KEY =
                                             P_INCDNT_CHRGCD --------- FOR KC AND KSZB  AND VAHICLE
                                         AND RD.CRNT_REC_FLG = 1)),
                             0)
                           REC
                  INTO V_TOT_CHRGS_TO_BE_DEDUCT ----------   CURRENT BUCKET TOTAL DUE AMOUNT
                  FROM MW_LOAN_APP  LA
                       JOIN MW_PYMT_SCHED_HDR PSH
                           ON     LA.LOAN_APP_SEQ = PSH.LOAN_APP_SEQ
                              AND PSH.CRNT_REC_FLG = 1
                       JOIN MW_PYMT_SCHED_DTL PSD
                           ON     PSH.PYMT_SCHED_HDR_SEQ =
                                  PSD.PYMT_SCHED_HDR_SEQ
                              AND PSD.CRNT_REC_FLG = 1
                       JOIN MW_PYMT_SCHED_CHRG PSC
                           ON     PSD.PYMT_SCHED_DTL_SEQ =
                                  PSC.PYMT_SCHED_DTL_SEQ
                              AND PSC.CRNT_REC_FLG = 1
                              AND PSC.CHRG_TYPS_SEQ = P_INCDNT_CHRGCD --------- FOR KC AND KSZB  AND VAHICLE
                 WHERE     LA.LOAN_APP_SEQ = RNK.LOAN_APP_SEQ
                       AND LA.CRNT_REC_FLG = 1
                       AND LA.LOAN_APP_STS = 703;
            EXCEPTION WHEN OTHERS
            THEN
                V_TOT_CHRGS_TO_BE_DEDUCT := 0;
            END;

            V_TOT_CHRGS_TO_BE_DEDUCTSUM := V_TOT_CHRGS_TO_BE_DEDUCTSUM + NVL(V_TOT_CHRGS_TO_BE_DEDUCT,0);    
            
        ELSE                    -----------  ELSE PART RANK-2 FOR 2ND LOAN
            IF (RNK.PRD_SEQ = 51)
            THEN
                PRC_KTK_KSZB_POLICY_RECEIVABLE_REVERSAL (RNK.LOAN_APP_SEQ,
                                                         P_USER_ID,
                                                         P_INCDNT_RTN_MSG_CALC);

                IF UPPER (P_INCDNT_RTN_MSG_CALC) != 'SUCCESS'
                THEN
                    ROLLBACK;
                        V_TOT_CHRGS_TO_BE_DEDUCTSUMTOT := 0;
                    RETURN;
                END IF;

                PRC_DEF_CHRGS (0,
                               RNK.LOAN_APP_SEQ,
                               P_USER_ID,
                               V_INCDNT_RTN_MSG_DEFF,
                               P_INCDNT_CHRGCD); -- CHARGES ABOVE CURRENT TENURE WILL BE DEFFFERED

                IF UPPER (V_INCDNT_RTN_MSG_DEFF) != 'SUCCESS'
                THEN
                    ROLLBACK;
                         V_TOT_CHRGS_TO_BE_DEDUCTSUMTOT := 0;
                    RETURN;
                END IF;
            ELSE
                PRC_DEF_CHRGS (0,
                               RNK.LOAN_APP_SEQ,
                               P_USER_ID,
                               V_INCDNT_RTN_MSG_DEFF,
                               P_INCDNT_CHRGCD); -- CHARGES ABOVE CURRENT TENURE WILL BE DEFFFERED

                IF UPPER (V_INCDNT_RTN_MSG_DEFF) != 'SUCCESS'
                THEN
                    ROLLBACK;
                        V_TOT_CHRGS_TO_BE_DEDUCTSUMTOT := 0;
                    RETURN;
                END IF;
            END IF;        
        END IF;  ---------  end rnk
        
        V_TOT_CHRGS_TO_BE_DEDUCTSUMTOT := V_TOT_CHRGS_TO_BE_DEDUCTSUMTOT + V_TOT_CHRGS_TO_BE_DEDUCTSUM;
        
    END LOOP;      

P_INCDNT_RTN_MSG_CALC := 'SUCCESS';
V_DED_AMT := V_TOT_CHRGS_TO_BE_DEDUCTSUMTOT;

EXCEPTION
WHEN OTHERS
THEN
    ROLLBACK;
    KASHF_REPORTING.PRO_LOG_MSG (
        'PRC_CALC_FNRL_CHRGS',
           'ISSUE IN PRC_CALC_FNRL_CHRGS:  CLNT==> P_CLNT_SEQ='
        || P_CLNT_SEQ
        || SQLERRM);
    P_INCDNT_RTN_MSG_CALC :=
           'ERROR PRC_CALC_FNRL_CHRGS => ISSUE IN PRC_CALC_FNRL_CHRGS:  CLNT==> P_CLNT_SEQ='
        || P_CLNT_SEQ;
    RETURN;   
END;
/