CREATE OR REPLACE package Recovery as
    procedure BulkRecovery(userid varchar, p_msg out varchar2);
    Procedure PostRecClnt(mInstNum varchar,mPymtDt Date, mPymtAmt Number, mTypSeq Number,mClntSeq Number, mUsrId varchar, mBrnchSeq number,mAgntNm varchar,mClntNm varchar,mPostFlg number, mPrntLoanApp number);    
    Procedure PostRecClnt_(mInstNum varchar,mPymtDt Date, mPymtAmt Number, mTypSeq Number,mClntSeq Number, mUsrId varchar, mBrnchSeq number,mAgntNm varchar,mClntNm varchar,mPostFlg number, mPrntLoanApp number);
    procedure updtPymtSchedDtl(mInstDueDt date,mPymtDt date ,mPymtSchedDtlSeq number,mUserId varchar);
    Procedure UpdateLaStsByClnt(pClntSeq number,mUserId varchar, mPymtDt date);
    Procedure UpdateLaStsByLoan(pLoanAppSeq number,mUserId varchar, mPymtDt date);
    Function getGlAcct(mTypSeq number) return varchar;
    procedure crtJvDtlRec(jvHdrSeq number,GlCd0 varchar,glCd1 varchar, mAmt number,mLnItmNum number);
    Procedure PostAdjRecClnt(mInstNum varchar,mPymtDt Date, mPymtAmt Number, mTypSeq Number,mClntSeq Number, mUsrId varchar,mBrnchSeq number,mAgntNm varchar,mClntNm varchar, mPrntLoanApp number);
    procedure adjust_krk_recovery(p_clnt_seq number, mUsrId varchar2, p_msg out varchar2);
    procedure reverse_krk_recovery(p_clnt_seq number, mUsrId varchar2, p_msg out varchar2);
    procedure postRcvryTrx(mTrxSeq number,mUsrId varchar);
    function getPrdStr(mClntSeq number) return varchar;    
    procedure updtPymtSchedDtl_LOAN_ADJSTMNT(mInstDueDt date,mPymtDt date ,mPymtSchedDtlSeq number,mUserId varchar);
    PROCEDURE PRC_PST_LOAN_ASJSTMNT(mInstNum VARCHAR, mPymtDt DATE,mPymtAmt NUMBER,mTypSeq NUMBER,mClntSeq NUMBER,mUsrId VARCHAR,mBrnchSeq NUMBER,mAgntNm VARCHAR,mClntNm VARCHAR,mPostFlg NUMBER,mMsgOut OUT VARCHAR);
end;
/