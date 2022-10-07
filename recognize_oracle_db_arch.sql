REM
REM     Script:     recognize_oracle_db_arch.sql
REM     Author:     Quanwen Zhao
REM     Dated:      Oct 07, 2022
REM
REM     Last tested:
REM             10.2.0.1
REM             11.2.0.4
REM             12.2.0.1
REM             19.3.0.0
REM
REM     Purpose:
REM       The SQL script (it is oracle anonymous plsql blocks actually) uses to recognize oracle database architecture (such as, Single Instance, RAC, Data Guard) 
REM       and next lists some basic information of oracle database, it need to be run on SYS schema.
REM

SET SERVEROUTPUT ON;

DECLARE
  db_srv_names VARCHAR2(50);
  db_lsnr_port VARCHAR2(10);
  is_rac VARCHAR2(5);
  
  db_ver VARCHAR2(15);
  db_host_name VARCHAR2(30);
  db_ip_addr VARCHAR2(15);
  db_ins_name VARCHAR2(30);
  
  db_name VARCHAR2(30);
  db_unq_name VARCHAR2(30);
  db_platform_name VARCHAR2(50);
  db_open_mode VARCHAR2(30);
  db_log_mode VARCHAR2(15);
  db_role VARCHAR2(20);
  db_protect_mode VARCHAR2(20);
  db_swit_status VARCHAR2(30);
  
  db_arch VARCHAR2(20);
  
  remote_tns_name VARCHAR2(30);
  remote_db_unq_name VARCHAR2(30);
  dg_config VARCHAR2(80);
  dg_pry_arch VARCHAR2(20);
  dg_stby_arch VARCHAR2(20);
  
  db_cdb VARCHAR2(5);
