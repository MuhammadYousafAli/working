
INSERT INTO MW_INCDNT_RPT (INCDNT_RPT_SEQ,
                           CLNT_SEQ,
                           INCDNT_EFFECTEE,
                           INCDNT_TYP,
                           INCDNT_CTGRY,
                           DT_OF_INCDNT,
                           CAUSE_OF_INCDNT,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG,
                           AMT,
                           CMNT,
                           CLM_STS,
                           INCDNT_STS,
                           INCDNT_REF,
                           INCDNT_REF_RMRKS
                           )
    SELECT INCDNT_RPT_SEQ.NEXTVAL,
           RP.CLNT_SEQ,
           NVL (
               (SELECT VL.REF_CD_SEQ
                  FROM MW_REF_CD_VAL  VL
                       JOIN MW_REF_CD_GRP GRP
                           ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                              AND GRP.CRNT_REC_FLG = 1
                 WHERE     GRP.REF_CD_GRP = '0418'
                       AND VL.REF_CD = RP.CLNT_NOM_FLG),
               0)
               INCDNT_EFFECTEE,
           (SELECT VL.REF_CD_SEQ
              FROM MW_REF_CD_VAL  VL
                   JOIN MW_REF_CD_GRP GRP
                       ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                          AND GRP.CRNT_REC_FLG = 1
             WHERE GRP.REF_CD_GRP = '0413' AND VL.REF_CD = '0001')
               INCDNT_TYP,
           (SELECT VL.REF_CD_SEQ
              FROM MW_REF_CD_VAL  VL
                   JOIN MW_REF_CD_GRP GRP
                       ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                          AND GRP.CRNT_REC_FLG = 1
             WHERE GRP.REF_CD_GRP = '0414' AND VL.REF_CD = '0001')
               INCDNT_CTGRY,
           RP.DT_OF_DTH,
           RP.CAUSE_OF_DTH,
           CRTD_BY,
           CRTD_DT,
           LAST_UPD_BY,
           LAST_UPD_DT,
           DEL_FLG,
           EFF_END_DT,
           CRNT_REC_FLG,
           AMT,
           CMNT,
           INSR_CLM_STS,
           ADJ_FLG,
           RP.CLNT_SEQ,
           (SELECT VL.REF_CD_DSCR
              FROM MW_REF_CD_VAL  VL
                   JOIN MW_REF_CD_GRP GRP
                       ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                          AND GRP.CRNT_REC_FLG = 1
             WHERE GRP.REF_CD_GRP = '0413' AND VL.REF_CD = '0001')
               INCDNT_REF_RMRKS
      FROM MW_DTH_RPT RP
     WHERE     RP.CLNT_SEQ NOT IN (SELECT ANR.ANML_RGSTR_SEQ
                                     FROM MW_ANML_RGSTR ANR)
           AND EXISTS
                   (SELECT 1
                      FROM MW_CLNT MT
                     WHERE MT.CLNT_SEQ = RP.CLNT_SEQ);



INSERT INTO MW_INCDNT_RPT (INCDNT_RPT_SEQ,
                           CLNT_SEQ,
                           INCDNT_EFFECTEE,
                           INCDNT_TYP,
                           INCDNT_CTGRY,
                           DT_OF_INCDNT,
                           CAUSE_OF_INCDNT,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG,
                           AMT,
                           CMNT,
                           CLM_STS,
                           INCDNT_STS,
                           INCDNT_REF,
                           INCDNT_REF_RMRKS)
    SELECT INCDNT_RPT_SEQ.NEXTVAL,
           (SELECT AP.CLNT_SEQ
FROM MW_ANML_RGSTR ANML
JOIN MW_LOAN_APP AP ON AP.LOAN_APP_SEQ = ANML.LOAN_APP_SEQ
AND ANML.ANML_RGSTR_SEQ = RP.CLNT_SEQ
) CLNT_SEQ
           ,(SELECT VL.REF_CD_SEQ
              FROM MW_REF_CD_VAL  VL
                   JOIN MW_REF_CD_GRP GRP
                       ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                          AND GRP.CRNT_REC_FLG = 1
             WHERE GRP.REF_CD_GRP = '0423' AND VL.REF_CD = '1')
               INCDNT_EFFECTEE,
           (SELECT VL.REF_CD_SEQ
              FROM MW_REF_CD_VAL  VL
                   JOIN MW_REF_CD_GRP GRP
                       ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                          AND GRP.CRNT_REC_FLG = 1
             WHERE GRP.REF_CD_GRP = '0413' AND VL.REF_CD = '0002')
               INCDNT_TYP,
           nvl((SELECT VL.REF_CD_SEQ
              FROM MW_REF_CD_VAL  VL
                   JOIN MW_REF_CD_GRP GRP
                       ON     GRP.REF_CD_GRP_SEQ = VL.REF_CD_GRP_KEY
                          AND GRP.CRNT_REC_FLG = 1
             WHERE GRP.REF_CD_GRP = '0415' 
             AND VL.REF_CD = CASE WHEN RP.CLNT_NOM_FLG = 4 THEN '0002' ELSE '0001' END),-1)
               INCDNT_CTGRY,
           RP.DT_OF_DTH,
           RP.CAUSE_OF_DTH,
           CRTD_BY,
           CRTD_DT,
           LAST_UPD_BY,
           LAST_UPD_DT,
           DEL_FLG,
           EFF_END_DT,
           CRNT_REC_FLG,
           AMT,
           CMNT,
           INSR_CLM_STS,
           NVL(ADJ_FLG,-1),
           RP.CLNT_SEQ,
           'ANIMAL'
               INCDNT_REF_RMRKS
      FROM MW_DTH_RPT RP
    WHERE     RP.CLNT_SEQ IN (SELECT ANR.ANML_RGSTR_SEQ
                                     FROM MW_ANML_RGSTR ANR);
          


                     