/* Formatted on 07/02/2023 6:05:17 pm (QP5 v5.326) */
-------------------  REVERSAL SCRIPT ------------

DECLARE
    ERR_942     EXCEPTION;
    ERR_2298    EXCEPTION;
    PRAGMA EXCEPTION_INIT (ERR_942, -942);
    PRAGMA EXCEPTION_INIT (ERR_2298, -2289);

    P_RTN_MSG   VARCHAR2 (1000);
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE MW_STP_INCDNT CASCADE CONSTRAINTS';
    EXCEPTION
        WHEN ERR_942
        THEN
            DBMS_OUTPUT.put_line ('MW_STP_INCDNT TABLE- DOES NOT EXIST');
    END;

    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE MW_INCDNT_RPT CASCADE CONSTRAINTS';
    EXCEPTION
        WHEN ERR_942
        THEN
            DBMS_OUTPUT.put_line ('MW_INCDNT_RPT TABLE - DOES NOT EXIST');
    END;

    BEGIN
        EXECUTE IMMEDIATE 'DROP SEQUENCE INCDNT_STP_SEQ';
    EXCEPTION
        WHEN ERR_2298
        THEN
            DBMS_OUTPUT.put_line ('INCDNT_STP_SEQ SEQUANCE- DOES NOT EXIST');
    END;
    
    BEGIN
        EXECUTE IMMEDIATE 'DROP SEQUENCE PSC_DEF_UNIQUE_NUM_SEQ';
    EXCEPTION
        WHEN ERR_2298
        THEN
            DBMS_OUTPUT.put_line ('PSC_DEF_UNIQUE_NUM_SEQ SEQUANCE- DOES NOT EXIST');
    END;

    BEGIN
        EXECUTE IMMEDIATE 'DROP SEQUENCE INCDNT_RPT_SEQ';
    EXCEPTION
        WHEN ERR_2298
        THEN
            DBMS_OUTPUT.put_line ('INCDNT_RPT_SEQ SEQUANCE- DOES NOT EXIST');
    END;

    DELETE FROM MW_REF_CD_VAL VAL
          WHERE     VAL.LAST_UPD_BY = 'yousaf.ali'
                AND VAL.REF_CD_GRP_KEY IN
                        (SELECT GRP.REF_CD_GRP_SEQ
                           FROM MW_REF_CD_GRP GRP
                          WHERE     GRP.LAST_UPD_BY = 'yousaf.ali'
                                AND GRP.REF_CD_GRP_NM IN
                                        ('INCIDENT TYPE',
                                         'DISABILITY CATEGORY',
                                         'VEHICLE INCIDENT CATEGORY',
                                         'INCIDENT EFFECTEE',
                                         'PRODUCT CHARGE',
                                         'INCIDENT PREMIUM AMOUNT',
                                         'CHARGES DEDUCTION',
                                         'DEDUCTION APPLIED ON',
                                         'ANIMAL CATEGORY',
                                         'DEATH CATEGORY',
                                         'INCIDENT EFFECTEE ANIMAL',
                                         'INCIDENT EFFECTEE VEHICLE',
                                         'INCIDENT STATUS'));

    IF (SQL%NOTFOUND)
    THEN
        DBMS_OUTPUT.put_line (
            'NO DATA FOUND TO DELETE FROM - MW_REF_CD_VAL!');
    END IF;

    DELETE FROM MW_REF_CD_GRP GRP
          WHERE     GRP.LAST_UPD_BY = 'yousaf.ali'
                AND GRP.REF_CD_GRP_NM IN ('INCIDENT TYPE',
                                          'DISABILITY CATEGORY',
                                          'VEHICLE INCIDENT CATEGORY',
                                          'INCIDENT EFFECTEE',
                                          'PRODUCT CHARGE',
                                          'INCIDENT PREMIUM AMOUNT',
                                          'CHARGES DEDUCTION',
                                          'DEDUCTION APPLIED ON',
                                          'ANIMAL CATEGORY',
                                          'DEATH CATEGORY',
                                          'INCIDENT EFFECTEE ANIMAL',
                                          'INCIDENT EFFECTEE VEHICLE',
                                          'INCIDENT STATUS');

    IF (SQL%NOTFOUND)
    THEN
        DBMS_OUTPUT.put_line (
            'NO DATA FOUND TO DELETE FROM - MW_REF_CD_GRP!');
    END IF;
