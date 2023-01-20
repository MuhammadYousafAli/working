CREATE OR REPLACE PACKAGE BODY Recovery
AS
    PROCEDURE BulkRecovery (userid VARCHAR, p_msg OUT VARCHAR2)
    IS
        CURSOR clntLst IS
              SELECT RCVRY_LOAD_VLD_SEQ,
                     TRX_SEQ,
                     stg.CLNT_SEQ,
                     AMT                                 pymt_amt,
                     TRX_DATE,
                     AGNT_ID,
                     tp.typ_seq,
                     ap.brnch_seq,
                     tp.typ_str,
                     cl.frst_nm || ' ' || cl.last_nm     clntnm
                FROM mw_rcvy_load_vld stg
                     JOIN mw_clnt cl
                         ON cl.clnt_seq = stg.clnt_seq AND cl.crnt_rec_flg = 1
                     JOIN mw_loan_app ap
                         ON     ap.clnt_seq = cl.clnt_seq
                            AND ap.crnt_rec_flg = 1
                            AND ap.LOAN_APP_STS IN (703, 704)
                     JOIN mw_typs tp
                         ON     tp.typ_id = LPAD (stg.agnt_id, 4, '0')
                            AND tp.crnt_rec_flg = 1
                            AND tp.brnch_seq = ap.brnch_seq
                            AND TYP_CTGRY_KEY = 4
               WHERE ap.brnch_seq =
                     (  SELECT app.brnch_seq
                          FROM mw_loan_app app
                         WHERE     app.CLNT_SEQ = ap.CLNT_SEQ
                               AND app.CRNT_REC_FLG = 1
                               AND app.LOAN_APP_SEQ = app.PRNT_LOAN_APP_SEQ
                               AND app.LOAN_APP_STS IN (703, 704)
                               AND app.LOAN_CYCL_NUM =
                                   (SELECT MAX (LOAN_CYCL_NUM)
                                      FROM mw_loan_app ap1
                                     WHERE     ap1.clnt_seq = app.clnt_seq
                                           AND ap1.crnt_rec_flg = 1
                                           AND ap1.LOAN_APP_STS IN (703, 704))
                      GROUP BY app.brnch_seq)
            GROUP BY RCVRY_LOAD_VLD_SEQ,
                     TRX_SEQ,
                     stg.CLNT_SEQ,
                     AMT,
                     TRX_DATE,
                     AGNT_ID,
                     tp.typ_seq,
                     ap.brnch_seq,
                     tp.typ_str,
                     cl.frst_nm || ' ' || cl.last_nm
            ORDER BY 3, 5;

        err_code               VARCHAR2 (25);
        err_msg                VARCHAR2 (500);
        mClntSeq               NUMBER;
        mTrnsId                VARCHAR2 (100);
        mTrxDt                 DATE;
        mAmt                   NUMBER;
        mAgntId                NUMBER;
        mMsg                   VARCHAR2 (20000);
        v_trx_count            NUMBER;
        v_count_clnts          NUMBER;
        v_count_posted_trx     NUMBER;
        v_sum_amt_posted_trx   NUMBER;
        v_count_posted_clnt    NUMBER;
        v_count_failed_trx     NUMBER;
    BEGIN
        FOR crec IN clntLst
        LOOP
            mClntSeq := crec.clnt_seq;
            --DBMS_OUTPUT.put_line ('clntSeq=' || mClntSeq);
            PostRecClnt_ (crec.trx_seq,
                          TO_DATE (crec.trx_date),
                          crec.pymt_amt,
                          crec.typ_seq,
                          crec.clnt_seq,
                          userid,
                          crec.brnch_seq,
                          crec.typ_str,
                          crec.ClntNm,
                          1,
                          NULL);
            p_msg := p_msg || '<====>' || mMsg;
        END LOOP;

        SELECT COUNT (vld.TRX_SEQ)
                   trx_count,
               COUNT (DISTINCT vld.CLNT_SEQ)
                   count_clnts,
               COUNT (trx.INSTR_NUM)
                   count_posted_trx,
               SUM (NVL (trx.PYMT_AMT, 0))
                   sum_amt_posted_trx,
               COUNT (DISTINCT trx.PYMT_REF)
                   count_posted_clnt,
               COUNT (vld.TRX_SEQ) - COUNT (trx.INSTR_NUM)
                   count_failed_trx
          INTO v_trx_count,
               v_count_clnts,
               v_count_posted_trx,
               v_sum_amt_posted_trx,
               v_count_posted_clnt,
               v_count_failed_trx
          FROM mw_rcvy_load_vld  vld
               LEFT OUTER JOIN mw_rcvry_trx trx
                   ON     trx.INSTR_NUM = vld.TRX_SEQ
                      AND trx.PYMT_REF = vld.CLNT_SEQ
                      AND trx.CRNT_REC_FLG = 1;

        p_msg :=
               'Summary : Posted Trns: '
            || v_count_posted_trx
            || ' Posted Clnts: '
            || v_count_posted_clnt
            || ' Posted Amt: '
            || v_sum_amt_posted_trx
            || ' || Failed Trx: '
            || v_count_failed_trx
            || CASE
                   WHEN v_count_failed_trx > 0
                   THEN
                       ' [Plese see report for failed Trxs.]'
                   ELSE
                       ''
               END;
    EXCEPTION
        WHEN OTHERS
        THEN
            --DBMS_OUTPUT.put_line ('inside exception');
            ROLLBACK;
            err_code := SQLCODE;
            err_msg := SUBSTR (SQLERRM, 1, 200);
            p_msg := 'Clnt Seq : ' || mclntSeq || 'Error: ' || err_msg;

            INSERT INTO mw_rcvry_load_log
                 VALUES (SYSDATE,
                         mClntSeq,
                         err_code,
                         err_msg,
                         mTrnsId,
                         mTrxDt,
                         mAmt,
                         mAgntId);

             --COMMIT; // UPDATE BY YOUSAF DATED: 30-DEC-2022
    END;

    PROCEDURE PostRecClnt (mInstNum       VARCHAR,
                           mPymtDt        DATE,
                           mPymtAmt       NUMBER,
                           mTypSeq        NUMBER,
                           mClntSeq       NUMBER,
                           mUsrId         VARCHAR,
                           mBrnchSeq      NUMBER,
                           mAgntNm        VARCHAR,
                           mClntNm        VARCHAR,
                           mPostFlg       NUMBER,
                           mPrntLoanApp   NUMBER)
    IS
        CURSOR dtlRec (vClntSeq NUMBER)
        IS
            WITH
                ClntQry
                AS
                    (  SELECT /*+ MATERIALIZE */
                              *
                         FROM (-- Principal Amount
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      -1
                                          chrg_seq,
                                        psd.ppal_amt_due
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key = -1),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      (SELECT adj_ordr
                                         FROM mw_prd_chrg_adj_ordr ordr
                                        WHERE     ordr.crnt_rec_flg = 1
                                              AND ordr.prd_seq = app.prd_seq
                                              AND prd_chrg_seq = -1)
                                          adj_ordr,
                                      (SELECT DT_OF_INCDNT DT_OF_INCDNT
                                         FROM mw_incdnt_rpt
                                        WHERE     clnt_seq = app.clnt_seq
                                              AND crnt_rec_flg = 1
                                              AND TRUNC (DT_OF_INCDNT) >=
                                                  (SELECT TRUNC (dsbmt_dt)
                                                     FROM mw_dsbmt_vchr_hdr dvh
                                                    WHERE     dvh.loan_app_seq =
                                                              psh.loan_app_seq
                                                          AND dvh.crnt_rec_flg =
                                                              1))
                                          dth_dt,
                                      (SELECT gl_acct_num
                                         FROM mw_prd_acct_set pas
                                        WHERE     pas.crnt_rec_flg = 1
                                              AND pas.prd_seq = app.prd_seq
                                              AND pas.acct_ctgry_key = 255)
                                          gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                             AND app.PRNT_LOAN_APP_SEQ =
                                                 mPrntLoanApp
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                WHERE     psh.crnt_rec_flg = 1
                                      AND app.loan_app_sts IN (703, 1245)
                               UNION
                               -- srvc charges
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      tp.typ_seq,
                                        psd.tot_chrg_due
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key =
                                                        (SELECT chrg_typ_seq
                                                           FROM mw_prd_chrg psc
                                                                JOIN mw_typs tp
                                                                    ON     tp.typ_seq =
                                                                           psc.chrg_typ_seq
                                                                       AND tp.crnt_rec_flg =
                                                                           1
                                                                       AND tp.typ_id =
                                                                           '0017'
                                                          WHERE     psc.crnt_rec_flg =
                                                                    1
                                                                AND psc.prd_seq =
                                                                    app.prd_seq)),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      (SELECT adj_ordr
                                         FROM mw_prd_chrg_adj_ordr ordr
                                        WHERE     ordr.crnt_rec_flg = 1
                                              AND ordr.prd_seq = app.prd_seq
                                              AND prd_chrg_seq =
                                                  (SELECT prd_chrg_seq
                                                     FROM mw_prd_chrg psc
                                                          JOIN mw_typs tp
                                                              ON     tp.typ_seq =
                                                                     psc.chrg_typ_seq
                                                                 AND tp.crnt_rec_flg =
                                                                     1
                                                                 AND tp.typ_id =
                                                                     '0017'
                                                    WHERE     psc.crnt_rec_flg =
                                                              1
                                                          AND psc.prd_seq =
                                                              app.prd_seq))
                                          adj_ordr,
                                      (SELECT DT_OF_INCDNT
                                         FROM mw_incdnt_rpt
                                        WHERE     clnt_seq = app.clnt_seq
                                              AND crnt_rec_flg = 1
                                              AND TRUNC (DT_OF_INCDNT) >=
                                                  (SELECT TRUNC (dsbmt_dt)
                                                     FROM mw_dsbmt_vchr_hdr dvh
                                                    WHERE     dvh.loan_app_seq =
                                                              psh.loan_app_seq
                                                          AND dvh.crnt_rec_flg =
                                                              1))
                                          dth_dt,
                                      tp.gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                             AND app.PRNT_LOAN_APP_SEQ =
                                                 mPrntLoanApp
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg psc
                                          ON     psc.prd_seq = app.prd_seq
                                             AND psc.crnt_rec_flg = 1
                                      JOIN mw_typs tp
                                          ON     tp.typ_seq = psc.chrg_typ_seq
                                             AND tp.crnt_rec_flg = 1
                                             AND tp.typ_id = '0017'
                                WHERE     psh.crnt_rec_flg = 1
                                      AND app.loan_app_sts IN (703, 1245)
                               UNION
                               -- KSZB
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      psc.chrg_typs_seq,
                                        psc.amt
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key =
                                                        psc.chrg_typs_seq),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      (SELECT adj_ordr
                                         FROM mw_prd_chrg_adj_ordr ordr
                                        WHERE     ordr.crnt_rec_flg = 1
                                              AND ordr.prd_seq = app.prd_seq
                                              AND prd_chrg_seq = -2)
                                          adj_ordr,
                                      (SELECT DT_OF_INCDNT
                                         FROM mw_incdnt_rpt
                                        WHERE     clnt_seq = app.clnt_seq
                                              AND crnt_rec_flg = 1
                                              AND TRUNC (DT_OF_INCDNT) >=
                                                  (SELECT TRUNC (dsbmt_dt)
                                                     FROM mw_dsbmt_vchr_hdr dvh
                                                    WHERE     dvh.loan_app_seq =
                                                              psh.loan_app_seq
                                                          AND dvh.crnt_rec_flg =
                                                              1))
                                          dth_dt,
                                      (SELECT hip.gl_acct_num     gl_acct_num
                                         FROM mw_clnt_hlth_insr chi
                                              JOIN MW_HLTH_INSR_PLAN hip
                                                  ON     hip.hlth_insr_plan_seq =
                                                         chi.hlth_insr_plan_seq
                                                     AND (   hip.crnt_rec_flg =
                                                             1
                                                          OR (    hip.crnt_rec_flg =
                                                                  0
                                                              AND hip.hlth_insr_plan_seq =
                                                                  1243))
                                              JOIN mw_pymt_sched_hdr hdr
                                                  ON     hdr.loan_app_seq =
                                                         chi.loan_app_seq
                                                     AND hdr.crnt_rec_flg = 1
                                              JOIN mw_pymt_sched_dtl dtl
                                                  ON     dtl.pymt_sched_hdr_seq =
                                                         hdr.pymt_sched_hdr_seq
                                                     AND dtl.crnt_rec_flg = 1
                                        WHERE     chi.crnt_rec_flg = 1
                                              AND hip.PLAN_ID != '1223'
                                              AND dtl.pymt_sched_dtl_seq =
                                                  psd.pymt_sched_dtl_seq)
                                          gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                             AND app.PRNT_LOAN_APP_SEQ =
                                                 mPrntLoanApp
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_chrg psc
                                          ON     psc.pymt_sched_dtl_seq =
                                                 psd.pymt_sched_dtl_seq
                                             AND psc.crnt_rec_flg = 1
                                WHERE     psh.crnt_rec_flg = 1
                                      AND psc.chrg_typs_seq = -2
                                      AND app.loan_app_sts IN (703, 1245)
                               UNION
                               -- other charges
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      psc.chrg_typs_seq,
                                        psc.amt
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key =
                                                        psc.chrg_typs_seq),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      ordr.adj_ordr,
                                      (SELECT DT_OF_INCDNT
                                         FROM mw_incdnt_rpt
                                        WHERE     clnt_seq = app.clnt_seq
                                              AND crnt_rec_flg = 1
                                              AND TRUNC (DT_OF_INCDNT) >=
                                                  (SELECT TRUNC (dsbmt_dt)
                                                     FROM mw_dsbmt_vchr_hdr dvh
                                                    WHERE     dvh.loan_app_seq =
                                                              psh.loan_app_seq
                                                          AND dvh.crnt_rec_flg =
                                                              1))
                                          dth_dt,
                                      tp.gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                             AND app.PRNT_LOAN_APP_SEQ =
                                                 mPrntLoanApp
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_chrg psc
                                          ON     psc.pymt_sched_dtl_seq =
                                                 psd.pymt_sched_dtl_seq
                                             AND psc.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg pc
                                          ON pc.chrg_typ_seq =
                                             psc.chrg_typs_seq
                                      JOIN mw_typs tp
                                          ON     tp.typ_seq = pc.chrg_typ_seq
                                             AND tp.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg_adj_ordr ordr
                                          ON     ordr.prd_chrg_seq =
                                                 pc.prd_chrg_seq
                                             AND ordr.prd_seq = app.prd_seq
                                             AND ordr.crnt_rec_flg = 1
                                WHERE     psh.crnt_rec_flg = 1
                                      AND psc.chrg_typs_seq NOT IN (-2, 1)
                                      AND app.loan_app_sts IN (703, 1245)
                               UNION
                               -- doc charges
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      psc.chrg_typs_seq,
                                        psc.amt
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key =
                                                        psc.chrg_typs_seq),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      ordr.adj_ordr,
                                      (SELECT dth.DT_OF_INCDNT
                                         FROM mw_incdnt_rpt dth
                                        WHERE     dth.clnt_seq = app.clnt_seq
                                              AND dth.crnt_rec_flg = 1
                                              AND TRUNC (dth.DT_OF_INCDNT) >=
                                                  (SELECT TRUNC (dsbmt_dt)
                                                     FROM mw_dsbmt_vchr_hdr dvh
                                                    WHERE     dvh.loan_app_seq =
                                                              psh.loan_app_seq
                                                          AND dvh.crnt_rec_flg =
                                                              1))
                                          dth_dt,
                                      tp.gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                             AND app.PRNT_LOAN_APP_SEQ =
                                                 mPrntLoanApp
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_chrg psc
                                          ON     psc.pymt_sched_dtl_seq =
                                                 psd.pymt_sched_dtl_seq
                                             AND psc.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg pc
                                          ON pc.chrg_typ_seq =
                                             psc.chrg_typs_seq
                                      JOIN mw_typs tp
                                          ON     tp.typ_seq = pc.chrg_typ_seq
                                             AND tp.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg_adj_ordr ordr
                                          ON     ordr.prd_chrg_seq =
                                                 pc.prd_chrg_seq
                                             AND ordr.prd_seq = app.prd_seq
                                             AND ordr.crnt_rec_flg = 1
                                WHERE     psh.crnt_rec_flg = 1
                                      AND psc.chrg_typs_seq = 1
                                      AND app.loan_app_sts IN (703, 1245))
                     ORDER BY inst_num, prd_seq, adj_ordr)
            SELECT *
              FROM clntQry
             WHERE due_amt > 0;

        mRcvry_trx_seq      NUMBER;
        mPymtSchedSeq       NUMBER;
        mInstDueAmt         NUMBER;
        mInstPaidAmt        NUMBER;
        mTotalPaidAmt       NUMBER;
        mApldamt            NUMBER;
        mInstDueDt          DATE;
        mJvHdrSeq           NUMBER;
        mAgntGlCd           VARCHAR2 (35);
        mLnItmNum           NUMBER;
        mERglCd             VARCHAR2 (35);
        mPrdStr             VARCHAR2 (200);
        mJvNart             VARCHAR2 (500);
        err_code            VARCHAR2 (25);
        err_msg             VARCHAR2 (500);
        pLoanAppSeq         NUMBER;
        pLstInstFlg         NUMBER;
        mTotalInstDueAmt    NUMBER;
        mTotalInstPaidAmt   NUMBER;
        mPrntLoanFlg        NUMBER;
    BEGIN
        mRcvry_trx_seq := RCVRY_TRX_seq.NEXTVAL;
        mAgntGlCd := getGlAcct (mTypSeq);
        mLnItmNum := 0;
        pLoanAppSeq := 0;
        mPrdStr := getPrdStr (mClntSeq);
        -- Get client and prd info for gl header
        /*       begin
                   select listagg(prd_cmnt,',') within group (order by ap.prd_seq) prd_cmnt
                   into mPrdStr
                   from mw_prd prd
                   join mw_loan_app ap on ap.prd_seq=prd.prd_seq and ap.crnt_rec_flg=1 and ap.loan_app_sts=703
                   join mw_clnt clnt on clnt.clnt_seq=ap.clnt_seq and clnt.crnt_rec_flg=1
                   where prd.crnt_rec_flg=1
                   and ap.clnt_seq=mClntSeq;
               end;
       */
       -- DBMS_OUTPUT.put_line ('recovery record');

        -- ======= create record in Recovery Trx table
        INSERT INTO mw_rcvry_trx
                 VALUES (
                     mRcvry_trx_seq,                           --RCVRY_TRX_SEQ
                     SYSDATE,                                   --EFF_START_DT
                     NVL (mInstNum, mRcvry_trx_seq),               --INSTR_NUM
                     TO_DATE (mPymtDt || ' 13:00:00',
                              'dd-mon-rrrr hh24:mi:ss'),             --PYMT_DT
                     mPymtAmt,                                      --PYMT_AMT
                     mTypSeq,                                  --RCVRY_TYP_SEQ
                     mClntSeq,                                  --PYMT_MOD_KEY
                     0,                                        --PYMT_STS_KEY,
                     mUsrId,                                        --CRTD_BY,
                     SYSDATE,                                      -- CRTD_DT,
                     mUsrId,                                    --LAST_UPD_BY,
                     SYSDATE,                                   --LAST_UPD_DT,
                     0,                                             --DEL_FLG,
                     NULL,                                       --EFF_END_DT,
                     1,                                        --CRNT_REC_FLG,
                     mClntSeq,                                     --PYMT_REF,
                     mPostFlg,                                     --POST_FLG,
                     NULL,                                     --CHNG_RSN_KEY,
                     NULL,                                    --CHNG_RSN_CMNT,
                     NULL,                                   --PRNT_RCVRY_REF,
                     NULL,                                      --DPST_SLP_DT,
                     mPrntLoanApp);

        -- =========== create JV header Record
        -- if client is dead then create Access Recovery
        -- Create JV Header
        IF mPostFlg = 1
        THEN
            mJvNart :=
                   NVL (mPrdStr, ' ')
                || ' Recovery received from Client '
                || NVL (mClntNm, ' ')
                || ' through '
                || NVL (mAgntNm, ' ');
            --mJvNart := 'Performance test';
            mJvHdrSeq := jv_hdr_seq.NEXTVAL;

            BEGIN
                INSERT INTO mw_jv_hdr (JV_HDR_SEQ,
                                       PRNT_VCHR_REF,
                                       JV_ID,
                                       JV_DT,
                                       JV_DSCR,
                                       JV_TYP_KEY,
                                       enty_seq,
                                       ENTY_TYP,
                                       CRTD_BY,
                                       POST_FLG,
                                       RCVRY_TRX_SEQ,
                                       BRNCH_SEQ)
                         VALUES (
                             mJvHdrSeq,                          --JV_HDR_SEQ,
                             NULL,                            --PRNT_VCHR_REF,
                             mJvHdrSeq,                               --JV_ID,
                             TO_DATE (mPymtDt || ' 13:00:00',
                                      'dd-mon-rrrr hh24:mi:ss'),      --JV_DT,
                             mJvnart,                               --JV_DSCR,
                             NULL,                               --JV_TYP_KEY,
                             mRcvry_trx_seq,                        --enty_seq
                             'Recovery',                           --ENTY_TYP,
                             mUsrId,                                --CRTD_BY,
                             1,                                    --POST_FLG,
                             mRcvry_trx_seq,                  --RCVRY_TRX_SEQ,
                             mBrnchSeq                             --BRNCH_SEQ
                                      );
            END;
        END IF;

        -- ================================================================
        -- =========== Create Recovery Detail Records =====================
        -- ================================================================
        mPymtSchedSeq := 0;                    --previous installment sequence
        mTotalPaidAmt := 0;

        --DBMS_OUTPUT.put_line ('rcvry outside loop ' || mClntSeq);

        FOR rdl IN dtlRec (mClntSeq)
        LOOP
            --=== client/nominee reported as dead apply then Excess Recovery
