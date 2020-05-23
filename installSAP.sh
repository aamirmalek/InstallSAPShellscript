#!/usr/bin/env sh

################################################################################
# 
# install_SAP.sh
# 
# Version:  3.9
# RS        2016/08/05 01:35 PM
# 
# 
# - mount software-depot from fileserver
# - prepare host to run SAP
# - conduct SAP installation
# - check SAP installation
# 
# 
# CHANGELOG
# 3.9   
#       - refactoring of function _prepare_sap_infrastructure
#       - refactoring of error handling (function _exit_on_error)
#       - refactoring and renaming function _prepare_process_xslt to _determine_sap_product_id
#       - new function to manipulate SAP profiles
#       - Oracle autostart (init)
#       - set autostart=y for HDB
#       - improved fstab handling
#       - included possibility to install HDB and SAP on the same host
#       - moved sanity_check for scrGlobalHost into SAP section
#       - provide the option to run sapinst until summary phase using scrDryRun
#       - include Secure Storage Key Generation
#       - remove spaces from local_input.ini
#       - changed scrSapFlavour into scrSapStack
#       - replace makeProperEtcHosts.awk file with three simple sed commands
#       - delete obsolete function prepareInputParamIni
#       - consistent file names for temporary or backup files
#       - moving sapinst_instdir to sapinst_instdir.$$
#       - implemented workaround for MCOD installation with Oracle
#       - fix for DB-user Names now using DBSID
#       - refined the section for calling OUI. removed temporary file OO-ora.log
# 3.8
#       - including Doublestack
#       - deleting DBSIZE.XML check for Sybase
#       - new option to use inifile.params
#       - new option to stop the installation at summary phase
#       - Uncomment createDBFolders
#       - important variables in inifile will be set to local_input.ini values
#       - Check for running sapinst
#       - Introduced DB-SID
#       - Entered Database Schema for Java
#       - HDB Config file working
#       - complete AAS for all DBs
#       - Modified Oracle Installation. DatabaseSchema is now set by inifile.params
#
# 3.7.1
#       - support for SAP NW 7.5 and SAP Business Suite 2016
#       - changed the sapinst parameter options
#
# 3.7
#       - fixed SAP installation with Oracle
#       - refactoring the _check_db_status() function
#       - refactoring the functionality for mounting the global host share
#       - removed the mounting of shared HANA directory
#       - refactoring the script to be POSIX compliant
#       - change shebang from #!/bin/sh to #!/usr/bin/env sh
#       - removed deprecated JCEPolicyFile
#       - updated HostFunctions to be consistent with SAP instance naming
#         standard, ascs, scs, db, pas, aas
#       - fixed missing SCS support for Java installations
#       - removed old variables (backward compatibility)
#       - added option for length and characters of the random password
#       - removed old or not used functions
#       - code cleanup
#       - adjusted makeProperEtcHosts function
#
# 3.6
#       - code cleanup
#       - fixed some problems
#       - changed from hdbinst to hdblcm for HANA deployments
#       - support for S/4HANA on-premise 1511 (official release)
#
# 3.5
#       - support for S/4HANA on-premise 1511 (internal release)
# 
# 3.3
#       - adjusted naming of host functions
#
# 3.2
#       - added support for S/4HANA 
#
# 3.1
#       - added support for HANA Database installations (TDI)
#
# 3.0
#       - added support for Business Suite on HANA and S/4HANA installations
#
# 2.0
#       - removed HP-UX support
#       - new processing of Product-ID
#       - improved handling of sapinst
#       - SWPM required
#
# 1.1
#       - update to support 70-SWPM
#       - automatic OS configuration LX
#       - Kernel 3.0 support SLES11-SP2
#       - rewrite of sapinst section
#
# 1.0
#       - initial release built out of OO workflow operations
#         and other already existing scripts
# 
################################################################################

################################################################################
# Add sapinst group
################################################################################
_add_sapinst_group()
{
    grep -q sapinst /etc/group || echo "sapinst:x:1000:root" >> /etc/group
}

################################################################################
# Add HPE header long
################################################################################
_add_hpe_header_long()
{
    echo "#-----------------------------------------------------------------------"
    _add_hpe_header_short
    echo "#-----------------------------------------------------------------------"
}

################################################################################
# Add HPE header short
################################################################################
_add_hpe_header_short()
{
    echo "# Added by HPE Automated Installation"
}

################################################################################
# Attach the global host
################################################################################
#_attach_global_host()
#{
#    ${ECHO} "$(date)\t Attaching Global Host." >> "${DEV_LOG}"
    # grep -q HPE /etc/fstab || _add_hpe_header_long >> /etc/fstab

    # if [ "$scrMultipleOS" = "true"  ]; then
        # mountlist="global profile"
        # ${ECHO} "$(date)\t Heterogeneous Installation. Mounting ==>${mountlist}<==" >> "${DEV_LOG}"
    # else
        # mountlist="exe global profile"
        # ${ECHO} "$(date)\t Homogeneous Installation. Mounting ==>${mountlist}<==" >> "${DEV_LOG}"
    # fi

    # for dir in ${mountlist}; do
        # [ -d "${SAPMNT_MOUNTPOINT}/${scrSID}/${dir}" ] || mkdir -p "${SAPMNT_MOUNTPOINT}/${scrSID}/${dir}"

        # mount | grep -q "${SAPMNT_MOUNTPOINT}/${scrSID}/${dir}"
        # if [ "$?" -ne 0 ]; then
            # ${ECHO} "$(date)\t 'mount -o rsize=32768,wsize=32768 ${scrGlobalHost}:${SAPMNT_MOUNTPOINT}/${scrSID}/${dir} ${SAPMNT_MOUNTPOINT}/${scrSID}/${dir} >/dev/null 2>&1'" >> "${DEV_LOG}"
            # mount -o rsize=32768,wsize=32768 "${scrGlobalHost}:${SAPMNT_MOUNTPOINT}/${scrSID}/${dir}" "${SAPMNT_MOUNTPOINT}/${scrSID}/${dir}" >/dev/null 2>&1
            # [ "$?" -ne 0 ] && _exit_on_error "MOUNT_ERROR - Could not mount central share. Mount of ${scrGlobalHost}:${SAPMNT_MOUNTPOINT}/${scrSID}/${dir} went wrong!" "${LINENO}"
        # fi

        # grep -q "${SAPMNT_MOUNTPOINT}/${scrSID}/${dir}" /etc/fstab
        # [ "$?" -ne 0 ] && echo "${scrGlobalHost}:${SAPMNT_MOUNTPOINT}/${scrSID}/${dir} ${SAPMNT_MOUNTPOINT}/${scrSID}/${dir} nfs defaults,rsize=32768,wsize=32768 0 0" >> /etc/fstab
    # done

    # # Sanity check
    # for dir in ${mountlist}; do
        # mount | grep -iq "${scrGlobalHost}:${SAPMNT_MOUNTPOINT}/${scrSID}/${dir}" || _exit_on_error "MOUNTCHECK_ERROR - One ore more central shares not mounted. ${scrGlobalHost}:${SAPMNT_MOUNTPOINT}/${scrSID}/${dir} not mounted!" "${LINENO}"
    # done
# }

################################################################################
# Check DB Status
################################################################################
_check_db_status()
{
    DB_ONLINE=false

    case "${scrDatabaseVendor}" in
        ADA)
            su - "${SQDSID}" -c 'dbmcli -U c db_state' | grep -q ONLINE && DB_ONLINE=true
            ;;
        DB6)
            su - "${DB2SID}" -c 'db2pd -' | grep -q Active && DB_ONLINE=true
            ;;
        HDB)
            # ToDo: check HDB with: sapcontrol -host RH0ac9c7fc21 -nr 00 -function GetProcessList
            su - "${SIDADM_HDB}" -c 'HDB info' | grep -q hdbxsengine && DB_ONLINE=true
            ;;
        ORA)
            ps -ef | grep pmon | grep -q "${scrSID}" && DB_ONLINE=true
            ;;
        SYB)
            ps -ef | grep dataserver | grep -q "${scrSID}" && DB_ONLINE=true
            ;;
        *)
            _exit_on_error "UNKNOWN_DB_VENDOR - '${scrDatabaseVendor}' not supported." "${LINENO}"
            ;;
    esac
}

################################################################################
# Check /etc/hosts
################################################################################
_check_etc_hosts()
{
    ${ECHO} "$(date)\t Make proper '/etc/hosts' file" >> "${INSTALLATION_LOG}"
    [ "${INSTALL_SAP_OR_HDB}" = "hdb" ] && host="${HOSTNAME_HDB}" || host="${HOSTNAME}"

    header=$( _add_hpe_header_short )

    sed -i "s/^\(127\.0\.0\.1\).*${host}.*/${header}\n#&\n\1\tlocalhost/gi" /etc/hosts
    sed -i "s/^127\..*${host}.*/${header}\n#&/gi" /etc/hosts
    sed -i "s/^\(::1\).*${host}.*/${header}\n#&\n\1\t\tlocalhost/gi" /etc/hosts
}

################################################################################
# Check for NFS Server
################################################################################
#_check_nfs_server()
{
    if [ "${scrHostFunction}" = "standard" ] || [ "${scrHostFunction}" = "ascs" ] || [ "${scrHostFunction}" = "scs" ] || [ "${INSTALL_SAP_OR_HDB}" = "hdb" ]; then
        ${ECHO} "$(date)\t Checking for Kernel NFS server" >> "${INSTALLATION_LOG}"

        # check if nfs server is installed
        [ "${DISTRO}" = "RHEL" ] && _check_packages 'rpcbind nfs-utils'
        [ "${DISTRO}" = "SLES" ] && _check_packages 'rpcbind nfs-kernel-server'

        # ensure rpcbind and nfs-server services are enabled and running
        if [ "${DISTRO_VERSION}" = "RHEL6" ]; then
            chkconfig rpcbind on >/dev/null || _exit_on_error "ERROR_RPCBIND_ENABLE - Error enabling 'rpcbind' service!" "${LINENO}"
            service rpcbind start >/dev/null || _exit_on_error "ERROR_RPCBIND_START - Error starting 'rpcbind' service!" "${LINENO}"
            chkconfig nfs on >/dev/null || _exit_on_error "ERROR_NFS_ENABLE - Error enabling 'nfs' service!" "${LINENO}"
            service nfs start >/dev/null || _exit_on_error "ERROR_NFS_START - Error starting 'nfs' service!" "${LINENO}"
        elif [ "${DISTRO_VERSION}" = "SLES11" ]; then
            chkconfig rpcbind on >/dev/null || _exit_on_error "ERROR_RPCBIND_ENABLE - Error enabling 'rpcbind' service!" "${LINENO}"
            service rpcbind start >/dev/null || _exit_on_error "ERROR_RPCBIND_START - Error starting 'rpcbind' service!" "${LINENO}"
            chkconfig nfsserver on >/dev/null || _exit_on_error "ERROR_NFSSERVER_ENABLE - Error enabling 'nfsserver' service!" "${LINENO}"
            service nfsserver start >/dev/null || _exit_on_error "ERROR_NFSSERVER_START - Error starting 'nfsserver' service!" "${LINENO}"
        elif [ "${DISTRO_VERSION}" = "RHEL7" ] || [ "${DISTRO_VERSION}" = "SLES12" ]; then
            systemctl enable rpcbind >/dev/null || _exit_on_error "ERROR_RPCBIND_ENABLE - Error enabling 'rpcbind' service!" "${LINENO}"
            systemctl start rpcbind >/dev/null || _exit_on_error "ERROR_RPCBIND_START - Error starting 'rpcbind' service!" "${LINENO}"
            systemctl enable nfs-server >/dev/null || _exit_on_error "ERROR_NFSSERVER_ENABLE - Error enabling 'nfs-server' service!" "${LINENO}"
            systemctl start nfs-server >/dev/null || _exit_on_error "ERROR_NFSSERVER_START - Error starting 'nfs-server' service!" "${LINENO}"
        fi
    fi
}

################################################################################
# Check distro packages
#
# Arguments:
#   packages    List of packages to check separated by space
################################################################################
_check_packages()
{
    packages="${1}"

    for package in ${packages}; do
        rpm -qa | grep -iq ^"${package}" || _exit_on_error "PACKAGE_NOT_FOUND - The '${package}' package is not installed on your system." "${LINENO}"
    done
}

################################################################################
# Check requirements
################################################################################
_check_requirements()
{
    # Check if package requirements are met
    ${ECHO} "$(date)\t Check if package requirements are met." >> "${DEV_LOG}"
    if [ "${DISTRO_VERSION}" = "RHEL6" ] || [ "${DISTRO_VERSION}" = "RHEL7" ]; then
        _check_packages 'libuuid uuidd'
    elif [ "${DISTRO_VERSION}" = "SLES11" ]; then
        _check_packages 'sapconf libuuid1 uuid-runtime'
    elif [ "${DISTRO_VERSION}" = "SLES12" ]; then
        _check_packages 'sapconf libuuid1 uuidd'
    fi

    # Ensure uuidd service is enabled and running
    ${ECHO} "$(date)\t Ensure uuidd service is enabled and running." >> "${DEV_LOG}"
    if [ "${DISTRO_VERSION}" = "RHEL6" ] || [ "${DISTRO_VERSION}" = "SLES11" ]; then
        chkconfig uuidd on >/dev/null || _exit_on_error "ERROR_UUIDD_ENABLE - Error enabling 'uuidd' service!" "${LINENO}"
        service uuidd start >/dev/null || _exit_on_error "ERROR_UUIDD_START - Error starting 'uuidd' service!" "${LINENO}"
    elif [ "${DISTRO_VERSION}" = "RHEL7" ] || [ "${DISTRO_VERSION}" = "SLES12" ]; then
        systemctl enable uuidd >/dev/null || _exit_on_error "ERROR_UUIDD_ENABLE - Error enabling 'uuidd' service!" "${LINENO}"
        systemctl start uuidd >/dev/null || _exit_on_error "ERROR_UUIDD_START - Error starting 'uuidd' service!" "${LINENO}"
    fi
}

################################################################################
# Configuring NFS
################################################################################
#_configure_nfs()
#{
#    local_ip=$( getent hosts "${scrHostnameFQDN}" | awk '{print $1}' )
#    ${ECHO} "$(date)\t Determining local production network mask in CIDR prefix notation" >> "${DEV_LOG}"
#    local_production_net=$( ip route | grep "${local_ip}" | awk '{print $1}' )
#
#    ${ECHO} "$(date)\t Determining local deployment network mask in CIDR prefix notation" >> "${DEV_LOG}"
    # shellcheck disable=SC2154
