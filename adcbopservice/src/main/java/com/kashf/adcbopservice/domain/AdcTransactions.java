package com.kashf.adcbopservice.domain;

import javax.persistence.*;

@Entity
@Table(name = "ADC_TRANSACTIONS")
public class AdcTransactions {
    @Id
    @GeneratedValue(generator="INQRY_TRANS_SEQ")
    @SequenceGenerator(name="INQRY_TRANS_SEQ",sequenceName="INQRY_TRANS_SEQ", allocationSize=1)
    @Column(name = "TRX_SEQ")
    private Long trxSeq;

    @Column(name = "REF_CD_VNDR_SEQ")
    private Long refCdVndrSeq;

    @Column(name = "LOAN_APP_SEQ")
    private Long loanAppSeq;

    @Column(name = "CLNT_SEQ")
    private Long clntSeq;

    @Column(name = "REF_SEQ")
    private Long refSeq;

    @Column(name = "REF_CD_PYMT_TYP_SEQ")
    private Long refCdPymtTypSeq;

    @Lob
    @Column(name = "ADC_REQUEST")
    private String adcRequest;

    @Lob
    @Column(name = "ADC_RESPONSE")
    private String adcResponse;

    @Column(name = "REF_CD_RESP_STS_SEQ")
    private Long refCdRespStsSeq;

    @Column(name = "REMARKS")
    private String remarks;

    @Column(name = "REMOTE_ADDRS")
    private String remoteAddrs;

    @Column(name = "CRNT_REC_FLG")
    private Boolean crntRecFlg;

    @Column(name = "CRTD_DT")
    private java.util.Date crtdDt;

    @Column(name = "CRTD_BY")
    private String crtdBy;

    @Column(name = "LAST_UPD_AT")
    private java.util.Date lastUpdAt;

    @Column(name = "LAST_UPD_BY")
    private String lastUpdBy;

    @Column(name = "BRNCH_SEQ")
    private Long brnchSeq;

    public Long getTrxSeq() {
        return this.trxSeq;
    }

    public void setTrxSeq(Long trxSeq) {
        this.trxSeq = trxSeq;
    }

    public Long getRefCdVndrSeq() {
        return this.refCdVndrSeq;
    }

    public void setRefCdVndrSeq(Long refCdVndrSeq) {
        this.refCdVndrSeq = refCdVndrSeq;
    }

    public Long getLoanAppSeq() {
        return this.loanAppSeq;
    }

    public void setLoanAppSeq(Long loanAppSeq) {
        this.loanAppSeq = loanAppSeq;
    }

    public Long getClntSeq() {
        return this.clntSeq;
    }

    public void setClntSeq(Long clntSeq) {
        this.clntSeq = clntSeq;
    }

    public Long getRefSeq() {
        return this.refSeq;
    }

    public void setRefSeq(Long refSeq) {
        this.refSeq = refSeq;
    }

    public Long getRefCdPymtTypSeq() {
        return this.refCdPymtTypSeq;
    }

    public void setRefCdPymtTypSeq(Long refCdPymtTypSeq) {
        this.refCdPymtTypSeq = refCdPymtTypSeq;
    }

    public String getAdcRequest() {
        return this.adcRequest;
    }

    public void setAdcRequest(String adcRequest) {
        this.adcRequest = adcRequest;
    }

    public String getAdcResponse() {
        return this.adcResponse;
    }

    public void setAdcResponse(String adcResponse) {
        this.adcResponse = adcResponse;
    }

    public Long getRefCdRespStsSeq() {
        return this.refCdRespStsSeq;
    }

    public void setRefCdRespStsSeq(Long refCdRespStsSeq) {
        this.refCdRespStsSeq = refCdRespStsSeq;
    }

    public String getRemarks() {
        return this.remarks;
    }

    public void setRemarks(String remarks) {
        this.remarks = remarks;
    }

    public String getRemoteAddrs() {
        return this.remoteAddrs;
    }

    public void setRemoteAddrs(String remoteAddrs) {
        this.remoteAddrs = remoteAddrs;
    }

    public Boolean getCrntRecFlg() {
        return this.crntRecFlg;
    }

    public void setCrntRecFlg(Boolean crntRecFlg) {
        this.crntRecFlg = crntRecFlg;
    }

    public java.util.Date getCrtdDt() {
        return this.crtdDt;
    }

    public void setCrtdDt(java.util.Date crtdDt) {
        this.crtdDt = crtdDt;
    }

    public String getCrtdBy() {
        return this.crtdBy;
    }

    public void setCrtdBy(String crtdBy) {
        this.crtdBy = crtdBy;
    }

    public java.util.Date getLastUpdAt() {
        return this.lastUpdAt;
    }

    public void setLastUpdAt(java.util.Date lastUpdAt) {
        this.lastUpdAt = lastUpdAt;
    }

    public String getLastUpdBy() {
        return this.lastUpdBy;
    }

    public void setLastUpdBy(String lastUpdBy) {
        this.lastUpdBy = lastUpdBy;
    }

    public Long getBrnchSeq() {
        return brnchSeq;
    }

    public void setBrnchSeq(Long brnchSeq) {
        this.brnchSeq = brnchSeq;
    }
}

