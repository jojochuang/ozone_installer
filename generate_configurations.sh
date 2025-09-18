#!/bin/bash

# Generate Ozone Configuration Files
# This script creates core-site.xml, ozone-site.xml, and log4j.properties

set -e

# Configuration file path
CONFIG_FILE="$(dirname "$0")/ozone_installer.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Function to load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Source the configuration file
    source "$CONFIG_FILE"
}

# Function to create core-site.xml
create_core_site_xml() {
    local output_file="$1"
    
    log "Creating core-site.xml at $output_file"
    
    cat > "$output_file" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>ofs://ozone1/</value>
    <description>The default filesystem URI</description>
  </property>
  
  <property>
    <name>fs.ofs.impl</name>
    <value>org.apache.hadoop.fs.ozone.OzoneFileSystem</value>
  </property>
  
  <property>
    <name>fs.AbstractFileSystem.ofs.impl</name>
    <value>org.apache.hadoop.fs.ozone.OzFs</value>
  </property>
</configuration>
EOF
}

# Function to create ozone-site.xml
create_ozone_site_xml() {
    local output_file="$1"
    
    log "Creating ozone-site.xml at $output_file"
    
    # Get the first host as SCM and OM leader
    IFS=',' read -ra HOSTS <<< "$CLUSTER_HOSTS"
    local primary_host=$(echo "${HOSTS[0]}" | xargs)
    
    cat > "$output_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<configuration>
  <!-- Storage Container Manager (SCM) Configuration -->
  <property>
    <name>ozone.scm.names</name>
    <value>$primary_host</value>
    <description>The hostname or IP address of the Storage Container Manager</description>
  </property>
  
  <property>
    <name>ozone.scm.db.dirs</name>
    <value>$OZONE_SCM_DB_DIRS</value>
    <description>SCM metadata storage directory</description>
  </property>
  
  <property>
    <name>ozone.scm.ha.ratis.storage.dir</name>
    <value>$OZONE_SCM_HA_RATIS_STORAGE_DIR</value>
    <description>SCM Ratis storage directory</description>
  </property>
  
  <property>
    <name>ozone.metadata.dirs</name>
    <value>$OZONE_SCM_METADATA_DIRS</value>
    <description>SCM metadata directory</description>
  </property>
  
  <!-- Ozone Manager (OM) Configuration -->
  <property>
    <name>ozone.om.address</name>
    <value>$primary_host</value>
    <description>The hostname or IP address of the Ozone Manager</description>
  </property>
  
  <property>
    <name>ozone.om.db.dirs</name>
    <value>$OZONE_OM_DB_DIR</value>
    <description>OM metadata storage directory</description>
  </property>
  
  <property>
    <name>ozone.om.ratis.storage.dir</name>
    <value>$OZONE_OM_RATIS_STORAGE_DIR</value>
    <description>OM Ratis storage directory</description>
  </property>
  
  <!-- Recon Configuration -->
  <property>
    <name>ozone.recon.address</name>
    <value>$primary_host</value>
    <description>The hostname or IP address of Recon</description>
  </property>
  
  <property>
    <name>ozone.recon.db.dir</name>
    <value>$OZONE_RECON_DB_DIR</value>
    <description>Recon database directory</description>
  </property>
  
  <property>
    <name>ozone.recon.scm.db.dirs</name>
    <value>$OZONE_RECON_SCM_DB_DIRS</value>
    <description>Recon SCM database directory</description>
  </property>
  
  <property>
    <name>ozone.recon.om.db.dir</name>
    <value>$OZONE_RECON_OM_DB_DIR</value>
    <description>Recon OM database directory</description>
  </property>
  
  <!-- DataNode Configuration -->
  <property>
    <name>ozone.scm.datanode.id.dir</name>
    <value>$OZONE_SCM_DATANODE_ID_DIR</value>
    <description>DataNode ID storage directory</description>
  </property>
  
  <property>
    <name>dfs.container.ratis.datanode.storage.dir</name>
    <value>$DFS_CONTAINER_RATIS_DATANODE_STORAGE_DIR</value>
    <description>DataNode Ratis storage directory</description>
  </property>
  
  <property>
    <name>hdds.datanode.dir</name>
    <value>$HDDS_DATANODE_DIR</value>
    <description>DataNode data storage directory</description>
  </property>
  
  <!-- General Configuration -->
  <property>
    <name>ozone.enabled</name>
    <value>true</value>
    <description>Enable Ozone in the cluster</description>
  </property>
  
  <property>
    <name>ozone.security.enabled</name>
    <value>false</value>
    <description>Security is disabled for simplicity in this setup</description>
  </property>
  
</configuration>
EOF
}