#    local_deployment_net=$( ip route | grep "${scrDeploymentIpAddr}" | awk '{print $1}' )
#
#    ${ECHO} "$(date)\t Updating /etc/exports with ${SAPMNT_MOUNTPOINT}/${scrSID} data" >> "${DEV_LOG}"
#    grep -q HPE /etc/exports || _add_hpe_header_short >> /etc/exports
#    echo "${SAPMNT_MOUNTPOINT}/${scrSID} ${local_production_net}(rw,no_root_squash,no_subtree_check,fsid=0)" >> /etc/exports
#    if [ "${local_production_net}" != "${local_deployment_net}" ]; then
#        echo "${SAPMNT_MOUNTPOINT}/${scrSID} ${local_deployment_net}(rw,no_root_squash,no_subtree_check,fsid=0)" >> /etc/exports
#    fi

    # export the nfs share
 #   exportfs -a >/dev/null || _exit_on_error "NFS_EXPORT_FAILED - Cannot export the nfs share with 'exportfs -a'." "${LINENO}"
#}

################################################################################
# Create local directories
################################################################################
_create_local_directories()
{
   [ -d "${SAPINST_INSTDIR}" ] || mkdir -p "${SAPINST_INSTDIR}"
 
    chmod 775 "${SAPINST_INSTDIR}"
    chgrp sapinst "${SAPINST_INSTDIR}"
}

################################################################################
# Create random SAP master password
#
# Arguments:
#   none
# Returns:
#   stdout
################################################################################
_create_master_password()
{
    valid_pwd='false'
    while [ "${valid_pwd}" = 'false' ]; do
        stdout=$( head -c 500 /dev/urandom | tr -dc "${PWCHAR}" | fold -w "${PWLENGTH}" | head -n 1 )
        echo "${stdout}" | grep -E '^[a-zA-Z#$][a-zA-Z0-9_#$]{7,13}$' | grep '[a-zA-Z]' | grep -q '[0-9]' && valid_pwd='true'
    done

    # return the password
    echo "${stdout}"
}

################################################################################
# Create Oracle autostart (init)
################################################################################
_create_oracle_autostart()
{
    # shellcheck disable=SC2016
    stdout=$( su - "${ORASID}" -c 'echo ${ORACLE_HOME}' )
    [ -d "${stdout}" ] || _exit_on_error "NO_ORACLE_HOME - Was not able to get the ORACLE_HOME environment variable!" "${LINENO}"

    if [ -f /etc/oratab ]; then
        # create copy of /etc/oratab
        cp -p /etc/oratab /etc/oratab.HPE_AI_BCK_"${scrSID_DB}"
        # comment the entry if available
        sed -i "s/^${scrSID_DB}/#&/g" /etc/oratab
    fi

    # create /etc/oratab autostart entry
    _add_hpe_header_long >> /etc/oratab
    echo "${scrSID_DB}:${stdout}:Y" >> /etc/oratab

    if [ ! -f /etc/init.d/dbora ]; then
        cat <<EOF > /etc/init.d/dbora
#!/bin/sh
#
# chkconfig: 345 99 10
# description: Start and stop Oracle Database Enterprise Edition

### BEGIN INIT INFO
# Provides: dbora
# Required-Start: \$network \$syslog \$remote_fs \$time
# X-UnitedLinux-Should-Start:
# Required-Stop:
# Default-Start: 3 5
# Default-Stop: 0 1 2 6
# Short-Description: Start and stop the Oracle Database Enterprise Edition
# Description: Start the Oracle Database Enterprise Edition
### END INIT INFO

ORACLE_HOME=${stdout}
ORACLE=oracle

PATH=\${PATH}:\${ORACLE_HOME}/bin
export \${PATH} \${ORACLE_HOME}

case "\${1}" in
    start)
        su \${ORACLE} -c "\${ORACLE_HOME}/bin/dbstart \${ORACLE_HOME}" &
        ;;
    stop)
        su \${ORACLE} -c "\${ORACLE_HOME}/bin/dbshut \${ORACLE_HOME}" &
        ;;
    restart)
        su \${ORACLE} -c "\${ORACLE_HOME}/bin/dbshut \${ORACLE_HOME}" &
        sleep 5
        su \${ORACLE} -c "\${ORACLE_HOME}/bin/dbstart \${ORACLE_HOME}" &
        ;;
    *)
        echo "usage: \${0} {start|stop|restart}"
        exit
        ;;
esac
EOF
    fi

    # Set group and rights
    chgrp dba /etc/init.d/dbora || _exit_on_error "ERROR_CHGRP_DBORA - Error adding group 'dba' to 'dbora' service!" "${LINENO}"
    chmod 750 /etc/init.d/dbora || _exit_on_error "ERROR_CHMOD_DBORA - Error changing rights for 'dbora' service!" "${LINENO}"

    # Ensure dbora service is created and enabled
    chkconfig --add dbora >/dev/null || _exit_on_error "ERROR_ADDING_DBORA - Error adding 'dbora' service!" "${LINENO}"
    chkconfig dbora on >/dev/null || _exit_on_error "ERROR_DBORA_ENABLE - Error enabling 'dbora' service!" "${LINENO}"
}

################################################################################
# Secure Storage Key Generation
################################################################################
_create_secure_storage_key()
{
    if [ ! -f "${SECURE_STORAGE_FILE}" ]; then
        # Generate Secure Storage Key ID
        secure_storage_key_id=$( date +%Y%m%d_%H%M%S_"${scrSID}"_INSTALLER )

        path_dbindep=$( find -L "${SAP_MEDIA_DIR}" -name DBINDEP -type d | grep -i "_U_${OS_SEARCH}" | head -n 1 )
        file_list=$( "${path_dbindep}/SAPCAR" -tvf "${path_dbindep}/SAPEXE.SAR" | grep libicu | awk '{print $NF}' | tr '\n' ' ' )
        ${ECHO} "$(date)\t Extract files for Secure Storage Key Generation 'rsecssfx ${file_list}'." >> "${DEV_LOG}"
        # shellcheck disable=SC2086
        "${path_dbindep}/SAPCAR" -xf "${path_dbindep}/SAPEXE.SAR" -R /tmp/rsecssfx rsecssfx ${file_list} >/dev/null

        export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/tmp/rsecssfx"
        secure_storage_key=$( /tmp/rsecssfx/rsecssfx generatekey -keyId "${secure_storage_key_id}" -getPlainValueToConsole )

        # write the key-id and key to the secure storage key file
        echo "key-id=${secure_storage_key_id}" > "${SECURE_STORAGE_FILE}"
        echo "key=${secure_storage_key}" >> "${SECURE_STORAGE_FILE}"
        
        # make the file only available for root
        chmod 600 "${SECURE_STORAGE_FILE}"
        ${ECHO} "$(date)\t Secure Storage Key created and written to ${SECURE_STORAGE_FILE}." >> "${DEV_LOG}"

        # remove the temporary created rsecssfx directory
        rm -rf /tmp/rsecssfx >/dev/null
    fi
}

################################################################################
# Create Variables
################################################################################
_create_variables()
{
    # Set scrDryRun to false if empty
    [ -z "${scrDryRun}" ] && scrDryRun="false"
    # Set scrMultipleOS to false if empty
    [ -z "${scrMultipleOS}" ] && scrMultipleOS="false"
    # Set scrDatabaseVendor to DB6 if DB2
    [ "${scrDatabaseVendor}" = "DB2" ] && scrDatabaseVendor="DB6"

    # Convert from uppercase to lowercase and vise versa
    scrDepotHost=$( _upper_lower "${scrDepotHost}" 'lower' )
    scrDryRun=$( _upper_lower "${scrDryRun}" 'lower' )
    scrMultipleOS=$( _upper_lower "${scrMultipleOS}" 'lower' )
    scrHostFunction=$( _upper_lower "${scrHostFunction}" 'lower' )
    scrDatabaseVendor=$( _upper_lower "${scrDatabaseVendor}" 'upper' )
    scrGlobalHost=$( _upper_lower "${scrGlobalHost}" 'lower' )

    # Sanity checks
    _sanity_check 'scrDepotHost'
    _sanity_check 'scrDepotName'
    #_sanity_check 'scrDepotSapDirectory'
    _sanity_check 'scrDryRun'
    _sanity_check 'scrMultipleOS'
    _sanity_check 'scrHostFunction'
    _sanity_check 'scrDatabaseVendor'

    # Path to SAP media directory
    # shellcheck disable=SC2154
    SAP_MEDIA_DIR="${SWDEPOT_MOUNTPOINT}"

    # shellcheck disable=SC2154
    {
        ${ECHO} "$(date)\t Assigned variables:";
        ${ECHO} "$(date)\t scrDepotHost='${scrDepotHost}'";
        ${ECHO} "$(date)\t scrDepotName='${scrDepotName}'";
        ${ECHO} "$(date)\t scrDepotSapDirectory='${scrDepotSapDirectory}'";
        ${ECHO} "$(date)\t scrCifsUsername='${scrCifsUsername}'";
#        ${ECHO} "$(date)\t scrCifsPassword='${scrCifsPassword}'";
        ${ECHO} "$(date)\t scrDryRun='${scrDryRun}'";
        ${ECHO} "$(date)\t scrMultipleOS='${scrMultipleOS}'";
        ${ECHO} "$(date)\t scrHostFunction='${scrHostFunction}'";
        ${ECHO} "$(date)\t scrDatabaseVendor='${scrDatabaseVendor}'";
        ${ECHO} "$(date)\t scrGlobalHost='${scrGlobalHost}'";
    } >> "${DEV_LOG}"

    if [ "${scrDatabaseVendor}" = "HDB" ] && { [ "${scrHostFunction}" = "db" ] || [ "${scrHostFunction}" = "standard" ]; }; then
        [ -n "${scrIpAddr}" ] && INSTALL_SAP_OR_HDB="sap" || INSTALL_SAP_OR_HDB="hdb"
        [ "${scrIpAddr_HDB}" = "${scrIpAddr}" ] && INSTALL_SAP_OR_HDB="both"
    else
        INSTALL_SAP_OR_HDB="sap"
    fi

    if [ "${scrHostFunction}" = "db" ] && [ "${scrDatabaseVendor}" = "HDB" ]; then
        _create_variables_hana_db
        # for distributed DB installation
        [ "${INSTALL_SAP_OR_HDB}" = "both" ] && _create_variables_sap_systems
    elif [ "${scrHostFunction}" != "db" ] && [ "${scrDatabaseVendor}" = "HDB" ]; then
        _create_variables_sap_systems
        _create_variables_hana_db
    else
        _create_variables_sap_systems
    fi

    # Checks for SAP and HDB on same host
    if [ "${INSTALL_SAP_OR_HDB}" = "both" ]; then
        # shellcheck disable=SC2154
        [ "${scrSID}" = "${scrSID_HDB}" ] && _exit_on_error "SANITY_CHECK - Error during sanity check of SAP SID '${scrSID}' and HDB SID '${scrSID_HDB}'. SIDs may not be the same." "${LINENO}"
        # shellcheck disable=SC2154
        [ "${scrInstanceNumber}" = "${scrInstanceNumber_HDB}" ] && _exit_on_error "SANITY_CHECK - Error during sanity check of SAP InstanceNr '${scrInstanceNumber}' and HDB InstanceNumber '${scrInstanceNumber_HDB}'. SAP Instance Numbers may not be the same." "${LINENO}"
    fi
}

################################################################################
# Create variables for HANA DB
################################################################################
_create_variables_hana_db()
{
    HDB_CONF_TEMPLATE="${SAP_MEDIA_DIR}/hdblcm_custom.conf"
    HDB_CONF="${SCRIPTDIR}/hdblcm.conf"

    # Convert from uppercase to lowercase and vise versa
    scrHostnameFQDN_HDB=$( _upper_lower "${scrHostnameFQDN_HDB}" 'lower' )
    scrSID_HDB=$( _upper_lower "${scrSID_HDB}" 'upper' )
    sid_hdb_lc=$( _upper_lower "${scrSID_HDB}" 'lower' )

    # Sanity checks
    _sanity_check 'scrHostnameFQDN_HDB'
    _sanity_check 'scrIpAddr_HDB'
    _sanity_check 'scrDeploymentIpAddr_HDB'
    _sanity_check 'scrSID_HDB'
    _sanity_check 'scrInstanceNumber_HDB'
    _sanity_check 'scrMasterPW_HDB'

    # Check FQDN for domainname
    echo "${scrHostnameFQDN_HDB}" | grep -q '\.'
    # shellcheck disable=SC2154
    [ "$?" -ne 0 ] && scrHostnameFQDN_HDB=$( _get_hostname "${scrIpAddr_HDB}" )
    # HOSTNAME_HDB and domainname_hdb out of scrHostnameFQDN_HDB
    HOSTNAME_HDB=$( echo "${scrHostnameFQDN_HDB}" | cut -d. -f1 )
    _sanity_check 'HOSTNAME_HDB'

    # Create the HDB <sid>adm user
    SIDADM_HDB="${sid_hdb_lc}adm"

    # shellcheck disable=SC2154
    {
        ${ECHO} "$(date)\t scrHostnameFQDN_HDB='${scrHostnameFQDN_HDB}'";
        ${ECHO} "$(date)\t scrIpAddr_HDB='${scrIpAddr_HDB}'";
        ${ECHO} "$(date)\t scrDeploymentIpAddr_HDB='${scrDeploymentIpAddr_HDB}'";
        ${ECHO} "$(date)\t scrSID_HDB='${scrSID_HDB}'";
        ${ECHO} "$(date)\t scrInstanceNumber_HDB='${scrInstanceNumber_HDB}'";
        ${ECHO} "$(date)\t SIDADM_HDB='${SIDADM_HDB}'";
    } >> "${DEV_LOG}"

    ${ECHO} "$(date)\t HDB_MASSIMPORT=YES">> "${DEV_LOG}"
    export HDB_MASSIMPORT=YES
}