--            DBMS_OUTPUT.put_line (
--                   'inside rdl loop installment'
--                || rdl.pymt_sched_dtl_seq
--                || ' mPymtSeq:'
--                || mPymtSchedSeq);

            IF rdl.dth_dt >= rdl.dsbmt_dt
            THEN
                ROLLBACK;

                ----------  for dth Excess Recovery ---------
                INSERT INTO mw_rcvry_trx
                         VALUES (
                             mRcvry_trx_seq,                   --RCVRY_TRX_SEQ
                             SYSDATE,                           --EFF_START_DT
                             NVL (mInstNum, mRcvry_trx_seq),       --INSTR_NUM
                             TO_DATE (mPymtDt || ' 13:00:00',
                                      'dd-mon-rrrr hh24:mi:ss'),     --PYMT_DT
                             mPymtAmt,                              --PYMT_AMT
                             mTypSeq,                          --RCVRY_TYP_SEQ
                             mClntSeq,                          --PYMT_MOD_KEY
                             0,                                --PYMT_STS_KEY,
                             mUsrId,                                --CRTD_BY,
                             SYSDATE,                              -- CRTD_DT,
                             mUsrId,                            --LAST_UPD_BY,
                             SYSDATE,                           --LAST_UPD_DT,
                             0,                                     --DEL_FLG,
                             NULL,                               --EFF_END_DT,
                             1,                                --CRNT_REC_FLG,
                             mClntSeq,                             --PYMT_REF,
                             mPostFlg,                             --POST_FLG,
                             NULL,                             --CHNG_RSN_KEY,
                             NULL,                            --CHNG_RSN_CMNT,
                             NULL,                           --PRNT_RCVRY_REF,
                             NULL,                               --DPST_SLP_DT
                             mPrntLoanApp);

                ---------------------------------------------------------
                EXIT;
            END IF;

            mLnItmNum := mLnItmNum + 1;

            -- in case the installment is completed then update the status
            IF mPymtSchedSeq <> rdl.pymt_sched_dtl_seq
            THEN
--                DBMS_OUTPUT.put_line (
--                       'update psd sts Tot inst amt:'
--                    || mTotalInstDueAmt
--                    || ' mInstPaidAmt:'
--                    || mInstPaidAmt);
--                DBMS_OUTPUT.put_line (
--                    'update psd mpymtdtlseq:' || mPymtSchedSeq);

                IF mPymtSchedSeq <> 0
                THEN
--                    DBMS_OUTPUT.put_line (
--                           'update psd sts Tot inst amt:'
--                        || mTotalInstDueAmt
--                        || ' mInstPaidAmt:'
--                        || mInstPaidAmt);

                    IF mTotalInstDueAmt = mInstPaidAmt AND mInstPaidAmt <> 0
                    THEN
--                        DBMS_OUTPUT.put_line ('inside udate psd');
                        updtPymtSchedDtl (mInstDueDt,
                                          mPymtDt,
                                          mPymtSchedSeq,
                                          mUsrId);

                        -- if last then update loan App status
                        IF pLstInstFlg = 1 AND mPostFlg = 1
                        THEN
                            IF mPrntLoanFlg = 0
                            THEN
                                IF loan_app_ost (pLoanAppSeq,
                                                 SYSDATE + 1,
                                                 'psc') =
                                   0
                                THEN
                                    IF clnt_ost (mClntSeq,
                                                 SYSDATE + 1,
                                                 'psc') =
                                       0
                                    THEN
                                        UpdateLaStsByClnt (mClntSeq,
                                                           mUsrId,
                                                           mPymtDt);
                                    ELSE
                                        UpdateLaStsByLoan (pLoanAppSeq,
                                                           mUsrId,
                                                           mPymtDt);
                                    END IF;
                                END IF;
                            ELSE
                                IF clnt_ost (mClntSeq, SYSDATE + 1, 'psc') =
                                   0
                                THEN
                                    UpdateLaStsByLoan (pLoanAppSeq,
                                                       mUsrId,
                                                       mPymtDt);
                                END IF;
                            END IF;
                        END IF;
                    END IF;

--                    DBMS_OUTPUT.put_line (
--                           'update prtl psd sts '
--                        || mTotalInstDueAmt
--                        || '-'
--                        || mInstPaidAmt);

                    IF mTotalInstDueAmt - mInstPaidAmt > 0
                    THEN              -- check ost amount for last installment
                        -- Update Partial Status
                        updtPymtSchedDtl (mInstDueDt,
                                          NULL,
                                          mPymtSchedSeq,
                                          mUsrId);
                    END IF;
                END IF;

                mInstPaidAmt := rdl.total_inst_paid_amt;
                pLstInstFlg := 0;
                mPymtSchedSeq := rdl.pymt_sched_dtl_seq;
                mInstDueDt := rdl.due_dt;
                pLoanAppSeq := rdl.loan_app_seq;
                mprntloanflg := rdl.prnt_loan_flg;

                IF rdl.inst_num = rdl.lst_inst
                THEN
                    pLstInstFlg := 1;
                END IF;

                mTotalInstDueAmt := rdl.Total_inst_due_amt;
--                DBMS_OUTPUT.put_line (
--                    'value assigned mTotalInstDueAmt:' || mTotalInstDueAmt);
            END IF;

            --dbms_output.put_line('Total Paid:'||mTotalPaidAmt||' Payment Amount: '||mPymtAmt);
            IF mTotalPaidAmt < mPymtAmt
            THEN
                IF mTotalPaidAmt + rdl.due_amt <= mPymtAmt
                THEN
                    mApldamt := rdl.due_amt;
                ELSE
                    mApldamt := mPymtAmt - mTotalPaidAmt;
                END IF;

--                DBMS_OUTPUT.put_line (
--                       'insert '
--                    || mclntseq
--                    || ' inst seq:'
--                    || rdl.PYMT_SCHED_DTL_SEQ
--                    || ' :'
--                    || rdl.chrg_seq
--                    || ' :'
--                    || mApldamt);

                INSERT INTO mw_rcvry_dtl
                     VALUES (rcvry_chrg_seq.NEXTVAL,         --RCVRY_CHRG_SEQ,
                             SYSDATE,                          --EFF_START_DT,
                             mRcvry_trx_seq,                  --RCVRY_TRX_SEQ,
                             rdl.chrg_seq,                     --CHRG_TYP_KEY,
                             mApldamt,                             --PYMT_AMT,
                             mUsrId,                                --CRTD_BY,
                             SYSDATE,                               --CRTD_DT,
                             mUsrId,                            --LAST_UPD_BY,
                             SYSDATE,                           --LAST_UPD_DT,
                             0,                                     --DEL_FLG,
                             NULL,                               --EFF_END_DT,
                             1,                                --CRNT_REC_FLG,
                             rdl.PYMT_SCHED_DTL_SEQ,
                             0);

                -- Insert JV Dtl Entry
                IF mPostFlg = 1
                THEN
                    crtJvDtlRec (mJvHdrSeq,
                                 rdl.gl_acct_num,
                                 mAgntGlCd,
                                 mApldamt,
                                 mLnItmNum);

                    IF pLoanAppSeq > 0
                    THEN
                        IF loan_app_ost (pLoanAppSeq, SYSDATE + 1, 'psc') = 0
                        THEN
                            UpdateLaStsByLoan (pLoanAppSeq, mUsrId, mPymtDt);
                        END IF;
                    END IF;
                END IF;

                mInstPaidAmt := mInstPaidAmt + mApldamt;
                mTotalPaidAmt := mTotalPaidAmt + mApldamt;
--                DBMS_OUTPUT.put_line ('mInstPaidAmt ' || mInstPaidAmt);
            ELSE
                EXIT;
            END IF;
        END LOOP;

        IF mTotalInstDueAmt - mInstPaidAmt > 0 AND mInstPaidAmt > 0
        THEN                          -- check ost amount for last installment
            -- Update Partial Status
--            DBMS_OUTPUT.put_line (
--                   'inside prtl sts '
--                || mTotalInstDueAmt
--                || ' : '
--                || mInstPaidAmt);
            updtPymtSchedDtl (mInstDueDt,
                              NULL,
                              mPymtSchedSeq,
                              mUsrId);
        END IF;

        IF pLstInstFlg = 1
        THEN
            IF mTotalInstDueAmt = mInstPaidAmt AND mInstPaidAmt <> 0
            THEN
                updtPymtSchedDtl (mInstDueDt,
                                  mPymtDt,
                                  mPymtSchedSeq,
                                  mUsrId);

                -- if last then update loan App status
                IF pLstInstFlg = 1 AND mPostFlg = 1
                THEN
                    IF mPrntLoanFlg = 0
                    THEN
                        IF loan_app_ost (pLoanAppSeq, SYSDATE + 1, 'psc') = 0
                        THEN
                            IF clnt_ost (mClntSeq, SYSDATE + 1, 'psc') = 0
                            THEN
                                UpdateLaStsByClnt (mClntSeq, mUsrId, mPymtDt);
                            ELSE
                                UpdateLaStsByLoan (pLoanAppSeq,
                                                   mUsrId,
                                                   mPymtDt);
                            END IF;
                        END IF;
                    ELSE
                        IF clnt_ost (mClntSeq, SYSDATE + 1, 'psc') = 0
                        THEN
                            UpdateLaStsByLoan (pLoanAppSeq, mUsrId, mPymtDt);
                        END IF;
                    END IF;
                END IF;
            END IF;

            IF mTotalInstDueAmt - mInstPaidAmt > 0 AND mInstPaidAmt > 0
            THEN
                -- Update Partial Status
                updtPymtSchedDtl (mInstDueDt,
                                  NULL,
                                  mPymtSchedSeq,
                                  mUsrId);
            END IF;
        END IF;

        -- Create excess Recovery
        IF mPymtAmt - NVL (mTotalPaidamt, 0) > 0
        THEN
            BEGIN
                -- jv dtl
                INSERT INTO mw_rcvry_dtl
                     VALUES (rcvry_chrg_seq.NEXTVAL,         --RCVRY_CHRG_SEQ,
                             SYSDATE,                          --EFF_START_DT,
                             mRcvry_trx_seq,                  --RCVRY_TRX_SEQ,
                             241,                              --CHRG_TYP_KEY,
                             mPymtAmt - NVL (mTotalPaidamt, 0),    --PYMT_AMT,
                             mUsrId,                                --CRTD_BY,
                             SYSDATE,                               --CRTD_DT,
                             mUsrId,                            --LAST_UPD_BY,
                             SYSDATE,                           --LAST_UPD_DT,
                             0,                                     --DEL_FLG,
                             NULL,                               --EFF_END_DT,
                             1,                                --CRNT_REC_FLG,
                             NULL,
                             0);
            END;

            -- Jv Dtl Record
            -- get ER gl code
            IF mPostFlg = 1
            THEN
                BEGIN
                    SELECT gl_acct_num
                      INTO mERglCd
                      FROM mw_typs typ
                     WHERE typ.crnt_rec_flg = 1 AND typ.typ_seq = 241;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;             -- Excess Recovery Gl code not found
                END;

                -- jv Header for Excess Recovery
                mJvNart :=
                       ' Excess Recovery received from Client '
                    || NVL (mClntNm, ' ');
                mJvHdrSeq := jv_hdr_seq.NEXTVAL;

                INSERT INTO mw_jv_hdr (JV_HDR_SEQ,
                                       PRNT_VCHR_REF,
                                       JV_ID,
                                       JV_DT,
                                       JV_DSCR,
                                       JV_TYP_KEY,
                                       enty_seq,
                                       ENTY_TYP,
                                       CRTD_BY,
                                       POST_FLG,
                                       RCVRY_TRX_SEQ,
                                       BRNCH_SEQ)
                         VALUES (
                             mJvHdrSeq,                          --JV_HDR_SEQ,
                             NULL,                            --PRNT_VCHR_REF,
                             mJvHdrSeq,                               --JV_ID,
                             TO_DATE (mPymtDt || ' 13:00:00',
                                      'dd-mon-rrrr hh24:mi:ss'),      --JV_DT,
                             mJvnart,                               --JV_DSCR,
                             NULL,                               --JV_TYP_KEY,
                             mRcvry_trx_seq,                        --enty_seq
                             'EXCESS RECOVERY',                    --ENTY_TYP,
                             mUsrId,                                --CRTD_BY,
                             1,                                    --POST_FLG,
                             mRcvry_trx_seq,                  --RCVRY_TRX_SEQ,
                             mBrnchSeq                             --BRNCH_SEQ
                                      );

                crtJvDtlRec (mJvHdrSeq,
                             mERglCd,
                             mAgntGlCd,
                             mPymtAmt - NVL (mTotalPaidamt, 0),
                             mLnItmNum);

                IF pLoanAppSeq > 0
                THEN
                    IF loan_app_ost (pLoanAppSeq, SYSDATE + 1, 'psc') = 0
                    THEN
                        UpdateLaStsByLoan (pLoanAppSeq, mUsrId, mPymtDt);
                    END IF;
                END IF;
            END IF;
        END IF;

         --COMMIT; // UPDATE BY YOUSAF DATED: 30-DEC-2022
    EXCEPTION
        WHEN OTHERS
        THEN