# Function to create log4j.properties
create_log4j_properties() {
    local output_file="$1"
    
    log "Creating log4j.properties at $output_file"
    
    cat > "$output_file" << 'EOF'
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Define some default values that can be overridden by system properties
hadoop.root.logger=INFO,console
hadoop.log.dir=.
hadoop.log.file=hadoop.log

# Define the root logger to the system property "hadoop.root.logger".
log4j.rootLogger=${hadoop.root.logger}, EventCounter

# Logging Threshold
log4j.threshold=ALL

# Null Appender
log4j.appender.NullAppender=org.apache.log4j.varia.NullAppender

#
# Rolling File Appender - cap space usage at 5gb.
#
hadoop.log.maxfilesize=256MB
hadoop.log.maxbackupindex=20
log4j.appender.RFA=org.apache.log4j.RollingFileAppender
log4j.appender.RFA.File=${hadoop.log.dir}/${hadoop.log.file}

log4j.appender.RFA.MaxFileSize=${hadoop.log.maxfilesize}
log4j.appender.RFA.MaxBackupIndex=${hadoop.log.maxbackupindex}

log4j.appender.RFA.layout=org.apache.log4j.PatternLayout

# Pattern format: Date LogLevel LoggerName LogMessage
log4j.appender.RFA.layout.ConversionPattern=%d{ISO8601} %p %c: %m%n
# Debugging Pattern format
#log4j.appender.RFA.layout.ConversionPattern=%d{ISO8601} %-5p %c{2} (%F:%M(%L)) - %m%n


#
# Daily Rolling File Appender
#

log4j.appender.DRFA=org.apache.log4j.DailyRollingFileAppender
log4j.appender.DRFA.File=${hadoop.log.dir}/${hadoop.log.file}

# Rollover at midnight
log4j.appender.DRFA.DatePattern=.yyyy-MM-dd

log4j.appender.DRFA.layout=org.apache.log4j.PatternLayout

# Pattern format: Date LogLevel LoggerName LogMessage
log4j.appender.DRFA.layout.ConversionPattern=%d{ISO8601} %p %c: %m%n
# Debugging Pattern format
#log4j.appender.DRFA.layout.ConversionPattern=%d{ISO8601} %-5p %c{2} (%F:%M(%L)) - %m%n


#
# console
# Add "console" to rootlogger above if you want to use this
#

log4j.appender.console=org.apache.log4j.ConsoleAppender
log4j.appender.console.target=System.err
log4j.appender.console.layout=org.apache.log4j.PatternLayout
log4j.appender.console.layout.ConversionPattern=%d{yy/MM/dd HH:mm:ss} %p %c{2}: %m%n

#
# TaskLog Appender
#

#Default values
hadoop.tasklog.taskid=null
hadoop.tasklog.iscleanup=false
hadoop.tasklog.noKeepSplits=4
hadoop.tasklog.totalLogFileSize=100
hadoop.tasklog.purgeLogSplits=true
hadoop.tasklog.logsRetainHours=12

log4j.appender.TLA=org.apache.hadoop.mapred.TaskLogAppender
log4j.appender.TLA.taskId=${hadoop.tasklog.taskid}
log4j.appender.TLA.isCleanup=${hadoop.tasklog.iscleanup}
log4j.appender.TLA.totalLogFileSize=${hadoop.tasklog.totalLogFileSize}

log4j.appender.TLA.layout=org.apache.log4j.PatternLayout
log4j.appender.TLA.layout.ConversionPattern=%d{ISO8601} %p %c: %m%n

#
# HDFS block state change log from block manager
#
# Uncomment the following to suppress normal block state change
# messages from BlockManager in NameNode.
#log4j.logger.BlockStateChange=WARN

#
#Security appender
#
hadoop.security.logger=INFO,NullAppender
hadoop.security.log.maxfilesize=256MB
hadoop.security.log.maxbackupindex=20
log4j.category.SecurityLogger=${hadoop.security.logger}
log4j.additivity.SecurityLogger=false
log4j.appender.RFAS=org.apache.log4j.RollingFileAppender
log4j.appender.RFAS.File=${hadoop.log.dir}/${hadoop.security.log.file}
log4j.appender.RFAS.layout=org.apache.log4j.PatternLayout
log4j.appender.RFAS.layout.ConversionPattern=%d{ISO8601} %p %c: %m%n
log4j.appender.RFAS.MaxFileSize=${hadoop.security.log.maxfilesize}
log4j.appender.RFAS.MaxBackupIndex=${hadoop.security.log.maxbackupindex}

#
# hdfs audit logging
#
hdfs.audit.logger=INFO,NullAppender
hdfs.audit.log.maxfilesize=256MB
hdfs.audit.log.maxbackupindex=20
log4j.logger.org.apache.hadoop.hdfs.server.namenode.FSNamesystem.audit=${hdfs.audit.logger}
log4j.additivity.org.apache.hadoop.hdfs.server.namenode.FSNamesystem.audit=false
log4j.appender.RFAAUDIT=org.apache.log4j.RollingFileAppender
log4j.appender.RFAAUDIT.File=${hadoop.log.dir}/hdfs-audit.log
log4j.appender.RFAAUDIT.layout=org.apache.log4j.PatternLayout
log4j.appender.RFAAUDIT.layout.ConversionPattern=%d{ISO8601} %p %c{2}: %m%n
log4j.appender.RFAAUDIT.MaxFileSize=${hdfs.audit.log.maxfilesize}
log4j.appender.RFAAUDIT.MaxBackupIndex=${hdfs.audit.log.maxbackupindex}

# Event Counter Appender
# Sends counts of logging messages at different severity levels to Hadoop Metrics.
log4j.appender.EventCounter=org.apache.hadoop.log.metrics.EventCounter

#
# Ozone audit logging
#
ozone.audit.log.maxfilesize=256MB
ozone.audit.log.maxbackupindex=20
log4j.logger.OzoneAudit=INFO,OZONEAUDIT
log4j.additivity.OzoneAudit=false
log4j.appender.OZONEAUDIT=org.apache.log4j.RollingFileAppender
log4j.appender.OZONEAUDIT.File=${hadoop.log.dir}/ozone-audit.log
log4j.appender.OZONEAUDIT.layout=org.apache.log4j.PatternLayout
log4j.appender.OZONEAUDIT.layout.ConversionPattern=%d{ISO8601} %p %c{2}: %m%n
log4j.appender.OZONEAUDIT.MaxFileSize=${ozone.audit.log.maxfilesize}
log4j.appender.OZONEAUDIT.MaxBackupIndex=${ozone.audit.log.maxbackupindex}

# Ozone specific logging
log4j.logger.org.apache.hadoop.ozone=INFO
log4j.logger.org.apache.hadoop.hdds=INFO
EOF
}