################################################################################
# Create variables for SAP systems
################################################################################
_create_variables_sap_systems()
{
    INIFILE_PARAMS_TEMPLATE="${SAP_MEDIA_DIR}/inifile_custom.params"
    INIFILE_PARAMS="${SAPINST_INSTDIR}/inifile.params"

    # Define scrSID_DB if empty
    [ -z "${scrSID_DB}" ] && scrSID_DB="${scrSID}"
    # Backward compatibility for scrSapFlavour which changed to scrSapStack
    # shellcheck disable=SC2154
    if [ -z "${scrSapStack}" ] && [ -n "${scrSapFlavour}" ]; then
        scrSapStack="${scrSapFlavour}"
    fi

    # Convert from uppercase to lowercase and vise versa
    scrHostnameFQDN=$( _upper_lower "${scrHostnameFQDN}" 'lower' )
    scrSID=$( _upper_lower "${scrSID}" 'upper' )
    scrSID_DB=$( _upper_lower "${scrSID_DB}" 'upper' )
    scrSapApplication=$( _upper_lower "${scrSapApplication}" 'upper' )
    scrSapVersion=$( _upper_lower "${scrSapVersion}" 'upper' )
    scrSapStack=$( _upper_lower "${scrSapStack}" 'upper' )
    sid_lc=$( _upper_lower "${scrSID}" 'lower' )
    sid_db_lc=$( _upper_lower "${scrSID_DB}" 'lower' )

    # Sanity checks
    _sanity_check 'scrGlobalHost'
    _sanity_check 'scrHostnameFQDN'
    _sanity_check 'scrIpAddr'
    _sanity_check 'scrDeploymentIpAddr'
    _sanity_check 'scrSID'
    _sanity_check 'scrSID_DB'
    _sanity_check 'scrInstanceNumber'
    _sanity_check 'scrSapStack'
    _sanity_check 'scrMasterPW'

    # Check FQDN for domainname
    echo "${scrHostnameFQDN}" | grep -q '\.'
    # shellcheck disable=SC2154
    [ "$?" -ne 0 ] && scrHostnameFQDN=$( _get_hostname "${scrIpAddr}" )
    # HOSTNAME and DOMAINNAME out of scrHostnameFQDN
    HOSTNAME=$(echo "${scrHostnameFQDN}" | cut -d. -f1)
    DOMAINNAME=$(echo "${scrHostnameFQDN}" | cut -s -d. -f2-)
    _sanity_check 'HOSTNAME'

    # Set scrSapStack with the right values
    [ "${scrSapStack}" = "JAVA" ] && scrSapStack="Java"
    [ "${scrSapStack}" = "DOUBLESTACK" ] && scrSapStack="Doublestack"

    # Set scrHostFunction with the right values for ascs and scs
    if [ "$scrHostFunction" = "ascs" ] || [ "$scrHostFunction" = "scs" ]; then
        [ "$scrSapStack" = "ABAP" ] && scrHostFunction="ascs" || scrHostFunction="scs"
    fi

    # Create the various sap users
    SIDADM="${sid_lc}adm"
    SQDSID="sqd${sid_db_lc}"
    DB2SID="db2${sid_db_lc}"
    ORASID="ora${sid_db_lc}"
    SYBSID="syb${sid_db_lc}"

    # Check for MCOD system
    grep -q "${ORASID}" /etc/passwd && ( su - "${ORASID}" -c '[ -d ${ORACLE_HOME} ]' && DB_EXISTS=true )

    # shellcheck disable=SC2154
    {
        ${ECHO} "$(date)\t scrHostnameFQDN='${scrHostnameFQDN}'";
        ${ECHO} "$(date)\t scrIpAddr='${scrIpAddr}'";
        ${ECHO} "$(date)\t scrDeploymentIpAddr='${scrDeploymentIpAddr}'";
        ${ECHO} "$(date)\t scrSID='${scrSID}'";
        ${ECHO} "$(date)\t scrSID_DB='${scrSID_DB}'";
        ${ECHO} "$(date)\t scrInstanceNumber='${scrInstanceNumber}'";
        ${ECHO} "$(date)\t scrSapApplication='${scrSapApplication}'";
        ${ECHO} "$(date)\t scrSapVersion='${scrSapVersion}'";
        ${ECHO} "$(date)\t scrSapStack='${scrSapStack}'";
        ${ECHO} "$(date)\t HOSTNAME='${HOSTNAME}'";
        ${ECHO} "$(date)\t DOMAINNAME='${DOMAINNAME}'";
        ${ECHO} "$(date)\t SIDADM='${SIDADM}'";
        ${ECHO} "$(date)\t SQDSID='${SQDSID}'";
        ${ECHO} "$(date)\t DB2SID='${DB2SID}'";
        ${ECHO} "$(date)\t ORASID='${ORASID}'";
        ${ECHO} "$(date)\t SYBSID='${SYBSID}'";
    } >> "${DEV_LOG}"
}

################################################################################
# Determine SAP Product ID
################################################################################
_determine_sap_product_id()
{
    ${ECHO} "$(date)\t Starting SAP installation through SWPM" >> "${DEV_LOG}"
    product_catalog="${SWPM_DIR}/product.catalog"

    [ -f "${product_catalog}" ] || _exit_on_error "NO_PRODUCT_CATALOG - No product.catalog file found in '${SWPM_DIR}'." "${LINENO}"

    case "${scrHostFunction}" in
        # Standard system on a single host
        standard)
            front_pattern="NW_${scrSapStack}_OneHost"
            ;;   
        # Central Services instance for ABAP (ASCS instance)
        ascs)
            front_pattern="NW_${scrSapStack}_ASCS"
            ;;
        # Central Services instance for Java (SCS instance)
        scs)
            front_pattern="NW_${scrSapStack}_SCS"
            ;;
        # Database instance (DB)
        db)
            front_pattern="NW_${scrSapStack}_DB"
            ;;
        # Primary Application Server instance (PAS instance)
        pas)
            front_pattern="NW_${scrSapStack}_CI"
            ;;
        # Additional Application Server instance (AAS instance)
        aas)
            front_pattern="NW_DI"
            ;;
        *)
            _exit_on_error "NO_HOSTFUNCTION - '${scrHostFunction}' is no valid HostFunction." "${LINENO}"
            ;;
    esac

    # SAP version and application

    # check for NetWeaver
    # shellcheck disable=SC2154
    echo "${scrSapVersion}" | grep -q "^NW" && back_pattern="${scrSapVersion}\.${scrDatabaseVendor}\.${scrSapApplication}"

    # check for Business Suite
    echo "${scrSapVersion}" | grep -q "^BS2" && back_pattern="${scrSapVersion}\.${scrSapApplication}\.${scrDatabaseVendor}\.P.*"

    # check for Business Suite on HANA
    echo "${scrSapVersion}" | grep -q "^BSON" && back_pattern="${scrSapVersion}\.${scrSapApplication}\.${scrDatabaseVendor}\.P.*"

    # check for SolMan
    echo "${scrSapVersion}" | grep -q "^SOLMAN" && back_pattern="${scrSapVersion}\.${scrDatabaseVendor}\.P.*"

    # check for S4HANA
    echo "${scrSapVersion}" | grep -q "^S4HANA"
    if [ "$?" = 0 ]; then
        if [ "${scrSapStack}" = "ABAP" ]; then
            back_pattern="${scrSapVersion}\.${scrSapApplication}\.${scrDatabaseVendor}\.ABAP"
        elif [ "${scrSapStack}" = "Java" ]; then
            back_pattern="${scrSapVersion}\.${scrSapApplication}\.${scrDatabaseVendor}\.PD"
        fi
    fi

    [ -z "${back_pattern}" ] && _exit_on_error "SAPVERSION_NOT_SUPPORTED - '${scrSapVersion}' is not supported (yet)." "${LINENO}"

    pattern="${front_pattern}:${back_pattern}"

    # Try to determine Product-ID
    ${ECHO} "$(date)\t Determining Product-ID by processing Product Catalog '${product_catalog}'" >> "${DEV_LOG}"
    ${ECHO} "$(date)\t Pattern: '${pattern}'" >> "${DEV_LOG}"
    SAP_PRODUCT_ID=$( grep "id=\"${pattern}" "${product_catalog}" | grep -Eo 'id=\"[A-z0-9.:]*\"' | sed 's/id=\"\(.*\)\"/\1/g' | sort | uniq )

    # ToDo: If more than one Product-ID then _exit_on_error ???
    count=$( echo "${SAP_PRODUCT_ID}" | wc -l )
    if [ "${count}" -gt 1 ]; then
        ${ECHO} "Found more than 1 SAP Product ID! Taking first one!" >> "${INSTALLATION_LOG}"
        ${ECHO} "$(date)\t Found more than one product-ID! Taking first one" >> "${DEV_LOG}"
        for prodid in ${SAP_PRODUCT_ID}; do
            ${ECHO} "$(date)\t     ${prodid}" >> "${DEV_LOG}"
        done
        SAP_PRODUCT_ID=$( { echo "${SAP_PRODUCT_ID}" | while read -r i; do echo "$i"; break; done } )
    fi

    [ -z "${SAP_PRODUCT_ID}" ] && _exit_on_error "NO_SAP_PRODUCT_ID - Could not find SAP Product ID for '${scrSapVersion}' - '${scrSapApplication}'" "${LINENO}"

    ${ECHO} "$(date)\t SAP Product-ID: '${SAP_PRODUCT_ID}'" >> "${DEV_LOG}"
}

################################################################################
# Test with DryRun
################################################################################
_dry_run()
{
    if [ "${scrDryRun}" = "true" ] || [ "${scrDryRun}" = "host_preparation" ]; then
        ${ECHO} "$(date)\t Master Password created >DRY-RUN<" >> "${INSTALLATION_LOG}"
        ${ECHO} "$(date)\t Dry Run set to 'host_preparation', exiting!" >> "${INSTALLATION_LOG}"
        ${ECHO} "$(date)\t Dry Run set to 'host_preparation', exiting!" >> "${DEV_LOG}"
        exit 0
    fi
}

################################################################################
# Error handling
#
# Expected Input
#   error_msg:      Error message
#   error_line:     Error line number
################################################################################
_exit_on_error()
{
    error_msg="${1}"
    error_line="${2}"

    date=$( date +"${DATE_FORMAT}" )
    error_msg="ERROR: ${error_msg}"

    # Writing error message to error log
    printf '%s\n' "${error_msg}" > "${ERROR_LOG}"

    [ -n "${error_line}" ] && error_msg="ERROR Line ${error_line}: ${error_msg}"

    # Writing error message to installation logs
    printf '%s    %s\n' "${date}" "${error_msg}" >> "${DEV_LOG}"
    printf '%s    %s\n' "${date}" "${error_msg}" >> "${INSTALLATION_LOG}"

    # Writing error message to stdout
    printf '%s\n' "${error_msg}" >&2

    exit 1
}

################################################################################
# Get the hostname from DNS server or /etc/hosts
#
# Arguments:
#   ip_address
# Returns:
#   stdout
################################################################################
_get_hostname()
{
    ip_address="${1}"

    grep -q '^nameserver' /etc/resolv.conf
    if [ "$?" -eq 0 ]; then
        stdout=$( host "${ip_address}" | awk '{print $NF}' | sed 's/\.$//g' | tr '[:upper:]' '[:lower:]' )
    else
        stdout=$( getent hosts "${ip_address}" | awk '{print $2}' | tr '[:upper:]' '[:lower:]' )
    fi

    count="$( echo "${stdout}" | wc -w )"
    if [ "${count}" -eq 1 ]; then
        # there is exactly one hostname for the IP address
        echo "${stdout}"
    elif [ "${count}" -gt 1 ]; then
        # there is more than one hostname for the IP address
        _exit_on_error "GET_HOSTNAME_FAILED - There are multiple hostnames for the IP address: '${ip_address}'." "${LINENO}"
    else
        _exit_on_error "GET_HOSTNAME_FAILED - There is something wrong !!!" "${LINENO}"
    fi
}

################################################################################
# Initialize Script
################################################################################
_initialize()
{
    # Determine the script directory
    SCRIPTDIR="/tmp/sap_script"

    # location of local input file with input parameters
    LOCAL_INPUT_FILE="${SCRIPTDIR}/local_input.ini"

    # source the local input file
    _source_local_input_file

    # Log files
    INSTALLATION_LOG="${SCRIPTDIR}/sap_installation.log"
    DEV_LOG="${SCRIPTDIR}/sap_dev_installation.log"
    HDB_LOG="${SCRIPTDIR}/sap_hdb_installation.log"
    ERROR_LOG="${SCRIPTDIR}/sap_error.log"

    # ToDo: Description
    
	SWDEPOT_MOUNTPOINT="/usr/sap/scratch/media/ZTA/Netweaver_742"
	#SWDEPOT_MOUNTPOINT="/usr/sap/scratch/media/ZTA"
	#SWDEPOT_MOUNTPOINT="/tmp/SAPmedia"
    SAPMNT_MOUNTPOINT="/sapmnt"
    SAPINST_INSTDIR="/tmp/sapinst_instdir"
    SECURE_STORAGE_FILE="${SCRIPTDIR}/secure_storage_key_${scrSID}.txt"
    MASTER_PASSWORD_FILE="${SCRIPTDIR}/master_password.txt"

    # Password policy
    #
    # The SAP master password must meet the following requirements:
    # - It must be 8 to 14 characters long
    # - It must contain at least one letter (a-z, A-Z)
    # - It must contain at least one digit (0-9)
    # - It can contain the following characters: _, #, $, a-z, A-Z, 0-9
    # - It must not contain \ (backslash) and " (double quote)
    # - It must not begin with a digit nor an underscore
    #
    # The length of the random password
    PWLENGTH="10"
    # Characters that should be used for the random password
    PWCHAR="23456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ"

    # Date format for logging
    DATE_FORMAT="%b %d %T"

    # Determine Host-OS
    OS=$( uname -s )

    if [ "${OS}" = "Linux" ]; then
        ECHO="echo -e"
        OS_SEARCH="Linux"

        if [ -f /etc/redhat-release ]; then
            DISTRO="RHEL"
            DISTRO_VERSION="${DISTRO}"$( awk '/release/ {print $7}' /etc/redhat-release | sed 's/ //g' | cut -d. -f1 )
            DISTRO_PATCHLEVEL=$( awk '/release/ {print $7}' /etc/redhat-release | sed 's/ //g' | cut -d. -f2 )
        elif [ -f /etc/SuSE-release ]; then
            DISTRO="SLES"
            DISTRO_VERSION="${DISTRO}"$( awk '/VERSION/ {print $3}' /etc/SuSE-release | sed 's/ //g' )
            DISTRO_PATCHLEVEL=$( awk '/PATCHLEVEL/ {print $3}' /etc/SuSE-release | sed 's/ //g' )
        fi
    else
        _exit_on_error "OS_NOT_SUPPORTED - Local OS '${OS}' is not supported with this version!" "${LINENO}"
    fi

    # In case of an application server installation the log files could already exist.
    [ -f "${INSTALLATION_LOG}" ] && mv "${INSTALLATION_LOG}" "${INSTALLATION_LOG}.$$"
    [ -f "${DEV_LOG}" ] && mv "${DEV_LOG}" "${DEV_LOG}.$$"
    [ -f "${ERROR_LOG}" ] && mv "${ERROR_LOG}" "${ERROR_LOG}.$$"
    [ -d "${SAPINST_INSTDIR}" ] && mv "${SAPINST_INSTDIR}" "${SAPINST_INSTDIR}.$$"

    ${ECHO} "$(date)\t SAP Installation started" >> "${INSTALLATION_LOG}" 
}

