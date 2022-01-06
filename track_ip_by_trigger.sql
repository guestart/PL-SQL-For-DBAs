REM
REM     Script:     track_ip_by_trigger.sql
REM     Author:     Quanwen Zhao
REM     Dated:      Jan 06, 2022
REM
REM     Last tested:
REM             11.2.0.4
REM             19.3.0.0
REM             21.3.0.0
REM
REM     Purpose:
REM       The SQL script file describes 3 scenarios acquiring IP Address by creating trigger on SYS schema of oracle database.
REM
REM     References:
REM       (1) Why client_info in v$session never show IP address even if creating trigger acquiring IP? - https://asktom.oracle.com/pls/apex/f?p=100:11:16669030534501::::P11_QUESTION_ID:9543192700346829856
REM       (2) Why client_info in v$session never show IP address even if creating trigger acquiring IP? - https://community.oracle.com/tech/developers/discussion/4337533/why-client-info-in-v-session-never-show-ip-address-even-if-creating-trigger-acquiring-ip
REM

PROMPT ===================================================================
PROMPT                           ** SCENARIO 1 **
PROMPT  Showing the value (ip address) of column client_info on v$session
PROMPT  by creating a trigger execute dbms_application.set_client_info()
RPOMPT  when meeting a condition - after you logon on oracle database.
PROMPT ===================================================================

-- Running on SYS schema.

CREATE OR REPLACE TRIGGER login_trigger
AFTER LOGON ON database
BEGIN
  DBMS_APPLICATION_INFO.SET_CLIENT_INFO(SYS_CONTEXT('USERENV', 'IP_ADDRESS'));
END;
/

PROMPT ===================================================================
PROMPT                           ** SCENARIO 2 **
PROMPT  Showing the value (ip address) of column client_info on v$session
PROMPT  based on scenario 1, if the hidden parameter _system_trig_enabled
RPOMPT  is FALSE, whatever, you never get the real ip address. Yes, it's
PROMPT  TRUE (default value) unless you changed it before.
PROMPT ===================================================================

-- Running on SYS schema.

ALTER SYSTEM SET _system_trig_enabled=TRUE SCOPE=BOTH;

PROMPT ======================================================================
PROMPT                           ** SCENARIO 3 **
PROMPT  Showing the real ip address of server connecting an invalid password
PROMPT  of oracle database in ALERT log file in order to track which servers
RPOMPT  encountered this issue so far.
PROMPT ======================================================================

-- Running on SYS schema.

CREATE OR REPLACE TRIGGER logon_denied_to_alert
AFTER SERVERERROR ON database
DECLARE
  message    VARCHAR2(120);
  ip         VARCHAR2(15);
  v_os_user  VARCHAR2(80);
  v_module   VARCHAR2(50);
  v_action   VARCHAR2(50);
  v_pid      VARCHAR2(10);
  v_sid      NUMBER;
  v_username VARCHAR2(50);
  v_suser    VARCHAR2(50);
BEGIN
  IF (ORA_IS_SERVERERROR(1017)) THEN
    IF UPPER(SYS_CONTEXT('USERENV', 'NETWORK_PROTOCOL')) = 'TCP' THEN
      ip := SYS_CONTEXT('USERENV', 'IP_ADDRESS');
    ELSE
      SELECT DISTINCT sid INTO v_sid FROM SYS.V_$MYSTAT;
      SELECT p.spid INTO v_pid FROM v$process p, v$session v WHERE p.addr = v.paddr AND v.sid = v_sid;
    END IF;
    v_os_user := SYS_CONTEXT('USERENV', 'OS_USER');
    v_username := SYS_CONTEXT('USERENV', 'CURRENT_USER');
    v_suser := SYS_CONTEXT('USERENV','SESSION_USER');
    DBMS_APPLICATION_INFO.READ_MODULE(v_module, v_action);
    message := TO_CHAR(SYSDATE, 'Dy Mon dd HH24:MI:SS YYYY')
               || ' logon denied from '
               || v_username
               || ' '
               || v_suser
               || ' '
               || NVL(ip, v_pid)
               || ' '
               || v_os_user
               || ' with '
               || v_module
               || ' '
               || v_action;
    SYS.DBMS_SYSTEM.KSDWRT(2, message);
  END IF;
END;
/
