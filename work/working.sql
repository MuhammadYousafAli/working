INSERT INTO MW_INCDNT_STP
(
  INCDNT_STP_SEQ,INCDNT_TYP, INCDNT_CTGRY, INCDNT_EFFECTEE, PRD_CHRG, FXD_PRMUM,
  RVRSE_ALL_ADV,RVRSE_ALL_EXPT_SM_MNTH,DED_SM_MNTH,DED_BASE,DED_APLD_ON,
  CRTD_BY,CRTD_DT,LAST_UPD_BY,LAST_UPD_DT,
  DEL_FLG,EFF_END_DT,CRNT_REC_FLG
)
VALUES(
1, 302480, 302484, 302494, 302496, 302512,
1, 0, 0, 302507, 302517,
'yousaf.ali', sysdate,'yousaf.ali', sysdate,
0, null, 1
);


SELECT AP.CLNT_SEQ, AP.PRD_SEQ, psc.*
  FROM MW_LOAN_APP  AP
       JOIN MW_PYMT_SCHED_HDR psh
           ON psh.LOAN_APP_SEQ = AP.LOAN_APP_SEQ AND psh.CRNT_REC_FLG = 1
       JOIN MW_PYMT_SCHED_DTL PSD
           ON     PSD.PYMT_SCHED_HDR_SEQ = psh.PYMT_SCHED_HDR_SEQ
              AND PSD.CRNT_REC_FLG = 1
       JOIN MW_PYMT_SCHED_CHRG psc
           ON     psc.PYMT_SCHED_DTL_SEQ = psd.PYMT_SCHED_DTL_SEQ
              AND psc.crnt_rec_flg = 1
 WHERE     AP.brnch_Seq = 299
       AND AP.LOAN_APP_STS = 703
       AND psc.CHRG_TYPS_SEQ = -2
       AND AP.PRD_SEQ = 4
      --and ap.clnt_Seq = 29900005392
       AND psh.crnt_rec_flg = 1;
       
029900005392


INSERT INTO MW_INCDNT_RPT(INCDNT_RPT_SEQ,CLNT_SEQ,INCDNT_TYP,
INCDNT_CTGRY,INCDNT_EFFECTEE, DT_OF_INCDNT,CRTD_BY,CRTD_DT,LAST_UPD_BY,LAST_UPD_DT,
DEL_FLG,EFF_END_DT,CRNT_REC_FLG,AMT,CMNT,CLM_STS,INCDNT_STS
)
VALUES(
    INCDNT_RPT_SEQ.NEXTVAL, 29900005392, 302296,
    302301, 302311, SYSDATE-30, 'mbasheer255',sysdate, 'mbasheer255',sysdate,
    0, null,1, 0,NULL, NULL, -1
);


INSERT INTO MW_ANML_RGSTR (ANML_RGSTR_SEQ,
                           EFF_START_DT,
                           LOAN_APP_SEQ,
                           RGSTR_CD,
                           TAG_NUM,
                           ANML_KND,
                           ANML_TYP,
                           ANML_CLR,
                           ANML_BRD,
                           PRCH_DT,
                           AGE_YR,
                           AGE_MNTH,
                           PRCH_AMT,
                           PIC_DT,
                           ANML_PIC,
                           TAG_PIC,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG,
                           ANML_STS)
    SELECT 100000000050626594,
           EFF_START_DT,
           1000000000506265,
           RGSTR_CD,
           TAG_NUM,
           ANML_KND,
           ANML_TYP,
           ANML_CLR,
           ANML_BRD,
           PRCH_DT,
           AGE_YR,
           AGE_MNTH,
           PRCH_AMT,
           PIC_DT,
           ANML_PIC,
           TAG_PIC,
           CRTD_BY,
           CRTD_DT,
           LAST_UPD_BY,
           LAST_UPD_DT,
           DEL_FLG,
           EFF_END_DT,
           CRNT_REC_FLG,
           ANML_STS
      FROM MW_ANML_RGSTR ANML
     WHERE ANML.LOAN_APP_SEQ = 1000000000612917;