EXCEPTION
    WHEN OTHERS
    THEN
        ROLLBACK;
        P_RTN_MSG :=
               ' LINE NO: '
            || $$PLSQL_LINE
            || ' ERROR CODE: '
            || SQLCODE
            || ' ERROR MESSAGE: '
            || SQLERRM
            || 'TRACE: '
            || SYS.DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        DBMS_OUTPUT.put_line ('SETUP REVERSAL ISSUE => ' || P_RTN_MSG);
        RAISE;
END;


--------------- INCDNT TYPE -----------------

INSERT INTO MW_REF_CD_GRP (REF_CD_GRP_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP,
                           REF_CD_GRP_NM,
                           REF_CD_GRP_DSCR,
                           REF_CD_GRP_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_GRP_SEQ.NEXTVAL,
             SYSDATE,
             '0413',
             'INCIDENT TYPE',
             'INCIDENT TYPE',
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0001',
             'DEATH-[CLIENT/NOMINEE]',
             1,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0002',
             'ANIMAL',
             2,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);


INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0003',
             'DISABILITY',
             3,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0004',
             'VEHICLE',
             4,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);


---------------  DEATH CATEGORY ---------------

INSERT INTO MW_REF_CD_GRP (REF_CD_GRP_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP,
                           REF_CD_GRP_NM,
                           REF_CD_GRP_DSCR,
                           REF_CD_GRP_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_GRP_SEQ.NEXTVAL,
             SYSDATE,
             '0414',
             'DEATH CATEGORY',
             'DEATH CATEGORY',
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0001',
             'NATURAL DEATH',
             1,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0002',
             'ACCIDENT',
             2,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

---------------  ANIMAL CATEGORY ---------------

INSERT INTO MW_REF_CD_GRP (REF_CD_GRP_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP,
                           REF_CD_GRP_NM,
                           REF_CD_GRP_DSCR,
                           REF_CD_GRP_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_GRP_SEQ.NEXTVAL,
             SYSDATE,
             '0415',
             'ANIMAL CATEGORY',
             'ANIMAL CATEGORY',
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0003',
             'DEATH',
             1,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0004',
             'LOST',
             2,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0005',
             'SOLD',
             3,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

---------------  DISABILITY CATEGORY ---------------

INSERT INTO MW_REF_CD_GRP (REF_CD_GRP_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP,
                           REF_CD_GRP_NM,
                           REF_CD_GRP_DSCR,
                           REF_CD_GRP_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_GRP_SEQ.NEXTVAL,
             SYSDATE,
             '0416',
             'DISABILITY CATEGORY',
             'DISABILITY CATEGORY',
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0001',
             'PERMANENT',
             1,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0002',
             'PARTIAL',
             2,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

----------------------  VEHICLE CATEGORY ---------------------

INSERT INTO MW_REF_CD_GRP (REF_CD_GRP_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP,
                           REF_CD_GRP_NM,
                           REF_CD_GRP_DSCR,
                           REF_CD_GRP_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_GRP_SEQ.NEXTVAL,
             SYSDATE,
             '0417',
             'VEHICLE INCIDENT CATEGORY',
             'VEHICLE INCIDENT CATEGORY',
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0001',
             'THEFT',
             1,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0002',
             'SNATCHED',
             2,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0003',
             'ACCIDENT',
             3,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);


----------------------  INCDNT_EFFECTEE ---------------------

INSERT INTO MW_REF_CD_GRP (REF_CD_GRP_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP,
                           REF_CD_GRP_NM,
                           REF_CD_GRP_DSCR,
                           REF_CD_GRP_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_GRP_SEQ.NEXTVAL,
             SYSDATE,
             '0418',
             'INCIDENT EFFECTEE',
             'INCIDENT EFFECTEE',
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0',
             'CLIENT',
             1,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '1',
             'NOMINEE',
             2,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

----------------------  INCDNT_EFFECTEE ANIMAL---------------------

INSERT INTO MW_REF_CD_GRP (REF_CD_GRP_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP,
                           REF_CD_GRP_NM,
                           REF_CD_GRP_DSCR,
                           REF_CD_GRP_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_GRP_SEQ.NEXTVAL,
             SYSDATE,
             '0423',
             'INCIDENT EFFECTEE ANIMAL',
             'INCIDENT EFFECTEE ANIMAL',
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '1',
             'ANIMAL',
             1,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);


----------------------  INCDNT_EFFECTEE VEHICLE---------------------

INSERT INTO MW_REF_CD_GRP (REF_CD_GRP_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP,
                           REF_CD_GRP_NM,
                           REF_CD_GRP_DSCR,
                           REF_CD_GRP_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_GRP_SEQ.NEXTVAL,
             SYSDATE,
             '0424',
             'INCIDENT EFFECTEE VEHICLE',
             'INCIDENT EFFECTEE VEHICLE',
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '1',
             'VEHICLE',
             1,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

----------------------  PRODUCT CHARGE TYPE FOR INCIDENT CALCULATION ---------------------

INSERT INTO MW_REF_CD_GRP (REF_CD_GRP_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP,
                           REF_CD_GRP_NM,
                           REF_CD_GRP_DSCR,
                           REF_CD_GRP_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_GRP_SEQ.NEXTVAL,
             SYSDATE,
             '0419',
             'PRODUCT CHARGE',
             'PRODUCT CHARGE TYPE FOR INCIDENT CALCULATION',
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '-2',
             'KSZB',
             1,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '-2',
             'KST',
             2,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '-2',
             'KC',
             3,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '5',
             'INSURANCE PREMIUM LIVE-STOCK',
             4,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '20069',
             'KSWK INSURANCE PREMIUM',
             5,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '427',
             'ANIMAL TAKAFUL',
             6,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '382',
             'TAKAFUL CONRTIBUTION',
             7,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '1',
             'DOCUMENTS CHARGES',
             8,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '4',
             'LIFE INSURANCE PREMIUM',
             9,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '6',
             'TRAINING CHARGES',
             10,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '427',
             'LIVE-STOCK TAKAFUL',
             11,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '-1',
             'NO CHARGE',
             13,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

--------------- CHARGES DEDUCTION -----------------

INSERT INTO MW_REF_CD_GRP (REF_CD_GRP_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP,
                           REF_CD_GRP_NM,
                           REF_CD_GRP_DSCR,
                           REF_CD_GRP_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_GRP_SEQ.NEXTVAL,
             SYSDATE,
             '0420',
             'CHARGES DEDUCTION',
             'CHARGES DEDUCTION',
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0001',
             'Based on current 12 installments bucket',
             1,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0002',
             'Based on current 6 installments bucket',
             2,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0003',
             'Based on current 18 installments bucket',
             3,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0004',
             'Based on current 24 installments bucket',
             4,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0005',
             'Deduct all installment',
             5,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);


----------------------  PRODUCT CHARGE TYPE FOR INCIDENT CALCULATION ---------------------

INSERT INTO MW_REF_CD_GRP (REF_CD_GRP_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP,
                           REF_CD_GRP_NM,
                           REF_CD_GRP_DSCR,
                           REF_CD_GRP_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_GRP_SEQ.NEXTVAL,
             SYSDATE,
             '0421',
             'INCIDENT PREMIUM AMOUNT',
             'INCIDENT PREMIUM AMOUNT FOR INCIDENT CLAIM PAYMENT',
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0001',
             '5000',
             1,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0002',
             '7500',
             2,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0003',
             '10000',
             3,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0004',
             '0',
             4,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

--------------- DEDUCTION APPLIED ON -----------------

INSERT INTO MW_REF_CD_GRP (REF_CD_GRP_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP,
                           REF_CD_GRP_NM,
                           REF_CD_GRP_DSCR,
                           REF_CD_GRP_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_GRP_SEQ.NEXTVAL,
             SYSDATE,
             '0422',
             'DEDUCTION APPLIED ON',
             'DEDUCTION APPLIED ON',
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0001',
             'All products with their associate products',
             1,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0002',
             'First disbursed product along with associate product',
             2,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

--------------- INCIDENT STATUS -----------------

INSERT INTO MW_REF_CD_GRP (REF_CD_GRP_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP,
                           REF_CD_GRP_NM,
                           REF_CD_GRP_DSCR,
                           REF_CD_GRP_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_GRP_SEQ.NEXTVAL,
             SYSDATE,
             '0425',
             'INCIDENT STATUS',
             'INCIDENT STATUS',
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0001',
             'INCIDENT REPORTED',
             1,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0002',
             'FUNERAL PAID',
             2,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);

INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0003',
             'LOAN ADJUSTED AGAINST INCIDENT',
             3,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);


INSERT INTO MW_REF_CD_VAL (REF_CD_SEQ,
                           EFF_START_DT,
                           REF_CD_GRP_KEY,
                           REF_CD,
                           REF_CD_DSCR,
                           REF_CD_SORT_ORDR,
                           REF_CD_ACTIVE_FLG,
                           CRTD_BY,
                           CRTD_DT,
                           LAST_UPD_BY,
                           LAST_UPD_DT,
                           DEL_FLG,
                           EFF_END_DT,
                           CRNT_REC_FLG)
     VALUES (REF_CD_SEQ.NEXTVAL,
             SYSDATE,
             REF_CD_GRP_SEQ.CURRVAL,
             '0004',
             'FUNERAL SAVED',
             4,
             1,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1);



-------------  insert VEHICLE INSURANCE CLAIM for sawari ------

INSERT INTO MW_TYPS (TYP_SEQ,
                     EFF_START_DT,
                     TYP_ID,
                     TYP_STR,
                     GL_ACCT_NUM,
                     TYP_STS_KEY,
                     TYP_CTGRY_KEY,
                     CRTD_BY,
                     CRTD_DT,
                     LAST_UPD_BY,
                     LAST_UPD_DT,
                     DEL_FLG,
                     EFF_END_DT,
                     CRNT_REC_FLG,
                     PERD_FLG,
                     DFRD_ACCT_NUM,
                     BRNCH_SEQ,
                     BDDT_ACCT_NUM)
     VALUES (453,
             SYSDATE,
             '0453',
             'VEHICLE INSURANCE CLAIM',
             '000.000.203725.00000',
             201,
             2,
             'yousaf.ali',
             SYSDATE,
             'yousaf.ali',
             SYSDATE,
             0,
             NULL,
             1,
             0,
             NULL,
             0,
             NULL);

----------------- MW_STP_INCDNT ----------------

CREATE SEQUENCE PSC_DEF_UNIQUE_NUM_SEQ START WITH 1000
                                       MAXVALUE 9999999999999999999999999999
                                       MINVALUE 1000;

CREATE SEQUENCE INCDNT_STP_SEQ START WITH 1
                               MAXVALUE 9999999999999999999999999999
                               MINVALUE 1;

CREATE TABLE MW_STP_INCDNT
(
    INCDNT_STP_SEQ            NUMBER NOT NULL PRIMARY KEY,
    INCDNT_TYP                NUMBER NOT NULL,
    INCDNT_CTGRY              NUMBER NOT NULL,
    INCDNT_EFFECTEE           NUMBER NOT NULL,
    PRD_CHRG                  NUMBER NOT NULL,
    FXD_PRMUM                 NUMBER NOT NULL,
    RVRSE_ALL_ADV             NUMBER (1) CHECK (RVRSE_ALL_ADV IN (0, 1)) NOT NULL,
    RVRSE_ALL_EXPT_SM_MNTH    NUMBER (1)
                                 CHECK (RVRSE_ALL_EXPT_SM_MNTH IN (0, 1))
                                 NOT NULL,
    DED_SM_MNTH               NUMBER (1)
                                 CHECK (DED_SM_MNTH IN (0, 1))
                                 NOT NULL,
    DED_BASE                  NUMBER NOT NULL,
    DED_APLD_ON               NUMBER NOT NULL,
    CRTD_BY                   VARCHAR2 (35 BYTE) NOT NULL,
    CRTD_DT                   DATE DEFAULT SYSDATE NOT NULL,
    LAST_UPD_BY               VARCHAR2 (35 BYTE) NOT NULL,
    LAST_UPD_DT               DATE DEFAULT SYSDATE NOT NULL,
    DEL_FLG                   NUMBER (1)
                                 DEFAULT 0
                                 CHECK (DEL_FLG IN (0, 1))
                                 NOT NULL,
    EFF_END_DT                DATE,
    CRNT_REC_FLG              NUMBER (1)
                                 DEFAULT 1
                                 CHECK (CRNT_REC_FLG IN (0, 1))
                                 NOT NULL
);

ALTER TABLE MW_STP_INCDNT
    ADD (
        CONSTRAINT MW_STP_INCDNT_R01 FOREIGN KEY (INCDNT_TYP)
            REFERENCES MW_REF_CD_VAL (REF_CD_SEQ)
            ENABLE VALIDATE);

ALTER TABLE MW_STP_INCDNT
    ADD (
        CONSTRAINT MW_STP_INCDNT_R02 FOREIGN KEY (INCDNT_CTGRY)
            REFERENCES MW_REF_CD_VAL (REF_CD_SEQ)
            ENABLE VALIDATE);

ALTER TABLE MW_STP_INCDNT
    ADD (
        CONSTRAINT MW_STP_INCDNT_R03 FOREIGN KEY (INCDNT_EFFECTEE)
            REFERENCES MW_REF_CD_VAL (REF_CD_SEQ)
            ENABLE VALIDATE);

ALTER TABLE MW_STP_INCDNT
    ADD (
        CONSTRAINT MW_STP_INCDNT_R04 FOREIGN KEY (PRD_CHRG)
            REFERENCES MW_REF_CD_VAL (REF_CD_SEQ)
            ENABLE VALIDATE);

ALTER TABLE MW_STP_INCDNT
    ADD (
        CONSTRAINT MW_STP_INCDNT_R05 FOREIGN KEY (FXD_PRMUM)
            REFERENCES MW_REF_CD_VAL (REF_CD_SEQ)
            ENABLE VALIDATE);

ALTER TABLE MW_STP_INCDNT
    ADD (
        CONSTRAINT MW_STP_INCDNT_R06 FOREIGN KEY (DED_BASE)
            REFERENCES MW_REF_CD_VAL (REF_CD_SEQ)
            ENABLE VALIDATE);

ALTER TABLE MW_STP_INCDNT
    ADD (
        CONSTRAINT MW_STP_INCDNT_R07 FOREIGN KEY (DED_APLD_ON)
            REFERENCES MW_REF_CD_VAL (REF_CD_SEQ)
            ENABLE VALIDATE);

--------------------------   MAIN TABLE -----------------------------

CREATE SEQUENCE INCDNT_RPT_SEQ START WITH 1
                               MAXVALUE 9999999999999999999999999999
                               MINVALUE 1;

CREATE TABLE MW_INCDNT_RPT
(
    INCDNT_RPT_SEQ      NUMBER (20) PRIMARY KEY NOT NULL,
    CLNT_SEQ            NUMBER (20) NOT NULL,
    INCDNT_TYP          NUMBER NOT NULL,
    INCDNT_CTGRY        NUMBER NOT NULL,
    INCDNT_EFFECTEE     NUMBER NOT NULL,
    DT_OF_INCDNT        DATE NOT NULL,
    CAUSE_OF_INCDNT     VARCHAR2 (100),
    INCDNT_REF          NUMBER (20),
    INCDNT_REF_RMRKS    VARCHAR2 (100),
    CRTD_BY             VARCHAR2 (35 BYTE) NOT NULL,
    CRTD_DT             DATE DEFAULT SYSDATE NOT NULL,
    LAST_UPD_BY         VARCHAR2 (35 BYTE) NOT NULL,
    LAST_UPD_DT         DATE DEFAULT SYSDATE NOT NULL,
    DEL_FLG             NUMBER (1)
                           DEFAULT 0
                           CHECK (DEL_FLG IN (0, 1))
                           NOT NULL,
    EFF_END_DT          DATE,
    CRNT_REC_FLG        NUMBER (1)
                           DEFAULT 1
                           CHECK (CRNT_REC_FLG IN (0, 1))
                           NOT NULL,
    AMT                 NUMBER (10) NOT NULL,
    CMNT                VARCHAR2 (500 BYTE),
    CLM_STS             NUMBER (20),
    INCDNT_STS          NUMBER DEFAULT -1 NOT NULL
);

ALTER TABLE MW_INCDNT_RPT
    ADD (
        CONSTRAINT MW_INCDNT_RPT_R01 FOREIGN KEY (CLNT_SEQ)
            REFERENCES MW_CLNT (CLNT_SEQ)
            ENABLE VALIDATE);

ALTER TABLE MW_INCDNT_RPT
    ADD (
        CONSTRAINT MW_INCDNT_RPT_R02 FOREIGN KEY (INCDNT_TYP)
            REFERENCES MW_REF_CD_VAL (REF_CD_SEQ)
            ENABLE VALIDATE);

ALTER TABLE MW_INCDNT_RPT
    ADD (
        CONSTRAINT MW_INCDNT_RPT_R03 FOREIGN KEY (INCDNT_CTGRY)
            REFERENCES MW_REF_CD_VAL (REF_CD_SEQ)
            ENABLE VALIDATE);

ALTER TABLE MW_INCDNT_RPT
    ADD (
        CONSTRAINT MW_INCDNT_RPT_R04 FOREIGN KEY (INCDNT_EFFECTEE)
            REFERENCES MW_REF_CD_VAL (REF_CD_SEQ)
            ENABLE VALIDATE);

ALTER TABLE MW_INCDNT_RPT
    ADD (
        CONSTRAINT MW_INCDNT_RPT_R05 FOREIGN KEY (INCDNT_STS)
            REFERENCES MW_REF_CD_VAL (REF_CD_SEQ)
            ENABLE VALIDATE);