CREATE OR REPLACE FUNCTION PRC_BOP_EMPTY_RSP(P_RSP_CODE VARCHAR2)
return varchar2
AS
    CURSOR CR IS
        SELECT JSON_OBJECT ('status' VALUE P_RSP_CODE,
                            'reference_no' VALUE NULL,
                            'client_no' VALUE NULL,
                            'client_name' VALUE NULL,
                            'client_cnic' VALUE NULL,
                            'kashf_branch' VALUE NULL,
                            'loan_date' VALUE NULL,
                            'payment_status' VALUE NULL,
                            'amount' VALUE NULL,
                            'reserved' VALUE NULL)
                   AS json_body
          FROM DUAL;
BEGIN

 FOR CSR IN CR
    LOOP
        return CSR.json_body;
    END LOOP;
    
END;


