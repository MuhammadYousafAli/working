package com.kashf.adcbopservice.domain;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "ADC_REF_CD_VAL")
public class AdcRefCdVal {
    @Id
    @Column(name = "REF_CD_VAL_SEQ")
    private Long refCdValSeq;

    @Column(name = "REF_CD_GRP_CODE")
    private String refCdGrpCode;

    @Column(name = "REF_CD_VAL_CODE")
    private String refCdValCode;

    @Column(name = "REF_CD_VAL_DESC")
    private String refCdValDesc;

    @Column(name = "REF_CD_VAL_SHRT_DESC")
    private String refCdValShrtDesc;

    @Column(name = "REMARKS")
    private String remarks;

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

    public Long getRefCdValSeq() {
        return this.refCdValSeq;
    }

    public void setRefCdValSeq(Long refCdValSeq) {
        this.refCdValSeq = refCdValSeq;
    }

    public String getRefCdGrpCode() {
        return this.refCdGrpCode;
    }

    public void setRefCdGrpCode(String refCdGrpCode) {
        this.refCdGrpCode = refCdGrpCode;
    }

    public String getRefCdValCode() {
        return this.refCdValCode;
    }

    public void setRefCdValCode(String refCdValCode) {
        this.refCdValCode = refCdValCode;
    }

    public String getRefCdValDesc() {
        return this.refCdValDesc;
    }

    public void setRefCdValDesc(String refCdValDesc) {
        this.refCdValDesc = refCdValDesc;
    }

    public String getRefCdValShrtDesc() {
        return this.refCdValShrtDesc;
    }

    public void setRefCdValShrtDesc(String refCdValShrtDesc) {
        this.refCdValShrtDesc = refCdValShrtDesc;
    }

    public String getRemarks() {
        return this.remarks;
    }

    public void setRemarks(String remarks) {
        this.remarks = remarks;
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
}

