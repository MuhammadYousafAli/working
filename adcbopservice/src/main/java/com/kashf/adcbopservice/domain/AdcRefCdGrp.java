package com.kashf.adcbopservice.domain;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "ADC_REF_CD_GRP")
public class AdcRefCdGrp {
    @Id
    @Column(name = "REF_CD_GRP_SEQ")
    private Long refCdGrpSeq;

    @Column(name = "REF_CD_GRP_CODE")
    private String refCdGrpCode;

    @Column(name = "REF_CD_GRP_DESC")
    private String refCdGrpDesc;

    @Column(name = "REF_CD_GRP_SHRT_DESC")
    private String refCdGrpShrtDesc;

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

    public Long getRefCdGrpSeq() {
        return this.refCdGrpSeq;
    }

    public void setRefCdGrpSeq(Long refCdGrpSeq) {
        this.refCdGrpSeq = refCdGrpSeq;
    }

    public String getRefCdGrpCode() {
        return this.refCdGrpCode;
    }

    public void setRefCdGrpCode(String refCdGrpCode) {
        this.refCdGrpCode = refCdGrpCode;
    }

    public String getRefCdGrpDesc() {
        return this.refCdGrpDesc;
    }

    public void setRefCdGrpDesc(String refCdGrpDesc) {
        this.refCdGrpDesc = refCdGrpDesc;
    }

    public String getRefCdGrpShrtDesc() {
        return this.refCdGrpShrtDesc;
    }

    public void setRefCdGrpShrtDesc(String refCdGrpShrtDesc) {
        this.refCdGrpShrtDesc = refCdGrpShrtDesc;
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