# Function to distribute configuration files to all hosts
distribute_configs() {
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"
    
    # Create output directory if it doesn't exist
    local output_dir="./ozone-config"
    mkdir -p "$output_dir"
    
    # Create configuration files locally first
    create_core_site_xml "$output_dir/core-site.xml"
    create_ozone_site_xml "$output_dir/ozone-site.xml"
    create_log4j_properties "$output_dir/log4j.properties"
    
    # Convert CLUSTER_HOSTS to array
    IFS=',' read -ra HOSTS <<< "$CLUSTER_HOSTS"
    
    # Distribute to each host
    for host in "${HOSTS[@]}"; do
        host=$(echo "$host" | xargs)
        
        info "Distributing configuration files to $host"
        
        # Create Ozone configuration directory on remote host
        ssh -i "$ssh_key_expanded" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
            mkdir -p /etc/hadoop/conf
            mkdir -p /opt/ozone/etc/hadoop
        "
        
        # Copy configuration files
        scp -i "$ssh_key_expanded" -o StrictHostKeyChecking=no "$output_dir/core-site.xml" "$SSH_USER@$host:/etc/hadoop/conf/"
        scp -i "$ssh_key_expanded" -o StrictHostKeyChecking=no "$output_dir/ozone-site.xml" "$SSH_USER@$host:/etc/hadoop/conf/"
        scp -i "$ssh_key_expanded" -o StrictHostKeyChecking=no "$output_dir/log4j.properties" "$SSH_USER@$host:/etc/hadoop/conf/"
        
        # Also copy to Ozone directory
        ssh -i "$ssh_key_expanded" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
            cp /etc/hadoop/conf/core-site.xml /opt/ozone/etc/hadoop/ 2>/dev/null || true
            cp /etc/hadoop/conf/ozone-site.xml /opt/ozone/etc/hadoop/ 2>/dev/null || true
            cp /etc/hadoop/conf/log4j.properties /opt/ozone/etc/hadoop/ 2>/dev/null || true
        "
        
        log "Configuration files distributed to $host"
    done
}

# Main function
main() {
    log "Starting Ozone Configuration Generator"
    
    # Load configuration
    load_config
    
    if [[ -z "$CLUSTER_HOSTS" ]]; then
        error "CLUSTER_HOSTS is empty in configuration file"
        exit 1
    fi
    
    # Generate and distribute configuration files
    distribute_configs
    
    log "Ozone configuration files generated and distributed successfully"
    log "Configuration files are available in:"
    log "  - Local: ./ozone-config/"
    log "  - Remote hosts: /etc/hadoop/conf/ and /opt/ozone/etc/hadoop/"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi