package com.kashf.adcbopservice.domain;

import javax.persistence.*;

@Entity
@Table(name = "ADC_USERS")
public class AdcUsers {
    @Id
    @Column(name = "USER_ID")
    private Long userId;

    @Column(name = "REF_CD_VNDR_SEQ")
    private Long refCdVndrSeq;

    @Column(name = "REF_CD_USR_TYP_SEQ")
    private Long refCdUsrTypSeq;

    @Column(name = "CON_URL")
    private String conUrl;

    @Column(name = "USERNAME")
    private String username;

    @Column(name = "USER_PASS")
    private String userPass;

    @Column(name = "VRSN")
    private String vrsn;

    @Column(name = "AUTH_KEY")
    private String authKey;

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

    public Long getUserId() {
        return this.userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public Long getRefCdVndrSeq() {
        return this.refCdVndrSeq;
    }

    public void setRefCdVndrSeq(Long refCdVndrSeq) {
        this.refCdVndrSeq = refCdVndrSeq;
    }

    public Long getRefCdUsrTypSeq() {
        return this.refCdUsrTypSeq;
    }

    public void setRefCdUsrTypSeq(Long refCdUsrTypSeq) {
        this.refCdUsrTypSeq = refCdUsrTypSeq;
    }

    public String getConUrl() {
        return this.conUrl;
    }

    public void setConUrl(String conUrl) {
        this.conUrl = conUrl;
    }

    public String getUsername() {
        return this.username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getUserPass() {
        return this.userPass;
    }

    public void setUserPass(String userPass) {
        this.userPass = userPass;
    }

    public String getVrsn() {
        return this.vrsn;
    }

    public void setVrsn(String vrsn) {
        this.vrsn = vrsn;
    }

    public String getAuthKey() {
        return this.authKey;
    }

    public void setAuthKey(String authKey) {
        this.authKey = authKey;
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