################################################################################
# SAP HANA database installation with hdblcm
################################################################################
_install_hdblcm()
{
    ${ECHO} "$(date)\t Installing SAP HANA Database" >> "${INSTALLATION_LOG}"

    #######################################
    # Locate hdblcm for HANA DB
    #######################################
    ${ECHO} "$(date)\t HDBLCM ==> find -L ${SAP_MEDIA_DIR} -name hdblcm | grep LCM | grep -i \"${OS_SEARCH}\" " >> "${DEV_LOG}" 2>&1
    HDBLCM=$( find -L "${SAP_MEDIA_DIR}" -name hdblcm -type f | grep -i "HDB_LCM_${OS_SEARCH}" )
    [ -z "${HDBLCM}" ] && _exit_on_error "NO_HDBLCM_FOUND - There is no hdblcm present in '${SAP_MEDIA_DIR}'." "${LINENO}"

    count=$( echo "${HDBLCM}" | wc -l )
    [ "${count}" -gt 1 ] && _exit_on_error "TOO_MANY_HDBLCM_FOUND - There is more than one hdblcm present in '${SAP_MEDIA_DIR}'." "${LINENO}"

    ${ECHO} "$(date)\t HDBLCM ==>>${HDBLCM}<==" >> "${INSTALLATION_LOG}" 2>&1

    _prepare_hdb_conf

    #######################################
    # Install HANA DB 
    #######################################
    ${ECHO} "$(date)\t Installing HANA DB" >> "${INSTALLATION_LOG}"
    ${ECHO} "$(date)\t Installing HANA DB with configuration file '${HDB_CONF}'" >> "${DEV_LOG}"
    
    ${HDBLCM} --batch --configfile="${HDB_CONF}" >> "${HDB_LOG}" 2>&1 || _exit_on_error "HDBLCM_FAILED - HANA DB installation failed. Please check '${HDB_LOG}'." "${LINENO}"

    ${ECHO} "$(date)\t HDB Installation finished successfully." >> "${INSTALLATION_LOG}"
}

################################################################################
# SAP installation with sapinst (SWPM) - NetWeaver, BusinessSuite, S/4HANA ...
################################################################################
install_sapinst()
{
    ${ECHO} "$(date)\t Installing SAP Business Suite or S/4HANA" >> "${INSTALLATION_LOG}"

    #######################################
    # Check if SAP is already installed
    #######################################
    #if [ "${scrHostFunction}" = "aas" ]; then
    #${ECHO} "$(date)\t Check if SAP already installed" >> "${INSTALLATION_LOG}"

    #if [ -f /home/"${SIDADM}"/.sapenv_"${HOSTNAME}".csh ]; then
    #    ${ECHO} "$(date)\t SAP already installed, nothing to do here" >> "${INSTALLATION_LOG}"
    #    return
    #fi
    #fi

    #######################################
    # Add sapinst group
    #######################################
    ${ECHO} "$(date)\t Adding group 'sapinst' to /etc/group file." >> "${INSTALLATION_LOG}"
    _add_sapinst_group

    #######################################
    # Creating directories and copying files
    #######################################
    ${ECHO} "$(date)\t Creating local directories" >> "${INSTALLATION_LOG}"
    _create_local_directories

    #######################################
    # Making OS specific settings
    #######################################
    ${ECHO} "$(date)\t Creating Linux specific OS settings" >> "${INSTALLATION_LOG}"
    _linux_config

    #######################################
    # Attach the global host
    #######################################
    #if [ "${scrHostFunction}" = "pas" ] || [ "$scrHostFunction" = "aas" ] || { [ "${scrHostFunction}" = "db" ] && [ "${scrDatabaseVendor}" != "HDB" ]; }; then
    #    ${ECHO} "$(date)\t Attaching shares from global host" >> "${INSTALLATION_LOG}"
    #    _attach_global_host
    fi

    #######################################
    # Prepare SAP infrastructure
    #######################################
    ${ECHO} "$(date)\t Preparing SAP Media remotely and locally" >> "${INSTALLATION_LOG}"
    _prepare_sap_media

    # Determine SAP Product ID
    _determine_sap_product_id

    ${ECHO} "$(date)\t Installing '${scrSapVersion}' '${scrSapApplication}' on '${scrDatabaseVendor}' as '${scrHostFunction}' system with SAP Product-ID '${SAP_PRODUCT_ID}'." >> "${INSTALLATION_LOG}"

    #######################################
    # Secure Storage Key Generation
    #######################################
    if [ "${scrHostFunction}" = "standard" ] || [ "${scrHostFunction}" = "pas" ] ; then
        ${ECHO} "$(date)\t Create Secure Storage Key file." >> "${DEV_LOG}"
        _create_secure_storage_key
    fi

    ###############################################
    # DB-specific actions
    ###############################################
    if [ "${scrHostFunction}" = "standard" ] || [ "${scrHostFunction}" = "db" ] && [ "${scrDatabaseVendor}" = "DB6" ]; then
      _reserve_db2_ports
    fi

    #######################################
    # Creating inputParamIni
    #######################################
    ${ECHO} "$(date)\t Creating inifile.params" >> "${INSTALLATION_LOG}"
    _prepare_inifile_params

    # Assembling sapisnt "command line"
    SAPINST_BASE_COMMAND="${SWPM_DIR}/sapinst"

    # In case of SLES11 SP2 we need to take care of Linux Kernel 3.0
    if [ "${DISTRO_VERSION}" = "SLES11" ] && [ "${DISTRO_PATCHLEVEL}" = "2" ]; then
        SAPINST_BASE_COMMAND="/usr/bin/uname26 ${SWPM_DIR}/sapinst"
    fi
    SAPINST_BASE_COMMAND="${SAPINST_BASE_COMMAND} -nogui -noguiserver"
    SAPINST_BASE_COMMAND="${SAPINST_BASE_COMMAND} SAPINST_SKIP_DIALOGS=true"
    SAPINST_BASE_COMMAND="${SAPINST_BASE_COMMAND} SAPINST_DETAIL_SUMMARY=true"
    SAPINST_BASE_COMMAND="${SAPINST_BASE_COMMAND} SAPINST_EXECUTE_PRODUCT_ID=${SAP_PRODUCT_ID}"

    if [ "${scrDryRun}" = "sap_summary" ]; then
        SAPINST_BASE_COMMAND="${SAPINST_BASE_COMMAND} SAPINST_STOP_AFTER_DIALOG_PHASE=true"
        ${ECHO} "$(date)\t This is a Dry Run. Sapinst will stop after DIALOG phase." >> "${DEV_LOG}"
    fi
    # Assembling sapinst "command line" for 1st sapinst calls
    SAPINST_1ST_COMMAND="${SAPINST_BASE_COMMAND} SAPINST_INPUT_PARAMETERS_URL=${INIFILE_PARAMS}"

    # Assembling sapinst "command line" for subsequent sapinst calls
    SAPINST_2ND_COMMAND="${SAPINST_BASE_COMMAND} SAPINST_PARAMETER_CONTAINER_URL=${SAPINST_INSTDIR}/inifile.xml"

    ${ECHO} "$(date)\t First invocation of sapinst ==>${SAPINST_1ST_COMMAND}<==" >> "${DEV_LOG}"
    ${ECHO} "$(date)\t Further invocation(s) of sapinst ==>${SAPINST_2ND_COMMAND}<==" >> "${DEV_LOG}"

    ########################################################################
    ########################################################################
    # debug exit
    # exit
    ########################################################################
    ########################################################################

    cd "${SAPINST_INSTDIR}" || _exit_on_error "ERROR_DIR_CHANGE - Change working directory to '${SAPINST_INSTDIR}' not possible!" "${LINENO}"
      
    ###############################################
    # Oracle
    ###############################################
    if [ "${scrDatabaseVendor}" = "ORA" ]; then
        ###############################################
        # Oracle Standard or Database
        ###############################################
        if  [  "${scrHostFunction}" = "standard" ] || [ "${scrHostFunction}" = "db" ];  then
            ${ECHO} "$(date)\t Performing Standard or Database on Oracle installation" >> "${DEV_LOG}"
            #######################################
            # Oracle installations
            #######################################
            # Installing SAP on Oracle requires the installation of the Oracle database as an extra step during sapinst.
            # The following command will start sapinst and check when to call the Oracle installer. The SAP installation
            # will be continued in one of the next commands

            ###############################################
            # Calling sapinst
            ###############################################
            if [ "${DB_EXISTS}" = "true" ]; then
                ${ECHO} "$(date)\t Calling sapinst for Oracle 1st time" >> "${INSTALLATION_LOG}"
                cd "${SAPINST_INSTDIR}" || _exit_on_error "ERROR_DIR_CHANGE - Change working directory to '${SAPINST_INSTDIR}' not possible!" "${LINENO}"

                SAPINST_COMMAND="${SAPINST_1ST_COMMAND}"

                ${ECHO} "$(date)\t Assigned SAPINST_COMMAND ==>${SAPINST_COMMAND}<==" >> "${DEV_LOG}"

                # Please note that sapinst is running as background job here!
                ${SAPINST_COMMAND} > sapinst_stdout.log 2>1 &

                # after waiting a grace period we trace sapinst_dev.log and check for "StopToInstallOracleServerSW"
                # if this string appears we kill sapinst and call the Oracle installer
                sleep 30

                ################################################
                # Waiting for trigger to install Oracle
                ################################################

                RC=1
                while [ ! $RC -eq 0 ]; do
                    # shellcheck disable=SC2009
                    ps ax | grep sapinst_exe | grep -qv 'grep'
                    RC3=$?
                    if [ ! $RC3 -eq 0 ]; then
                        grep -q "Check input element rbDatabase" sapinst_dev.log
                        MCOD_ISSUE=$?
                        if [ ${MCOD_ISSUE} -eq 0 ]; then
                             ${ECHO} "$(date)\t Modify installation for MCOD scenario"  >> "${DEV_LOG}"
                            BLOCK_BEGIN='fld name="rbDatabase"'
                            BLOCK_END='</fld>'
                            OLD_STRING='<strval><![CDATA[]]>'
                            NEW_STRING='<strval><![CDATA[MCOD]]>'
                            FILE="${SAPINST_INSTDIR}/inifile.xml"
                            _modfile_block

                            RC=0
                        elif [ "${scrDryRun}" = "sap_summary"  ] && [ -f "${SAPINST_INSTDIR}/summary.html" ]; then
                            ${ECHO} "$(date)\t Sapinst stopped at the end of dialog phase." >> "${DEV_LOG}"
                            return
                        else
                            _exit_on_error "SAPINST_STOPPED - sapinst ran into an error. Please check '${SAPINST_INSTDIR}/sapinst.log' or '${SAPINST_INSTDIR}/sapinst_dev.log'!" "${LINENO}"
                        fi
                    fi
                done

                cd "${SAPINST_INSTDIR}" || _exit_on_error "ERROR_DIR_CHANGE - Change working directory to '${SAPINST_INSTDIR}' not possible!" "${LINENO}"
                ${ECHO} "$(date)\t Calling sapinst again to finish SAP installation." >> "${INSTALLATION_LOG}"
                 SAPINST_COMMAND="${SAPINST_1ST_COMMAND}"

                ${ECHO} "$(date)\t Assigned SAPINST_COMMAND ==>${SAPINST_COMMAND}<==" >> "${DEV_LOG}"

                # Please note that sapinst is running as background job here!
                ${SAPINST_COMMAND} > sapinst_stdout.log 2>1 &

                # after waiting a grace period we trace sapinst_dev.log and check for "StopToInstallOracleServerSW"
                # if this string appears we kill sapinst and call the Oracle installer
                sleep 30
                ################################################
                # Waiting for trigger to install Oracle
                ################################################

                RC=1
                while [ ! $RC -eq 0 ]; do
                    grep -q 'FCO-00011  The step syb_step_dbclient_install' "${SAPINST_INSTDIR}"/sapinst_dev.log | grep "${SCRIPTDIR}/sapinst_instdir/DBCLIENT.1.log"
                    RC1=$?

                    grep -q "The installation of component .* has completed"  "${SAPINST_INSTDIR}"/sapinst_dev.log
                    RC2=$?

                    if [ ! $RC1 -eq 0 ] && [ ! $RC2 -eq 0 ]; then
                        RC=1
                        sleep 5
                    else
                        if [ $RC2 -eq 0 ]; then
                            INSTALL_SUCCESS="true"
                        fi
                        RC=0
                    fi

                    # Check if sapinst is still running
                    # shellcheck disable=SC2009
                    ps ax | grep sapinst_exe | grep -qv 'grep'
                    RC3=$?

                    if [ ! $RC3 -eq 0 ]; then
                        # wait to see if installation finished successfully
                        sleep 10
                        grep -q "The installation of component .* has completed" "${SAPINST_INSTDIR}"/sapinst_dev.log
                        RC2=$?
                        if [ $RC2 -eq 0 ]; then
                            INSTALL_SUCCESS="true"
                            RC=0
                        elif [ "${scrDryRun}" = "sap_summary" ] && [ -f "${SAPINST_INSTDIR}/summary.html" ]; then
                            ${ECHO} "$(date)\t Sapinst stopped at the end of dialog phase." >> "${DEV_LOG}"
                            return
                        else
                            _exit_on_error "SAPINST_STOPPED - sapinst ran into an error. Please check '${SAPINST_INSTDIR}/sapinst.log' or '${SAPINST_INSTDIR}/sapinst_dev.log'!" "${LINENO}"
                        fi
                    fi
                done
                ${ECHO} "$(date)\t sapinst finished" >> "${DEV_LOG}"

            else #No MCOD system
                ${ECHO} "$(date)\t Calling sapinst for Oracle 1st time" >> "${INSTALLATION_LOG}"
                cd "${SAPINST_INSTDIR}" || _exit_on_error "ERROR_DIR_CHANGE - Change working directory to '${SAPINST_INSTDIR}' not possible!" "${LINENO}"

                SAPINST_COMMAND="${SAPINST_1ST_COMMAND}"

                ${ECHO} "$(date)\t Assigned SAPINST_COMMAND ==>${SAPINST_COMMAND}<==" >> "${DEV_LOG}"

                # Please note that sapinst is running as background job here!
                ${SAPINST_COMMAND} > sapinst_stdout.log 2>1 &

                # after waiting a grace period we trace sapinst_dev.log and check for "StopToInstallOracleServerSW"
                # if this string appears we kill sapinst and call the Oracle installer
                sleep 30
                ################################################
                # Waiting for trigger to install Oracle
                ################################################

                RC=1
                while [ ! $RC -eq 0 ]; do
                    # shellcheck disable=SC2009
                    ps ax | grep sapinst_exe | grep -qv 'grep'
                    RC3=$?
                    if [ ! $RC3 -eq 0 ]; then
                        if [ "${scrDryRun}" = "sap_summary"  ] && [ -f "${SAPINST_INSTDIR}/summary.html" ]; then
                            ${ECHO} "$(date)\t Sapinst stopped at the end of dialog phase." >> "${DEV_LOG}"
                            return
                        else
                            _exit_on_error "SAPINST_STOPPED - sapinst ran into an error. Please check '${SAPINST_INSTDIR}/sapinst.log' or '${SAPINST_INSTDIR}/sapinst_dev.log'!" "${LINENO}"
                        fi
                    fi

                    #Check if SAPINST waits to install Oracle
                    grep -q "StopToInstallOracleServerSW" "${SAPINST_INSTDIR}"/sapinst_dev.log
                    RC1=$?
                    if [ $RC1 -ne 0 ]; then
                        RC=1
                        sleep 5
                    else
                        # shellcheck disable=SC2009
                        # shellcheck disable=SC2046
                        kill $( ps ax | grep sapinst_exe | grep -v 'grep' | awk '{print $1}' )
                        RC=0
                    fi
                done

                ###############################################
                # Installing Oracle
                ###############################################

                # Get the Oracle install script out of the staging area
                oracle_install=$( find /oracle/stage -name '*install.sh' -type f )
                [ -z "${oracle_install}" ] && _exit_on_error "NO_ORACLE_INSTALLER - Was not able to find an Oracle installation script!" "${LINENO}"

                # Get the Oracle stage directory out of the oracle_install path
                oracle_stage=$( cd "$(dirname "${oracle_install}")"/.. >/dev/null 2>&1 && pwd ) || _exit_on_error "NO_ORACLE_STAGE - Not able to get the Oracle stage directory!" "${LINENO}"
                ${ECHO} "$(date)\t sapinst stopped for Oracle installation. Calling '${oracle_install}'" >> "${DEV_LOG}"
                ${ECHO} "$(date)\t sapinst stopped for Oracle installation. Calling '${oracle_install}'" >> "${INSTALLATION_LOG}"

                # Define Oracle stdout log file
                ora_stdout_log="${SAPINST_INSTDIR}/$( basename "${oracle_install}" | cut -d. -f1 )_stdout.log"

                # Start the Oracle installation
                su - oracle -c "setenv DB_SID ${scrSID_DB} && ${oracle_install} -oracle_stage ${oracle_stage} -silent -nocheck >& ${ora_stdout_log}"
                [ "$?" -ne 0 ] && _exit_on_error "ORACLE_INSTALLATION_FAILED - Please check the logfile '${ora_stdout_log}'." "${LINENO}"
                ${ECHO} "$(date)\t Oracle Database software installation finished successfully." >> "${DEV_LOG}"
                ${ECHO} "$(date)\t Oracle Database software installation finished successfully." >> "${INSTALLATION_LOG}"

                # Execute the orainstRoot.sh script
                ora_inst_root=$( awk -F' ' '/orainstRoot.sh/ {print $NF}' "${ora_stdout_log}" )
                if [ -n "${ora_inst_root}" ]; then
                    ${ECHO} "$(date)\t Execute the '${ora_inst_root}' script." >> "${DEV_LOG}"
                    stdout=$( "${ora_inst_root}" ) || _exit_on_error "ERROR_ORA_INST_SCRIPT - ${stdout}." "${LINENO}"
                fi

                # Execute the root.sh script
                ora_root_script=$( awk -F' ' '/root.sh/ {print $NF}' "${ora_stdout_log}" )
                ${ECHO} "$(date)\t Execute the '${ora_root_script}' script." >> "${DEV_LOG}"
                stdout=$( "${ora_root_script}" ) || _exit_on_error "ERROR_ORA_ROOT_SCRIPT - ${stdout}." "${LINENO}"

                ${ECHO} "$(date)\t Calling 'sapinst' again to finish the SAP installation." >> "${DEV_LOG}"
                ${ECHO} "$(date)\t Calling 'sapinst' again to finish the SAP installation." >> "${INSTALLATION_LOG}"

                # Before proceeding we need to mark the Oracle DB software as installed
                ${ECHO} "$(date)\t Preparing 2nd call of sapinst." >> "${INSTALLATION_LOG}"
                cp -p "${SAPINST_INSTDIR}/keydb.xml" "${SAPINST_INSTDIR}/keydb.xml.HPE_AI_BCK"

                BLOCK_BEGIN='<strval><![CDATA[.*StopToInstallOracleServerSW'
                BLOCK_END='</row>'
                OLD_STRING='<strval><![CDATA[ERROR]]>'
                NEW_STRING='<strval><![CDATA[OK]]>'
                FILE="${SAPINST_INSTDIR}/keydb.xml"
                _modfile_block

                # Ensure that sapinst will find the Oracle libraries
                orahome=$( awk '/Installation Oracle home is/ {print $NF}' "${ora_stdout_log}" )
                [ "${OS}" = "Linux" ] && export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${orahome}/lib"

                ###############################################
                # Calling sapinst 2nd time
                ###############################################

                # Please note that sapinst is now running in the foreground and
                # we use different parameters
                cd "${SAPINST_INSTDIR}" || _exit_on_error "ERROR_DIR_CHANGE - Change working directory to '${SAPINST_INSTDIR}' not possible!" "${LINENO}"
                ${ECHO} "$(date)\t Calling sapinst again to finish SAP installation." >> "${INSTALLATION_LOG}"

                SAPINST_COMMAND="${SAPINST_2ND_COMMAND}"
                ${SAPINST_COMMAND} >> sapinst_stdout.log 2>1
                SAPINST_RC=$?
                
                ${ECHO} "$(date)\t Assigned SAPINST_COMMAND ==>${SAPINST_COMMAND}<==" >> "${DEV_LOG}"
                ${ECHO} "$(date)\t sapinst stopped with RC ==>${SAPINST_RC}<==" >> "${DEV_LOG}"

                if [ ! ${SAPINST_RC} -eq 0 ] && [ ! -f "${SAPINST_INSTDIR}"/installationSuccesfullyFinished.dat ]; then
                    # In case ${SAPINST_INSTDIR}/installationSuccesfullyFinished.dat does exist
                    # we can safely ignore a return code other than 0
                    _exit_on_error "SAPINST_STOPPED - sapinst ran into an error. Please check '${SAPINST_INSTDIR}/sapinst.log' or '${SAPINST_INSTDIR}/sapinst_dev.log'!" "${LINENO}"
                fi

            fi # End if Clause for MCOD installation

            ###############################################
            # Create Oracle autostart (init)
            ###############################################
            _create_oracle_autostart
            
        else # All other instances with Oracle Database
            ${ECHO} "$(date)\t Performing Standard installation" >> "${DEV_LOG}"
            _standard_sapinst_call
        fi

    else
        ###############################################
        # All other installations except Oracle DB
        ###############################################
        ${ECHO} "$(date)\t Performing Standard installation" >> "${DEV_LOG}"
        _standard_sapinst_call
    fi

    #######################################
    # Preparing SAP to work with Linux kernel 3.0
    #######################################

    # In case of SLES11 SP2 we need to take care of Linux Kernel 3.0
    if [ "${DISTRO_VERSION}" = "SLES11" ] && [ "${DISTRO_PATCHLEVEL}" = "2" ]; then
        ${ECHO} "$(date)\t Enabling SAP system to run on Linux kernel 3.0 (SLES11 SP2)" >> "${INSTALLATION_LOG}"
        ${ECHO} "$(date)\t Patching /etc/init.d/sapinit to start with uname26" >> "${INSTALLATION_LOG}"
        [ -f /etc/init.d/sapinit ] || _exit_on_error "NO_SAPINIT - '/etc/init.d/sapinit' does not exist" "${LINENO}"

        ${ECHO} "$(date)\t Stopping SAP system" >> "${DEV_LOG}"
        # ToDo: Switch to sapcontrol
        su - "${SIDADM}" -c "stopsap" >> "${DEV_LOG}" 2>&1

        # ToDo: Switch to sapcontrol
        if [ "${scrDatabaseVendor}" = "ADA" ]; then
            ${ECHO} "$(date)\t Stopping x_server (x_server stop)" >> "${DEV_LOG}"
            su - "${SQDSID}" -c "x_server stop" >> "${DEV_LOG}" 2>&1
        fi

        # shellcheck disable=SC2129
        ${ECHO} "$(date)\t Stopping sapinit (/etc/init.d/sapinit stop)" >> "${DEV_LOG}"
        /etc/init.d/sapinit stop >> "${DEV_LOG}" 2>&1

        ${ECHO} "$(date)\t Patching /etc/init.d/sapinit to start with uname26" >> "${DEV_LOG}"
        cp -p /etc/init.d/sapinit /etc/init.d/sapinit.HPE_AI_BCK
        sed -i 's/ ^\#\!\/bin\/sh / \#\!\/usr\/bin\/uname26 \/bin\/sh\n\#\#\!\/bin\/sh/g' /etc/init.d/sapinit

        # Sanity check
        grep -q "uname26" /etc/init.d/sapinit || _exit_on_error "UNAME26_NOT_PATCHED - Could not add #!/bin/uname26 to /etc/init.d/sapinit" "${LINENO}"

        # shellcheck disable=SC2129
        ${ECHO} "$(date)\t Starting SAP system" >> "${DEV_LOG}"
        su - "${SIDADM}" -c "startsap" >> "${DEV_LOG}" 2>&1

        ${ECHO} "$(date)\t Starting Diagnostic Agent" >> "${DEV_LOG}"
        su - daaadm -c "startsap" >> "${DEV_LOG}" 2>&1

        ${ECHO} "$(date)\t SAP system enabled to run on Linux kernel 3.0 (SLES11 SP2)" >> "${INSTALLATION_LOG}"
    fi

    ###############################################
    # Configuring NFS
    ###############################################
#    if [ "${scrHostFunction}" = "standard" ] || [ "${scrHostFunction}" = "ascs" ] || [ "${scrHostFunction}" = "scs" ]; then
#        _configure_nfs
#    fi

    ###############################################
    # Manipulate SAP profiles
    ###############################################
    _prepare_sap_profiles

    ###############################################
    # Restart SAP application instances
    ###############################################
    _restart_sap_application_instance

    #######################################
    # Check SAP status
    #######################################
#    if [ "${scrHostFunction}" = "standard" ]; then
#        for counter in {1..20}; do
#            _sapcontrol "${scrHostnameFQDN}" "00" "GetProcessList"
#            [ "${SAP_STATUS}" = "GREEN" ] && break || sleep 5
#        done
#        if [ "$counter" -lt 3 ]; then
#            ${ECHO} "$(date)\t SAP instance successfully started" >> "${INSTALLATION_LOG}"
#        else
#            _exit_on_error "SAPINST_NOT_RUNNING - SAP instance is not running. Please check '${SAPINST_INSTDIR}/sapinst.log' or '${SAPINST_INSTDIR}/sapinst_dev.log'!" "${LINENO}"
#        fi
#    fi

    #######################################
    # Check DB status
    #######################################
#    if [ "${scrHostFunction}" = "db" ]; then
#        for counter in {1..20}; do
#            _check_db_status
#            [ "${DB_ONLINE}" = "true" ] && break || sleep 5
#        done
#        if [ "$counter" -lt 3 ]; then
#            ${ECHO} "$(date)\t DB instance successfully started" >> "${INSTALLATION_LOG}"
#        else
#            _exit_on_error "DATABASE_NOT_RUNNING - Database instance is not running. Please check '${SAPINST_INSTDIR}/sapinst.log' or '${SAPINST_INSTDIR}/sapinst_dev.log'!" "${LINENO}"
#        fi
#    fi   
}

