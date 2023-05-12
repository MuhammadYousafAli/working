package com.kashf.adcbopservice.domain;

import javax.persistence.*;
import java.util.Date;

@Entity
@Table(name = "ADC_API_CRED")
public class AdcApiCred {
    @Id
    @Column(name = "ID")
    private Long id;

    @Column(name = "END_POINT_URL")
    private String endPointUrl;

    @Column(name = "ACTION_URL")
    private String actionUrl;

    @Column(name = "REF_CD_VNDR_SEQ")
    private Long refCdVndrSeq;

    @Column(name = "AUTH_KEY")
    private String authKey;

    @Column(name = "MTO_CODE")
    private String mtoCode;

    @Column(name = "USER_NAME")
    private String userName;

    @Column(name = "USER_PASS")
    private String userPass;

    @Column(name = "CERT_USER")
    private String certUser;

    @Column(name = "CERT_PASS")
    private String certPass;

    @Column(name = "CRNT_REC_FLG")
    private Boolean crntRecFlg;

    @Column(name = "CRTD_DT")
    private Date crtdDt;

    @Column(name = "CRTD_BY")
    private String crtdBy;

    public Long getId() {
        return this.id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getEndPointUrl() {
        return this.endPointUrl;
    }

    public void setEndPointUrl(String endPointUrl) {
        this.endPointUrl = endPointUrl;
    }

    public String getActionUrl() {
        return this.actionUrl;
    }

    public void setActionUrl(String actionUrl) {
        this.actionUrl = actionUrl;
    }

    public Long getRefCdVndrSeq() {
        return this.refCdVndrSeq;
    }

    public void setRefCdVndrSeq(Long refCdVndrSeq) {
        this.refCdVndrSeq = refCdVndrSeq;
    }

    public String getAuthKey() {
        return this.authKey;
    }

    public void setAuthKey(String authKey) {
        this.authKey = authKey;
    }

    public String getUserName() {
        return this.userName;
    }

    public void setUserName(String userName) {
        this.userName = userName;
    }

    public String getUserPass() {
        return this.userPass;
    }

    public void setUserPass(String userPass) {
        this.userPass = userPass;
    }

    public Boolean getCrntRecFlg() {
        return this.crntRecFlg;
    }

    public void setCrntRecFlg(Boolean crntRecFlg) {
        this.crntRecFlg = crntRecFlg;
    }

    public Date getCrtdDt() {
        return this.crtdDt;
    }

    public void setCrtdDt(Date crtdDt) {
        this.crtdDt = crtdDt;
    }

    public String getCrtdBy() {
        return this.crtdBy;
    }

    public void setCrtdBy(String crtdBy) {
        this.crtdBy = crtdBy;
    }

    public String getMtoCode() {
        return mtoCode;
    }

    public void setMtoCode(String mtoCode) {
        this.mtoCode = mtoCode;
    }

    public String getCertUser() {
        return certUser;
    }

    public void setCertUser(String certUser) {
        this.certUser = certUser;
    }

    public String getCertPass() {
        return certPass;
    }

    public void setCertPass(String certPass) {
        this.certPass = certPass;
    }
}

