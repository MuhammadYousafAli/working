/*Written by Areeba
  23-01-2023
  Incident Setup Rules*/

INSERT INTO MW_APP_SB_MOD
     VALUES (SB_MOD_SEQ.NEXTVAL,
             SYSDATE,
             7,
             SB_MOD_SEQ.CURRVAL,
             'Incident Rules',
             '/incident-rules',
             '/incident-rules',
             'areeba.naveed',
             SYSDATE,
             'areeba.naveed',
             SYSDATE,
             0,
             NULL,
             1);