--            DBMS_OUTPUT.put_line ('inside exception');
            ROLLBACK;
            err_code := SQLCODE;
            err_msg := SUBSTR (SQLERRM, 1, 200);

            INSERT INTO mw_rcvry_load_log
                 VALUES (SYSDATE,
                         mClntSeq,
                         err_code,
                         err_msg,
                         mInstNum,
                         mPymtDt,
                         mPymtAmt,
                         mTypSeq);

            --COMMIT; // UPDATE BY YOUSAF DATED: 30-DEC-2022
    END;

    PROCEDURE PostRecClnt_ (mInstNum       VARCHAR,
                            mPymtDt        DATE,
                            mPymtAmt       NUMBER,
                            mTypSeq        NUMBER,
                            mClntSeq       NUMBER,
                            mUsrId         VARCHAR,
                            mBrnchSeq      NUMBER,
                            mAgntNm        VARCHAR,
                            mClntNm        VARCHAR,
                            mPostFlg       NUMBER,
                            mPrntLoanApp   NUMBER)
    IS
        CURSOR dtlRec (vClntSeq NUMBER)
        IS
            WITH
                ClntQry
                AS
                    (  SELECT /*+ MATERIALIZE */
                              *
                         FROM (-- Principal Amount
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      -1
                                          chrg_seq,
                                        psd.ppal_amt_due
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key = -1),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      (SELECT adj_ordr
                                         FROM mw_prd_chrg_adj_ordr ordr
                                        WHERE     ordr.crnt_rec_flg = 1
                                              AND ordr.prd_seq = app.prd_seq
                                              AND prd_chrg_seq = -1)
                                          adj_ordr,
                                      (SELECT DT_OF_INCDNT
                                         FROM MW_INCDNT_RPT
                                        WHERE     clnt_seq = app.clnt_seq
                                              AND crnt_rec_flg = 1
                                              AND TRUNC (DT_OF_INCDNT) >=
                                                  (SELECT TRUNC (dsbmt_dt)
                                                     FROM mw_dsbmt_vchr_hdr dvh
                                                    WHERE     dvh.loan_app_seq =
                                                              psh.loan_app_seq
                                                          AND dvh.crnt_rec_flg =
                                                              1))
                                          dth_dt,
                                      (SELECT gl_acct_num
                                         FROM mw_prd_acct_set pas
                                        WHERE     pas.crnt_rec_flg = 1
                                              AND pas.prd_seq = app.prd_seq
                                              AND pas.acct_ctgry_key = 255)
                                          gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt,
                                      app.PRNT_LOAN_APP_SEQ
                                          PrntLoanApp
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                WHERE     psh.crnt_rec_flg = 1
                                      AND app.loan_app_sts IN (703)
                               UNION
                               -- srvc charges
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      tp.typ_seq,
                                        psd.tot_chrg_due
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key =
                                                        (SELECT chrg_typ_seq
                                                           FROM mw_prd_chrg psc
                                                                JOIN mw_typs tp
                                                                    ON     tp.typ_seq =
                                                                           psc.chrg_typ_seq
                                                                       AND tp.crnt_rec_flg =
                                                                           1
                                                                       AND tp.typ_id =
                                                                           '0017'
                                                          WHERE     psc.crnt_rec_flg =
                                                                    1
                                                                AND psc.prd_seq =
                                                                    app.prd_seq)),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      (SELECT adj_ordr
                                         FROM mw_prd_chrg_adj_ordr ordr
                                        WHERE     ordr.crnt_rec_flg = 1
                                              AND ordr.prd_seq = app.prd_seq
                                              AND prd_chrg_seq =
                                                  (SELECT prd_chrg_seq
                                                     FROM mw_prd_chrg psc
                                                          JOIN mw_typs tp
                                                              ON     tp.typ_seq =
                                                                     psc.chrg_typ_seq
                                                                 AND tp.crnt_rec_flg =
                                                                     1
                                                                 AND tp.typ_id =
                                                                     '0017'
                                                    WHERE     psc.crnt_rec_flg =
                                                              1
                                                          AND psc.prd_seq =
                                                              app.prd_seq))
                                          adj_ordr,
                                      (SELECT DT_OF_INCDNT
                                         FROM MW_INCDNT_RPT
                                        WHERE     clnt_seq = app.clnt_seq
                                              AND crnt_rec_flg = 1
                                              AND TRUNC (DT_OF_INCDNT) >=
                                                  (SELECT TRUNC (dsbmt_dt)
                                                     FROM mw_dsbmt_vchr_hdr dvh
                                                    WHERE     dvh.loan_app_seq =
                                                              psh.loan_app_seq
                                                          AND dvh.crnt_rec_flg =
                                                              1))
                                          dth_dt,
                                      tp.gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt,
                                      app.PRNT_LOAN_APP_SEQ
                                          PrntLoanApp
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg psc
                                          ON     psc.prd_seq = app.prd_seq
                                             AND psc.crnt_rec_flg = 1
                                      JOIN mw_typs tp
                                          ON     tp.typ_seq = psc.chrg_typ_seq
                                             AND tp.crnt_rec_flg = 1
                                             AND tp.typ_id = '0017'
                                WHERE     psh.crnt_rec_flg = 1
                                      AND app.loan_app_sts IN (703)
                               UNION
                               -- KSZB
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      psc.chrg_typs_seq,
                                        psc.amt
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key =
                                                        psc.chrg_typs_seq),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      (SELECT adj_ordr
                                         FROM mw_prd_chrg_adj_ordr ordr
                                        WHERE     ordr.crnt_rec_flg = 1
                                              AND ordr.prd_seq = app.prd_seq
                                              AND prd_chrg_seq = -2)
                                          adj_ordr,
                                      (SELECT DT_OF_INCDNT
                                         FROM MW_INCDNT_RPT
                                        WHERE     clnt_seq = app.clnt_seq
                                              AND crnt_rec_flg = 1
                                              AND TRUNC (DT_OF_INCDNT) >=
                                                  (SELECT TRUNC (dsbmt_dt)
                                                     FROM mw_dsbmt_vchr_hdr dvh
                                                    WHERE     dvh.loan_app_seq =
                                                              psh.loan_app_seq
                                                          AND dvh.crnt_rec_flg =
                                                              1))
                                          dth_dt,
                                      (SELECT hip.gl_acct_num     gl_acct_num
                                         FROM mw_clnt_hlth_insr chi
                                              JOIN MW_HLTH_INSR_PLAN hip
                                                  ON     hip.hlth_insr_plan_seq =
                                                         chi.hlth_insr_plan_seq
                                                     AND (   hip.crnt_rec_flg =
                                                             1
                                                          OR (    hip.crnt_rec_flg =
                                                                  0
                                                              AND hip.hlth_insr_plan_seq =
                                                                  1243))
                                              JOIN mw_pymt_sched_hdr hdr
                                                  ON     hdr.loan_app_seq =
                                                         chi.loan_app_seq
                                                     AND hdr.crnt_rec_flg = 1
                                              JOIN mw_pymt_sched_dtl dtl
                                                  ON     dtl.pymt_sched_hdr_seq =
                                                         hdr.pymt_sched_hdr_seq
                                                     AND dtl.crnt_rec_flg = 1
                                        WHERE     chi.crnt_rec_flg = 1
                                              AND hip.PLAN_ID != '1223'
                                              AND dtl.pymt_sched_dtl_seq =
                                                  psd.pymt_sched_dtl_seq)
                                          gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt,
                                      app.PRNT_LOAN_APP_SEQ
                                          PrntLoanApp
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_chrg psc
                                          ON     psc.pymt_sched_dtl_seq =
                                                 psd.pymt_sched_dtl_seq
                                             AND psc.crnt_rec_flg = 1
                                WHERE     psh.crnt_rec_flg = 1
                                      AND psc.chrg_typs_seq = -2
                                      AND app.loan_app_sts IN (703)
                               UNION
                               -- other charges
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      psc.chrg_typs_seq,
                                        psc.amt
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key =
                                                        psc.chrg_typs_seq),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      ordr.adj_ordr,
                                      (SELECT DT_OF_INCDNT
                                         FROM MW_INCDNT_RPT
                                        WHERE     clnt_seq = app.clnt_seq
                                              AND crnt_rec_flg = 1
                                              AND TRUNC (DT_OF_INCDNT) >=
                                                  (SELECT TRUNC (dsbmt_dt)
                                                     FROM mw_dsbmt_vchr_hdr dvh
                                                    WHERE     dvh.loan_app_seq =
                                                              psh.loan_app_seq
                                                          AND dvh.crnt_rec_flg =
                                                              1))
                                          dth_dt,
                                      tp.gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt,
                                      app.PRNT_LOAN_APP_SEQ
                                          PrntLoanApp
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_chrg psc
                                          ON     psc.pymt_sched_dtl_seq =
                                                 psd.pymt_sched_dtl_seq
                                             AND psc.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg pc
                                          ON pc.chrg_typ_seq =
                                             psc.chrg_typs_seq
                                      JOIN mw_typs tp
                                          ON     tp.typ_seq = pc.chrg_typ_seq
                                             AND tp.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg_adj_ordr ordr
                                          ON     ordr.prd_chrg_seq =
                                                 pc.prd_chrg_seq
                                             AND ordr.prd_seq = app.prd_seq
                                             AND ordr.crnt_rec_flg = 1
                                WHERE     psh.crnt_rec_flg = 1
                                      AND psc.chrg_typs_seq NOT IN (-2, 1)
                                      AND app.loan_app_sts IN (703)
                               UNION
                               -- doc charges
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      psc.chrg_typs_seq,
                                        psc.amt
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key =
                                                        psc.chrg_typs_seq),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      ordr.adj_ordr,
                                      (SELECT DT_OF_INCDNT
                                         FROM MW_INCDNT_RPT dth
                                        WHERE     dth.clnt_seq = app.clnt_seq
                                              AND dth.crnt_rec_flg = 1
                                              AND TRUNC (dth.DT_OF_INCDNT) >=
                                                  (SELECT TRUNC (dsbmt_dt)
                                                     FROM mw_dsbmt_vchr_hdr dvh
                                                    WHERE     dvh.loan_app_seq =
                                                              psh.loan_app_seq
                                                          AND dvh.crnt_rec_flg =
                                                              1))
                                          dth_dt,
                                      tp.gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt,
                                      app.PRNT_LOAN_APP_SEQ
                                          PrntLoanApp
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_chrg psc
                                          ON     psc.pymt_sched_dtl_seq =
                                                 psd.pymt_sched_dtl_seq
                                             AND psc.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg pc
                                          ON pc.chrg_typ_seq =
                                             psc.chrg_typs_seq
                                      JOIN mw_typs tp
                                          ON     tp.typ_seq = pc.chrg_typ_seq
                                             AND tp.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg_adj_ordr ordr
                                          ON     ordr.prd_chrg_seq =
                                                 pc.prd_chrg_seq
                                             AND ordr.prd_seq = app.prd_seq
                                             AND ordr.crnt_rec_flg = 1
                                WHERE     psh.crnt_rec_flg = 1
                                      AND psc.chrg_typs_seq = 1
                                      AND app.loan_app_sts IN (703))
                     ORDER BY due_dt, prd_seq, adj_ordr)
              SELECT *
                FROM clntQry
               WHERE due_amt > 0
            ORDER BY due_dt, prd_seq, adj_ordr;

        mRcvry_trx_seq      NUMBER;
        mPymtSchedSeq       NUMBER;
        mInstDueAmt         NUMBER;
        mInstPaidAmt        NUMBER;
        mTotalPaidAmt       NUMBER;
        mApldamt            NUMBER;
        mInstDueDt          DATE;
        mJvHdrSeq           NUMBER;
        mAgntGlCd           VARCHAR2 (35);
        mLnItmNum           NUMBER;
        mERglCd             VARCHAR2 (35);
        mPrdStr             VARCHAR2 (200);
        mJvNart             VARCHAR2 (500);
        err_code            VARCHAR2 (25);
        err_msg             VARCHAR2 (500);
        pLoanAppSeq         NUMBER;
        pLstInstFlg         NUMBER;
        mTotalInstDueAmt    NUMBER;
        mTotalInstPaidAmt   NUMBER;
        mPrntLoanFlg        NUMBER;
    BEGIN
        mRcvry_trx_seq := RCVRY_TRX_seq.NEXTVAL;
        mAgntGlCd := getGlAcct (mTypSeq);
        mLnItmNum := 0;
        pLoanAppSeq := 0;
        mPrdStr := getPrdStr (mClntSeq);
        -- Get client and prd info for gl header
        /*       begin
                   select listagg(prd_cmnt,',') within group (order by ap.prd_seq) prd_cmnt
                   into mPrdStr
                   from mw_prd prd
                   join mw_loan_app ap on ap.prd_seq=prd.prd_seq and ap.crnt_rec_flg=1 and ap.loan_app_sts=703
                   join mw_clnt clnt on clnt.clnt_seq=ap.clnt_seq and clnt.crnt_rec_flg=1
                   where prd.crnt_rec_flg=1
                   and ap.clnt_seq=mClntSeq;
               end;
       */
--        DBMS_OUTPUT.put_line ('recovery record');

        -- ======= create record in Recovery Trx table
        INSERT INTO mw_rcvry_trx
                 VALUES (
                     mRcvry_trx_seq,                           --RCVRY_TRX_SEQ
                     SYSDATE,                                   --EFF_START_DT
                     NVL (mInstNum, mRcvry_trx_seq),               --INSTR_NUM
                     TO_DATE (mPymtDt || ' 13:00:00',
                              'dd-mon-rrrr hh24:mi:ss'),             --PYMT_DT
                     mPymtAmt,                                      --PYMT_AMT
                     mTypSeq,                                  --RCVRY_TYP_SEQ
                     mClntSeq,                                  --PYMT_MOD_KEY
                     0,                                        --PYMT_STS_KEY,
                     mUsrId,                                        --CRTD_BY,
                     SYSDATE,                                      -- CRTD_DT,
                     mUsrId,                                    --LAST_UPD_BY,
                     SYSDATE,                                   --LAST_UPD_DT,
                     0,                                             --DEL_FLG,
                     NULL,                                       --EFF_END_DT,
                     1,                                        --CRNT_REC_FLG,
                     mClntSeq,                                     --PYMT_REF,
                     mPostFlg,                                     --POST_FLG,
                     NULL,                                     --CHNG_RSN_KEY,
                     NULL,                                    --CHNG_RSN_CMNT,
                     NULL,                                   --PRNT_RCVRY_REF,
                     NULL,                                      --DPST_SLP_DT,
                     mPrntLoanApp);

        -- =========== create JV header Record
        -- if client is dead then create Access Recovery
        -- Create JV Header
        IF mPostFlg = 1
        THEN
            mJvNart :=
                   NVL (mPrdStr, ' ')
                || ' Recovery received from Client '
                || NVL (mClntNm, ' ')
                || ' through '
                || NVL (mAgntNm, ' ');
            --mJvNart := 'Performance test';
            mJvHdrSeq := jv_hdr_seq.NEXTVAL;

            BEGIN
                INSERT INTO mw_jv_hdr (JV_HDR_SEQ,
                                       PRNT_VCHR_REF,
                                       JV_ID,
                                       JV_DT,
                                       JV_DSCR,
                                       JV_TYP_KEY,
                                       enty_seq,
                                       ENTY_TYP,
                                       CRTD_BY,
                                       POST_FLG,
                                       RCVRY_TRX_SEQ,
                                       BRNCH_SEQ)
                         VALUES (
                             mJvHdrSeq,                          --JV_HDR_SEQ,
                             NULL,                            --PRNT_VCHR_REF,
                             mJvHdrSeq,                               --JV_ID,
                             TO_DATE (mPymtDt || ' 13:00:00',
                                      'dd-mon-rrrr hh24:mi:ss'),      --JV_DT,
                             mJvnart,                               --JV_DSCR,
                             NULL,                               --JV_TYP_KEY,
                             mRcvry_trx_seq,                        --enty_seq
                             'Recovery',                           --ENTY_TYP,
                             mUsrId,                                --CRTD_BY,
                             1,                                    --POST_FLG,
                             mRcvry_trx_seq,                  --RCVRY_TRX_SEQ,
                             mBrnchSeq                             --BRNCH_SEQ
                                      );
            END;
        END IF;

        -- ================================================================
        -- =========== Create Recovery Detail Records =====================
        -- ================================================================
        mPymtSchedSeq := 0;                    --previous installment sequence
        mTotalPaidAmt := 0;

--        DBMS_OUTPUT.put_line ('rcvry outside loop ' || mClntSeq);

        FOR rdl IN dtlRec (mClntSeq)
        LOOP
            --=== client/nominee reported as dead apply then Excess Recovery
--            DBMS_OUTPUT.put_line (
--                   'inside rdl loop installment'
--                || rdl.pymt_sched_dtl_seq
--                || ' mPymtSeq:'
--                || mPymtSchedSeq);

            IF rdl.dth_dt >= rdl.dsbmt_dt
            THEN
                ROLLBACK;

                ----------  for dth Excess Recovery ---------
                INSERT INTO mw_rcvry_trx
                         VALUES (
                             mRcvry_trx_seq,                   --RCVRY_TRX_SEQ
                             SYSDATE,                           --EFF_START_DT
                             NVL (mInstNum, mRcvry_trx_seq),       --INSTR_NUM
                             TO_DATE (mPymtDt || ' 13:00:00',
                                      'dd-mon-rrrr hh24:mi:ss'),     --PYMT_DT
                             mPymtAmt,                              --PYMT_AMT
                             mTypSeq,                          --RCVRY_TYP_SEQ
                             mClntSeq,                          --PYMT_MOD_KEY
                             0,                                --PYMT_STS_KEY,
                             mUsrId,                                --CRTD_BY,
                             SYSDATE,                              -- CRTD_DT,
                             mUsrId,                            --LAST_UPD_BY,
                             SYSDATE,                           --LAST_UPD_DT,
                             0,                                     --DEL_FLG,
                             NULL,                               --EFF_END_DT,
                             1,                                --CRNT_REC_FLG,
                             mClntSeq,                             --PYMT_REF,
                             mPostFlg,                             --POST_FLG,
                             NULL,                             --CHNG_RSN_KEY,
                             NULL,                            --CHNG_RSN_CMNT,
                             NULL,                           --PRNT_RCVRY_REF,
                             NULL,                               --DPST_SLP_DT
                             mPrntLoanApp);

                ---------------------------------------------------------
                EXIT;
            END IF;

            mLnItmNum := mLnItmNum + 1;

            -- in case the installment is completed then update the status
            IF mPymtSchedSeq <> rdl.pymt_sched_dtl_seq
            THEN
--                DBMS_OUTPUT.put_line (
--                       'update psd sts Tot inst amt:'
--                    || mTotalInstDueAmt
--                    || ' mInstPaidAmt:'
--                    || mInstPaidAmt);
--                DBMS_OUTPUT.put_line (
--                    'update psd mpymtdtlseq:' || mPymtSchedSeq);

                IF mPymtSchedSeq <> 0
                THEN
--                    DBMS_OUTPUT.put_line (
--                           'update psd sts Tot inst amt:'
--                        || mTotalInstDueAmt
--                        || ' mInstPaidAmt:'
--                        || mInstPaidAmt);

                    IF mTotalInstDueAmt = mInstPaidAmt AND mInstPaidAmt <> 0
                    THEN
--                        DBMS_OUTPUT.put_line ('inside udate psd');
                        updtPymtSchedDtl (mInstDueDt,
                                          mPymtDt,
                                          mPymtSchedSeq,
                                          mUsrId);

                        -- if last then update loan App status
                        IF pLstInstFlg = 1 AND mPostFlg = 1
                        THEN
                            IF mPrntLoanFlg = 0
                            THEN
                                IF loan_app_ost (pLoanAppSeq,
                                                 SYSDATE + 1,
                                                 'psc') =
                                   0
                                THEN
                                    IF clnt_ost (mClntSeq,
                                                 SYSDATE + 1,
                                                 'psc') =
                                       0
                                    THEN
                                        UpdateLaStsByClnt (mClntSeq,
                                                           mUsrId,
                                                           mPymtDt);
                                    ELSE
                                        UpdateLaStsByLoan (pLoanAppSeq,
                                                           mUsrId,
                                                           mPymtDt);
                                    END IF;
                                END IF;
                            ELSE
                                IF clnt_ost (mClntSeq, SYSDATE + 1, 'psc') =
                                   0
                                THEN
                                    UpdateLaStsByLoan (pLoanAppSeq,
                                                       mUsrId,
                                                       mPymtDt);
                                END IF;
                            END IF;
                        END IF;
                    END IF;

--                    DBMS_OUTPUT.put_line (
--                           'update prtl psd sts '
--                        || mTotalInstDueAmt
--                        || '-'
--                        || mInstPaidAmt);

                    IF mTotalInstDueAmt - mInstPaidAmt > 0
                    THEN              -- check ost amount for last installment
                        -- Update Partial Status
                        updtPymtSchedDtl (mInstDueDt,
                                          NULL,
                                          mPymtSchedSeq,
                                          mUsrId);
                    END IF;
                END IF;

                mInstPaidAmt := rdl.total_inst_paid_amt;
                pLstInstFlg := 0;
                mPymtSchedSeq := rdl.pymt_sched_dtl_seq;
                mInstDueDt := rdl.due_dt;
                pLoanAppSeq := rdl.loan_app_seq;
                mprntloanflg := rdl.prnt_loan_flg;

                IF rdl.inst_num = rdl.lst_inst
                THEN
                    pLstInstFlg := 1;
                END IF;

                mTotalInstDueAmt := rdl.Total_inst_due_amt;
--                DBMS_OUTPUT.put_line (
--                    'value assigned mTotalInstDueAmt:' || mTotalInstDueAmt);
            END IF;

            --dbms_output.put_line('Total Paid:'||mTotalPaidAmt||' Payment Amount: '||mPymtAmt);
            IF mTotalPaidAmt < mPymtAmt
            THEN
                IF mTotalPaidAmt + rdl.due_amt <= mPymtAmt
                THEN
                    mApldamt := rdl.due_amt;
                ELSE
                    mApldamt := mPymtAmt - mTotalPaidAmt;
                END IF;

                --dbms_output.put_line('insert '||mclntseq||' inst seq:' || rdl.PYMT_SCHED_DTL_SEQ||' :' ||rdl.chrg_seq||' :'||mApldamt);
                INSERT INTO mw_rcvry_dtl
                     VALUES (rcvry_chrg_seq.NEXTVAL,         --RCVRY_CHRG_SEQ,
                             SYSDATE,                          --EFF_START_DT,
                             mRcvry_trx_seq,                  --RCVRY_TRX_SEQ,
                             rdl.chrg_seq,                     --CHRG_TYP_KEY,
                             mApldamt,                             --PYMT_AMT,
                             mUsrId,                                --CRTD_BY,
                             SYSDATE,                               --CRTD_DT,
                             mUsrId,                            --LAST_UPD_BY,
                             SYSDATE,                           --LAST_UPD_DT,
                             0,                                     --DEL_FLG,
                             NULL,                               --EFF_END_DT,
                             1,                                --CRNT_REC_FLG,
                             rdl.PYMT_SCHED_DTL_SEQ,
                             0);

                BEGIN
                    UPDATE mw_rcvry_trx trxx
                       SET trxx.PRNT_LOAN_APP_SEQ = rdl.PrntLoanApp
                     WHERE     trxx.RCVRY_TRX_SEQ = mRcvry_trx_seq
                           AND trxx.PRNT_LOAN_APP_SEQ IS NULL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                -- Insert JV Dtl Entry
                IF mPostFlg = 1
                THEN
                    crtJvDtlRec (mJvHdrSeq,
                                 rdl.gl_acct_num,
                                 mAgntGlCd,
                                 mApldamt,
                                 mLnItmNum);
                END IF;

                mInstPaidAmt := mInstPaidAmt + mApldamt;
                mTotalPaidAmt := mTotalPaidAmt + mApldamt;
            --dbms_output.put_line('mInstPaidAmt '||mInstPaidAmt);
            ELSE
                EXIT;
            END IF;
        END LOOP;

        IF mTotalInstDueAmt - mInstPaidAmt > 0 AND mInstPaidAmt > 0
        THEN                          -- check ost amount for last installment
            -- Update Partial Status