################################################################################
# Configure Linux for SAP use
################################################################################
_linux_config()
{
    # ToDo: SLES12 and RHEL7 check if /etc/sysctl.d is available
    #if (grep -q HPE /etc/sysctl.conf); then
         # ${ECHO} "$(date)\t SAP entries already exist in /etc/sysctl.conf" >> "${DEV_LOG}"
    # else
        # ${ECHO} "$(date)\t Preparing /etc/sysctl.conf" >> "${INSTALLATION_LOG}"
        # {
            # _add_hpe_header_short;
            # echo "kernel.msgmni = 1024";
            # echo "kernel.randomize_va_space = 0";
         #   echo "kernel.exec-shield = 0";
            # echo "kernel.shmmax = 9223372036854775807";
            # echo "kernel.sem = 1250 256000 100 8192";
            # echo "kernel.shmall = 1152921504606846720";
            # echo "vm.max_map_count = 1000000";
        # } >> /etc/sysctl.conf
        # sysctl -p >> "${DEV_LOG}"
    #fi

    if (grep -q HPE /etc/security/limits.conf); then
         ${ECHO} "$(date)\t SAP entries already exist in /etc/security/limits.conf" >> "${DEV_LOG}"
    else
        ${ECHO} "$(date)\t Preparing /etc/security/limits.conf" >> "${INSTALLATION_LOG}"
        {
          _add_hpe_header_short;
          echo "@sapsys          soft    nofile          32800";
          echo "@sapsys          hard    nofile          32800";
          echo "@sdba            soft    nofile          32800";
          echo "@sdba            hard    nofile          32800";
          echo "@dba             soft    nofile          32800";
          echo "@dba             hard    nofile          32800";
          echo "root             hard    nproc           unlimited";
          echo "root             soft    nproc           unlimited";
          echo "root             hard    as              unlimited";
          echo "root             soft    as              unlimited";
          echo "root             hard    rss             unlimited";
          echo "root             soft    rss             unlimited";
        } >> /etc/security/limits.conf

        {
          ulimit -m unlimited;
          ulimit -v unlimited;
          ulimit -u unlimited;
        } >> "${DEV_LOG}" 2>&1
    
    fi

    # In case of SLES11 SP2 we need to take care of Linux Kernel 3.0
    if [ "${DISTRO_VERSION}" = "SLES11" ] && [ "${DISTRO_PATCHLEVEL}" = "2" ]; then
        ${ECHO} "$(date)\t Adding ${SIDADM} to /etc/security/uname26.conf" >> "${INSTALLATION_LOG}"
        echo "${SIDADM}" >> /etc/security/uname26.conf
    fi

    # Beginning of SAP Kernel 7.40 a multicasting route is required on the corresponding interface
    #
    # Getting corresponding interface
    ${ECHO} "$(date)\t Adding multicast route to production net interface" >> "${INSTALLATION_LOG}"
    local_ip=$( getent hosts "${scrHostnameFQDN}" | awk '{print $1}' )
    if [ "${local_ip}" = "${scrIpAddr}" ]; then
        production_interface=$( ip addr | grep "${local_ip}" | awk '{print $NF}' )
    else
        ${ECHO} "$(date)\t Designated IP address >${scrIpAddr}< not assigned to hostname >${scrHostnameFQDN} in /etc.hosts" >> "${DEV_LOG}"
        ${ECHO} "$(date)\t Found IP address >${local_ip}< instead." >> "${DEV_LOG}"
        production_interface=$( ip addr | grep "${scrIpAddr}" | awk '{print $NF}' )
    fi

    {
        ${ECHO} "$(date)\t Production net interface is >${production_interface}<";
        ${ECHO} "$(date)\t Adding multicast route to production net interface";
        ${ECHO} "$(date)\t route add -net 224.0.0.0 netmask 255.255.255.0 ${production_interface}";
        route add -net 224.0.0.0 netmask 255.255.255.0 "${production_interface}";
    } >> "${DEV_LOG}" 2>&1
}

################################################################################
# Modify file with pattern
################################################################################
_modfile()
{
    OLD_STRING=$( echo "${OLD_STRING}" | sed -e 's/"/\\\"/g' -e 's#\/#\\\/#g' -e 's/\[/\\\[/g' )
    NEW_STRING=$( echo "${NEW_STRING}" | sed -e 's/"/\\\"/g' -e 's#\/#\\\/#g' -e 's/\[/\\\[/g' )
    ${ECHO} "$(date)\t ==> sed -i \"s/${OLD_STRING}/${NEW_STRING}/g\" ${FILE}" >> "${DEV_LOG}"
    sed -i "s/${OLD_STRING}/${NEW_STRING}/g" "${FILE}"
}

