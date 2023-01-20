CREATE OR REPLACE PROCEDURE PRC_INCDNT_RCVRY_ADJSTMNT (
    P_CLNT_SEQ            NUMBER,
    P_CLNT_NM             VARCHAR2,
    P_ADJSTMNT_AMT        NUMBER,
    P_USER_ID             VARCHAR2,
    P_MSG_RCVRY_ADJ   OUT VARCHAR2)
AS
    V_AML_FOUND            VARCHAR2 (200);
    V_UNPOSTED_REC_FOUND   NUMBER := 0;
    V_UNPOSTED_EXP_FOUND   NUMBER := 0;
    V_BRNCH_SEQ            MW_BRNCH.BRNCH_SEQ%TYPE;
    V_CNIC_NUM             MW_CLNT.CNIC_NUM%TYPE;
    P_MSG_RCVRY_OUT        VARCHAR2 (500);
BEGIN
    SELECT FN_FIND_CLNT_TAGGED ('AML', P_CLNT_SEQ, NULL)
      INTO V_AML_FOUND
      FROM DUAL;

    IF V_AML_FOUND LIKE '%SUCESS%'
    THEN
        P_MSG_RCVRY_ADJ :=
            'NACTA Matched. Client and other individual/s (Nominee/CO borrower/Next of Kin) cannot be Adjusted.';
        RETURN;
    END IF;

        SELECT BRNCH_SEQ
          INTO V_BRNCH_SEQ
          FROM MW_LOAN_APP AP
         WHERE     AP.CLNT_SEQ = P_CLNT_SEQ
               AND AP.CRNT_REC_FLG = 1
               AND AP.LOAN_APP_STS IN (703, 1305)
      GROUP BY BRNCH_SEQ
      ORDER BY 1 DESC
    FETCH NEXT 1 ROWS ONLY;

    BEGIN
        SELECT COUNT (1)
          INTO V_UNPOSTED_REC_FOUND
          FROM MW_RCVRY_TRX TRX
         WHERE     TRX.PYMT_REF = P_CLNT_SEQ
               AND TRX.CRNT_REC_FLG = 1
               AND TRX.POST_FLG = 0;

        SELECT COUNT (1)
          INTO V_UNPOSTED_EXP_FOUND
          FROM MW_EXP EXP
         WHERE     EXP.EXP_REF = P_CLNT_SEQ
               AND EXP.CRNT_REC_FLG = 1
               AND EXP.POST_FLG = 0;

        IF (V_UNPOSTED_REC_FOUND > 0 OR V_UNPOSTED_EXP_FOUND > 0)
        THEN
            ROLLBACK;
            P_MSG_RCVRY_ADJ :=
                   'PLEASE POST ALL UNPOSTED TRNSACTIONS FIRST FOR CLNT_SEQ : '
                || P_CLNT_SEQ;
            RETURN;
        END IF;

        RECOVERY.PRC_PPST_LOAN_ASJSTMNT ('LOAN ADJUSTMENT',
                                         SYSDATE,
                                         P_ADJSTMNT_AMT,
                                         301,
                                         P_CLNT_SEQ,
                                         P_USER_ID,
                                         V_BRNCH_SEQ,
                                         'LOAN ADJUSTMENT',
                                         P_CLNT_NM,
                                         1,
                                         P_MSG_RCVRY_OUT);

        IF P_MSG_RCVRY_OUT != 'SUCCESS'
        THEN
            ROLLBACK;
            P_MSG_RCVRY_ADJ :=
                   'PRC_INCDNT_RCVRY_ADJSTMNT - ISSUE IN LOAN ADJUSTMENT ==> ERROR CODE : '
                || SQLCODE
                || ' ERROR MSG : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            P_MSG_RCVRY_ADJ :=
                   'PRC_INCDNT_RCVRY_ADJSTMNT - ISSUE IN LOAN ADJUSTMENT ==> ERROR CODE : '
                || SQLCODE
                || ' ERROR MSG : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN;
    END;

    UPDATE MW_INCDNT_RPT RPT
       SET RPT.INCDNT_STS =
               (SELECT REF_CD_SEQ
                  FROM MW_REF_CD_VAL  VL
                       JOIN MW_REF_CD_GRP GRP
                           ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                              AND GRP.CRNT_REC_FLG = 1
                 WHERE     VL.CRNT_REC_FLG = 1
                       AND GRP.REF_CD_GRP = 425
                       AND VL.REF_CD = '0003')
     WHERE     RPT.CLNT_SEQ = P_CLNT_SEQ
           AND RPT.CRNT_REC_FLG = 1
           AND RPT.INCDNT_STS =
               (SELECT REF_CD_SEQ
                  FROM MW_REF_CD_VAL  VL
                       JOIN MW_REF_CD_GRP GRP
                           ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                              AND GRP.CRNT_REC_FLG = 1
                 WHERE     VL.CRNT_REC_FLG = 1
                       AND GRP.REF_CD_GRP = 425
                       AND VL.REF_CD = '0002');

    P_MSG_RCVRY_ADJ := 'SUCCESS';
EXCEPTION
    WHEN OTHERS
    THEN
        ROLLBACK;
        KASHF_REPORTING.PRO_LOG_MSG (
            'PRC_INCDNT_RCVRY_ADJSTMNT',
               'ISSUE IN LOAN ADJUSTMENT:  CLNT==> P_CLNT_SEQ='
            || P_CLNT_SEQ
            || SQLERRM);
        P_MSG_RCVRY_ADJ :=
               'ERROR PRC_INCDNT_RCVRY_ADJSTMNT => ISSUE IN LOAN ADJUSTMENT:  CLNT==> P_CLNT_SEQ='
            || P_CLNT_SEQ;
        RETURN;
END;