--            DBMS_OUTPUT.put_line (
--                   'inside prtl sts '
--                || mTotalInstDueAmt
--                || ' : '
--                || mInstPaidAmt);
                
            updtPymtSchedDtl (mInstDueDt,
                              NULL,
                              mPymtSchedSeq,
                              mUsrId);
        END IF;

        IF pLoanAppSeq > 0
        THEN
            IF loan_app_ost (pLoanAppSeq, SYSDATE + 1, 'psc') = 0
            THEN
                UpdateLaStsByLoan (pLoanAppSeq, mUsrId, mPymtDt);
            END IF;
        END IF;

        IF pLstInstFlg = 1
        THEN
            IF mTotalInstDueAmt = mInstPaidAmt AND mInstPaidAmt <> 0
            THEN
                updtPymtSchedDtl (mInstDueDt,
                                  mPymtDt,
                                  mPymtSchedSeq,
                                  mUsrId);

                -- if last then update loan App status
                IF pLstInstFlg = 1 AND mPostFlg = 1
                THEN
                    IF mPrntLoanFlg = 0
                    THEN
                        IF loan_app_ost (pLoanAppSeq, SYSDATE + 1, 'psc') = 0
                        THEN
                            IF clnt_ost (mClntSeq, SYSDATE + 1, 'psc') = 0
                            THEN
                                UpdateLaStsByClnt (mClntSeq, mUsrId, mPymtDt);
                            ELSE
                                UpdateLaStsByLoan (pLoanAppSeq,
                                                   mUsrId,
                                                   mPymtDt);
                            END IF;
                        END IF;
                    ELSE
                        IF clnt_ost (mClntSeq, SYSDATE + 1, 'psc') = 0
                        THEN
                            UpdateLaStsByLoan (pLoanAppSeq, mUsrId, mPymtDt);
                        END IF;
                    END IF;
                END IF;
            END IF;

            IF mTotalInstDueAmt - mInstPaidAmt > 0 AND mInstPaidAmt > 0
            THEN
                -- Update Partial Status
                updtPymtSchedDtl (mInstDueDt,
                                  NULL,
                                  mPymtSchedSeq,
                                  mUsrId);
            END IF;
        END IF;

        -- Create excess Recovery
        IF mPymtAmt - NVL (mTotalPaidamt, 0) > 0
        THEN
            BEGIN
                -- jv dtl
                INSERT INTO mw_rcvry_dtl
                     VALUES (rcvry_chrg_seq.NEXTVAL,         --RCVRY_CHRG_SEQ,
                             SYSDATE,                          --EFF_START_DT,
                             mRcvry_trx_seq,                  --RCVRY_TRX_SEQ,
                             241,                              --CHRG_TYP_KEY,
                             mPymtAmt - NVL (mTotalPaidamt, 0),    --PYMT_AMT,
                             mUsrId,                                --CRTD_BY,
                             SYSDATE,                               --CRTD_DT,
                             mUsrId,                            --LAST_UPD_BY,
                             SYSDATE,                           --LAST_UPD_DT,
                             0,                                     --DEL_FLG,
                             NULL,                               --EFF_END_DT,
                             1,                                --CRNT_REC_FLG,
                             NULL,
                             0);
            END;

            -- Jv Dtl Record
            -- get ER gl code
            IF mPostFlg = 1
            THEN
                BEGIN
                    SELECT gl_acct_num
                      INTO mERglCd
                      FROM mw_typs typ
                     WHERE typ.crnt_rec_flg = 1 AND typ.typ_seq = 241;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;             -- Excess Recovery Gl code not found
                END;

                -- jv Header for Excess Recovery
                mJvNart :=
                       ' Excess Recovery received from Client '
                    || NVL (mClntNm, ' ');
                mJvHdrSeq := jv_hdr_seq.NEXTVAL;

                INSERT INTO mw_jv_hdr (JV_HDR_SEQ,
                                       PRNT_VCHR_REF,
                                       JV_ID,
                                       JV_DT,
                                       JV_DSCR,
                                       JV_TYP_KEY,
                                       enty_seq,
                                       ENTY_TYP,
                                       CRTD_BY,
                                       POST_FLG,
                                       RCVRY_TRX_SEQ,
                                       BRNCH_SEQ)
                         VALUES (
                             mJvHdrSeq,                          --JV_HDR_SEQ,
                             NULL,                            --PRNT_VCHR_REF,
                             mJvHdrSeq,                               --JV_ID,
                             TO_DATE (mPymtDt || ' 13:00:00',
                                      'dd-mon-rrrr hh24:mi:ss'),      --JV_DT,
                             mJvnart,                               --JV_DSCR,
                             NULL,                               --JV_TYP_KEY,
                             mRcvry_trx_seq,                        --enty_seq
                             'EXCESS RECOVERY',                    --ENTY_TYP,
                             mUsrId,                                --CRTD_BY,
                             1,                                    --POST_FLG,
                             mRcvry_trx_seq,                  --RCVRY_TRX_SEQ,
                             mBrnchSeq                             --BRNCH_SEQ
                                      );

                crtJvDtlRec (mJvHdrSeq,
                             mERglCd,
                             mAgntGlCd,
                             mPymtAmt - NVL (mTotalPaidamt, 0),
                             mLnItmNum);

                IF pLoanAppSeq > 0
                THEN
                    IF loan_app_ost (pLoanAppSeq, SYSDATE + 1, 'psc') = 0
                    THEN
                        UpdateLaStsByLoan (pLoanAppSeq, mUsrId, mPymtDt);
                    END IF;
                END IF;
            END IF;
        END IF;

        COMMIT; -- COMMIT REQUIRED DUE TO BULK RECOVERY: 30-DEC-2022
        
        
    EXCEPTION
        WHEN OTHERS
        THEN
            --DBMS_OUTPUT.put_line ('inside exception');
            ROLLBACK;
            err_code := SQLCODE;
            err_msg := SUBSTR (SQLERRM, 1, 200);

            INSERT INTO mw_rcvry_load_log
                 VALUES (SYSDATE,
                         mClntSeq,
                         err_code,
                         err_msg,
                         mInstNum,
                         mPymtDt,
                         mPymtAmt,
                         mTypSeq);

             --COMMIT; // UPDATE BY YOUSAF DATED: 30-DEC-2022
    END;

    PROCEDURE updtPymtSchedDtl (mInstDueDt         DATE,
                                mPymtDt            DATE,
                                mPymtSchedDtlSeq   NUMBER,
                                mUserId            VARCHAR)
    IS
        mStatusKey   NUMBER;
    BEGIN
        IF mPymtDt IS NULL
        THEN
            mStatusKey := 1145;
        ELSE
            mStatusKey :=
                CASE
                    WHEN mPymtDt < mInstDueDt THEN 947
                    WHEN mPymtDt = mInstDueDt THEN 946
                    ELSE 948
                END;
        END IF;

        UPDATE mw_pymt_sched_dtl
           SET pymt_sts_key = mStatusKey
         WHERE pymt_sched_dtl_seq = mPymtSchedDtlSeq;

        IF SQL%NOTFOUND
        THEN
            raise_application_error (
                -20010,
                'Uncable to update Payment sched status',
                TRUE);
        END IF;
    END;
    PROCEDURE updtPymtSchedDtl_LOAN_ADJSTMNT (mInstDueDt         DATE,
                                mPymtDt            DATE,
                                mPymtSchedDtlSeq   NUMBER,
                                mUserId            VARCHAR)
    IS
        mStatusKey   NUMBER;
    BEGIN
        UPDATE mw_pymt_sched_dtl
           SET pymt_sts_key = 949,
               LAST_UPD_BY = mUserId,
               LAST_UPD_DT = SYSDATE
         WHERE pymt_sched_dtl_seq = mPymtSchedDtlSeq;
    END;
    PROCEDURE UpdateLaStsByClnt (pClntSeq   NUMBER,
                                 mUserid    VARCHAR,
                                 mPymtDt    DATE)
    IS
        laRow   mw_loan_app%ROWTYPE;

        CURSOR actLns IS
            SELECT loan_app_seq
              FROM mw_loan_app
             WHERE     crnt_rec_flg = 1
                   AND loan_app_sts = 703
                   AND clnt_seq = pClntSeq;
    BEGIN
        FOR rec IN actLns
        LOOP
            SELECT *
              INTO laRow
              FROM mw_loan_app
             WHERE crnt_rec_flg = 1 AND loan_app_seq = rec.loan_app_seq;

            IF SQL%NOTFOUND
            THEN
                raise_application_error (-1720,
                                         'Unable to update Loan App status',
                                         TRUE);
            END IF;

            laRow.loan_app_sts := 704;
            laRow.loan_app_sts_dt := NVL (mPymtDt, SYSDATE);
            laRow.eff_start_dt := SYSDATE;
            laRow.last_upd_dt := SYSDATE;
            laRow.last_upd_by := 'R-' || mUserid;

            UPDATE mw_loan_app
               SET loan_app_sts_dt = NVL (mPymtDt, SYSDATE),
                   eff_end_dt = SYSDATE,
                   loan_app_sts = 704,
                   last_upd_dt = SYSDATE,
                   last_upd_by = 'R-' || mUserid
             WHERE loan_app_seq = rec.loan_app_seq;
        --insert into mw_loan_app values laRow;
        END LOOP;
    END;

    PROCEDURE UpdateLaStsByLoan (pLoanAppSeq   NUMBER,
                                 mUserId       VARCHAR,
                                 mPymtDt       DATE)
    IS
        laRow   mw_loan_app%ROWTYPE;
    BEGIN
        SELECT *
          INTO laRow
          FROM mw_loan_app
         WHERE crnt_rec_flg = 1 AND loan_app_seq = pLoanAppSeq;

        --update mw_loan_app set crnt_rec_flg=0, eff_end_dt = sysdate where loan_app_seq=pLoanAppSeq;
        IF SQL%NOTFOUND
        THEN
            raise_application_error (-1720,
                                     'Unable to update Loan App status',
                                     TRUE);
        END IF;

        laRow.loan_app_sts := 704;
        laRow.loan_app_sts_dt := NVL (mPymtDt, SYSDATE);
        laRow.eff_start_dt := SYSDATE;
        laRow.last_upd_dt := SYSDATE;
        laRow.last_upd_by := 'R-' || mUserid;

        UPDATE mw_loan_app
           SET loan_app_sts_dt = NVL (mPymtDt, SYSDATE),
               eff_end_dt = SYSDATE,
               loan_app_sts = 704,
               last_upd_dt = SYSDATE,
               last_upd_by = 'R-' || mUserid
         WHERE loan_app_seq = pLoanAppSeq;
    --insert into mw_loan_app values laRow;
    END;

    ------------------------------------------------------------------------------


    FUNCTION getGlAcct (mTypSeq NUMBER)
        RETURN VARCHAR
    IS
        retval   VARCHAR2 (35);
    BEGIN
        SELECT gl_acct_num
          INTO retval
          FROM mw_typs tp
         WHERE tp.crnt_rec_flg = 1 AND tp.typ_seq = mTypSeq;

        RETURN retval;
    END;

    PROCEDURE crtJvDtlRec (jvHdrSeq    NUMBER,
                           GlCd0       VARCHAR,
                           glCd1       VARCHAR,
                           mAmt        NUMBER,
                           mLnItmNum   NUMBER)
    IS
    BEGIN
        -- 0 Record
        INSERT INTO mw_jv_dtl
             VALUES (jv_dtl_seq.NEXTVAL,                         --JV_DTL_SEQ,
                     jvHdrSeq,                                   --JV_HDR_SEQ,
                     0,                                        --CRDT_DBT_FLG,
                     mAmt,                                              --AMT,
                     GlCd0,                                     --GL_ACCT_NUM,
                     'Credit',                                         --DSCR,
                     mLnItmNum                                    --LN_ITM_NUM
                              );

        -- 1 Record
        INSERT INTO mw_jv_dtl
             VALUES (jv_dtl_seq.NEXTVAL,                         --JV_DTL_SEQ,
                     jvHdrSeq,                                   --JV_HDR_SEQ,
                     1,                                        --CRDT_DBT_FLG,
                     mAmt,                                              --AMT,
                     GlCd1,                                     --GL_ACCT_NUM,
                     'Debit',                                          --DSCR,
                     mLnItmNum                                    --LN_ITM_NUM
                              );
    END;

    PROCEDURE PostAdjRecClnt (mInstNum       VARCHAR,
                              mPymtDt        DATE,
                              mPymtAmt       NUMBER,
                              mTypSeq        NUMBER,
                              mClntSeq       NUMBER,
                              mUsrId         VARCHAR,
                              mBrnchSeq      NUMBER,
                              mAgntNm        VARCHAR,
                              mClntNm        VARCHAR,
                              mPrntLoanApp   NUMBER)
    IS
        CURSOR dtlRec (vClntSeq NUMBER)
        IS
            WITH
                ClntQry
                AS
                    (  SELECT /*+ MATERIALIZE */
                              *
                         FROM (-- Principal Amount
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      -1
                                          chrg_seq,
                                        psd.ppal_amt_due
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key = -1),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      (SELECT adj_ordr
                                         FROM mw_prd_chrg_adj_ordr ordr
                                        WHERE     ordr.crnt_rec_flg = 1
                                              AND ordr.prd_seq = app.prd_seq
                                              AND prd_chrg_seq = -1)
                                          adj_ordr,
                                      (SELECT DT_OF_INCDNT
                                         FROM MW_INCDNT_RPT dth
                                        WHERE     dth.clnt_seq = app.clnt_seq
                                              AND dth.crnt_rec_flg = 1
                                              AND TRUNC (dth.DT_OF_INCDNT) >=
                                                  (SELECT TRUNC (dsbmt_dt)
                                                     FROM mw_dsbmt_vchr_hdr dvh
                                                    WHERE     dvh.loan_app_seq =
                                                              psh.loan_app_seq
                                                          AND dvh.crnt_rec_flg =
                                                              1))
                                          dth_dt,
                                      (SELECT gl_acct_num
                                         FROM mw_prd_acct_set pas
                                        WHERE     pas.crnt_rec_flg = 1
                                              AND pas.prd_seq = app.prd_seq
                                              AND pas.acct_ctgry_key = 255)
                                          gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                WHERE     psh.crnt_rec_flg = 1
                                      AND app.loan_app_sts IN (703, 1245)
                               UNION
                               -- srvc charges
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      tp.typ_seq,
                                        psd.tot_chrg_due
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key =
                                                        (SELECT chrg_typ_seq
                                                           FROM mw_prd_chrg psc
                                                                JOIN mw_typs tp
                                                                    ON     tp.typ_seq =
                                                                           psc.chrg_typ_seq
                                                                       AND tp.crnt_rec_flg =
                                                                           1
                                                                       AND tp.typ_id =
                                                                           '0017'
                                                          WHERE     psc.crnt_rec_flg =
                                                                    1
                                                                AND psc.prd_seq =
                                                                    app.prd_seq)),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      (SELECT adj_ordr
                                         FROM mw_prd_chrg_adj_ordr ordr
                                        WHERE     ordr.crnt_rec_flg = 1
                                              AND ordr.prd_seq = app.prd_seq
                                              AND prd_chrg_seq =
                                                  (SELECT prd_chrg_seq
                                                     FROM mw_prd_chrg psc
                                                          JOIN mw_typs tp
                                                              ON     tp.typ_seq =
                                                                     psc.chrg_typ_seq
                                                                 AND tp.crnt_rec_flg =
                                                                     1
                                                                 AND tp.typ_id =
                                                                     '0017'
                                                    WHERE     psc.crnt_rec_flg =
                                                              1
                                                          AND psc.prd_seq =
                                                              app.prd_seq))
                                          adj_ordr,
                                      (SELECT DT_OF_INCDNT
                                         FROM MW_INCDNT_RPT dth
                                        WHERE     dth.clnt_seq = app.clnt_seq
                                              AND dth.crnt_rec_flg = 1
                                              AND TRUNC (dth.DT_OF_INCDNT) >=
                                                  (SELECT TRUNC (dsbmt_dt)
                                                     FROM mw_dsbmt_vchr_hdr dvh
                                                    WHERE     dvh.loan_app_seq =
                                                              psh.loan_app_seq
                                                          AND dvh.crnt_rec_flg =
                                                              1))
                                          dth_dt,
                                      tp.gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg psc
                                          ON     psc.prd_seq = app.prd_seq
                                             AND psc.crnt_rec_flg = 1
                                      JOIN mw_typs tp
                                          ON     tp.typ_seq = psc.chrg_typ_seq
                                             AND tp.crnt_rec_flg = 1
                                             AND tp.typ_id = '0017'
                                WHERE     psh.crnt_rec_flg = 1
                                      AND app.loan_app_sts IN (703, 1245)
                               UNION
                               -- KSZB
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      psc.chrg_typs_seq,
                                        psc.amt
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key =
                                                        psc.chrg_typs_seq),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      (SELECT adj_ordr
                                         FROM mw_prd_chrg_adj_ordr ordr
                                        WHERE     ordr.crnt_rec_flg = 1
                                              AND ordr.prd_seq = app.prd_seq
                                              AND prd_chrg_seq = -2)
                                          adj_ordr,
                                      (SELECT DT_OF_INCDNT
                                         FROM MW_INCDNT_RPT dth
                                        WHERE     dth.clnt_seq = app.clnt_seq
                                              AND dth.crnt_rec_flg = 1
                                              AND TRUNC (dth.DT_OF_INCDNT) >=
                                                  (SELECT TRUNC (dsbmt_dt)
                                                     FROM mw_dsbmt_vchr_hdr dvh
                                                    WHERE     dvh.loan_app_seq =
                                                              psh.loan_app_seq
                                                          AND dvh.crnt_rec_flg =
                                                              1))
                                          dth_dt,
                                      (SELECT hip.gl_acct_num     gl_acct_num
                                         FROM mw_clnt_hlth_insr chi
                                              JOIN MW_HLTH_INSR_PLAN hip
                                                  ON     hip.hlth_insr_plan_seq =
                                                         chi.hlth_insr_plan_seq
                                                     AND (   hip.crnt_rec_flg =
                                                             1
                                                          OR (    hip.crnt_rec_flg =
                                                                  0
                                                              AND hip.hlth_insr_plan_seq =
                                                                  1243))
                                              JOIN mw_pymt_sched_hdr hdr
                                                  ON     hdr.loan_app_seq =
                                                         chi.loan_app_seq
                                                     AND hdr.crnt_rec_flg = 1
                                              JOIN mw_pymt_sched_dtl dtl
                                                  ON     dtl.pymt_sched_hdr_seq =
                                                         hdr.pymt_sched_hdr_seq
                                                     AND dtl.crnt_rec_flg = 1
                                        WHERE     chi.crnt_rec_flg = 1
                                              AND hip.PLAN_ID != '1223'
                                              AND dtl.pymt_sched_dtl_seq =
                                                  psd.pymt_sched_dtl_seq)
                                          gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_chrg psc
                                          ON     psc.pymt_sched_dtl_seq =
                                                 psd.pymt_sched_dtl_seq
                                             AND psc.crnt_rec_flg = 1
                                WHERE     psh.crnt_rec_flg = 1
                                      AND psc.chrg_typs_seq = -2
                                      AND app.loan_app_sts IN (703, 1245)
                               UNION
                               -- other charges
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      psc.chrg_typs_seq,
                                        psc.amt
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key =
                                                        psc.chrg_typs_seq),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      ordr.adj_ordr,
                                      (SELECT DT_OF_INCDNT
                                         FROM MW_INCDNT_RPT dth
                                        WHERE     dth.clnt_seq = app.clnt_seq
                                              AND dth.crnt_rec_flg = 1
                                              AND TRUNC (dth.DT_OF_INCDNT) >=
                                                  (SELECT TRUNC (dsbmt_dt)
                                                     FROM mw_dsbmt_vchr_hdr dvh
                                                    WHERE     dvh.loan_app_seq =
                                                              psh.loan_app_seq
                                                          AND dvh.crnt_rec_flg =
                                                              1))
                                          dth_dt,
                                      tp.gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_chrg psc
                                          ON     psc.pymt_sched_dtl_seq =
                                                 psd.pymt_sched_dtl_seq
                                             AND psc.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg pc
                                          ON pc.chrg_typ_seq =
                                             psc.chrg_typs_seq
                                      JOIN mw_typs tp
                                          ON     tp.typ_seq = pc.chrg_typ_seq
                                             AND tp.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg_adj_ordr ordr
                                          ON     ordr.prd_chrg_seq =
                                                 pc.prd_chrg_seq
                                             AND ordr.prd_seq = app.prd_seq
                                             AND ordr.crnt_rec_flg = 1
                                WHERE     psh.crnt_rec_flg = 1
                                      AND psc.chrg_typs_seq NOT IN (-2, 1)
                                      AND app.loan_app_sts IN (703, 1245)
                               UNION
                               -- doc charges
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      psc.chrg_typs_seq,
                                        psc.amt
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key =
                                                        psc.chrg_typs_seq),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      ordr.adj_ordr,
                                      (SELECT DT_OF_INCDNT
                                         FROM MW_INCDNT_RPT dth
                                        WHERE     dth.clnt_seq = app.clnt_seq
                                              AND dth.crnt_rec_flg = 1
                                              AND TRUNC (dth.DT_OF_INCDNT) >=
                                                  (SELECT TRUNC (dsbmt_dt)
                                                     FROM mw_dsbmt_vchr_hdr dvh
                                                    WHERE     dvh.loan_app_seq =
                                                              psh.loan_app_seq
                                                          AND dvh.crnt_rec_flg =
                                                              1))
                                          dth_dt,
                                      tp.gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_chrg psc
                                          ON     psc.pymt_sched_dtl_seq =
                                                 psd.pymt_sched_dtl_seq
                                             AND psc.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg pc
                                          ON pc.chrg_typ_seq =
                                             psc.chrg_typs_seq
                                      JOIN mw_typs tp
                                          ON     tp.typ_seq = pc.chrg_typ_seq
                                             AND tp.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg_adj_ordr ordr
                                          ON     ordr.prd_chrg_seq =
                                                 pc.prd_chrg_seq
                                             AND ordr.prd_seq = app.prd_seq
                                             AND ordr.crnt_rec_flg = 1
                                WHERE     psh.crnt_rec_flg = 1
                                      AND psc.chrg_typs_seq = 1
                                      AND app.loan_app_sts IN (703, 1245))
                     ORDER BY due_dt, prd_seq, adj_ordr)
            SELECT *
              FROM clntQry
             WHERE due_amt > 0;

        mRcvry_trx_seq      NUMBER;
        mPymtSchedSeq       NUMBER;
        mInstDueAmt         NUMBER;
        mInstPaidAmt        NUMBER;
        mTotalPaidAmt       NUMBER;
        mApldamt            NUMBER;
        mInstDueDt          DATE;
        mJvHdrSeq           NUMBER;
        mAgntGlCd           VARCHAR2 (35);
        mLnItmNum           NUMBER;
        mERglCd             VARCHAR2 (35);
        mPrdStr             VARCHAR2 (200);
        mJvNart             VARCHAR2 (500);
        err_code            VARCHAR2 (25);
        err_msg             VARCHAR2 (500);
        pLoanAppSeq         NUMBER;
        pLstInstFlg         NUMBER;
        mTotalInstDueAmt    NUMBER;
        mTotalInstPaidAmt   NUMBER;
        mPrntLoanFlg        NUMBER;
    BEGIN
        mRcvry_trx_seq := RCVRY_TRX_seq.NEXTVAL;
        mAgntGlCd := getGlAcct (mTypSeq);
        mLnItmNum := 0;
        pLoanAppSeq := 0;

        -- Get client and prd info for gl header
        BEGIN
            SELECT LISTAGG (prd_cmnt, ',') WITHIN GROUP (ORDER BY ap.prd_seq)
                       prd_cmnt
              INTO mPrdStr
              FROM mw_prd  prd
                   JOIN mw_loan_app ap
                       ON     ap.prd_seq = prd.prd_seq
                          AND ap.crnt_rec_flg = 1
                          AND ap.loan_app_sts IN (703, 1245)
                   JOIN mw_clnt clnt
                       ON     clnt.clnt_seq = ap.clnt_seq
                          AND clnt.crnt_rec_flg = 1
             WHERE prd.crnt_rec_flg = 1 AND ap.clnt_seq = mClntSeq;
        END;

        --dbms_output.put_line('recovery record');
        -- ======= create record in Recovery Trx table
        INSERT INTO mw_rcvry_trx
             VALUES (mRcvry_trx_seq,                           --RCVRY_TRX_SEQ
                     SYSDATE,                                   --EFF_START_DT
                     NVL (mInstNum, mRcvry_trx_seq), --INSTR_NUM --------- Yousaf
                     SYSDATE,                                        --PYMT_DT
                     mPymtAmt,                                      --PYMT_AMT
                     mTypSeq,                                  --RCVRY_TYP_SEQ
                     mClntSeq,                                  --PYMT_MOD_KEY
                     0,                                        --PYMT_STS_KEY,
                     mUsrId,                                        --CRTD_BY,
                     SYSDATE,                                      -- CRTD_DT,
                     mUsrId,                                    --LAST_UPD_BY,
                     SYSDATE,                                   --LAST_UPD_DT,
                     0,                                             --DEL_FLG,
                     NULL,                                       --EFF_END_DT,
                     1,                                        --CRNT_REC_FLG,
                     mClntSeq,                                     --PYMT_REF,
                     1,                                            --POST_FLG,
                     NULL,                                     --CHNG_RSN_KEY,
                     'KRK adjustment recovery',               --CHNG_RSN_CMNT,
                     NULL,                                   --PRNT_RCVRY_REF,
                     NULL,                                       --DPST_SLP_DT
                     mPrntLoanApp);

        -- =========== create JV header Record
        -- if client is dead then create Access Recovery
        -- Create JV Header
        mJvNart :=
               NVL (mPrdStr, ' ')
            || ' Recovery received from Client '
            || NVL (mClntNm, ' ')
            || ' through '
            || NVL (mAgntNm, ' ');
        --mJvNart := 'Performance test';
        mJvHdrSeq := jv_hdr_seq.NEXTVAL;

        BEGIN
            INSERT INTO mw_jv_hdr (JV_HDR_SEQ,
                                   PRNT_VCHR_REF,
                                   JV_ID,
                                   JV_DT,
                                   JV_DSCR,
                                   JV_TYP_KEY,
                                   enty_seq,
                                   ENTY_TYP,
                                   CRTD_BY,
                                   POST_FLG,
                                   RCVRY_TRX_SEQ,
                                   BRNCH_SEQ)
                 VALUES (mJvHdrSeq,                              --JV_HDR_SEQ,
                         NULL,                                --PRNT_VCHR_REF,
                         mJvHdrSeq,                                   --JV_ID,
                         SYSDATE,                                     --JV_DT,
                         mJvnart,                                   --JV_DSCR,
                         NULL,                                   --JV_TYP_KEY,
                         mRcvry_trx_seq,                            --enty_seq
                         'Recovery',                               --ENTY_TYP,
                         mUsrId,                                    --CRTD_BY,
                         1,                                        --POST_FLG,
                         mRcvry_trx_seq,                      --RCVRY_TRX_SEQ,
                         mBrnchSeq                                 --BRNCH_SEQ
                                  );
        END;

        -- ================================================================
        -- =========== Create Recovery Detail Records =====================
        -- ================================================================
        mPymtSchedSeq := 0;                    --previous installment sequence
        mTotalPaidAmt := 0;

        --dbms_output.put_line('rcvry outside loop '||mClntSeq);
        FOR rdl IN dtlRec (mClntSeq)
        LOOP
            --=== client/nominee reported as dead apply then Excess Recovery
            --dbms_output.put_line('inside rdl loop installment'||rdl.pymt_sched_dtl_seq||' mPymtSeq:'||mPymtSchedSeq);
            IF rdl.dth_dt > rdl.dsbmt_dt
            THEN
                ROLLBACK;

                ----------  for dth Excess Recovery ---------
                INSERT INTO mw_rcvry_trx
                     VALUES (mRcvry_trx_seq,                   --RCVRY_TRX_SEQ
                             SYSDATE,                           --EFF_START_DT
                             NVL (mInstNum, mRcvry_trx_seq), --INSTR_NUM --------- Yousaf
                             SYSDATE,                                --PYMT_DT
                             mPymtAmt,                              --PYMT_AMT
                             mTypSeq,                          --RCVRY_TYP_SEQ
                             mClntSeq,                          --PYMT_MOD_KEY
                             0,                                --PYMT_STS_KEY,
                             mUsrId,                                --CRTD_BY,
                             SYSDATE,                              -- CRTD_DT,
                             mUsrId,                            --LAST_UPD_BY,
                             SYSDATE,                           --LAST_UPD_DT,
                             0,                                     --DEL_FLG,
                             NULL,                               --EFF_END_DT,
                             1,                                --CRNT_REC_FLG,
                             mClntSeq,                             --PYMT_REF,
                             1,                                    --POST_FLG,
                             NULL,                             --CHNG_RSN_KEY,
                             'KRK adjustment recovery',       --CHNG_RSN_CMNT,
                             NULL,                           --PRNT_RCVRY_REF,
                             NULL,                               --DPST_SLP_DT
                             mPrntLoanApp);

                ---------------------------------------------------------
                EXIT;
            END IF;

            mLnItmNum := mLnItmNum + 1;

            -- in case the installment is completed then update the status
            IF mPymtSchedSeq <> rdl.pymt_sched_dtl_seq
            THEN
                --dbms_output.put_line('update psd sts Tot inst amt:'||mTotalInstDueAmt||' mInstPaidAmt:'||mInstPaidAmt);
                --dbms_output.put_line('update psd mpymtdtlseq:'||mPymtSchedSeq);
                IF mPymtSchedSeq <> 0
                THEN
                    --dbms_output.put_line('update psd sts Tot inst amt:'||mTotalInstDueAmt||' mInstPaidAmt:'||mInstPaidAmt);
                    IF mTotalInstDueAmt = mInstPaidAmt AND mInstPaidAmt <> 0
                    THEN
                        --dbms_output.put_line('inside udate psd');
                        updtPymtSchedDtl (mInstDueDt,
                                          mPymtDt,
                                          mPymtSchedSeq,
                                          mUsrId);

                        -- if last then update loan App status
                        IF pLstInstFlg = 1
                        THEN
                            IF mPrntLoanFlg = 0
                            THEN
                                IF loan_app_ost (pLoanAppSeq,
                                                 SYSDATE + 1,
                                                 'psc') =
                                   0
                                THEN
                                    IF clnt_ost (mClntSeq,
                                                 SYSDATE + 1,
                                                 'psc') =
                                       0
                                    THEN
                                        UpdateLaStsByClnt (mClntSeq,
                                                           mUsrId,
                                                           mPymtDt);
                                    ELSE
                                        UpdateLaStsByLoan (pLoanAppSeq,
                                                           mUsrId,
                                                           mPymtDt);
                                    END IF;
                                END IF;
                            ELSE
                                IF clnt_ost (mClntSeq, SYSDATE + 1, 'psc') =
                                   0
                                THEN
                                    UpdateLaStsByLoan (pLoanAppSeq,
                                                       mUsrId,
                                                       mPymtDt);
                                END IF;
                            END IF;
                        END IF;
                    END IF;

                    -- dbms_output.put_line('update prtl psd sts '||mTotalInstDueAmt||'-'||mInstPaidAmt);
                    IF mTotalInstDueAmt - mInstPaidAmt > 0
                    THEN              -- check ost amount for last installment
                        -- Update Partial Status
                        updtPymtSchedDtl (mInstDueDt,
                                          NULL,
                                          mPymtSchedSeq,
                                          mUsrId);
                    END IF;
                END IF;

                mInstPaidAmt := rdl.total_inst_paid_amt;
                pLstInstFlg := 0;
                mPymtSchedSeq := rdl.pymt_sched_dtl_seq;
                mInstDueDt := rdl.due_dt;
                pLoanAppSeq := rdl.loan_app_seq;
                mprntloanflg := rdl.prnt_loan_flg;

                IF rdl.inst_num = rdl.lst_inst
                THEN
                    pLstInstFlg := 1;
                END IF;

                mTotalInstDueAmt := rdl.Total_inst_due_amt;
            -- dbms_output.put_line('value assigned mTotalInstDueAmt:'||mTotalInstDueAmt);
            END IF;

            --dbms_output.put_line('Total Paid:'||mTotalPaidAmt||' Payment Amount: '||mPymtAmt);
            IF mTotalPaidAmt < mPymtAmt
            THEN
                IF mTotalPaidAmt + rdl.due_amt <= mPymtAmt
                THEN
                    mApldamt := rdl.due_amt;
                ELSE
                    mApldamt := mPymtAmt - mTotalPaidAmt;
                END IF;

                --dbms_output.put_line('insert '||mclntseq||' inst seq:' || rdl.PYMT_SCHED_DTL_SEQ||' :' ||rdl.chrg_seq||' :'||mApldamt);
                INSERT INTO mw_rcvry_dtl
                     VALUES (rcvry_chrg_seq.NEXTVAL,         --RCVRY_CHRG_SEQ,
                             SYSDATE,                          --EFF_START_DT,
                             mRcvry_trx_seq,                  --RCVRY_TRX_SEQ,
                             rdl.chrg_seq,                     --CHRG_TYP_KEY,
                             mApldamt,                             --PYMT_AMT,
                             mUsrId,                                --CRTD_BY,
                             SYSDATE,                               --CRTD_DT,
                             mUsrId,                            --LAST_UPD_BY,
                             SYSDATE,                           --LAST_UPD_DT,
                             0,                                     --DEL_FLG,
                             NULL,                               --EFF_END_DT,
                             1,                                --CRNT_REC_FLG,
                             rdl.PYMT_SCHED_DTL_SEQ,
                             0);

                -- Insert JV Dtl Entry

                IF     (rdl.due_dt) > TO_DATE (SYSDATE)
                   AND rdl.gl_acct_num IN
                           ('000.000.404714.00000', '000.000.404717.00000') -------  for KRK, IP, LSIP , Yousaf
                THEN
                    SELECT DFRD_ACCT_NUM
                      INTO mAgntGlCd
                      FROM mw_typs mt
                     WHERE     mt.GL_ACCT_NUM = rdl.gl_acct_num
                           AND mt.CRNT_REC_FLG = 1
                           AND mt.TYP_CTGRY_KEY = 1; -------  for KRK , Yousaf

                    --dbms_output.put_line('debit account head ip OR lsip'||mAgntGlCd);
                    recovery.crtJvDtlRec (mJvHdrSeq,
                                          rdl.gl_acct_num,
                                          mAgntGlCd,
                                          mApldamt,
                                          mLnItmNum);
                ELSIF rdl.gl_acct_num IN
                          ('000.000.404709.00000', '000.000.404721.00000')
                THEN
                    SELECT DISTINCT DFRD_ACCT_NUM
                      INTO mAgntGlCd
                      FROM MW_HLTH_INSR_PLAN hp
                     WHERE     hp.GL_ACCT_NUM = rdl.gl_acct_num -------  for KRK, KSZB, KC , Yousaf
                           AND hp.CRNT_REC_FLG = 1;

                    --dbms_output.put_line('debit account head kszb'||mAgntGlCd);
                    recovery.crtJvDtlRec (mJvHdrSeq,
                                          rdl.gl_acct_num,
                                          mAgntGlCd,
                                          mApldamt,
                                          mLnItmNum);
                ELSE
                    mAgntGlCd := getGlAcct (mTypSeq);
                    --DBMS_OUTPUT.put_line ('else debit account ' || mAgntGlCd);
                    recovery.crtJvDtlRec (mJvHdrSeq,
                                          rdl.gl_acct_num,
                                          mAgntGlCd,
                                          mApldamt,
                                          mLnItmNum);
                END IF;

                mInstPaidAmt := mInstPaidAmt + mApldamt;
                mTotalPaidAmt := mTotalPaidAmt + mApldamt;
            --dbms_output.put_line('mInstPaidAmt '||mInstPaidAmt);
            ELSE
                EXIT;
            END IF;
        END LOOP;

        IF mTotalInstDueAmt - mInstPaidAmt > 0 AND mInstPaidAmt > 0
        THEN                          -- check ost amount for last installment
            -- Update Partial Status
            --dbms_output.put_line('inside prtl sts '||mTotalInstDueAmt||' : '||mInstPaidAmt );
            updtPymtSchedDtl (mInstDueDt,
                              NULL,
                              mPymtSchedSeq,
                              mUsrId);
        END IF;

        IF pLstInstFlg = 1
        THEN
            IF mTotalInstDueAmt = mInstPaidAmt AND mInstPaidAmt <> 0
            THEN
                updtPymtSchedDtl (mInstDueDt,
                                  mPymtDt,
                                  mPymtSchedSeq,
                                  mUsrId);

                -- if last then update loan App status
                IF pLstInstFlg = 1
                THEN
                    IF mPrntLoanFlg = 0
                    THEN
                        IF loan_app_ost (pLoanAppSeq, SYSDATE + 1, 'psc') = 0
                        THEN
                            IF clnt_ost (mClntSeq, SYSDATE + 1, 'psc') = 0
                            THEN
                                UpdateLaStsByClnt (mClntSeq, mUsrId, mPymtDt);
                            ELSE
                                UpdateLaStsByLoan (pLoanAppSeq,
                                                   mUsrId,
                                                   mPymtDt);
                            END IF;
                        END IF;
                    ELSE
                        IF clnt_ost (mClntSeq, SYSDATE + 1, 'psc') = 0
                        THEN
                            UpdateLaStsByLoan (pLoanAppSeq, mUsrId, mPymtDt);
                        END IF;
                    END IF;
                END IF;
            END IF;

            IF mTotalInstDueAmt - mInstPaidAmt > 0 AND mInstPaidAmt > 0
            THEN
                -- Update Partial Status
                updtPymtSchedDtl (mInstDueDt,
                                  NULL,
                                  mPymtSchedSeq,
                                  mUsrId);
            END IF;
        END IF;

        -- Create excess Recovery
        IF mPymtAmt - NVL (mTotalPaidamt, 0) > 0
        THEN
            BEGIN
                -- jv dtl
                INSERT INTO mw_rcvry_dtl
                     VALUES (rcvry_chrg_seq.NEXTVAL,         --RCVRY_CHRG_SEQ,
                             SYSDATE,                          --EFF_START_DT,
                             mRcvry_trx_seq,                  --RCVRY_TRX_SEQ,
                             241,                              --CHRG_TYP_KEY,
                             mPymtAmt - NVL (mTotalPaidamt, 0),    --PYMT_AMT,
                             mUsrId,                                --CRTD_BY,
                             SYSDATE,                               --CRTD_DT,
                             mUsrId,                            --LAST_UPD_BY,
                             SYSDATE,                           --LAST_UPD_DT,
                             0,                                     --DEL_FLG,
                             NULL,                               --EFF_END_DT,
                             1,                                --CRNT_REC_FLG,
                             NULL,
                             0);
            END;

            -- Jv Dtl Record
            -- get ER gl code
            BEGIN
                SELECT gl_acct_num
                  INTO mERglCd
                  FROM mw_typs typ
                 WHERE typ.crnt_rec_flg = 1 AND typ.typ_seq = 241;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;                 -- Excess Recovery Gl code not found
            END;

            -- jv Header for Excess Recovery
            mJvNart :=
                   ' Excess Recovery received from Client '
                || NVL (mClntNm, ' ');
            mJvHdrSeq := jv_hdr_seq.NEXTVAL;

            INSERT INTO mw_jv_hdr (JV_HDR_SEQ,
                                   PRNT_VCHR_REF,
                                   JV_ID,
                                   JV_DT,
                                   JV_DSCR,
                                   JV_TYP_KEY,
                                   enty_seq,
                                   ENTY_TYP,
                                   CRTD_BY,
                                   POST_FLG,
                                   RCVRY_TRX_SEQ,
                                   BRNCH_SEQ)
                 VALUES (mJvHdrSeq,                              --JV_HDR_SEQ,
                         NULL,                                --PRNT_VCHR_REF,
                         mJvHdrSeq,                                   --JV_ID,
                         SYSDATE,                                     --JV_DT,
                         mJvnart,                                   --JV_DSCR,
                         NULL,                                   --JV_TYP_KEY,
                         mRcvry_trx_seq,                            --enty_seq
                         'EXCESS RECOVERY',                        --ENTY_TYP,
                         mUsrId,                                    --CRTD_BY,
                         1,                                        --POST_FLG,
                         mRcvry_trx_seq,                      --RCVRY_TRX_SEQ,
                         mBrnchSeq                                 --BRNCH_SEQ
                                  );

            crtJvDtlRec (mJvHdrSeq,
                         mERglCd,
                         mAgntGlCd,
                         mPymtAmt - NVL (mTotalPaidamt, 0),
                         mLnItmNum);
        END IF;

         --COMMIT; // UPDATE BY YOUSAF DATED: 30-DEC-2022
    EXCEPTION
        WHEN OTHERS
        THEN
            --DBMS_OUTPUT.put_line ('inside exception');
            ROLLBACK;
            err_code := SQLCODE;
            err_msg := SUBSTR (SQLERRM, 1, 200);

            INSERT INTO mw_rcvry_load_log
                 VALUES (SYSDATE,
                         mClntSeq,
                         err_code,
                         err_msg,
                         mInstNum,
                         mPymtDt,
                         mPymtAmt,
                         mTypSeq);

             --COMMIT; // UPDATE BY YOUSAF DATED: 30-DEC-2022
    END;

    PROCEDURE adjust_krk_recovery (p_clnt_seq       NUMBER,
                                   mUsrId           VARCHAR2,
                                   p_msg        OUT VARCHAR2)
    AS
        v_adj_amt        NUMBER;
        mBrnchSeq        NUMBER;
        mClntNm          VARCHAR2 (200);
        mPrdSeq          NUMBER;
        mLoanApp         NUMBER;
        mPrntLoanApp     NUMBER;
        mLoanAppExists   NUMBER;
        err_code         VARCHAR2 (25);
        err_msg          VARCHAR2 (500);
        --p_msg varchar2(200);
        app_exist        NUMBER := 0;
    BEGIN
        SELECT COUNT (ap.LOAN_APP_SEQ)
          INTO app_exist
          FROM mw_loan_app ap
         WHERE     ap.clnt_seq = p_clnt_seq
               AND ap.CRNT_REC_FLG = 1
               AND (   ap.LOAN_APP_STS = 703
                    OR (    ap.LOAN_APP_STS = 704
                        AND ap.LOAN_APP_STS_DT > '01-jan-2020'))
               AND loan_app_ost (ap.LOAN_APP_SEQ, TO_DATE (SYSDATE), 'ps') >
                   0;

        IF app_exist > 0
        THEN
            FOR i
                IN (  SELECT ap.LOAN_APP_SEQ
                        FROM mw_loan_app ap
                       WHERE     ap.clnt_seq = p_clnt_seq
                             AND ap.CRNT_REC_FLG = 1
                             AND (   ap.LOAN_APP_STS = 703
                                  OR (    ap.LOAN_APP_STS = 704
                                      AND ap.LOAN_APP_STS_DT > '01-jan-2020'))
                             AND loan_app_ost (ap.LOAN_APP_SEQ,
                                               TO_DATE (SYSDATE),
                                               'psc') >
                                 0
                    ORDER BY 1)
            LOOP