################################################################################
# Modify file with Begin/End
################################################################################
_modfile_block()
{
    BLOCK_BEGIN=$( echo "${BLOCK_BEGIN}" | sed -e 's/"/\\\"/g' -e 's#\/#\\\/#g' -e 's/\[/\\\[/g' )
    BLOCK_END=$( echo "${BLOCK_END}" | sed -e 's/"/\\\"/g' -e 's#\/#\\\/#g' -e 's/\[/\\\[/g' )
    OLD_STRING=$( echo "${OLD_STRING}" | sed -e 's/"/\\\"/g' -e 's#\/#\\\/#g' -e 's/\[/\\\[/g' )
    NEW_STRING=$( echo "${NEW_STRING}" | sed -e 's/"/\\\"/g' -e 's#\/#\\\/#g' -e 's/\[/\\\[/g' )
    ${ECHO} "$(date)\t ==> sed -i \"/${BLOCK_BEGIN}/,/${BLOCK_END}/{ s@${OLD_STRING}@${NEW_STRING}@ }\" ${FILE}" >> "${DEV_LOG}"
    sed -i "/${BLOCK_BEGIN}/,/${BLOCK_END}/{ s@${OLD_STRING}@${NEW_STRING}@ }" "${FILE}"
}

################################################################################
# Mount Software Depot
################################################################################
_mount_software_depot()
{
    ${ECHO} "$(date)\t Mount Software Depot" >> "${INSTALLATION_LOG}"
    
    [ -d ${SWDEPOT_MOUNTPOINT} ] || mkdir -p ${SWDEPOT_MOUNTPOINT}

    # shellcheck disable=SC2154
    mount_type=$( echo "${scrDepotHost}" | cut -d: -f1 )
    mount_host=$( echo "${scrDepotHost}" | cut -d: -f2 )

    case "${mount_type}" in
        cifs)
            # check if cifs is installed
            _check_packages 'cifs-utils'

            # shellcheck disable=SC2154
            ${ECHO} "$(date)\t Mounting Software Depot ==>mount -t ${mount_type} -o username=${scrCifsUsername},password=******** //${mount_host}/${scrDepotName} ${SWDEPOT_MOUNTPOINT}<==" >> "${DEV_LOG}"

            # Is share already mounted?
            ${ECHO} "$(date)\t Software Depot mounted? ==> mount | grep -iq \"//${mount_host}/${scrDepotName} on ${SWDEPOT_MOUNTPOINT}\"<==" >> "${DEV_LOG}"
            mount | grep -iq "//${mount_host}/${scrDepotName} on ${SWDEPOT_MOUNTPOINT}"
            if [ "$?" -ne 0 ]; then
                # Need to mount share
                mount -t "${mount_type}" -o username="${scrCifsUsername}",password="${scrCifsPassword}" //"${mount_host}"/"${scrDepotName}" ${SWDEPOT_MOUNTPOINT} >> "${DEV_LOG}" 2>&1
                [ "$?" -ne 0 ] && _exit_on_error "CIFS_MOUNT_FAILED - Cannot mount Software Depot through CIFS. Depot: '${scrDepotName}' Host: '${mount_host}' Protocol: '${mount_type}'" "${LINENO}"
            fi
            ${ECHO} "$(date)\t Software Depot successfully mounted." >> "${DEV_LOG}"
            ;;
        local)
            ${ECHO} "$(date)\t Local SAP Software Depot '${SWDEPOT_MOUNTPOINT}' will be used."  >> "${DEV_LOG}"
            ;;
        nfs)
            # check if nfs-client is installed
            [ "${DISTRO}" = "RHEL" ] && _check_packages 'rpcbind nfs-utils'
            [ "${DISTRO}" = "SLES" ] && _check_packages 'rpcbind nfs-client'

            ${ECHO} "$(date)\t Mounting Software Depot ==>mount -t ${mount_type} -o rsize=32768,wsize=32768 ${mount_host}:/${scrDepotName} ${SWDEPOT_MOUNTPOINT}<==" >> "${DEV_LOG}"
            mount -t "${mount_type}" -o rsize=32768,wsize=32768 "${mount_host}":/"${scrDepotName}" ${SWDEPOT_MOUNTPOINT} >> "${DEV_LOG}" 2>&1
            [ "$?" -ne 0 ] && _exit_on_error "NFS_MOUNT_FAILED - Cannot mount Software Depot through NFS. Depot: '${scrDepotName}' Host: '${mount_host}' Protocol: '${mount_type}'" "${LINENO}"

            ${ECHO} "$(date)\t Software Depot successfully mounted." >> "${DEV_LOG}"
            ;;
        *)
            _exit_on_error "NO_DEPOT_HOST - Cannot determine how to mount central Software Depot share. Unknown/unsupported protocol ${mount_type}." "${LINENO}"
            ;;
    esac
}

################################################################################
# Prepare HANA database config file
################################################################################
_prepare_hdb_conf()
{
    if [ -f "${HDB_CONF_TEMPLATE}" ]; then
        ${ECHO} "$(date)\t HDB config template '${HDB_CONF_TEMPLATE}' exists. Copy to '${HDB_CONF}'." >> "${DEV_LOG}"
        cp "${HDB_CONF_TEMPLATE}" "${HDB_CONF}"
    else
        # shellcheck disable=SC2129
        ${ECHO} "$(date)\t HDB config file '${HDB_CONF}' will be created." >> "${DEV_LOG}"
        ${ECHO} "$(date)\t ${HDBLCM} --action=install --dump_configfile_template=${HDB_CONF}" >> "${DEV_LOG}"
        "${HDBLCM}" --action=install --dump_configfile_template"=${HDB_CONF}" >> "${HDB_LOG}"
    fi

    ${ECHO} "$(date)\t Check values in file '${HDB_CONF}'." >> "${DEV_LOG}"

    # HDB components to be installed
    _process_hdb_conf 'components' 'client,server'
    # HDB Hostname
    _process_hdb_conf 'hostname' "${HOSTNAME_HDB}"
    # HDB SID
    _process_hdb_conf 'sid' "${scrSID_HDB}"
    # HDB Instance Number
    _process_hdb_conf 'number' "${scrInstanceNumber_HDB}"
    # Password for the SAP Host Agent administrator
    _process_hdb_conf 'sapadm_password' "${scrMasterPW_HDB}"
    # Password for the <sid>adm user
    _process_hdb_conf 'password' "${scrMasterPW_HDB}"
    # Password for the database superuser
    _process_hdb_conf 'system_user_password' "${scrMasterPW_HDB}"
    # Start database after machine reboot
    _process_hdb_conf 'autostart' 'y'
    # HDB installation
    _process_hdb_conf 'action' 'install'

    # make the file only available for root
    chmod 600 "${HDB_CONF}"
    chmod 600 "${HDB_CONF}.xml"
}

################################################################################
# Prepare inifile.params file
################################################################################
_prepare_inifile_params()
{
    if [ -f "${INIFILE_PARAMS_TEMPLATE}" ]; then
        ${ECHO} "$(date)\t HDB config template '${HDB_TEMPLATE_CONF}' exists. Copy to '${HDB_CONF}'." >> "${DEV_LOG}"
        ${ECHO} "$(date)\t SAP inifile template '${INIFILE_PARAMS_TEMPLATE}' exists. Copy to '${INIFILE_PARAMS}'" >> "${DEV_LOG}"
        cp "${INIFILE_PARAMS_TEMPLATE}" "${INIFILE_PARAMS}"
    elif [ ! -f "${INIFILE_PARAMS}" ]; then
        touch "${INIFILE_PARAMS}"
    fi

    ${ECHO} "$(date)\t Check values in file '${INIFILE_PARAMS}'." >> "${DEV_LOG}"

    # SAP mountpoint (default: /sapmnt)
    _process_inifile_params 'NW_GetSidNoProfiles.sapmnt' "${SAPMNT_MOUNTPOINT}"
    # SAP SID
    _process_inifile_params 'NW_GetSidNoProfiles.sid' "${scrSID}"
    # SAP master password
    _process_inifile_params 'NW_GetMasterPassword.masterPwd' "${scrMasterPW}"
    # SAP FQDN
    _process_inifile_params 'NW_getFQDN.FQDN' "${DOMAINNAME}"
    # SAP use FQDN
    _process_inifile_params 'NW_getFQDN.setFQDN' 'false' 'custom'

    case "${scrHostFunction}" in
        # Standard system on a single host
        standard)
            # PAS instance number (CI)
            _process_inifile_params 'NW_CI_Instance.ciInstanceNumber' "${scrInstanceNumber}" 'custom'
            # ASCS hostname
            _process_inifile_params 'NW_CI_Instance.ascsVirtualHostname' "${HOSTNAME}"
            # SCS hostname
            _process_inifile_params 'NW_CI_Instance.scsVirtualHostname' "${HOSTNAME}"
            # PAS hostname (CI)
            _process_inifile_params 'NW_CI_Instance.ciVirtualHostname' "${HOSTNAME}"
            # SLD
            _process_inifile_params 'NW_SLD_Configuration.configureSld' 'false' 'custom'
            # Secure Storage Key
            _process_inifile_params 'NW_ABAP_SSFS_CustomKey.ssfsKeyInputFile' "${SECURE_STORAGE_FILE}"

            _prepare_inifile_params_db
            ;;
        # Central services instance for ABAP (ASCS and SCS instance)
        ascs|scs)
            # ASCS/SCS instance number
            _process_inifile_params 'NW_SCS_Instance.instanceNumber' "${scrInstanceNumber}" 'custom'
            # ASCS hostname
            _process_inifile_params 'NW_SCS_Instance.ascsVirtualHostname' "${HOSTNAME}"
            # SCS hostname
            _process_inifile_params 'NW_SCS_Instance.scsVirtualHostname' "${HOSTNAME}"
            ;;
        # Database instance (DB instance)
        db)
            # SAP profile directory
            _process_inifile_params 'NW_readProfileDir.profileDir' "${SAPMNT_MOUNTPOINT}/${scrSID}/profile"
            # SAP profiles available
            _process_inifile_params 'NW_readProfileDir.profilesAvailable' 'true'

            _prepare_inifile_params_db
            ;;
        # Primary application server instance (PAS instance)
        pas)
            # SAP profile directory
            _process_inifile_params 'NW_readProfileDir.profileDir' "${SAPMNT_MOUNTPOINT}/${scrSID}/profile"
            # PAS instance number (CI)
            _process_inifile_params 'NW_CI_Instance.ciInstanceNumber' "${scrInstanceNumber}" 'custom'
            # ASCS hostname
            _process_inifile_params 'NW_CI_Instance.ascsVirtualHostname' "${HOSTNAME}"
            # SCS hostname
            _process_inifile_params 'NW_CI_Instance.scsVirtualHostname' "${HOSTNAME}"
            # PAS hostname (CI)
            _process_inifile_params 'NW_CI_Instance.ciVirtualHostname' "${HOSTNAME}"
            # SLD
            _process_inifile_params 'NW_SLD_Configuration.configureSld' 'false' 'custom'
            # Secure Storage Key
            _process_inifile_params 'NW_ABAP_SSFS_CustomKey.ssfsKeyInputFile' "${SECURE_STORAGE_FILE}"

            if [ "${scrDatabaseVendor}" = "ORA" ]; then
                # Oracle client version
                _process_inifile_params 'storageBasedCopy.ora.clientVersion' '121' 'custom'
                # Oracle database schema
                _process_inifile_params 'storageBasedCopy.ora.ABAPSchema' 'SAPSR3' 'custom'
            fi
            ;;
        # Additional application server instance (AAS instance)
        aas)
            # SAP profile directory
            _process_inifile_params 'NW_readProfileDir.profileDir' "${SAPMNT_MOUNTPOINT}/${scrSID}/profile"
            # SAP profiles available
            _process_inifile_params 'NW_readProfileDir.profilesAvailable' 'true'
            # AAS instance number
            _process_inifile_params 'NW_AS.instanceNumber' "${scrInstanceNumber}" 'custom'
            # AAS hostname (DI)
            _process_inifile_params 'NW_DI_Instance.virtualHostname' "${HOSTNAME}"

            if [ "${scrDatabaseVendor}" = "ADA" ]; then
                # superdba password
                _process_inifile_params 'Sdb_DBUser.dbaPassword' "${scrMasterPW}"
                # control password
                _process_inifile_params 'Sdb_DBUser.dbmPassword' "${scrMasterPW}"
                 # database user password
                _process_inifile_params 'Sdb_Schema_Dialogs.dbSchemaPassword' "${scrMasterPW}"     
            elif [ "${scrDatabaseVendor}" = "DB6" ]; then
                # ABAP schema connect user
                _process_inifile_params 'NW_DB6_DB.db6.abap.connect.user' "sap${sid_lc}" 
                # ABAP schema
                _process_inifile_params 'NW_DB6_DB.db6.abap.schema' "SAP${scrSID}" 'custom'
            elif [ "${scrDatabaseVendor}" = "ORA" ]; then
                # Oracle client version
                _process_inifile_params 'storageBasedCopy.ora.clientVersion' '121' 'custom'
                # Oracle database schema
                _process_inifile_params 'storageBasedCopy.ora.ABAPSchema' 'SAPSR3' 'custom'
            fi
            ;;
        *)
            _exit_on_error "NO_HOST_FUNCTION - '${scrHostFunction}' is no valid HostFunction." "${LINENO}"
            ;;
    esac
    
    cp -p "${INIFILE_PARAMS}" "${SCRIPTDIR}/inifile_${scrSID}.params"
    chmod 600 "${SCRIPTDIR}/inifile_${scrSID}.params"
}

################################################################################
# Prepare database part of inifile.params file
################################################################################
_prepare_inifile_params_db()
{
    case "${scrDatabaseVendor}" in
        ADA)
            # If DBSID does not exist, the default scrSID will be used, otherwise the value from inifile.params will be taken
            _process_inifile_params 'NW_ADA_getDBInfo.dbsid' "${scrSID_DB}" 'custom'
            ;;
        DB6)
            # If DBSID does not exist, the default scrSID will be used, otherwise the value from inifile.params will be taken
            _process_inifile_params 'NW_getDBInfoGeneric.dbsid' "${scrSID_DB}" 'custom'
            ;;
        HDB)
            # HDB server installation components
            _process_inifile_params 'HDB_Server_Install.installationComponents' 'server' 'custom'
            # HDB hostname
            _process_inifile_params 'NW_HDB_getDBInfo.dbhost' "${HOSTNAME_HDB}"
            # HDB SID
            _process_inifile_params 'NW_HDB_getDBInfo.dbsid' "${scrSID_HDB}"
            # HDB Instance Number
            # shellcheck disable=SC2154
            _process_inifile_params 'NW_HDB_getDBInfo.instanceNumber' "${scrInstanceNumber_HDB}"
            # HDB Master Password
            # shellcheck disable=SC2154
            _process_inifile_params 'NW_HDB_getDBInfo.systemPassword' "${scrMasterPW_HDB}"
            # HDB client location (can be LOCAL or SAPCPE)
            _process_inifile_params 'NW_HDB_DBClient.clientPathStrategy' 'LOCAL' 'custom'
            ;;
        ORA)
            # If DBSID does not exist, the default scrSID will be used, otherwise the value from inifile.params will be taken
            _process_inifile_params 'NW_getDBInfoGeneric.dbsid' "${scrSID_DB}" 'custom'
            # If Oracle client version does not exist, the default for Oracle 12G will be used, otherwise the value from inifile.params will be taken
            _process_inifile_params 'storageBasedCopy.ora.clientVersion' '121' 'custom'
            # If Oracle server version does not exist, the default for Oracle 12G will be used, otherwise the value from inifile.params will be taken
            _process_inifile_params 'storageBasedCopy.ora.serverVersion' '121' 'custom'
            # TODO (ST)
            #if [ "${DB_EXISTS}" = "true" ]; then
            #   Fill with right parameter for inifile. Need to wait for SAP to implement the solution
            #fi
            ;;
        SYB)
            # If DBSID does not exist, the default scrSID will be used, otherwise the value from inifile.params will be taken
            _process_inifile_params 'NW_getDBInfoGeneric.dbsid' "${scrSID_DB}" 'custom'
            ;;
        *)
            _exit_on_error "UNKNOWN_DB_VENDOR - '${scrDatabaseVendor}' not supported." "${LINENO}"
            ;;
    esac
}

