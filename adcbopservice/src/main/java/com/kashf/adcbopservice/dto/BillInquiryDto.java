package com.kashf.adcbopservice.dto;

/*****
 * as per ducument below DTO
{ "reference_no":"112233445566", "transaction_date":"20180101", "transaction_time":"121212", "branch_code":"123456", “stan”:0 "reserved ":"" }
*****/

public class BillInquiryDto {

    public String reference_no;

    public String transaction_date;

    public String transaction_time;

    public String branch_code;

    public Long stan;

    public String reserved;

    public String getReference_no() {
        return reference_no;
    }

    public void setReference_no(String reference_no) {
        this.reference_no = reference_no;
    }

    public String getTransaction_date() {
        return transaction_date;
    }

    public void setTransaction_date(String transaction_date) {
        this.transaction_date = transaction_date;
    }

    public String getTransaction_time() {
        return transaction_time;
    }

    public void setTransaction_time(String transaction_time) {
        this.transaction_time = transaction_time;
    }

    public String getBranch_code() {
        return branch_code;
    }

    public void setBranch_code(String branch_code) {
        this.branch_code = branch_code;
    }

    public Long getStan() {
        return stan;
    }

    public void setStan(Long stan) {
        this.stan = stan;
    }

    public String getReserved() {
        return reserved;
    }

    public void setReserved(String reserved) {
        this.reserved = reserved;
    }

    public String toJSONString(){
        return "{ reference_no: \"" + this.getReference_no() + "\", transaction_date:\"" + this.getTransaction_date() +
                "\", transaction_time:\"" + this.getTransaction_time() + "\", branch_code:\"" +
                this.getBranch_code() + "\", Reserved:\"" + this.getReserved() + "\"}";
    }

}