--                DBMS_OUTPUT.put_line (
--                    'before pymt insert ' || i.LOAN_APP_SEQ);

                INSERT INTO MW_PYMT_SCHED_DTL_RVSAL (PYMT_SCHED_DTL_SEQ,
                                                     EFF_START_DT,
                                                     PYMT_SCHED_HDR_SEQ,
                                                     INST_NUM,
                                                     DUE_DT,
                                                     PPAL_AMT_DUE,
                                                     TOT_CHRG_DUE,
                                                     CRTD_BY,
                                                     CRTD_DT,
                                                     LAST_UPD_BY,
                                                     LAST_UPD_DT,
                                                     DEL_FLG,
                                                     EFF_END_DT,
                                                     CRNT_REC_FLG,
                                                     PYMT_STS_KEY,
                                                     SYNC_FLG)
                    SELECT psd.PYMT_SCHED_DTL_SEQ,
                           psd.EFF_START_DT,
                           psd.PYMT_SCHED_HDR_SEQ,
                           psd.INST_NUM,
                           psd.DUE_DT,
                           psd.PPAL_AMT_DUE,
                           psd.TOT_CHRG_DUE,
                           psd.CRTD_BY,
                           psd.CRTD_DT,
                           psd.LAST_UPD_BY,
                           psd.LAST_UPD_DT,
                           psd.DEL_FLG,
                           psd.EFF_END_DT,
                           psd.CRNT_REC_FLG,
                           psd.PYMT_STS_KEY,
                           psd.SYNC_FLG
                      FROM MW_PYMT_SCHED_HDR psh, MW_PYMT_SCHED_DTL psd
                     WHERE     psh.PYMT_SCHED_HDR_SEQ =
                               psd.PYMT_SCHED_HDR_SEQ
                           AND psh.CRNT_REC_FLG = 1
                           AND psd.CRNT_REC_FLG = 1
                           AND psh.LOAN_APP_SEQ = i.LOAN_APP_SEQ;