################################################################################
# Prepare SAP media
################################################################################
_prepare_sap_media()
{
    # Locate sapinst
    ${ECHO} "$(date)\t path_to_sapinst ==> find -L ${SAP_MEDIA_DIR} -name sapinst -type f" >> "${DEV_LOG}"
    path_to_sapinst=$( find -L "${SAP_MEDIA_DIR}" -name sapinst -type f )
    [ -z "${path_to_sapinst}" ] && _exit_on_error "NO_SAPINST_FOUND - There is no sapinst present in '${SAP_MEDIA_DIR}'." "${LINENO}"

    # Sanity check: do we have more than one sapinst
    count_sapinst=$( echo "${path_to_sapinst}" | wc -l )
    if [ "${count_sapinst}" -gt 1 ]; then
        ${ECHO} "$(date)\t Found more than one sapinst! Taking the first matching one." >> "${DEV_LOG}"
        ${ECHO} "$(date)\t ${path_to_sapinst}" >> "${DEV_LOG}"
        for swpm_sapinst in ${path_to_sapinst}; do
            swpm_path=$( dirname "${swpm_sapinst}" )
            if [ -f "${swpm_path}/manifest.mf" ]; then
                # Check that the OS string and SWPM is part of the manifest.mf file
                grep -i "${OS_SEARCH}" "${swpm_path}/manifest.mf" | grep -iq 'swpm' && break || swpm_sapinst=''
            fi
        done
        ${ECHO} "$(date)\t Using first valid sapinst: '${swpm_sapinst}'" >> "${DEV_LOG}"
    else
        swpm_sapinst="${path_to_sapinst}"
        swpm_path=$( dirname "${swpm_sapinst}" )
        if [ -f "${swpm_path}/manifest.mf" ]; then
            # Check that the OS string and SWPM is part of the manifest.mf file
            grep -i "${OS_SEARCH}" "${swpm_path}/manifest.mf" | grep -iq 'swpm' || swpm_sapinst=''
        else
            swpm_sapinst=''
        fi
    fi

    [ -z ${swpm_sapinst} ] && _exit_on_error "NO_SAPINST_FOUND - There is no valid sapinst present in '${SAP_MEDIA_DIR}'." "${LINENO}"

    SWPM_DIR=$( dirname "${swpm_sapinst}" )

    # Create start_dir.cd
    find -L "${SAP_MEDIA_DIR}" -mindepth 1 -maxdepth 1 -type d > "${SAPINST_INSTDIR}/start_dir.cd"

    {
        ${ECHO} "$(date)\t path_to_sapinst ==> '${path_to_sapinst}'";
        ${ECHO} "$(date)\t swpm_sapinst ==> '${swpm_sapinst}'";
        ${ECHO} "$(date)\t SWPM_DIR ==> '${SWPM_DIR}'";
    } >> "${DEV_LOG}"
}

################################################################################
# Prepare SAP profile entries
################################################################################
_prepare_sap_profiles()
{
    # SAP autostart after a server reboot
    _process_sap_profiles 'instance' 'Autostart' '1'
    # sapgui user_scripting for ABAP application server
    _process_sap_profiles 'instance' 'sapgui/user_scripting' 'TRUE' 'Start application server'
}

################################################################################
# Process HDB config
#
# Arguments:
#   parameter
#   value
# Returns:
#   none
################################################################################
_process_hdb_conf()
{
    parameter="${1}"
    value="${2}"

    inifile_value=$( grep "^${parameter}\s*=" "${HDB_CONF}" )
    if [ "$?" -eq 0 ]; then
        # Check if paramater=components
        if [ "${parameter}" = "components" ]; then
            inifile_value=$( echo "${inifile_value}" | cut -d= -f2 | tr -d ' ' )
            if [ -z "${inifile_value}" ]; then
                sed -i "s|^\(${parameter}\)\s*=.*|\1=${value}|g" "${HDB_CONF}"
                # hide the password for logging
                echo "${parameter}" | grep -iq password && value="********"
                ${ECHO} "$(date)\t Set parameter '${parameter}=${value}' in ${HDB_CONF}." >> "${DEV_LOG}"
            elif [ "${inifile_value}" != "all" ]; then
                for component_value in $( echo "${value}" | sed 's/,/ /g' ); do
                    echo "${inifile_value}" | grep -q "${component_value}"
                    [ "$?" -ne 0 ] && inifile_value="${inifile_value},${component_value}"
                done
                sed -i "s|^\(${parameter}\)\s*=.*|\1=${inifile_value}|g" "${HDB_CONF}"
                # hide the password for logging
                echo "${parameter}" | grep -iq password && value="********"
                ${ECHO} "$(date)\t Set parameter '${parameter}=${inifile_value}' in ${HDB_CONF}." >> "${DEV_LOG}"
            fi
        else
            sed -i "s|^\(${parameter}\)\s*=.*|\1=${value}|g" "${HDB_CONF}"
            ${ECHO} "$(date)\t Set parameter '${parameter}=${value}' in ${HDB_CONF}." >> "${DEV_LOG}"
        fi
    else
        printf '\n%s\n' "${parameter}=${value}" >> "${HDB_CONF}"
        # hide the password for logging
        echo "${parameter}" | grep -iq password && value="********"
        ${ECHO} "$(date)\t Parameter not found. Use local_input.ini value to set '${parameter}=${value}' in ${HDB_CONF}." >> "${DEV_LOG}"
    fi
}

################################################################################
# Process inifile.params
#
# Arguments:
#   parameter
#   value
#   custom
# Returns:
#   none
################################################################################
_process_inifile_params()
{
    parameter="${1}"
    value="${2}"
    custom="${3}"

    inifile_value=$( grep "^${parameter}\s*=" "${INIFILE_PARAMS}" )
    if [ "$?" -eq 0 ]; then
        inifile_value=$( echo "${inifile_value}" | cut -d= -f2 | tr -d ' ' )
        if [ -z "${inifile_value}" ] || [ -z "${custom}" ]; then
            sed -i "s|^\(${parameter}\)\s*=.*|\1 = ${value}|g" "${INIFILE_PARAMS}"
            # hide the password for logging
            echo "${parameter}" | grep -iq password && value="********"
            ${ECHO} "$(date)\t Replace parameter '${parameter} = ${value}' in ${INIFILE_PARAMS}." >> "${DEV_LOG}"
        else
            sed -i "s|^\(${parameter}\)\s*=.*|\1 = ${inifile_value}|g" "${INIFILE_PARAMS}"
            # hide the password for logging
            echo "${parameter}" | grep -iq password && value="********"
            ${ECHO} "$(date)\t Custom parameter value from template '${parameter} = ${value}' will be used in ${INIFILE_PARAMS}." >> "${DEV_LOG}"
        fi
    else
        printf '\n%s\n' "${parameter} = ${value}" >> "${INIFILE_PARAMS}"
        # hide the password for logging
        echo "${parameter}" | grep -iq password && value="********"
        ${ECHO} "$(date)\t Parameter not found. Use local_input.ini to set parameter '${parameter} = ${value}' in ${INIFILE_PARAMS}" >> "${DEV_LOG}"
    fi
}

################################################################################
# Process SAP profile entries
#
# Arguments:
#   profile     (default|instance)
#   parameter
#   value
#   search_string
################################################################################
_process_sap_profiles()
{
    profile="${1}"
    parameter="${2}"
    value="${3}"
    search_string="${4}"

    [ -z "${parameter}" ] && _exit_on_error "PROCESS_SAP_PROFILES - Second function argument 'parameter' is missing." "${LINENO}"
    [ -z "${value}" ] && _exit_on_error "PROCESS_SAP_PROFILES - Third function argument 'value' is missing." "${LINENO}"

    case "${profile}" in
        default)
            # ToDo: On Distributed or additional instances on the same host, check that entry will be created once
            default_profile="/usr/sap/${scrSID}/SYS/profile/DEFAULT.PFL"
            if [ -f "${default_profile}" ]; then
                [ -f "${default_profile}.HPE_AI_BCK" ] || cp -p "${default_profile}" "${default_profile}.HPE_AI_BCK"
                sed -i "s|^${parameter}|#&|g" "${default_profile}"
                grep -q HPE "${default_profile}" || _add_hpe_header_long >> "${default_profile}"
                echo "${parameter} = ${value}" >> "${default_profile}"
            fi
            ;;
        instance)
            if [ -f /usr/sap/sapservices ]; then
                instance_profiles=$( awk -F'pf=' '/pf=/ {print $NF}' /usr/sap/sapservices | awk -F' ' '{print $1}' )
                for instance_profile in ${instance_profiles}; do
                    grep -iq "${search_string}" "${instance_profile}"
                    if [ "$?" -eq 0 ] || [ -z "${search_string}" ]; then
                        [ -f "${instance_profile}.HPE_AI_BCK" ] || cp -p "${instance_profile}" "${instance_profile}.HPE_AI_BCK"
                        sed -i "s|^${parameter}|#&|g" "${instance_profile}"
                        grep -q HPE "${instance_profile}" || _add_hpe_header_long >> "${instance_profile}"
                        echo "${parameter} = ${value}" >> "${instance_profile}"
                    fi
                done
            fi
            ;;
        *)
            _exit_on_error "PROCESS_SAP_PROFILES - First function argument 'profile' is missing." "${LINENO}"
            ;;
    esac
}

################################################################################
# Reserve ports for DB2
################################################################################
_reserve_db2_ports()
{
    # Some default ports are used by DB2
    mv /etc/services /etc/services.HPE_AI_TMP
    awk '{ if ($2 ~ /591[2-7]/) print "# "$0; else print $0 }' /etc/services.HPE_AI_TMP > /etc/services
    rm -f /etc/services.HPE_AI_TMP
}

################################################################################
# Restart SAP application instances
################################################################################
_restart_sap_application_instance()
{
    if [ -f /usr/sap/sapservices ]; then
        instance_profiles=$( awk -F'pf=' '/pf=/ {print $NF}' /usr/sap/sapservices | awk -F' ' '{print $1}' )
        for instance_profile in ${instance_profiles}; do
            instance_name=$( awk '/^INSTANCE_NAME/ {print $NF}' "${instance_profile}" )
            if [ "${instance_name:0:1}" = "D" ] || [ "${instance_name:0:1}" = "J" ]; then
                _sapcontrol "${scrHostnameFQDN}" "${instance_name: -2}" "RestartSystem"
                ${ECHO} "$(date)\t Restart SAP Instance '${instance_name}'." >> "${INSTALLATION_LOG}"
                sleep 120
                for counter in {1..20}; do
                    _sapcontrol "${scrHostnameFQDN}" "${instance_name: -2}" "GetProcessList"
                    [ "${SAP_STATUS}" = "GREEN" ] && break || sleep 30
                done
                if [ "${SAP_STATUS}" = "GREEN" ]; then
                    ${ECHO} "$(date)\t SAP Instance ${instance_name} successfully restarted." >> "${INSTALLATION_LOG}"
                else
                    _exit_on_error "INSTANCE_RESTART - SAP Instance ${instance_name} not successfully restarted." "${LINENO}"
                fi
            fi
        done
    fi
}