BEGIN
  SELECT value INTO db_srv_names FROM v$parameter WHERE name = 'service_names';
  
  FOR cur_remote IN (
   SELECT SUBSTR(LOWER(value), 9, INSTR(LOWER(value), ' ', 1, 1)-9) remote_tns_name,
          SUBSTR(LOWER(value), INSTR(LOWER(value), 'db_unique_name=')+15) remote_db_unq_name
   FROM v$parameter
   WHERE name NOT LIKE 'log_archive_dest_state_%'
   AND name LIKE 'log_archive_dest_%'
   AND value IS NOT NULL
   AND LOWER(value) LIKE 'service%'
  )
  LOOP
    remote_tns_name := cur_remote.remote_tns_name;
    remote_db_unq_name := cur_remote.remote_db_unq_name;
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    DBMS_OUTPUT.PUT_LINE('Oracle Database Remote TNS Name: ' || remote_tns_name);
    DBMS_OUTPUT.PUT_LINE('Oracle Database Remote Unique Name: ' || remote_db_unq_name);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
  END LOOP;
  
  IF remote_tns_name IS NULL AND remote_db_unq_name IS NULL THEN
    SELECT value INTO is_rac FROM v$parameter WHERE name = 'cluster_database';
     
    IF is_rac = 'TRUE' THEN
      SELECT SUBSTR(listener, instr(listener, 'PORT=', 1, 2)+5, length(SUBSTR(listener, instr(listener, 'PORT=', 1, 2)+5))-3) listener_port
      INTO db_lsnr_port
      FROM v$dispatcher_config;
      
      db_arch := 'RAC';
      
      FOR cur_ins_and_db IN (
       WITH i AS
       (SELECT inst_id,
               version,
               host_name,
               utl_inaddr.get_host_address(host_name) ip_addr,
               instance_name
        FROM gv$instance
       ),
       d AS
       (SELECT inst_id,
               name,
               db_unique_name,
               platform_name,
               open_mode,
               log_mode,
               database_role,
               protection_mode,
               switchover_status
        FROM gv$database
       )
       SELECT i.version,
              i.host_name,
              i.ip_addr,
              i.instance_name,
              d.name,
              d.db_unique_name,
              d.platform_name,
              d.open_mode,
              d.log_mode,
              d.database_role,
              d.protection_mode,
              d.switchover_status
       FROM i, d
       WHERE i.inst_id = d.inst_id
       ORDER BY instance_name
      )
      LOOP
        DBMS_OUTPUT.PUT_LINE('*************************************************************************');
        DBMS_OUTPUT.PUT_LINE('Oracle Database Architecture: ' || db_arch);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Version: ' || cur_ins_and_db.version);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Host Name: ' || cur_ins_and_db.host_name);
        DBMS_OUTPUT.PUT_LINE('Oracle Database IP Address: ' || cur_ins_and_db.ip_addr);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Instance Name: ' || cur_ins_and_db.instance_name);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Database Name: ' || cur_ins_and_db.name);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Database Unique Name: ' || cur_ins_and_db.db_unique_name);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Platform Name: ' || cur_ins_and_db.platform_name);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Open Mode: ' || cur_ins_and_db.open_mode);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Log Mode: ' || cur_ins_and_db.log_mode);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Role: ' || cur_ins_and_db.database_role);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Protection Mode: ' || cur_ins_and_db.protection_mode);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Switchover Status: ' || cur_ins_and_db.switchover_status);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Service Names: ' || db_srv_names);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Listener Port: ' || db_lsnr_port);
        IF TO_NUMBER(SUBSTR(cur_ins_and_db.version, 1, 2)) >= 8 AND TO_NUMBER(SUBSTR(cur_ins_and_db.version, 1, 2)) <= 11 THEN
          db_cdb := 'NONE';
        ELSIF TO_NUMBER(SUBSTR(cur_ins_and_db.version, 1, 2)) = 12 OR TO_NUMBER(SUBSTR(cur_ins_and_db.version, 1, 2)) = 18 OR TO_NUMBER(SUBSTR(cur_ins_and_db.version, 1, 2)) = 19 THEN
          SELECT value INTO db_cdb FROM v$parameter where name = 'enable_pluggable_database';
        END IF;
        DBMS_OUTPUT.PUT_LINE('Oracle Database Multi-tenant: ' || db_cdb);
        $IF DBMS_DB_VERSION.VERSION >= 12 $THEN
          FOR cur_pdbs IN (SELECT name, open_mode FROM v$pdbs ORDER BY name)
          LOOP
            DBMS_OUTPUT.PUT_LINE('Oracle PDB Name: ' || cur_pdbs.name || ' Open Mode: ' || cur_pdbs.open_mode);
          END LOOP;
        $END
        DBMS_OUTPUT.PUT_LINE('*************************************************************************');
      END LOOP;
    ELSIF is_rac = 'FALSE' THEN
      SELECT SUBSTR(listener, instr(listener, 'PORT=')+5, length(SUBSTR(listener, instr(listener, 'PORT=')+5))-2) listener_port
      INTO db_lsnr_port
      FROM v$dispatcher_config;
      
      db_arch := 'Single Instance';
      
      SELECT version, host_name, utl_inaddr.get_host_address(host_name) ip_addr, instance_name
      INTO db_ver, db_host_name, db_ip_addr, db_ins_name
      FROM v$instance;
    
      SELECT name, db_unique_name, platform_name, open_mode, log_mode, database_role, protection_mode, switchover_status
      INTO db_name, db_unq_name, db_platform_name, db_open_mode, db_log_mode, db_role, db_protect_mode, db_swit_status
      FROM v$database;
      
      DBMS_OUTPUT.PUT_LINE('*************************************************************************');
      DBMS_OUTPUT.PUT_LINE('Oracle Database Architecture: ' || db_arch);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Version: ' || db_ver);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Host Name: ' || db_host_name);
      DBMS_OUTPUT.PUT_LINE('Oracle Database IP Address: ' || db_ip_addr);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Instance Name: ' || db_ins_name);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Database Name: ' || db_name);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Database Unique Name: ' || db_unq_name);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Platform Name: ' || db_platform_name);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Open Mode: ' || db_open_mode);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Log Mode: ' || db_log_mode);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Role: ' || db_role);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Protection Mode: ' || db_protect_mode);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Switchover Status: ' || db_swit_status);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Service Names: ' || db_srv_names);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Listener Port: ' || db_lsnr_port);
      IF TO_NUMBER(SUBSTR(db_ver, 1, 2)) >= 8 AND TO_NUMBER(SUBSTR(db_ver, 1, 2)) <= 11 THEN
        db_cdb := 'NONE';
      ELSIF TO_NUMBER(SUBSTR(db_ver, 1, 2)) = 12 OR TO_NUMBER(SUBSTR(db_ver, 1, 2)) = 18 OR TO_NUMBER(SUBSTR(db_ver, 1, 2)) = 19 THEN
        SELECT value INTO db_cdb FROM v$parameter where name = 'enable_pluggable_database';
      END IF;
      DBMS_OUTPUT.PUT_LINE('Oracle Database Multi-tenant: ' || db_cdb);
      $IF DBMS_DB_VERSION.VERSION >= 12 $THEN
        FOR cur_pdbs IN (SELECT name, open_mode FROM v$pdbs ORDER BY name)
        LOOP
          DBMS_OUTPUT.PUT_LINE('Oracle PDB Name: ' || cur_pdbs.name || ' Open Mode: ' || cur_pdbs.open_mode);
        END LOOP;
      $END
      DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    END IF;
  ELSIF remote_tns_name IS NOT NULL AND remote_db_unq_name IS NOT NULL THEN
    db_arch := 'Data Guard';
    
    SELECT value INTO is_rac FROM v$parameter WHERE name = 'cluster_database';
     
    IF is_rac = 'TRUE' THEN
      SELECT SUBSTR(listener, instr(listener, 'PORT=', 1, 2)+5, length(SUBSTR(listener, instr(listener, 'PORT=', 1, 2)+5))-3) listener_port
      INTO db_lsnr_port
      FROM v$dispatcher_config;
      
      FOR cur_ins_and_db IN (
       WITH i AS
       (SELECT inst_id,
               version,
               host_name,
               utl_inaddr.get_host_address(host_name) ip_addr,
               instance_name
        FROM gv$instance
       ),
       d AS
       (SELECT inst_id,
               name,
               db_unique_name,
               platform_name,
               open_mode,
               log_mode,
               database_role,
               protection_mode,
               switchover_status
        FROM gv$database
       )
       SELECT i.version,
              i.host_name,
              i.ip_addr,
              i.instance_name,
              d.name,
              d.db_unique_name,
              d.platform_name,
              d.open_mode,
              d.log_mode,
              d.database_role,
              d.protection_mode,
              d.switchover_status
       FROM i, d
       WHERE i.inst_id = d.inst_id
       ORDER BY instance_name
      )
      LOOP
        DBMS_OUTPUT.PUT_LINE('*************************************************************************');
        DBMS_OUTPUT.PUT_LINE('Oracle Database Architecture: ' || db_arch);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Version: ' || cur_ins_and_db.version);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Host Name: ' || cur_ins_and_db.host_name);
        DBMS_OUTPUT.PUT_LINE('Oracle Database IP Address: ' || cur_ins_and_db.ip_addr);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Instance Name: ' || cur_ins_and_db.instance_name);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Database Name: ' || cur_ins_and_db.name);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Database Unique Name: ' || cur_ins_and_db.db_unique_name);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Platform Name: ' || cur_ins_and_db.platform_name);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Open Mode: ' || cur_ins_and_db.open_mode);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Log Mode: ' || cur_ins_and_db.log_mode);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Role: ' || cur_ins_and_db.database_role);
        IF cur_ins_and_db.database_role = 'PRIMARY' THEN
          dg_pry_arch := 'RAC';
          DBMS_OUTPUT.PUT_LINE('Oracle Database Data Guard Primary Architecture: ' || dg_pry_arch);
        ELSIF cur_ins_and_db.database_role = 'PHYSICAL STANDBY' THEN
          dg_stby_arch := 'RAC';
          DBMS_OUTPUT.PUT_LINE('Oracle Database Data Guard Physical Standby Architecture: ' || dg_stby_arch);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Oracle Database Protection Mode: ' || cur_ins_and_db.protection_mode);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Switchover Status: ' || cur_ins_and_db.switchover_status);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Service Names: ' || db_srv_names);
        DBMS_OUTPUT.PUT_LINE('Oracle Database Listener Port: ' || db_lsnr_port);
        IF TO_NUMBER(SUBSTR(cur_ins_and_db.version, 1, 2)) >= 8 AND TO_NUMBER(SUBSTR(cur_ins_and_db.version, 1, 2)) <= 11 THEN
          db_cdb := 'NONE';
        ELSIF TO_NUMBER(SUBSTR(cur_ins_and_db.version, 1, 2)) = 12 OR TO_NUMBER(SUBSTR(cur_ins_and_db.version, 1, 2)) = 18 OR TO_NUMBER(SUBSTR(cur_ins_and_db.version, 1, 2)) = 19 THEN
          SELECT value INTO db_cdb FROM v$parameter where name = 'enable_pluggable_database';
        END IF;
        DBMS_OUTPUT.PUT_LINE('Oracle Database Multi-tenant: ' || db_cdb);
        $IF DBMS_DB_VERSION.VERSION >= 12 $THEN
          FOR cur_pdbs IN (SELECT name, open_mode FROM v$pdbs ORDER BY name)
          LOOP
            DBMS_OUTPUT.PUT_LINE('Oracle PDB Name: ' || cur_pdbs.name || ' Open Mode: ' || cur_pdbs.open_mode);
          END LOOP;
        $END
        DBMS_OUTPUT.PUT_LINE('*************************************************************************');
      END LOOP;
    ELSIF is_rac = 'FALSE' THEN
      SELECT SUBSTR(listener, instr(listener, 'PORT=')+5, length(SUBSTR(listener, instr(listener, 'PORT=')+5))-2) listener_port
      INTO db_lsnr_port
      FROM v$dispatcher_config;
      
      SELECT version, host_name, utl_inaddr.get_host_address(host_name) ip_addr, instance_name
      INTO db_ver, db_host_name, db_ip_addr, db_ins_name
      FROM v$instance;
    
      SELECT name, db_unique_name, platform_name, open_mode, log_mode, database_role, protection_mode, switchover_status
      INTO db_name, db_unq_name, db_platform_name, db_open_mode, db_log_mode, db_role, db_protect_mode, db_swit_status
      FROM v$database;
      
      DBMS_OUTPUT.PUT_LINE('*************************************************************************');
      DBMS_OUTPUT.PUT_LINE('Oracle Database Architecture: ' || db_arch);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Version: ' || db_ver);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Host Name: ' || db_host_name);
      DBMS_OUTPUT.PUT_LINE('Oracle Database IP Address: ' || db_ip_addr);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Instance Name: ' || db_ins_name);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Database Name: ' || db_name);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Database Unique Name: ' || db_unq_name);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Platform Name: ' || db_platform_name);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Open Mode: ' || db_open_mode);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Log Mode: ' || db_log_mode);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Role: ' || db_role);
      IF db_role = 'PRIMARY' THEN
        dg_pry_arch := 'Single Instance';
        DBMS_OUTPUT.PUT_LINE('Oracle Database Data Guard Primary Architecture: ' || dg_pry_arch);
      ELSIF db_role = 'PHYSICAL STANDBY' THEN
        dg_stby_arch := 'Single Instance';
        DBMS_OUTPUT.PUT_LINE('Oracle Database Data Guard Physical Standby Architecture: ' || dg_stby_arch);
      END IF;
      DBMS_OUTPUT.PUT_LINE('Oracle Database Protection Mode: ' || db_protect_mode);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Switchover Status: ' || db_swit_status);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Service Names: ' || db_srv_names);
      DBMS_OUTPUT.PUT_LINE('Oracle Database Listener Port: ' || db_lsnr_port);
      IF TO_NUMBER(SUBSTR(db_ver, 1, 2)) >= 8 AND TO_NUMBER(SUBSTR(db_ver, 1, 2)) <= 11 THEN
        db_cdb := 'NONE';
      ELSIF TO_NUMBER(SUBSTR(db_ver, 1, 2)) = 12 OR TO_NUMBER(SUBSTR(db_ver, 1, 2)) = 18 OR TO_NUMBER(SUBSTR(db_ver, 1, 2)) = 19 THEN
        SELECT value INTO db_cdb FROM v$parameter where name = 'enable_pluggable_database';
      END IF;
      DBMS_OUTPUT.PUT_LINE('Oracle Database Multi-tenant: ' || db_cdb);
      $IF DBMS_DB_VERSION.VERSION >= 12 $THEN
        FOR cur_pdbs IN (SELECT name, open_mode FROM v$pdbs ORDER BY name)
        LOOP
          DBMS_OUTPUT.PUT_LINE('Oracle PDB Name: ' || cur_pdbs.name || ' Open Mode: ' || cur_pdbs.open_mode);
        END LOOP;
      $END
      DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    END IF;  
  END IF;
END;
/