--                DBMS_OUTPUT.put_line (
--                    'before pymt sc update ' || i.LOAN_APP_SEQ);

                BEGIN
                    UPDATE MW_PYMT_SCHED_DTL psd
                       SET psd.TOT_CHRG_DUE = 0
                     WHERE psd.PYMT_SCHED_DTL_SEQ IN
                               (SELECT psd.PYMT_SCHED_DTL_SEQ
                                  FROM MW_PYMT_SCHED_HDR  psh,
                                       MW_PYMT_SCHED_DTL  psd
                                 WHERE     psh.PYMT_SCHED_HDR_SEQ =
                                           psd.PYMT_SCHED_HDR_SEQ
                                       AND psh.CRNT_REC_FLG = 1
                                       AND psd.CRNT_REC_FLG = 1
                                       AND psh.LOAN_APP_SEQ = i.LOAN_APP_SEQ
                                       AND psd.PYMT_STS_KEY = 945
                                       AND psd.DUE_DT > SYSDATE);
                EXCEPTION
                    WHEN NO_DATA_FOUND --- if no further installment remaining
                    THEN
                        ROLLBACK;
                        err_code := SQLCODE;
                        err_msg := SUBSTR (SQLERRM, 1, 200);
                        p_msg :=
                               'Recovery adjustement failed Pymt Schdl update failed-> Error Code:'
                            || err_code
                            || ' Error Msg: '
                            || err_msg;
                END;

--                DBMS_OUTPUT.put_line (
--                    'after pymt sc update ' || i.LOAN_APP_SEQ);
            END LOOP;

            BEGIN
--                DBMS_OUTPUT.put_line (
--                    'before paramaeters selection ' || p_clnt_seq);

                  SELECT mBrnchSeq,
                         mClntNm,
                         SUM (adj_amt),
                         MIN (mPrdSeq),
                         MIN (loan_app_seq)          loan_app_seq,
                         MIN (prnt_loan_app_seq)     mPrntLoanApp
                    INTO mBrnchSeq,
                         mClntNm,
                         v_adj_amt,
                         mPrdSeq,
                         mLoanApp,
                         mPrntLoanApp
                    FROM (SELECT ap.clnt_Seq,
                                 NVL (
                                     loan_app_ost (ap.LOAN_APP_SEQ,
                                                   TO_DATE (SYSDATE),
                                                   'psc'),
                                     0)
                                     adj_amt,
                                 app.brnch_seq
                                     mBrnchSeq,
                                 mc.FRST_NM || ' ' || mc.LAST_NM
                                     mClntNm,
                                 ap.PRD_SEQ
                                     mPrdSeq,
                                 ap.loan_app_seq,
                                 ap.prnt_loan_app_seq
                            FROM PRE_COVID_APR20_OUTS_LOAN_APPS app,
                                 mw_loan_app                   ap,
                                 mw_clnt                       mc
                           WHERE     app.LOAN_APP_SEQ = ap.LOAN_APP_SEQ
                                 AND ap.CRNT_REC_FLG = 1
                                 AND ap.CLNT_SEQ = mc.CLNT_SEQ
                                 AND mc.CRNT_REC_FLG = 1
                                 AND loan_app_ost (ap.LOAN_APP_SEQ,
                                                   TO_DATE (SYSDATE),
                                                   'psc') >
                                     0
                                 AND mc.clnt_Seq = p_clnt_seq)
                GROUP BY clnt_Seq, mBrnchSeq, mClntNm;

--                DBMS_OUTPUT.put_line (
--                    'after paramaeters selection ' || p_clnt_seq);

                IF (mPrdSeq IN (4, 29))
                THEN
                    PostAdjRecClnt (NULL,
                                    SYSDATE,
                                    v_adj_amt,
                                    16188,
                                    p_clnt_seq,
                                    mUsrId,
                                    mBrnchSeq,
                                    'LOAN PORTFOLIO ADJUSTMENT.KKK',
                                    LTRIM (RTRIM (mClntNm)),
                                    mPrntLoanApp);
                ELSIF (mPrdSeq IN (25, 26))
                THEN
                    PostAdjRecClnt (NULL,
                                    SYSDATE,
                                    v_adj_amt,
                                    16190,
                                    p_clnt_seq,
                                    mUsrId,
                                    mBrnchSeq,
                                    'LOAN PORTFOLIO ADJUSTMENT.KMK Dairy',
                                    LTRIM (RTRIM (mClntNm)),
                                    mPrntLoanApp);
                ELSIF (mPrdSeq IN (10))
                THEN
                    PostAdjRecClnt (NULL,
                                    SYSDATE,
                                    v_adj_amt,
                                    16191,
                                    p_clnt_seq,
                                    mUsrId,
                                    mBrnchSeq,
                                    'LOAN PORTFOLIO ADJUSTMENT.KM',
                                    LTRIM (RTRIM (mClntNm)),
                                    mPrntLoanApp);
                ELSIF (mPrdSeq IN (15, 16))
                THEN
                    PostAdjRecClnt (NULL,
                                    SYSDATE,
                                    v_adj_amt,
                                    16192,
                                    p_clnt_seq,
                                    mUsrId,
                                    mBrnchSeq,
                                    'LOAN PORTFOLIO ADJUSTMENT.KSS',
                                    LTRIM (RTRIM (mClntNm)),
                                    mPrntLoanApp);
                ELSIF (mPrdSeq IN (30, 31, 32))
                THEN
                    PostAdjRecClnt (NULL,
                                    SYSDATE,
                                    v_adj_amt,
                                    16193,
                                    p_clnt_seq,
                                    mUsrId,
                                    mBrnchSeq,
                                    'LOAN PORTFOLIO ADJUSTMENT.KMK Meat',
                                    LTRIM (RTRIM (mClntNm)),
                                    mPrntLoanApp);
                END IF;

                --DBMS_OUTPUT.put_line ('after PostAdjRecClnt');

                SELECT COUNT (*)
                  INTO mLoanAppExists
                  FROM mw_loan_app ap
                 WHERE     ap.LOAN_APP_SEQ = mLoanApp
                       AND ap.LOAN_APP_STS = 703
                       AND ap.CRNT_REC_FLG = 1;

                IF mLoanAppExists > 0
                THEN
                    ROLLBACK;
                    p_msg :=
                           'Recovery adjustement failed-> Error Code:'
                        || err_code
                        || ' Error Msg: Issue Pymt and Rec data'
                        || err_msg;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;
                    err_code := SQLCODE;
                    err_msg := SUBSTR (SQLERRM, 1, 200);
                    p_msg :=
                           'Recovery adjustement failed-> Error Code:'
                        || err_code
                        || ' Error Msg: '
                        || err_msg;
            END;

            IF p_msg IS NULL
            THEN
                p_msg := 'Recovery successfully adjusted';
                 --COMMIT; // UPDATE BY YOUSAF DATED: 30-DEC-2022
            END IF;
        ELSE
            p_msg :=
                   'Recovery adjustement failed-> Error Code:'
                || 'No active client found'
                || ' Error Msg: '
                || 'Recovery not posted';
        END IF;
    END;

    PROCEDURE reverse_krk_recovery (p_clnt_seq       NUMBER,
                                    mUsrId           VARCHAR2,
                                    p_msg        OUT VARCHAR2)
    AS
        v_RCVRY_TRX_SEQ   NUMBER;
        v_JV_HDR_SEQ      NUMBER;
        v_JV_HDR_SEQ_     NUMBER;
        err_code          VARCHAR2 (25);
        err_msg           VARCHAR2 (200);
        v_LOAN_APP_SEQ    NUMBER;
    BEGIN
        BEGIN
            FOR i
                IN (SELECT DISTINCT rcd.PYMT_SCHED_DTL_SEQ, rch.RCVRY_TRX_SEQ
                      FROM mw_rcvry_trx rch, mw_rcvry_dtl rcd
                     WHERE     rch.PYMT_REF = p_clnt_seq
                           AND rch.CRNT_REC_FLG = 1
                           AND rch.POST_FLG = 1
                           AND rch.RCVRY_TRX_SEQ = rcd.RCVRY_TRX_SEQ
                           AND rcd.CRNT_REC_FLG = 1
                           AND rch.CHNG_RSN_CMNT = 'KRK adjustment recovery')
            LOOP
                UPDATE MW_PYMT_SCHED_DTL psd
                   SET psd.TOT_CHRG_DUE =
                           (SELECT psdr.TOT_CHRG_DUE
                              FROM MW_PYMT_SCHED_DTL_RVSAL psdr
                             WHERE     psdr.PYMT_SCHED_DTL_SEQ =
                                       psd.PYMT_SCHED_DTL_SEQ
                                   AND psdr.CRNT_REC_FLG = 1),
                       psd.PYMT_STS_KEY =
                           (SELECT psdr.PYMT_STS_KEY
                              FROM MW_PYMT_SCHED_DTL_RVSAL psdr
                             WHERE     psdr.PYMT_SCHED_DTL_SEQ =
                                       psd.PYMT_SCHED_DTL_SEQ
                                   AND psdr.CRNT_REC_FLG = 1)
                 WHERE     psd.PYMT_SCHED_DTL_SEQ = i.PYMT_SCHED_DTL_SEQ
                       AND psd.CRNT_REC_FLG = 1;

                UPDATE MW_PYMT_SCHED_DTL_RVSAL psdr
                   SET psdr.CRNT_REC_FLG = 0
                 WHERE     psdr.PYMT_SCHED_DTL_SEQ = i.PYMT_SCHED_DTL_SEQ
                       AND psdr.CRNT_REC_FLG = 1;

                v_RCVRY_TRX_SEQ := i.RCVRY_TRX_SEQ;
            END LOOP;

            UPDATE mw_loan_app ap
               SET ap.LOAN_APP_STS = 703,
                   ap.loan_app_sts_dt =
                       (SELECT MAX (dsbmt_dt)
                          FROM MW_DSBMT_VCHR_HDR INN
                         WHERE     INN.loan_app_seq = ap.loan_app_seq
                               AND INN.crnt_Rec_flg = 1),
                   ap.LAST_UPD_DT = SYSDATE,
                   ap.LAST_UPD_BY = mUsrId
             WHERE     ap.LOAN_APP_SEQ IN
                           (SELECT DISTINCT psh.LOAN_APP_SEQ
                              FROM mw_rcvry_trx       rch,
                                   mw_rcvry_dtl       rcd,
                                   MW_PYMT_SCHED_DTL  psd,
                                   MW_PYMT_SCHED_HDR  psh
                             WHERE     rch.PYMT_REF = p_clnt_seq
                                   AND rch.CRNT_REC_FLG = 1
                                   AND rch.POST_FLG = 1
                                   AND rch.RCVRY_TRX_SEQ = rcd.RCVRY_TRX_SEQ
                                   AND rcd.PYMT_SCHED_DTL_SEQ =
                                       psd.PYMT_SCHED_DTL_SEQ
                                   AND psd.CRNT_REC_FLG = 1
                                   AND psd.PYMT_SCHED_HDR_SEQ =
                                       psh.PYMT_SCHED_HDR_SEQ
                                   AND psh.CRNT_REC_FLG = 1
                                   AND rcd.CRNT_REC_FLG = 1
                                   AND rch.CHNG_RSN_CMNT =
                                       'KRK adjustment recovery')
                   AND ap.CRNT_REC_FLG = 1
                   AND ap.LOAN_APP_STS = 704;

            UPDATE mw_rcvry_dtl rcd
               SET rcd.CRNT_REC_FLG = 0,
                   rcd.DEL_FLG = 1,
                   rcd.LAST_UPD_BY = mUsrId,
                   rcd.LAST_UPD_DT = SYSDATE
             WHERE     rcd.RCVRY_TRX_SEQ = v_RCVRY_TRX_SEQ
                   AND rcd.CRNT_REC_FLG = 1;

            UPDATE mw_rcvry_trx rch
               SET rch.CRNT_REC_FLG = 0,
                   rch.DEL_FLG = 1,
                   rch.LAST_UPD_BY = mUsrId,
                   rch.LAST_UPD_DT = SYSDATE
             WHERE     rch.RCVRY_TRX_SEQ = v_RCVRY_TRX_SEQ
                   AND rch.PYMT_REF = p_clnt_seq
                   AND rch.CHNG_RSN_CMNT = 'KRK adjustment recovery'
                   AND rch.CRNT_REC_FLG = 1;

            SELECT JV_HDR_SEQ.NEXTVAL INTO v_JV_HDR_SEQ FROM DUAL;

            SELECT JV_HDR_SEQ
              INTO v_JV_HDR_SEQ_
              FROM mw_jv_hdr mjh
             WHERE     mjh.ENTY_SEQ = v_RCVRY_TRX_SEQ
                   AND UPPER (mjh.ENTY_TYP) IN
                           ('RECOVERY', 'EXCESS RECOVERY');

            INSERT INTO MW_JV_HDR (JV_HDR_SEQ,
                                   PRNT_VCHR_REF,
                                   JV_ID,
                                   JV_DT,
                                   JV_DSCR,
                                   JV_TYP_KEY,
                                   ENTY_SEQ,
                                   ENTY_TYP,
                                   CRTD_BY,
                                   POST_FLG,
                                   RCVRY_TRX_SEQ,
                                   BRNCH_SEQ)
                SELECT v_JV_HDR_SEQ,
                       JV_HDR_SEQ,
                       v_JV_HDR_SEQ,
                       SYSDATE,
                       'Reversal ' || JV_DSCR,
                       JV_TYP_KEY,
                       ENTY_SEQ,
                       ENTY_TYP,
                       mUsrId,
                       POST_FLG,
                       RCVRY_TRX_SEQ,
                       BRNCH_SEQ
                  FROM mw_jv_hdr mjh
                 WHERE     mjh.ENTY_SEQ = v_RCVRY_TRX_SEQ
                       AND UPPER (mjh.ENTY_TYP) IN
                               ('RECOVERY', 'EXCESS RECOVERY');

            INSERT INTO MW_JV_DTL (JV_DTL_SEQ,
                                   JV_HDR_SEQ,
                                   CRDT_DBT_FLG,
                                   AMT,
                                   GL_ACCT_NUM,
                                   DSCR,
                                   LN_ITM_NUM)
                SELECT JV_DTL_SEQ.NEXTVAL,
                       v_JV_HDR_SEQ,
                       1,
                       AMT,
                       GL_ACCT_NUM,
                       'Debit',
                       LN_ITM_NUM
                  FROM mw_jv_dtl mjd
                 WHERE     mjd.JV_HDR_SEQ = v_JV_HDR_SEQ_
                       AND mjd.CRDT_DBT_FLG = 0;

            INSERT INTO MW_JV_DTL (JV_DTL_SEQ,
                                   JV_HDR_SEQ,
                                   CRDT_DBT_FLG,
                                   AMT,
                                   GL_ACCT_NUM,
                                   DSCR,
                                   LN_ITM_NUM)
                SELECT JV_DTL_SEQ.NEXTVAL,
                       v_JV_HDR_SEQ,
                       0,
                       AMT,
                       GL_ACCT_NUM,
                       'Credit',
                       LN_ITM_NUM
                  FROM mw_jv_dtl mjd
                 WHERE     mjd.JV_HDR_SEQ = v_JV_HDR_SEQ_
                       AND mjd.CRDT_DBT_FLG = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK;
                err_code := SQLCODE;
                err_msg := SUBSTR (SQLERRM, 1, 180);
                p_msg :=
                       'Recovery reversal failed-> Error Code:'
                    || err_code
                    || ' Error Msg: '
                    || err_msg;
        END;

        IF p_msg IS NULL
        THEN
            p_msg := 'Recovery reversal completed';
             --COMMIT; // UPDATE BY YOUSAF DATED: 30-DEC-2022
        END IF;
    END;



    -----------NEW PROCEDURES--------
    PROCEDURE postRcvryTrx (mTrxSeq NUMBER, mUsrId VARCHAR)
    IS
        CURSOR trx IS
            SELECT trx.pymt_dt,
                   trx.rcvry_trx_seq,
                   clnt.clnt_seq,
                   clnt.frst_nm || ' ' || last_nm
                       clnt_nm,
                   typ.typ_str
                       agnt_nm,
                   prt.brnch_seq,
                   rdl.pymt_amt,
                   CASE
                       WHEN chrg_typ_key = -1
                       THEN
                           (SELECT gl_acct_num
                              FROM mw_prd_acct_set pas
                             WHERE     pas.crnt_rec_flg = 1
                                   AND pas.prd_seq = app.prd_seq
                                   AND pas.acct_ctgry_key = 255)
                       WHEN chrg_typ_key = -2
                       THEN
                           (SELECT hip.gl_acct_num     gl_acct_num
                              FROM mw_clnt_hlth_insr  chi
                                   JOIN mw_hlth_insr_plan hip
                                       ON     hip.hlth_insr_plan_seq =
                                              chi.hlth_insr_plan_seq
                                          AND hip.crnt_rec_flg = 1
                                   JOIN mw_pymt_sched_hdr hdr
                                       ON     hdr.loan_app_seq =
                                              chi.loan_app_seq
                                          AND hdr.crnt_rec_flg = 1
                                   JOIN mw_pymt_sched_dtl dtl
                                       ON     dtl.pymt_sched_hdr_seq =
                                              hdr.pymt_sched_hdr_seq
                                          AND dtl.crnt_rec_flg = 1
                             WHERE     chi.crnt_rec_flg = 1
                                   AND hip.PLAN_ID != '1223'
                                   AND dtl.pymt_sched_dtl_seq =
                                       psd.pymt_sched_dtl_seq)
                       ELSE
                           (SELECT tp.gl_acct_num
                              FROM mw_typs tp
                             WHERE     tp.typ_seq = rdl.chrg_typ_key
                                   AND tp.crnt_rec_flg = 1)
                   END
                       rdl_gl_cd,
                   typ.gl_acct_num
                       agnt_gl_cd,
                   psd.inst_num,
                   MAX (psd.inst_num) OVER (PARTITION BY app.loan_app_seq)
                       lstInstNum,
                   app.loan_app_seq,
                   CASE
                       WHEN app.prnt_loan_app_seq = app.loan_app_seq THEN 1
                       ELSE 0
                   END
                       prnt_loan_flg
              FROM mw_rcvry_trx  trx
                   JOIN mw_rcvry_dtl rdl
                       ON rdl.rcvry_trx_seq = trx.rcvry_trx_seq --and rdl.crnt_rec_flg=1
                   JOIN mw_pymt_sched_dtl psd
                       ON     psd.pymt_sched_dtl_seq = rdl.pymt_sched_dtl_seq
                          AND psd.crnt_rec_flg = 1
                   JOIN mw_pymt_sched_hdr psh
                       ON     psh.pymt_sched_hdr_seq = psd.pymt_sched_hdr_seq
                          AND psh.crnt_rec_flg = 1
                   JOIN mw_loan_app app
                       ON     app.loan_app_seq = psh.loan_app_seq
                          AND app.crnt_rec_flg = 1
                   JOIN mw_clnt clnt
                       ON     clnt.clnt_seq = trx.pymt_ref
                          AND clnt.crnt_rec_flg = 1
                   JOIN mw_port prt
                       ON     prt.port_seq = clnt.port_key
                          AND prt.crnt_rec_flg = 1
                   JOIN mw_typs typ
                       ON     typ.typ_seq = trx.rcvry_typ_seq
                          AND typ.crnt_rec_flg = 1
             WHERE trx.rcvry_trx_seq = mTrxSeq AND rdl.chrg_typ_key <> 241;

        --- excess Recovery Cursor
        CURSOR exc IS
            SELECT trx.pymt_dt,
                   trx.rcvry_trx_seq,
                   clnt.clnt_seq,
                   clnt.frst_nm || ' ' || last_nm
                       clnt_nm,
                   prt.brnch_seq,
                   rdl.pymt_amt,
                   (SELECT tp.gl_acct_num
                      FROM mw_typs tp
                     WHERE     tp.typ_seq = rdl.chrg_typ_key
                           AND tp.crnt_rec_flg = 1)
                       ex_gl_cd,
                   typ.gl_acct_num
                       agnt_gl_cd
              FROM mw_rcvry_trx  trx
                   JOIN mw_rcvry_dtl rdl
                       ON rdl.rcvry_trx_seq = trx.rcvry_trx_seq --and rdl.crnt_rec_flg=1
                   JOIN mw_clnt clnt
                       ON     clnt.clnt_seq = trx.pymt_ref
                          AND clnt.crnt_rec_flg = 1
                   JOIN mw_port prt
                       ON     prt.port_seq = clnt.port_key
                          AND prt.crnt_rec_flg = 1
                   JOIN mw_typs typ
                       ON     typ.typ_seq = trx.rcvry_typ_seq
                          AND typ.crnt_rec_flg = 1
             WHERE     trx.rcvry_trx_seq = mTrxSeq
                   AND trx.post_flg = 0
                   AND chrg_typ_key = 241;

        mJvHdrSeq      VARCHAR2 (35);
        frstRc         NUMBER;
        mJvNart        VARCHAR2 (100);
        mLnItmNum      NUMBER;
        mLoanAppSeq    NUMBER;
        pLstInstFlg    NUMBER;
        mClntSeq       NUMBER;
        mPrntLoanFlg   NUMBER;
        err_code       VARCHAR2 (25);
        err_msg        VARCHAR2 (500);
    BEGIN
        mJvHdrSeq := jv_hdr_seq.NEXTVAL;
        frstRc := 0;
        mLnItmNum := 0;
        mLoanAppSeq := 0;
        mPrntLoanFlg := 0;
        mClntSeq := 0;

        FOR rec IN trx
        LOOP
            -- update status
            IF mloanappseq <> rec.loan_app_seq AND mLoanAppSeq <> 0
            THEN
                -- update status
                IF pLstInstFlg = 1
                THEN
                    IF mPrntLoanFlg = 0
                    THEN
                        IF loan_app_ost (mLoanAppSeq, SYSDATE + 1, 'psc') = 0
                        THEN
                            IF clnt_ost (rec.clnt_seq, SYSDATE + 1, 'psc') =
                               0
                            THEN
                                UpdateLaStsByClnt (rec.clnt_seq,
                                                   mUsrId,
                                                   SYSDATE);
                            ELSE
                                UpdateLaStsByLoan (mLoanAppSeq,
                                                   mUsrId,
                                                   SYSDATE);
                            END IF;
                        END IF;
                    ELSE
                        IF clnt_ost (rec.clnt_seq, SYSDATE + 1, 'psc') = 0
                        THEN
                            UpdateLaStsByLoan (mLoanAppSeq, mUsrId, SYSDATE);
                        END IF;
                    END IF;
                END IF;
            END IF;

            IF frstRc = 0
            THEN
                -- insert jv hdr table
                mJvNart :=
                       NVL (getPrdStr (rec.clnt_seq), ' ')
                    || ' Recovery received from Client '
                    || NVL (rec.clnt_nm, ' ')
                    || ' through '
                    || NVL (rec.agnt_nm, ' ');

                INSERT INTO mw_jv_hdr (JV_HDR_SEQ,
                                       PRNT_VCHR_REF,
                                       JV_ID,
                                       JV_DT,
                                       JV_DSCR,
                                       JV_TYP_KEY,
                                       enty_seq,
                                       ENTY_TYP,
                                       CRTD_BY,
                                       POST_FLG,
                                       RCVRY_TRX_SEQ,
                                       BRNCH_SEQ)
                         VALUES (
                             mJvHdrSeq,                          --JV_HDR_SEQ,
                             NULL,                            --PRNT_VCHR_REF,
                             mJvHdrSeq,                               --JV_ID,
                             TO_DATE (rec.pymt_dt || ' 13:00:00',
                                      'dd-mon-rrrr hh24:mi:ss'),      --JV_DT,
                             mJvnart,                               --JV_DSCR,
                             NULL,                               --JV_TYP_KEY,
                             rec.Rcvry_trx_seq,                     --enty_seq
                             'Recovery',                           --ENTY_TYP,
                             mUsrId,                                --CRTD_BY,
                             1,                                    --POST_FLG,
                             rec.rcvry_trx_seq,               --RCVRY_TRX_SEQ,
                             rec.brnch_seq                         --BRNCH_SEQ
                                          );

                frstRc := 1;
            END IF;

            mLnItmNum := mLnItmNum + 1;
            crtJvDtlRec (mJvHdrSeq,
                         rec.rdl_gl_cd,
                         rec.agnt_gl_cd,
                         rec.pymt_amt,
                         mLnItmNum);

            IF rec.inst_num = rec.lstInstNum
            THEN
                pLstInstFlg := 1;
            END IF;

            mPrntLoanFlg := rec.prnt_loan_flg;
            mLoanAppSeq := rec.loan_app_seq;
            mClntSeq := rec.clnt_seq;
        END LOOP;

        --- update status if last installment