################################################################################
# Sanity check
#
# Arguments:
#   option
# Returns:
#   none
################################################################################
_sanity_check()
{
    option="${1}"
    eval value="\${${option}}"

    case "${option}" in
        scrDepotHost|scrDryRun|scrMultipleOS|scrHostFunction|scrDatabaseVendor|scrSapStack)
            [ "${option}" = "scrDepotHost" ] && grepstr='^cifs:|^nfs:|^local$'
            [ "${option}" = "scrDryRun" ] && grepstr='^false$|^true$|^sap_summary$|^host_preparation$'
            [ "${option}" = "scrMultipleOS" ] && grepstr='^false$|^true$'
            [ "${option}" = "scrHostFunction" ] && grepstr='^standard$|^ascs$|^scs$|^db$|^pas$|^aas$'
            [ "${option}" = "scrDatabaseVendor" ] && grepstr='^ADA$|^DB6$|^HDB$|^ORA$|^SYB$'
            [ "${option}" = "scrSapStack" ] && grepstr='^ABAP$|^JAVA$|^DOUBLESTACK$'
            echo "${value}" | grep -Eq "${grepstr}" || _exit_on_error "SANITY_CHECK - Error during sanity check of '${option}' with value='${value}'. Please check your input in the local_input.ini file." "${LINENO}"
            ;;
        scrDepotName|scrDepotSapDirectory|scrSapVersion)
            if [ -z "${value}" ]; then
                if [ "${option}" = "scrDepotName" ] && [ "${scrDepotHost}" != "local" ]; then
                    _exit_on_error "SANITY_CHECK - Error during sanity check of '${option}' with value='${value}'. Please check your input in the local_input.ini file." "${LINENO}"
                elif [ "${option}" = "scrDepotSapDirectory" ] || [ "${option}" = "scrSapVersion" ]; then
                    _exit_on_error "SANITY_CHECK - Error during sanity check of '${option}' with value='${value}'. ${option} may not be empty." "${LINENO}"
                fi
            fi
            ;;
        scrSID|scrSID_DB|scrSID_HDB)
            if [ "${option}" = "scrSID" ] || [ "${option}" = "scrSID_DB" ]; then
                grepstr='^ADD$|^ALL$|^AND$|^ANY$|^ASC$|^AUX$|^COM$|^CON$|^DBA$|^END$|^EPS$|^FOR$|^GID$|^IBM$|^INT$|^KEY$|^LOG$|^LPT$|^MON$|^NIX$|^NOT$|^NUL$|^OFF$|^OMS$|^PRN$|^RAW$|^ROW$|^SAP$|^SET$|^SGA$|^SHG$|^SID$|^SQL$|^SYS$|^TMP$|^UID$|^USR$|^VAR$'
            elif [ "${option}" = "scrSID_HDB" ]; then
                grepstr='^ADD$|^ALL$|^AMD$|^AND$|^ANY$|^ARE$|^ASC$|^AUX$|^AVG$|^BIT$|^CDC$|^COM$|^CON$|^DBA$|^END$|^EPS$|^FOR$|^GET$|^GID$|^IBM$|^INT$|^KEY$|^LOG$|^LPT$|^MAP$|^MAX$|^MIN$|^MON$|^NIX$|^NOT$|^NUL$|^OFF$|^OLD$|^OMS$|^OUT$|^PAD$|^PRN$|^RAW$|^REF$|^ROW$|^SAP$|^SET$|^SGA$|^SHG$|^SID$|^SQL$|^SUM$|^SYS$|^TMP$|^TOP$|^UID$|^USE$|^USR$|^VAR$'
            fi
            echo "${value}" | grep -E '^[A-Z][A-Z0-9]{2}+$' | grep -Eqv "${grepstr}" || _exit_on_error "SANITY_CHECK - Error during sanity check of '${option}' with value='${value}'. ${value} does not comply with SAP rules." "${LINENO}"
            ;;
        scrInstanceNumber|scrInstanceNumber_HDB)
            if [ -n "${value}" ]; then
                echo "${value}" | grep -E '^[0-9]{2}+$' | grep -Eqv '98|99' || _exit_on_error "SANITY_CHECK - Error during sanity check of '${option}' with value='${value}'. ${value} does not comply with SAP rules." "${LINENO}"
            elif [ -z "${value}" ] && [ "${option}" = "scrInstanceNumber_HDB" ]; then
                _exit_on_error "SANITY_CHECK - Error during sanity check of '${option}' with value='${value}'. ${value} does not comply with SAP rules." "${LINENO}"
            fi
            ;;
        scrIpAddr|scrDeploymentIpAddr|scrIpAddr_HDB|scrDeploymentIpAddr_HDB)
            echo "${value}" | grep -Eq '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' || _exit_on_error "SANITY_CHECK - Error during sanity check of '${option}' with value='${value}'. ${value} is not an IP adress." "${LINENO}"
            ;;
        scrMasterPW|scrMasterPW_HDB)
            if [ -z "${value}" ]; then
                if [ "${option}" = "scrMasterPW" ] && [ "${scrHostFunction}" = "standard" ] || [ "${scrHostFunction}" = "ascs" ] || [ "${scrHostFunction}" = "scs" ]; then
                    scrMasterPW=$( _create_master_password )
                    # Save SAP Master Password and make the file only available for root
                    echo "${scrSID}:${scrMasterPW}" >> "${MASTER_PASSWORD_FILE}" && chmod 600 "${MASTER_PASSWORD_FILE}"
                    ${ECHO} "$(date)\t SAP Master Password created >********<" >> "${INSTALLATION_LOG}"
                elif [ "${option}" = "scrMasterPW_HDB" ] && { [ "${INSTALL_SAP_OR_HDB}" = "hdb" ] || [ "${INSTALL_SAP_OR_HDB}" = "both" ]; }; then
                    scrMasterPW_HDB=$( _create_master_password )
                    # Save HDB Master Password and make the file only available for root
                    echo "${scrSID_HDB}:${scrMasterPW_HDB}" >> "${MASTER_PASSWORD_FILE}" && chmod 600 "${MASTER_PASSWORD_FILE}"
                    ${ECHO} "$(date)\t HANA DB Master Password created >********<" >> "${INSTALLATION_LOG}"
                else
                    _exit_on_error "SANITY_CHECK - Error during sanity check of '${option}' with value='${value}'. ${option} must be set." "${LINENO}"
                fi
            else
                echo "${value}" | grep -E '^[a-zA-Z#$][a-zA-Z0-9_#$]{7,13}$' | grep '[a-zA-Z]' | grep -q '[0-9]' || _exit_on_error "SANITY_CHECK - Error during sanity check of '${option}' with value='${value}'. ${value} does not comply with SAP rules." "${LINENO}"
            fi
            ;;
        scrHostnameFQDN|scrHostnameFQDN_HDB)
            [ -z "${value}" ] && _exit_on_error "SANITY_CHECK - Error during sanity check of '${option}' with value='${value}'. ${option} may not be empty" "${LINENO}"
            ;;
        HOSTNAME|HOSTNAME_HDB)
            echo "${value}" | grep -Eq '^[a-zA-Z0-9-]{2,13}$' || _exit_on_error "SANITY_CHECK - Error during sanity check of '${option}' with value='${value}'. '${option}' is too long - SAP installer allows up to 13 characters." "${LINENO}"
            ;;
        scrGlobalHost)
            if [ -z "${value}" ] && { [ "$scrHostFunction" = "db" ] || [ "${scrHostFunction}" = "pas" ] || [ "$scrHostFunction" = "aas" ]; }; then
                _exit_on_error "SANITY_CHECK - Error during sanity check of '${option}' with value='${value}'. Please check your input in the local_input.ini file." "${LINENO}"
            fi
            ;;
        *)
            _exit_on_error "SANITY_CHECK - Error on function _sanity_check with parameters option='${option}' and value='${value}'. Option='${option}' not available or wrong." "${LINENO}"
            ;;
    esac
}

################################################################################
# Check SAP Status
#
# Arguments:
#   host        (required)
#   nr          (required)
#   function    (required)
#   user        (optional, only required for Start/Stop/Restart of a system)
#   password    (optional, only required for Start/Stop/Restart of a system)
################################################################################
_sapcontrol()
{
    host="${1}"
    nr="${2}"
    function="${3}"

    prot="NI_HTTP"

    [ "${INSTALL_SAP_OR_HDB}" = "hdb" ] && su_user="${SIDADM_HDB}" || su_user="${SIDADM}"

    if [ "${function}" = "GetProcessList" ]; then
        ${ECHO} "$(date)\t su - ${su_user} -c 'sapcontrol -prot ${prot} -host ${host} -nr ${nr} -function ${function} -format script' | awk '/dispstatus/ {print $NF}'" >> "${DEV_LOG}"
        stdout=$( su - "${su_user}" -c "sapcontrol -prot ${prot} -host ${host} -nr ${nr} -function ${function} -format script" | awk '/dispstatus/ {print $NF}' )
        for SAP_STATUS in ${stdout}; do
            [ "${SAP_STATUS}" != "GREEN" ] && break
        done
    else
        ${ECHO} "$(date)\t su - ${su_user} -c 'sapcontrol -prot ${prot} -host ${host} -nr ${nr} -function ${function}'" >> "${DEV_LOG}"
        stdout=$( su - "${su_user}" -c "sapcontrol -prot ${prot} -host ${host} -nr ${nr} -function ${function}" )
        [ "$?" -eq 1 ] && _exit_on_error "SAPCONTROL_FAILED - ${stdout}" "${LINENO}"
    fi
}

################################################################################
# Save some system files
################################################################################
_save_system_files()
{
    ${ECHO} "$(date)\t Saving some files in /etc" >> "${INSTALLATION_LOG}"
    cd /etc || _exit_on_error "ERROR_DIR_CHANGE - Change working directory to '/etc' not possible!" "${LINENO}"

    for fname in passwd shadow group services hosts exports fstab sysctl.conf; do
        if [ ! -f "${fname}.HPE_AI_BCK" ]; then
            cp -pv "${fname}" "${fname}.HPE_AI_BCK" >> "${DEV_LOG}"
        else
            # shellcheck disable=SC2154
            if [ "${scrDryRun}" = "false" ]; then
                cp -pv "${fname}" "${fname}.HPE_AI_B4_${scrSID}" >> "${DEV_LOG}"
            fi
        fi
    done
}

################################################################################
# Source the local input file
################################################################################
_source_local_input_file()
{
    # check if local_input.ini exists
    if [ -f "${LOCAL_INPUT_FILE}" ]; then
        # remove spaces from local_input.ini
        sed -i '/^#/!s/\s*//g' "${LOCAL_INPUT_FILE}"
        # source the local_input.ini file
        # shellcheck source=/dev/null
        . "${LOCAL_INPUT_FILE}"

        # make the file only available for root
        chmod 600 "${LOCAL_INPUT_FILE}"
    else
        _exit_on_error "NO_LOCAL_INPUT_FILE - '${LOCAL_INPUT_FILE}' file with runtime parameters not found!" "${LINENO}"
    fi
}

################################################################################
# Standard sapinst invocation
################################################################################
_standard_sapinst_call()
{
    cd "${SAPINST_INSTDIR}" || _exit_on_error "ERROR_DIR_CHANGE - Change working directory to '${SAPINST_INSTDIR}' not possible!" "${LINENO}"

    ###############################################
    # Calling sapinst 1st time
    ###############################################
    SAPINST_COMMAND="${SAPINST_1ST_COMMAND}"
    ${ECHO} "$(date)\t Assigned SAPINST_COMMAND ==>${SAPINST_COMMAND}<==" >> "${DEV_LOG}"
    INSTALL_SUCCESS="false"
    counter="first"
    while [ "${INSTALL_SUCCESS}" = "false"  ]; do

        ${ECHO} "$(date)\t Calling sapinst ${counter} time" >> "${INSTALLATION_LOG}"
        ${ECHO} "$(date)\t Calling sapinst ${counter} time" >> "${DEV_LOG}" 

        # Calling sapinst again in background since there MAY be some errors that require a 3rd invocation of sapinst
        ${SAPINST_COMMAND} >> sapinst_stdout.log 2>1 &

        # after waiting a grace period we trace sapinst_dev.log and check for "OraCom.getABAPSchemaEnv() done: undefined" and
        # "Front side checks for diOraDbNetworkConfig1 returns false Check input element"
        sleep 30

        RC=1
        while [ ! $RC -eq 0 ]; do
            # This is a dummy entry
            # grep 'Klaus waits for an error' ${SAPINST_INSTDIR}/sapinst_dev.log >/dev/null 2>&1
            # RC1=$?
            grep 'FCO-00011  The step syb_step_dbclient_install' "${SAPINST_INSTDIR}"/sapinst_dev.log | grep -q "${SCRIPTDIR}/sapinst_instdir/DBCLIENT.1.log"
            RC1=$?

            grep -q "The installation of component .* has completed"  "${SAPINST_INSTDIR}"/sapinst_dev.log
            RC2=$?

            if [ ! $RC1 -eq 0 ] && [ ! $RC2 -eq 0 ]; then
                RC=1
                sleep 5
            else
                if [ $RC2 -eq 0 ]; then
                    INSTALL_SUCCESS="true"
                fi
                RC=0
            fi

            # Check if sapinst is still running
            # shellcheck disable=SC2009
            ps ax | grep sapinst_exe | grep -qv 'grep'
            RC3=$?

            if [ ! $RC3 -eq 0 ]; then
                # wait to see if installation finished successfully
                sleep 10
                grep -q "The installation of component .* has completed"  "${SAPINST_INSTDIR}"/sapinst_dev.log
                RC2=$?
                if [ $RC2 -eq 0 ]; then
                    INSTALL_SUCCESS="true"
                    RC=0
                elif [ "${scrDryRun}" = "sap_summary" ] && [ -f "${SAPINST_INSTDIR}/summary.html" ]; then
                    ${ECHO} "$(date)\t Sapinst stopped at the end of dialog phase." >> "${DEV_LOG}"
                    return
                else
                    _exit_on_error "SAPINST_STOPPED - sapinst ran into an error. Please check '${SAPINST_INSTDIR}/sapinst.log' or '${SAPINST_INSTDIR}/sapinst_dev.log'!" "${LINENO}"
                fi
            fi
        done

        if [ "${INSTALL_SUCCESS}" = "false" ]; then
            # We need another invocation of sapinst
            ${ECHO} "$(date)\t Killing sapinst due to error condition - going to restart" >> "${DEV_LOG}"
            # shellcheck disable=SC2046
            # shellcheck disable=SC2009
            kill $( ps ax | grep sapinst_exe | grep -v 'grep' | awk '{print $1}' )

            counter="second"
            SAPINST_COMMAND="${SAPINST_2ND_COMMAND}"
            ${ECHO} "$(date)\t Assigned SAPINST_COMMAND ==>${SAPINST_COMMAND}<==" >> "${DEV_LOG}"
            # In case of an error put the correction here!
        fi
    done
    
    ${ECHO} "$(date)\t sapinst finished" >> "${DEV_LOG}"

    [ -f "${SAPINST_INSTDIR}/installationSuccesfullyFinished.dat" ] || _exit_on_error "SAPINST_STOPPED - sapinst ran into an error. Please check '${SAPINST_INSTDIR}/sapinst.log' or '${SAPINST_INSTDIR}/sapinst_dev.log'!" "${LINENO}"
}

################################################################################
# Start installation
################################################################################
_start_installation()
{
    # Check if HDB shall be installed on the same host
    case "${INSTALL_SAP_OR_HDB}" in
        both)
            [ -d "/hana/data/${scrSID_HDB}" ] || _install_hdblcm
            _check_db_status
            if [ "${DB_ONLINE}" = "false" ]; then
                ${ECHO} "$(date)\t Start HANA Database " >> "${DEV_LOG}"
                # ToDo: is not working without su - <sid>adm
                # /usr/sap/hostctrl/exe/sapcontrol -nr ${scrInstanceNumber_HDB} -function Start >> "${DEV_LOG}"
            fi
            sleep 20
            _check_db_status
            [ "${DB_ONLINE}" = "false" ] && _exit_on_error "START_HDB - Starting HANA DB with SID '${scrSID_HDB}' failed." "${LINENO}"

            ${ECHO} "$(date)\t Continue Installing SAP system " >> "${DEV_LOG}"
            _check_requirements
            install_sapinst
            ${ECHO} "$(date)\t HDB and SAP Installation finished successfully." >> "${INSTALLATION_LOG}"
            ;;
        hdb)
            _install_hdblcm
            ;;
        sap)
            _check_requirements
            install_sapinst
            ${ECHO} "$(date)\t SAP Installation finished successfully." >> "${INSTALLATION_LOG}"
            ;;
        *)
            _exit_on_error "DETECT_INSTALLATION_SCENARIO - Installation Scenario could not be detected. Installation option INSTALL_SAP_OR_HDB='${INSTALL_SAP_OR_HDB}' is not valid." "${LINENO}"
            ;;
    esac
}

################################################################################
# Convert from upper to lower and vise versa
#
# Arguments:
#   value
#   option
# Returns:
#   stdout
################################################################################
_upper_lower()
{
    value="${1}"
    option="${2}"

    case "${option}" in
        lower)
            stdout=$( echo "${value}" | tr '[:upper:]' '[:lower:]' )
            ;;
        upper)
            stdout=$( echo "${value}" | tr '[:lower:]' '[:upper:]' )
            ;;
        *)
            _exit_on_error "UPPER_LOWER - Option='${option}' not available or wrong." "${LINENO}"
            ;;
    esac
    echo "${stdout}"
}

################################################################################
# Main
################################################################################
_initialize
_create_variables
_check_nfs_server
_mount_software_depot
_save_system_files
_check_etc_hosts
_dry_run
_start_installation

# END