SELECT INCDNT_TYP,
                     INCDNT_CTGRY,
                     INCDNT_CHRG,
                     INCDNT_EFFECTEE
                FROM (SELECT IRP.INCDNT_TYP,
                             IRP.INCDNT_CTGRY,
                             CASE
                                 WHEN     PSC.CHRG_TYPS_SEQ = -2
                                      AND PRD.PRD_GRP_SEQ NOT IN (6,
                                                                  24,
                                                                  13,
                                                                  5766,
                                                                  22)
                                 THEN
                                     'KSZB'
                                 WHEN     PSC.CHRG_TYPS_SEQ = -2
                                      AND PRD.PRD_GRP_SEQ IN (13, 5766, 22)
                                 THEN
                                     'KC'
                                 WHEN     PSC.CHRG_TYPS_SEQ = -2
                                      AND PRD.PRD_GRP_SEQ IN (6, 24)
                                 THEN
                                     'KST'
                                 WHEN PSC.CHRG_TYPS_SEQ != -2
                                 THEN
                                     (SELECT MT.TYP_STR
                                        FROM MW_TYPS MT
                                       WHERE     MT.TYP_SEQ = PSC.CHRG_TYPS_SEQ
                                             AND MT.CRNT_REC_FLG = 1)
                             END
                                 INCDNT_CHRG,
                             IRP.INCDNT_EFFECTEE
                        FROM MW_INCDNT_RPT IRP
                             JOIN MW_LOAN_APP AP
                                 ON     AP.CLNT_SEQ = IRP.CLNT_SEQ
                                    AND AP.CRNT_REC_FLG = 1
                                    AND AP.LOAN_APP_SEQ = AP.PRNT_LOAN_APP_SEQ
                             JOIN MW_PRD PRD
                                 ON     PRD.PRD_SEQ = AP.PRD_SEQ
                                    AND PRD.CRNT_REC_FLG = 1
                             JOIN MW_DSBMT_VCHR_HDR DSH
                                 ON     DSH.LOAN_APP_SEQ = AP.LOAN_APP_SEQ
                                    AND DSH.CRNT_REC_FLG = 1
                             JOIN MW_PYMT_SCHED_HDR PSH
                                 ON     PSH.LOAN_APP_SEQ = DSH.LOAN_APP_SEQ
                                    AND PSH.CRNT_REC_FLG = 1
                             JOIN MW_PYMT_SCHED_DTL PSD
                                 ON     PSD.PYMT_SCHED_HDR_SEQ =
                                        PSH.PYMT_SCHED_HDR_SEQ
                                    AND PSD.CRNT_REC_FLG = 1
                             LEFT OUTER JOIN MW_PYMT_SCHED_CHRG PSC
                                 ON     PSC.PYMT_SCHED_DTL_SEQ =
                                        PSD.PYMT_SCHED_DTL_SEQ
                                    AND PSC.CRNT_REC_FLG = 1
                       WHERE     IRP.CLNT_SEQ = 29900005392
                             AND IRP.CRNT_REC_FLG = 1
                             AND AP.LOAN_APP_STS = 703
                             AND TRUNC (IRP.DT_OF_INCDNT) >=
                                 TRUNC (DSH.DSBMT_DT))
            GROUP BY INCDNT_TYP,
                     INCDNT_CTGRY,
                     INCDNT_CHRG,
                     INCDNT_EFFECTEE;

SELECT STP.INCDNT_STP_SEQ,
               STP.INCDNT_TYP,
               (SELECT VL.REF_CD_DSCR
                  FROM MW_REF_CD_VAL VL
                 WHERE VL.REF_CD_SEQ = STP.INCDNT_TYP AND VL.CRNT_REC_FLG = 1)
                   INCDNT_TYPE_DESC,
               STP.INCDNT_CTGRY,
               (SELECT VL.REF_CD_DSCR
                  FROM MW_REF_CD_VAL VL
                 WHERE     VL.REF_CD_SEQ = STP.INCDNT_CTGRY
                       AND VL.CRNT_REC_FLG = 1)
                   INCDNT_CTGRY_DESC,
               STP.INCDNT_EFFECTEE,
               (SELECT VL.REF_CD_DSCR
                  FROM MW_REF_CD_VAL VL
                 WHERE     VL.REF_CD_SEQ = STP.INCDNT_EFFECTEE
                       AND VL.CRNT_REC_FLG = 1)
                   INCDNT_EFFECTEE_DESC,
               STP.PRD_CHRG,
               (SELECT VL.REF_CD
                  FROM MW_REF_CD_VAL VL
                 WHERE VL.REF_CD_SEQ = STP.PRD_CHRG AND VL.CRNT_REC_FLG = 1)
                   PRD_CHRG_CD,
               (SELECT VL.REF_CD_DSCR
                  FROM MW_REF_CD_VAL VL
                 WHERE VL.REF_CD_SEQ = STP.PRD_CHRG AND VL.CRNT_REC_FLG = 1)
                   PRD_CHRG_DESC,
               STP.FXD_PRMUM,
               (SELECT VL.REF_CD_DSCR
                  FROM MW_REF_CD_VAL VL
                 WHERE VL.REF_CD_SEQ = STP.FXD_PRMUM AND VL.CRNT_REC_FLG = 1)
                   FXD_PRMUM_DESC,
               STP.RVRSE_ALL_ADV,
               STP.RVRSE_ALL_EXPT_SM_MNTH,
               STP.DED_SM_MNTH,
               STP.DED_BASE,
               (SELECT CASE
                           WHEN VL.REF_CD_DSCR =
                                'Based on current 12 installments bucket'
                           THEN
                               1
                           WHEN VL.REF_CD_DSCR =
                                'Based on current 6 installments bucket'
                           THEN
                               2
                           WHEN VL.REF_CD_DSCR =
                                'Based on current 18 installments bucket'
                           THEN
                               3
                           WHEN VL.REF_CD_DSCR =
                                'Based on current 24 installments bucket'
                           THEN
                               4
                           WHEN VL.REF_CD_DSCR = 'Deduct all installment'
                           THEN
                               5
                       END
                  FROM MW_REF_CD_VAL VL
                 WHERE VL.REF_CD_SEQ = STP.DED_BASE AND VL.CRNT_REC_FLG = 1)
                   DED_BASE_DESC,
               STP.DED_APLD_ON,
               (SELECT CASE
                           WHEN VL.REF_CD_DSCR =
                                'First disbursed product along with associate product'
                           THEN
                               1
                           ELSE
                               0
                       END
                  FROM MW_REF_CD_VAL VL
                 WHERE     VL.REF_CD_SEQ = STP.DED_APLD_ON
                       AND VL.CRNT_REC_FLG = 1)
                   DED_APLD_ON_DESC
          FROM MW_INCDNT_STP STP
         WHERE     STP.INCDNT_TYP = 302296
               AND STP.INCDNT_CTGRY = 302301
               AND STP.INCDNT_EFFECTEE = 302311
               AND (SELECT VL.REF_CD_DSCR
                      FROM MW_REF_CD_VAL VL
                     WHERE     VL.REF_CD_SEQ = STP.PRD_CHRG
                           AND VL.CRNT_REC_FLG = 1) = 'INSURANCE PREMIUM LIVE-STOCK'
               AND STP.CRNT_REC_FLG = 1                     