--        DBMS_OUTPUT.put_line ('update status' || pLstInstFlg);

        IF pLstInstFlg = 1
        THEN
--            DBMS_OUTPUT.put_line ('update status');

            IF mPrntLoanFlg = 0
            THEN
                IF loan_app_ost (mLoanAppSeq, SYSDATE + 1, 'psc') = 0
                THEN
                    IF clnt_ost (mClntSeq, SYSDATE + 1, 'psc') = 0
                    THEN
                        UpdateLaStsByClnt (mClntSeq, mUsrId, SYSDATE);
                    ELSE
                        UpdateLaStsByLoan (mLoanAppSeq, mUsrId, SYSDATE);
                    END IF;
                END IF;
            ELSE
                IF clnt_ost (mClntSeq, SYSDATE + 1, 'psc') = 0
                THEN
                    UpdateLaStsByLoan (mLoanAppSeq, mUsrId, SYSDATE);
                END IF;
            END IF;
        END IF;

        --- Create Excess Recovery if Exists
        mLnItmNum := 0;
--        DBMS_OUTPUT.put_line ('createing Excess Recovery');

        FOR rec IN exc
        LOOP
            -- create jv hdr record
            mJvNart :=
                   ' Excess Recovery received from Client '
                || NVL (rec.clnt_nm, ' ');
            mJvHdrSeq := jv_hdr_seq.NEXTVAL;

            INSERT INTO mw_jv_hdr (JV_HDR_SEQ,
                                   PRNT_VCHR_REF,
                                   JV_ID,
                                   JV_DT,
                                   JV_DSCR,
                                   JV_TYP_KEY,
                                   enty_seq,
                                   ENTY_TYP,
                                   CRTD_BY,
                                   POST_FLG,
                                   RCVRY_TRX_SEQ,
                                   BRNCH_SEQ)
                     VALUES (
                         mJvHdrSeq,                              --JV_HDR_SEQ,
                         NULL,                                --PRNT_VCHR_REF,
                         mJvHdrSeq,                                   --JV_ID,
                         TO_DATE (rec.pymt_dt || ' 13:00:00',
                                  'dd-mon-rrrr hh24:mi:ss'),          --JV_DT,
                         mJvnart,                                   --JV_DSCR,
                         NULL,                                   --JV_TYP_KEY,
                         rec.rcvry_trx_seq,                         --enty_seq
                         'EXCESS RECOVERY',                        --ENTY_TYP,
                         mUsrId,                                    --CRTD_BY,
                         1,                                        --POST_FLG,
                         rec.rcvry_trx_seq,                   --RCVRY_TRX_SEQ,
                         rec.brnch_seq                             --BRNCH_SEQ
                                      );

            mLnItmNum := mLnItmNum + 1;
            crtJvDtlRec (mJvHdrSeq,
                         rec.ex_gl_cd,
                         rec.agnt_gl_cd,
                         rec.pymt_amt,
                         mLnItmNum);
        END LOOP;

        -- update recovery post flg
        BEGIN
--            DBMS_OUTPUT.put_line ('update post flag ' || mTrxSeq);

            UPDATE mw_rcvry_trx
               SET post_flg = 1,
                   last_upd_dt = SYSDATE,
                   last_upd_by = 'R-' || mUsrId
             WHERE rcvry_trx_seq = mTrxSeq;

            IF SQL%NOTFOUND
            THEN
                raise_application_error (-20010,
                                         'Uncable to update Rcvry post Flag',
                                         TRUE);
            END IF;
        END;

         --COMMIT; // UPDATE BY YOUSAF DATED: 30-DEC-2022
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
--                DBMS_OUTPUT.put_line ('inside exception');
                ROLLBACK;
                err_code := SQLCODE;
                err_msg := SUBSTR (SQLERRM, 1, 200);

                INSERT INTO mw_rcvry_load_log
                     VALUES (SYSDATE,
                             mClntSeq,
                             err_code,
                             err_msg,
                             mTrxSeq,
                             NULL,
                             NULL,
                             NULL);

                 --COMMIT; // UPDATE BY YOUSAF DATED: 30-DEC-2022
            END;
    END;

    -------------------------------------

    FUNCTION getPrdStr (mClntSeq NUMBER)
        RETURN VARCHAR
    IS
        vPrdStr   VARCHAR2 (30);
    BEGIN
        BEGIN
            SELECT LISTAGG (prd_cmnt, ',') WITHIN GROUP (ORDER BY ap.prd_seq)
                       prd_cmnt
              INTO vPrdStr
              FROM mw_prd  prd
                   JOIN mw_loan_app ap
                       ON     ap.prd_seq = prd.prd_seq
                          AND ap.crnt_rec_flg = 1
                          AND ap.loan_app_sts IN (703, 1245)
                   JOIN mw_clnt clnt
                       ON     clnt.clnt_seq = ap.clnt_seq
                          AND clnt.crnt_rec_flg = 1
             WHERE prd.crnt_rec_flg = 1 AND ap.clnt_seq = mClntSeq;
        END;

        RETURN vPrdStr;
    END;
PROCEDURE PRC_PPST_LOAN_ASJSTMNT(mInstNum       VARCHAR,
                            mPymtDt        DATE,
                            mPymtAmt       NUMBER,
                            mTypSeq        NUMBER,
                            mClntSeq       NUMBER,
                            mUsrId         VARCHAR,
                            mBrnchSeq      NUMBER,
                            mAgntNm        VARCHAR,
                            mClntNm        VARCHAR,
                            mPostFlg       NUMBER,
                            mMsgOut     OUT VARCHAR)
    IS
        CURSOR dtlRec (vClntSeq NUMBER)
        IS
            WITH
                ClntQry
                AS
                    (  SELECT /*+ MATERIALIZE */
                              *
                         FROM (-- Principal Amount
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      -1
                                          chrg_seq,
                                        psd.ppal_amt_due
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key = -1),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      (SELECT adj_ordr
                                         FROM mw_prd_chrg_adj_ordr ordr
                                        WHERE     ordr.crnt_rec_flg = 1
                                              AND ordr.prd_seq = app.prd_seq
                                              AND prd_chrg_seq = -1)
                                          adj_ordr,
                                       NULL dth_dt, -----------  DUE TO INCIDENT REPORT
                                      (SELECT gl_acct_num
                                         FROM mw_prd_acct_set pas
                                        WHERE     pas.crnt_rec_flg = 1
                                              AND pas.prd_seq = app.prd_seq
                                              AND pas.acct_ctgry_key = 255)
                                          gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt,
                                      app.PRNT_LOAN_APP_SEQ
                                          PrntLoanApp
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                WHERE     psh.crnt_rec_flg = 1
                                      AND app.loan_app_sts IN (703)
                               UNION
                               -- srvc charges
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      tp.typ_seq,
                                        psd.tot_chrg_due
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key =
                                                        (SELECT chrg_typ_seq
                                                           FROM mw_prd_chrg psc
                                                                JOIN mw_typs tp
                                                                    ON     tp.typ_seq =
                                                                           psc.chrg_typ_seq
                                                                       AND tp.crnt_rec_flg =
                                                                           1
                                                                       AND tp.typ_id =
                                                                           '0017'
                                                          WHERE     psc.crnt_rec_flg =
                                                                    1
                                                                AND psc.prd_seq =
                                                                    app.prd_seq)),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      (SELECT adj_ordr
                                         FROM mw_prd_chrg_adj_ordr ordr
                                        WHERE     ordr.crnt_rec_flg = 1
                                              AND ordr.prd_seq = app.prd_seq
                                              AND prd_chrg_seq =
                                                  (SELECT prd_chrg_seq
                                                     FROM mw_prd_chrg psc
                                                          JOIN mw_typs tp
                                                              ON     tp.typ_seq =
                                                                     psc.chrg_typ_seq
                                                                 AND tp.crnt_rec_flg =
                                                                     1
                                                                 AND tp.typ_id =
                                                                     '0017'
                                                    WHERE     psc.crnt_rec_flg =
                                                              1
                                                          AND psc.prd_seq =
                                                              app.prd_seq))
                                          adj_ordr,
                                     NULL dth_dt, -----------  DUE TO INCIDENT REPORT
                                      tp.gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt,
                                      app.PRNT_LOAN_APP_SEQ
                                          PrntLoanApp
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg psc
                                          ON     psc.prd_seq = app.prd_seq
                                             AND psc.crnt_rec_flg = 1
                                      JOIN mw_typs tp
                                          ON     tp.typ_seq = psc.chrg_typ_seq
                                             AND tp.crnt_rec_flg = 1
                                             AND tp.typ_id = '0017'
                                WHERE     psh.crnt_rec_flg = 1
                                      AND app.loan_app_sts IN (703)
                               UNION
                               -- KSZB
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      psc.chrg_typs_seq,
                                        psc.amt
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key =
                                                        psc.chrg_typs_seq),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      (SELECT adj_ordr
                                         FROM mw_prd_chrg_adj_ordr ordr
                                        WHERE     ordr.crnt_rec_flg = 1
                                              AND ordr.prd_seq = app.prd_seq
                                              AND prd_chrg_seq = -2)
                                          adj_ordr,
                                       NULL dth_dt, -----------  DUE TO INCIDENT REPORT
                                      (SELECT hip.gl_acct_num     gl_acct_num
                                         FROM mw_clnt_hlth_insr chi
                                              JOIN MW_HLTH_INSR_PLAN hip
                                                  ON     hip.hlth_insr_plan_seq =
                                                         chi.hlth_insr_plan_seq
                                                     AND (   hip.crnt_rec_flg =
                                                             1
                                                          OR (    hip.crnt_rec_flg =
                                                                  0
                                                              AND hip.hlth_insr_plan_seq =
                                                                  1243))
                                              JOIN mw_pymt_sched_hdr hdr
                                                  ON     hdr.loan_app_seq =
                                                         chi.loan_app_seq
                                                     AND hdr.crnt_rec_flg = 1
                                              JOIN mw_pymt_sched_dtl dtl
                                                  ON     dtl.pymt_sched_hdr_seq =
                                                         hdr.pymt_sched_hdr_seq
                                                     AND dtl.crnt_rec_flg = 1
                                        WHERE     chi.crnt_rec_flg = 1
                                              AND hip.PLAN_ID != '1223'
                                              AND dtl.pymt_sched_dtl_seq =
                                                  psd.pymt_sched_dtl_seq)
                                          gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt,
                                      app.PRNT_LOAN_APP_SEQ
                                          PrntLoanApp
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_chrg psc
                                          ON     psc.pymt_sched_dtl_seq =
                                                 psd.pymt_sched_dtl_seq
                                             AND psc.crnt_rec_flg = 1
                                WHERE     psh.crnt_rec_flg = 1
                                      AND psc.chrg_typs_seq = -2
                                      AND app.loan_app_sts IN (703)
                               UNION
                               -- other charges
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      psc.chrg_typs_seq,
                                        psc.amt
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key =
                                                        psc.chrg_typs_seq),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      ordr.adj_ordr,
                                      NULL dth_dt, -----------  DUE TO INCIDENT REPORT
                                      tp.gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt,
                                      app.PRNT_LOAN_APP_SEQ
                                          PrntLoanApp
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_chrg psc
                                          ON     psc.pymt_sched_dtl_seq =
                                                 psd.pymt_sched_dtl_seq
                                             AND psc.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg pc
                                          ON pc.chrg_typ_seq =
                                             psc.chrg_typs_seq
                                      JOIN mw_typs tp
                                          ON     tp.typ_seq = pc.chrg_typ_seq
                                             AND tp.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg_adj_ordr ordr
                                          ON     ordr.prd_chrg_seq =
                                                 pc.prd_chrg_seq
                                             AND ordr.prd_seq = app.prd_seq
                                             AND ordr.crnt_rec_flg = 1
                                WHERE     psh.crnt_rec_flg = 1
                                      AND psc.chrg_typs_seq NOT IN (-2, 1)
                                      AND app.loan_app_sts IN (703)
                               UNION
                               -- doc charges
                               SELECT app.prd_seq,
                                      CASE
                                          WHEN app.prnt_loan_app_seq =
                                               app.loan_app_seq
                                          THEN
                                              1
                                          ELSE
                                              0
                                      END
                                          prnt_loan_flg,
                                      psd.pymt_sched_dtl_seq,
                                      psh.loan_app_seq,
                                      psd.inst_num,
                                      psc.chrg_typs_seq,
                                        psc.amt
                                      - NVL (
                                            (SELECT SUM (pymt_amt)
                                               FROM mw_rcvry_dtl rd
                                              WHERE     rd.crnt_rec_flg = 1
                                                    AND rd.pymt_sched_dtl_seq =
                                                        psd.pymt_sched_dtl_seq
                                                    AND chrg_typ_key =
                                                        psc.chrg_typs_seq),
                                            0)
                                          due_amt,
                                      psd.due_dt,
                                      (SELECT dsbmt_dt
                                         FROM mw_dsbmt_vchr_hdr dvh
                                        WHERE     dvh.loan_app_seq =
                                                  psh.loan_app_seq
                                              AND dvh.crnt_rec_flg = 1)
                                          dsbmt_dt,
                                      ordr.adj_ordr,
                                      NULL dth_dt, -----------  DUE TO INCIDENT REPORT
                                      tp.gl_acct_num,
                                      (SELECT MAX (inst_num)
                                         FROM mw_pymt_sched_dtl pd
                                        WHERE     pd.pymt_sched_hdr_seq =
                                                  psh.pymt_sched_hdr_seq
                                              AND pd.crnt_rec_flg = 1)
                                          lst_inst,
                                      (  psd.ppal_amt_due
                                       + tot_chrg_due
                                       + NVL (
                                             (SELECT SUM (amt)
                                                FROM mw_pymt_sched_chrg psc
                                               WHERE     psc.crnt_rec_flg = 1
                                                     AND psc.pymt_sched_dtl_seq =
                                                         psd.pymt_sched_dtl_seq),
                                             0))
                                          total_inst_due_amt,
                                      NVL (
                                          (SELECT SUM (pymt_amt)
                                             FROM mw_rcvry_dtl rd
                                            WHERE     rd.crnt_rec_flg = 1
                                                  AND rd.pymt_sched_dtl_seq =
                                                      psd.pymt_sched_dtl_seq),
                                          0)
                                          total_inst_paid_amt,
                                      app.PRNT_LOAN_APP_SEQ
                                          PrntLoanApp
                                 FROM mw_pymt_sched_hdr psh
                                      JOIN mw_loan_app app
                                          ON     app.loan_app_seq =
                                                 psh.loan_app_seq
                                             AND app.crnt_rec_flg = 1
                                             AND app.clnt_seq = vClntSeq
                                      JOIN mw_clnt clnt
                                          ON     clnt.clnt_seq = app.clnt_seq
                                             AND clnt.crnt_rec_flg = 1
                                      JOIN mw_prd prd
                                          ON     prd.prd_seq = app.prd_seq
                                             AND prd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_dtl psd
                                          ON     psd.pymt_sched_hdr_seq =
                                                 psh.pymt_sched_hdr_seq
                                             AND psd.crnt_rec_flg = 1
                                      JOIN mw_pymt_sched_chrg psc
                                          ON     psc.pymt_sched_dtl_seq =
                                                 psd.pymt_sched_dtl_seq
                                             AND psc.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg pc
                                          ON pc.chrg_typ_seq =
                                             psc.chrg_typs_seq
                                      JOIN mw_typs tp
                                          ON     tp.typ_seq = pc.chrg_typ_seq
                                             AND tp.crnt_rec_flg = 1
                                      JOIN mw_prd_chrg_adj_ordr ordr
                                          ON     ordr.prd_chrg_seq =
                                                 pc.prd_chrg_seq
                                             AND ordr.prd_seq = app.prd_seq
                                             AND ordr.crnt_rec_flg = 1
                                WHERE     psh.crnt_rec_flg = 1
                                      AND psc.chrg_typs_seq = 1
                                      AND app.loan_app_sts IN (703))
                     ORDER BY due_dt, prd_seq, adj_ordr)
              SELECT *
                FROM clntQry
               WHERE due_amt > 0
            ORDER BY due_dt, prd_seq, adj_ordr;

        mRcvry_trx_seq      NUMBER;
        mPymtSchedSeq       NUMBER;
        mInstDueAmt         NUMBER;
        mInstPaidAmt        NUMBER;
        mTotalPaidAmt       NUMBER;
        mApldamt            NUMBER;
        mInstDueDt          DATE;
        mJvHdrSeq           NUMBER;
        mAgntGlCd           VARCHAR2 (35);
        mLnItmNum           NUMBER;
        mERglCd             VARCHAR2 (35);
        mPrdStr             VARCHAR2 (200);
        mJvNart             VARCHAR2 (500);
        err_code            VARCHAR2 (25);
        err_msg             VARCHAR2 (500);
        pLoanAppSeq         NUMBER;
        pLstInstFlg         NUMBER;
        mTotalInstDueAmt    NUMBER;
        mTotalInstPaidAmt   NUMBER;
        mPrntLoanFlg        NUMBER;
    BEGIN
        mRcvry_trx_seq := RCVRY_TRX_seq.NEXTVAL;
        mAgntGlCd := getGlAcct (mTypSeq);
        mLnItmNum := 0;
        pLoanAppSeq := 0;
        mPrdStr := getPrdStr (mClntSeq);
        -- Get client and prd info for gl header
        /*       begin
                   select listagg(prd_cmnt,',') within group (order by ap.prd_seq) prd_cmnt
                   into mPrdStr
                   from mw_prd prd
                   join mw_loan_app ap on ap.prd_seq=prd.prd_seq and ap.crnt_rec_flg=1 and ap.loan_app_sts=703
                   join mw_clnt clnt on clnt.clnt_seq=ap.clnt_seq and clnt.crnt_rec_flg=1
                   where prd.crnt_rec_flg=1
                   and ap.clnt_seq=mClntSeq;
               end;
       */
--        DBMS_OUTPUT.put_line ('recovery record');

        -- ======= create record in Recovery Trx table
        INSERT INTO mw_rcvry_trx
                 VALUES (
                     mRcvry_trx_seq,                           --RCVRY_TRX_SEQ
                     SYSDATE,                                   --EFF_START_DT
                     NVL (mInstNum, mRcvry_trx_seq),               --INSTR_NUM
                     TO_DATE (mPymtDt || ' 13:00:00',
                              'dd-mon-rrrr hh24:mi:ss'),             --PYMT_DT
                     mPymtAmt,                                      --PYMT_AMT
                     mTypSeq,                                  --RCVRY_TYP_SEQ
                     mClntSeq,                                  --PYMT_MOD_KEY
                     0,                                        --PYMT_STS_KEY,
                     mUsrId,                                        --CRTD_BY,
                     SYSDATE,                                      -- CRTD_DT,
                     mUsrId,                                    --LAST_UPD_BY,
                     SYSDATE,                                   --LAST_UPD_DT,
                     0,                                             --DEL_FLG,
                     NULL,                                       --EFF_END_DT,
                     1,                                        --CRNT_REC_FLG,
                     mClntSeq,                                     --PYMT_REF,
                     mPostFlg,                                     --POST_FLG,
                     NULL,                                     --CHNG_RSN_KEY,
                     NULL,                                    --CHNG_RSN_CMNT,
                     NULL,                                   --PRNT_RCVRY_REF,
                     NULL,                                      --DPST_SLP_DT,
                     NULL);

        -- =========== create JV header Record
        -- if client is dead then create Access Recovery
        -- Create JV Header
        IF mPostFlg = 1
        THEN
            mJvNart :=
                   NVL (mPrdStr, ' ')
                || ' Loan is adjusted against incident '
                || NVL (mClntNm, ' ')
                || ' through '
                || NVL (mAgntNm, ' ');
            --mJvNart := 'Performance test';
            mJvHdrSeq := jv_hdr_seq.NEXTVAL;

            BEGIN
                INSERT INTO mw_jv_hdr (JV_HDR_SEQ,
                                       PRNT_VCHR_REF,
                                       JV_ID,
                                       JV_DT,
                                       JV_DSCR,
                                       JV_TYP_KEY,
                                       enty_seq,
                                       ENTY_TYP,
                                       CRTD_BY,
                                       POST_FLG,
                                       RCVRY_TRX_SEQ,
                                       BRNCH_SEQ,
                                       CLNT_SEQ,
                                       PYMT_MODE)
                         VALUES (
                             mJvHdrSeq,                          --JV_HDR_SEQ,
                             NULL,                            --PRNT_VCHR_REF,
                             mJvHdrSeq,                               --JV_ID,
                             TO_DATE (mPymtDt || ' 13:00:00',
                                      'dd-mon-rrrr hh24:mi:ss'),      --JV_DT,
                             mJvnart,                               --JV_DSCR,
                             NULL,                               --JV_TYP_KEY,
                             mRcvry_trx_seq,                        --enty_seq
                             'Recovery',                           --ENTY_TYP,
                             mUsrId,                                --CRTD_BY,
                             1,                                    --POST_FLG,
                             mRcvry_trx_seq,                  --RCVRY_TRX_SEQ,
                             mBrnchSeq,                         --BRNCH_SEQ
                             mClntSeq,
                             mTypSeq                             
                                      );
            END;
        END IF;

        -- ================================================================
        -- =========== Create Recovery Detail Records =====================
        -- ================================================================
        mPymtSchedSeq := 0;                    --previous installment sequence
        mTotalPaidAmt := 0;

--        DBMS_OUTPUT.put_line ('rcvry outside loop ' || mClntSeq);

        FOR rdl IN dtlRec (mClntSeq)
        LOOP
            --=== client/nominee reported as dead apply then Excess Recovery
--            DBMS_OUTPUT.put_line (
--                   'inside rdl loop installment'
--                || rdl.pymt_sched_dtl_seq
--                || ' mPymtSeq:'
--                || mPymtSchedSeq);

            IF rdl.dth_dt >= rdl.dsbmt_dt
            THEN
                ROLLBACK;
                ----------  for dth Excess Recovery ---------
                INSERT INTO mw_rcvry_trx
                         VALUES (
                             mRcvry_trx_seq,                   --RCVRY_TRX_SEQ
                             SYSDATE,                           --EFF_START_DT
                             NVL (mInstNum, mRcvry_trx_seq),       --INSTR_NUM
                             TO_DATE (mPymtDt || ' 13:00:00',
                                      'dd-mon-rrrr hh24:mi:ss'),     --PYMT_DT
                             mPymtAmt,                              --PYMT_AMT
                             mTypSeq,                          --RCVRY_TYP_SEQ
                             mClntSeq,                          --PYMT_MOD_KEY
                             0,                                --PYMT_STS_KEY,
                             mUsrId,                                --CRTD_BY,
                             SYSDATE,                              -- CRTD_DT,
                             mUsrId,                            --LAST_UPD_BY,
                             SYSDATE,                           --LAST_UPD_DT,
                             0,                                     --DEL_FLG,
                             NULL,                               --EFF_END_DT,
                             1,                                --CRNT_REC_FLG,
                             mClntSeq,                             --PYMT_REF,
                             mPostFlg,                             --POST_FLG,
                             NULL,                             --CHNG_RSN_KEY,
                             NULL,                            --CHNG_RSN_CMNT,
                             NULL,                           --PRNT_RCVRY_REF,
                             NULL,                               --DPST_SLP_DT
                             NULL);

                ---------------------------------------------------------
                EXIT;
            END IF;

            mLnItmNum := mLnItmNum + 1;

            -- in case the installment is completed then update the status
            IF mPymtSchedSeq <> rdl.pymt_sched_dtl_seq
            THEN
--                DBMS_OUTPUT.put_line (
--                       'update psd sts Tot inst amt:'
--                    || mTotalInstDueAmt
--                    || ' mInstPaidAmt:'
--                    || mInstPaidAmt);
--                DBMS_OUTPUT.put_line (
--                    'update psd mpymtdtlseq:' || mPymtSchedSeq);

                IF mPymtSchedSeq <> 0
                THEN
--                    DBMS_OUTPUT.put_line (
--                           'update psd sts Tot inst amt:'
--                        || mTotalInstDueAmt
--                        || ' mInstPaidAmt:'
--                        || mInstPaidAmt);

                    IF mTotalInstDueAmt = mInstPaidAmt AND mInstPaidAmt <> 0
                    THEN
--                        DBMS_OUTPUT.put_line ('inside udate psd');
                        updtPymtSchedDtl_LOAN_ADJSTMNT (mInstDueDt,
                                          mPymtDt,
                                          mPymtSchedSeq,
                                          mUsrId);

                        -- if last then update loan App status
                        IF pLstInstFlg = 1 AND mPostFlg = 1
                        THEN
                            IF mPrntLoanFlg = 0
                            THEN
                                IF loan_app_ost (pLoanAppSeq,
                                                 SYSDATE + 1,
                                                 'psc') =
                                   0
                                THEN
                                    IF clnt_ost (mClntSeq,
                                                 SYSDATE + 1,
                                                 'psc') =
                                       0
                                    THEN
                                        UpdateLaStsByClnt (mClntSeq,
                                                           mUsrId,
                                                           mPymtDt);
                                    ELSE
                                        UpdateLaStsByLoan (pLoanAppSeq,
                                                           mUsrId,
                                                           mPymtDt);
                                    END IF;
                                END IF;
                            ELSE
                                IF clnt_ost (mClntSeq, SYSDATE + 1, 'psc') =
                                   0
                                THEN
                                    UpdateLaStsByLoan (pLoanAppSeq,
                                                       mUsrId,
                                                       mPymtDt);
                                END IF;
                            END IF;
                        END IF;
                    END IF;

--                    DBMS_OUTPUT.put_line (
--                           'update prtl psd sts '
--                        || mTotalInstDueAmt
--                        || '-'
--                        || mInstPaidAmt);

                    IF mTotalInstDueAmt - mInstPaidAmt > 0
                    THEN              -- check ost amount for last installment
                        -- Update Partial Status
                        updtPymtSchedDtl_LOAN_ADJSTMNT (mInstDueDt,
                                          NULL,
                                          mPymtSchedSeq,
                                          mUsrId);
                    END IF;
                END IF;

                mInstPaidAmt := rdl.total_inst_paid_amt;
                pLstInstFlg := 0;
                mPymtSchedSeq := rdl.pymt_sched_dtl_seq;
                mInstDueDt := rdl.due_dt;
                pLoanAppSeq := rdl.loan_app_seq;
                mprntloanflg := rdl.prnt_loan_flg;

                IF rdl.inst_num = rdl.lst_inst
                THEN
                    pLstInstFlg := 1;
                END IF;

                mTotalInstDueAmt := rdl.Total_inst_due_amt;
--                DBMS_OUTPUT.put_line (
--                    'value assigned mTotalInstDueAmt:' || mTotalInstDueAmt);
            END IF;

            --dbms_output.put_line('Total Paid:'||mTotalPaidAmt||' Payment Amount: '||mPymtAmt);
            IF mTotalPaidAmt < mPymtAmt
            THEN
                IF mTotalPaidAmt + rdl.due_amt <= mPymtAmt
                THEN
                    mApldamt := rdl.due_amt;
                ELSE
                    mApldamt := mPymtAmt - mTotalPaidAmt;
                END IF;

                --dbms_output.put_line('insert '||mclntseq||' inst seq:' || rdl.PYMT_SCHED_DTL_SEQ||' :' ||rdl.chrg_seq||' :'||mApldamt);
                INSERT INTO mw_rcvry_dtl
                     VALUES (rcvry_chrg_seq.NEXTVAL,         --RCVRY_CHRG_SEQ,
                             SYSDATE,                          --EFF_START_DT,
                             mRcvry_trx_seq,                  --RCVRY_TRX_SEQ,
                             rdl.chrg_seq,                     --CHRG_TYP_KEY,
                             mApldamt,                             --PYMT_AMT,
                             mUsrId,                                --CRTD_BY,
                             SYSDATE,                               --CRTD_DT,
                             mUsrId,                            --LAST_UPD_BY,
                             SYSDATE,                           --LAST_UPD_DT,
                             0,                                     --DEL_FLG,
                             NULL,                               --EFF_END_DT,
                             1,                                --CRNT_REC_FLG,
                             rdl.PYMT_SCHED_DTL_SEQ,
                             0);

                BEGIN
                    UPDATE mw_rcvry_trx trxx
                       SET trxx.PRNT_LOAN_APP_SEQ = rdl.PrntLoanApp
                     WHERE     trxx.RCVRY_TRX_SEQ = mRcvry_trx_seq
                           AND trxx.PRNT_LOAN_APP_SEQ IS NULL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                -- Insert JV Dtl Entry
                IF mPostFlg = 1
                THEN
                    crtJvDtlRec (mJvHdrSeq,
                                 rdl.gl_acct_num,
                                 mAgntGlCd,
                                 mApldamt,
                                 mLnItmNum);
                END IF;

                mInstPaidAmt := mInstPaidAmt + mApldamt;
                mTotalPaidAmt := mTotalPaidAmt + mApldamt;
            --dbms_output.put_line('mInstPaidAmt '||mInstPaidAmt);
            ELSE
                EXIT;
            END IF;
        END LOOP;

        IF mTotalInstDueAmt - mInstPaidAmt > 0 AND mInstPaidAmt > 0
        THEN                          -- check ost amount for last installment
            -- Update Partial Status
--            DBMS_OUTPUT.put_line (
--                   'inside prtl sts '
--                || mTotalInstDueAmt
--                || ' : '
--                || mInstPaidAmt);
                
            updtPymtSchedDtl_LOAN_ADJSTMNT (mInstDueDt,
                              NULL,
                              mPymtSchedSeq,
                              mUsrId);
        END IF;

        IF pLoanAppSeq > 0
        THEN
            IF loan_app_ost (pLoanAppSeq, SYSDATE + 1, 'psc') = 0
            THEN
                UpdateLaStsByLoan (pLoanAppSeq, mUsrId, mPymtDt);
            END IF;
        END IF;

        IF pLstInstFlg = 1
        THEN
            IF mTotalInstDueAmt = mInstPaidAmt AND mInstPaidAmt <> 0
            THEN
                updtPymtSchedDtl_LOAN_ADJSTMNT (mInstDueDt,
                                  mPymtDt,
                                  mPymtSchedSeq,
                                  mUsrId);

                -- if last then update loan App status
                IF pLstInstFlg = 1 AND mPostFlg = 1
                THEN
                    IF mPrntLoanFlg = 0
                    THEN
                        IF loan_app_ost (pLoanAppSeq, SYSDATE + 1, 'psc') = 0
                        THEN
                            IF clnt_ost (mClntSeq, SYSDATE + 1, 'psc') = 0
                            THEN
                                UpdateLaStsByClnt (mClntSeq, mUsrId, mPymtDt);
                            ELSE
                                UpdateLaStsByLoan (pLoanAppSeq,
                                                   mUsrId,
                                                   mPymtDt);
                            END IF;
                        END IF;
                    ELSE
                        IF clnt_ost (mClntSeq, SYSDATE + 1, 'psc') = 0
                        THEN
                            UpdateLaStsByLoan (pLoanAppSeq, mUsrId, mPymtDt);
                        END IF;
                    END IF;
                END IF;
            END IF;

            IF mTotalInstDueAmt - mInstPaidAmt > 0 AND mInstPaidAmt > 0
            THEN
                -- Update Partial Status
                updtPymtSchedDtl_LOAN_ADJSTMNT(mInstDueDt,
                                  NULL,
                                  mPymtSchedSeq,
                                  mUsrId);
            END IF;
        END IF;

        -- Create excess Recovery
        IF mPymtAmt - NVL (mTotalPaidamt, 0) > 0
        THEN
            BEGIN
                -- jv dtl
                INSERT INTO mw_rcvry_dtl
                     VALUES (rcvry_chrg_seq.NEXTVAL,         --RCVRY_CHRG_SEQ,
                             SYSDATE,                          --EFF_START_DT,
                             mRcvry_trx_seq,                  --RCVRY_TRX_SEQ,
                             241,                              --CHRG_TYP_KEY,
                             mPymtAmt - NVL (mTotalPaidamt, 0),    --PYMT_AMT,
                             mUsrId,                                --CRTD_BY,
                             SYSDATE,                               --CRTD_DT,
                             mUsrId,                            --LAST_UPD_BY,
                             SYSDATE,                           --LAST_UPD_DT,
                             0,                                     --DEL_FLG,
                             NULL,                               --EFF_END_DT,
                             1,                                --CRNT_REC_FLG,
                             NULL,
                             0);
            END;

            -- Jv Dtl Record
            -- get ER gl code
            IF mPostFlg = 1
            THEN
                BEGIN
                    SELECT gl_acct_num
                      INTO mERglCd
                      FROM mw_typs typ
                     WHERE typ.crnt_rec_flg = 1 AND typ.typ_seq = 241;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;             -- Excess Recovery Gl code not found
                END;

                -- jv Header for Excess Recovery
                mJvNart :=
                       ' Excess Recovery received from Client '
                    || NVL (mClntNm, ' ');
                mJvHdrSeq := jv_hdr_seq.NEXTVAL;

                INSERT INTO mw_jv_hdr (JV_HDR_SEQ,
                                       PRNT_VCHR_REF,
                                       JV_ID,
                                       JV_DT,
                                       JV_DSCR,
                                       JV_TYP_KEY,
                                       enty_seq,
                                       ENTY_TYP,
                                       CRTD_BY,
                                       POST_FLG,
                                       RCVRY_TRX_SEQ,
                                       BRNCH_SEQ)
                         VALUES (
                             mJvHdrSeq,                          --JV_HDR_SEQ,
                             NULL,                            --PRNT_VCHR_REF,
                             mJvHdrSeq,                               --JV_ID,
                             TO_DATE (mPymtDt || ' 13:00:00',
                                      'dd-mon-rrrr hh24:mi:ss'),      --JV_DT,
                             mJvnart,                               --JV_DSCR,
                             NULL,                               --JV_TYP_KEY,
                             mRcvry_trx_seq,                        --enty_seq
                             'EXCESS RECOVERY',                    --ENTY_TYP,
                             mUsrId,                                --CRTD_BY,
                             1,                                    --POST_FLG,
                             mRcvry_trx_seq,                  --RCVRY_TRX_SEQ,
                             mBrnchSeq                             --BRNCH_SEQ
                                      );

                crtJvDtlRec (mJvHdrSeq,
                             mERglCd,
                             mAgntGlCd,
                             mPymtAmt - NVL (mTotalPaidamt, 0),
                             mLnItmNum);

                IF pLoanAppSeq > 0
                THEN
                    IF loan_app_ost (pLoanAppSeq, SYSDATE + 1, 'psc') = 0
                    THEN
                        UpdateLaStsByLoan (pLoanAppSeq, mUsrId, mPymtDt);
                    END IF;
                END IF;
            END IF;
        END IF;

    mMsgOut := 'SUCCESS';
    
    EXCEPTION
        WHEN OTHERS
        THEN
            --DBMS_OUTPUT.put_line ('inside exception');
            ROLLBACK;
            err_code := SQLCODE;
            err_msg := SUBSTR (SQLERRM, 1, 200);
            mMsgOut := 'ISSUE IN RECOVERY ADJUSTMENT => ERROR CODE :'||err_code||' ERROR MSG : '||err_msg;
            INSERT INTO mw_rcvry_load_log
                 VALUES (SYSDATE,
                         mClntSeq,
                         err_code,
                         'LOAN ADJUSTMENT ISSUE : '|| err_msg,
                         mInstNum,
                         mPymtDt,
                         mPymtAmt,
                         mTypSeq);

             --COMMIT; // UPDATE BY YOUSAF DATED: 30-DEC-2022
    END;    
END;
/