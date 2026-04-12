#!/usr/bin/env bash

#
# Generate each of the PKI sets
#
if [[ -z ${UID} ]]; then
    export UID=$(id -u);
else
    export UID     
fi
export GID=$(id -g); 

(
    cd PKI;

    echo
    echo "+---------------------+"
    echo "| Generating ops PKI |"
    echo "+---------------------+"
    mkdir -p ops/certs
    export PKI_ENV=ops; docker-compose up --menu=false

    echo
    echo "+---------------------+"
    echo "| Generating User PKI |"
    echo "+---------------------+"
    mkdir -p users/certs
    export PKI_ENV=users; docker-compose up --menu=false
)

#
# Copy them into the required config directories.
#
# All files need to have o+r so they can be read
# by the root user in the dockers 
#

# #########################
# 
# PKI
#
# #########################

echo
echo "+------------------------------+"
echo "| Copying PKI files to volumes |"
echo "+------------------------------+"


# #########################
# 
# PKI for High Import to send status and alerts to the status MM
#
# #########################

echo "High:Import ..."
OPS_CERTS=./PKI/ops/certs
OPS_ROOT_CA=${OPS_CERTS}/root-ca.ops.ctxd
OPS_INTER_CA=${OPS_ROOT_CA}/intermediate-ca.ops.ctxd
OPS_STATUS_WRITER_CA=${OPS_INTER_CA}/writer-ca.status.ops.ctxd
OPS_STATUS_HOST=status.ops.ctxd
OPS_ALERTS_WRITER_CA=${OPS_INTER_CA}/writer-ca.alerts.ops.ctxd
OPS_ALERTS_HOST=alerts.ops.ctxd

#
# Find which zones we have by looking for all the client certs
# we have for the status writer CA
#
ZONES=""    
DIR=${OPS_STATUS_WRITER_CA}
for ZoneDir in `find $DIR -maxdepth 1 -type d -name "import*"`; do
    ZONE=${ZoneDir##${DIR}/}
    ZONES="${ZONES} ${ZONE}"
done


for HOST in ${ZONES}; do

    # We need to make from the client hoist name to a volume
    #    import.high.ctxd         volumes/high/import
    #    import.high.zone1.ctxd   volumes/zone1/high/import
    
    # Strip the trailing '.ctxd'
    V=${HOST%%.ctxd}
    # Use a bit of sed magic and tr to reverse the path
    CONFIG=volumes/`echo $V | sed 's/\./\n/g' | tac | sed ':a; $!{N;ba};s/\n/\//g'`
    echo "    $HOST $CONFIG"

    mkdir -p ${CONFIG}
    rm -rf ${CONFIG}/certs

    # Status
    mkdir -p ${CONFIG}/certs/status
    cp -f \
        ${OPS_STATUS_WRITER_CA}/${HOST}/${HOST}.crt \
        ${OPS_STATUS_WRITER_CA}/${HOST}/${HOST}.pem \
        ${OPS_INTER_CA}/${OPS_STATUS_HOST}/${OPS_STATUS_HOST}.bundle.crt \
        ${CONFIG}/certs/status

    # Alerts
    mkdir -p ${CONFIG}/certs/alerts
    cp -f \
        ${OPS_ALERTS_WRITER_CA}/${HOST}/${HOST}.crt \
        ${OPS_ALERTS_WRITER_CA}/${HOST}/${HOST}.pem \
        ${OPS_INTER_CA}/${OPS_ALERTS_HOST}/${OPS_ALERTS_HOST}.bundle.crt \
        ${CONFIG}/certs/alerts

    find ${CONFIG} -type d -exec chmod o+rx {} \;
    find ${CONFIG} -type f -exec chmod o+r {} \;

done

# #########################
#
# PKI for High Export
#
# #########################
echo "High:Export ..."

#
# Read access to High GitWebHook 
#
OPS_CERTS=./PKI/ops/certs
OPS_ROOT_CA=${OPS_CERTS}/root-ca.ops.ctxd
OPS_INTER_CA=${OPS_ROOT_CA}/intermediate-ca.ops.ctxd
OPS_STATUS_WRITER_CA=${OPS_INTER_CA}/writer-ca.status.ops.ctxd
OPS_STATUS_HOST=status.ops.ctxd
OPS_GWH_READER_CA=${OPS_INTER_CA}/reader-ca.gitwh.ops.ctxd
OPS_GWH_HOST=gitwh.ops.ctxd

#
# Find which zones we have by looking for all the client certs
# we have for the status writer CA
#
ZONES=""    
DIR=${OPS_STATUS_WRITER_CA}
for ZoneDir in `find $DIR -maxdepth 1 -type d -name "export*"`; do
    ZONE=${ZoneDir##${DIR}/}
    ZONES="${ZONES} ${ZONE}"
done


for HOST in ${ZONES}; do

    # We need to make from the client host name to a volume
    #    export.high.ctxd         volumes/high/export
    #    export.high.zone1.ctxd   volumes/zone1/high/export
    
    # Strip the trailing '.ctxd'
    V=${HOST%%.ctxd}
    # Use a bit of sed magic and tr to reverse the path
    CONFIG=volumes/`echo $V | sed 's/\./\n/g' | tac | sed ':a; $!{N;ba};s/\n/\//g'`
    ZONE_VOLS="${ZONE_VOLS} ${CONFIG}"

    echo "   $HOST $CONFIG"
    
    rm -rf ${CONFIG}/certs ${CONFIG}/keys
    
    # Status
    mkdir -p ${CONFIG}/certs/status
    cp -f \
        ${OPS_STATUS_WRITER_CA}/${HOST}/${HOST}.crt \
        ${OPS_STATUS_WRITER_CA}/${HOST}/${HOST}.pem \
        ${OPS_INTER_CA}/${OPS_STATUS_HOST}/${OPS_STATUS_HOST}.bundle.crt \
        ${CONFIG}/certs/status

    # Git Web Hook
    mkdir -p ${CONFIG}/certs/gitwh
    cp -f \
        ${OPS_GWH_READER_CA}/${HOST}/${HOST}.crt\
        ${OPS_GWH_READER_CA}/${HOST}/${HOST}.pem\
        ${OPS_INTER_CA}/${OPS_GWH_HOST}/${OPS_GWH_HOST}.bundle.crt\
        ${CONFIG}/certs/gitwh

    #
    # System crypto keys and users CA for signature checking
    #
    USER_CERTS=./PKI/users/certs
    USER_ROOT_CA=ctxd-users-root-ca
    ADMINS_CA=ctxd-users-admins-ca
    KEYS=SystemCrypto

    mkdir -p ${CONFIG}

    # Config files 
    cp -rn templates/high/export/* ${CONFIG}

    mkdir -p ${CONFIG}/certs/users
    cp -f ${USER_CERTS}/${USER_ROOT_CA}/${ADMINS_CA}/${ADMINS_CA}.crt\
        ${CONFIG}/certs/users
        
    mkdir -p ${CONFIG}/keys
    cp -f ${USER_CERTS}/${USER_ROOT_CA}/${ADMINS_CA}/${KEYS}/${KEYS}.ecdh.pem\
        ${USER_CERTS}/${USER_ROOT_CA}/${ADMINS_CA}/${KEYS}/${KEYS}.ecdh.pub.pem\
        ${CONFIG}/keys

    find ${CONFIG} -type d -exec chmod o+rx {} \;
    find ${CONFIG} -type f -exec chmod o+r {} \;
done

# #########################
#
# PKI for High MQTT
#
# #########################
echo "High:MQTT ..."

#
# Read access to High GitWebHook 
#
OPS_CERTS=./PKI/ops/certs
OPS_ROOT_CA=${OPS_CERTS}/root-ca.ops.ctxd
OPS_INTER_CA=${OPS_ROOT_CA}/intermediate-ca.ops.ctxd
OPS_STATUS_WRITER_CA=${OPS_INTER_CA}/writer-ca.status.ops.ctxd
OPS_STATUS_HOST=status.ops.ctxd

#
# Find which zones we have by looking for all the client certs
# we have for the status writer CA
#
ZONES=""    
DIR=${OPS_STATUS_WRITER_CA}
for ZoneDir in `find $DIR -maxdepth 1 -type d -name "mqtt*"`; do
    ZONE=${ZoneDir##${DIR}/}
    ZONES="${ZONES} ${ZONE}"
done


for HOST in ${ZONES}; do

    # We need to make from the client host name to a volume
    #    mqtt.high.ctxd         volumes/high/mqtt
    #    mqtt.high.zone1.ctxd   volumes/zone1/high/mqtt
    
    # Strip the trailing '.ctxd'
    V=${HOST%%.ctxd}
    # Use a bit of sed magic and tr to reverse the path
    CONFIG=volumes/`echo $V | sed 's/\./\n/g' | tac | sed ':a; $!{N;ba};s/\n/\//g'`
    ZONE_VOLS="${ZONE_VOLS} ${CONFIG}"

    echo "   $HOST $CONFIG"
    
    rm -rf ${CONFIG}/certs ${CONFIG}/keys
    
    # Status
    mkdir -p ${CONFIG}/certs/status
    cp -f \
        ${OPS_STATUS_WRITER_CA}/${HOST}/${HOST}.crt \
        ${OPS_STATUS_WRITER_CA}/${HOST}/${HOST}.pem \
        ${OPS_INTER_CA}/${OPS_STATUS_HOST}/${OPS_STATUS_HOST}.bundle.crt \
        ${CONFIG}/certs/status

    find ${CONFIG} -type d -exec chmod o+rx {} \;
    find ${CONFIG} -type f -exec chmod o+r {} \;
done

# #########################
# 
# PKI for Ops Status /Alert MM
#
# #########################
echo "Ops:Status/Alerts/GitWebHook ..."

#
# Status High Import to write to it and the Console to read from it
#
OPS_CERTS=./PKI/ops/certs
OPS_ROOT_CA=${OPS_CERTS}/root-ca.ops.ctxd
OPS_INTER_CA=${OPS_ROOT_CA}/intermediate-ca.ops.ctxd

OPS_STATUS_WRITER=writer-ca.status.ops.ctxd
OPS_STATUS_WRITER_CA=${OPS_INTER_CA}/${OPS_STATUS_WRITER}
OPS_STATUS_READER=reader-ca.status.ops.ctxd
OPS_STATUS_READER_CA=${OPS_INTER_CA}/${OPS_STATUS_READER}
OPS_STATUS_HOST=status.ops.ctxd

OPS_ALERTS_WRITER=writer-ca.alerts.ops.ctxd
OPS_ALERTS_WRITER_CA=${OPS_INTER_CA}/${OPS_ALERTS_WRITER}
OPS_ALERTS_HOST=alerts.ops.ctxd

OPS_GWH_WRITER=writer-ca.gitwh.ops.ctxd
OPS_GWH_WRITER_CA=${OPS_INTER_CA}/${OPS_GWH_WRITER}
OPS_GWH_READER=reader-ca.gitwh.ops.ctxd
OPS_GWH_READER_CA=${OPS_INTER_CA}/${OPS_GWH_READER}
OPS_GWH_HOST=gitwh.ops.ctxd

CONFIG=volumes/ops/status/certs


rm -rf ${CONFIG}

mkdir -p ${CONFIG}/status
cp -f ${OPS_STATUS_WRITER_CA}/${OPS_STATUS_WRITER}.bundle.crt \
      ${OPS_STATUS_READER_CA}/${OPS_STATUS_READER}.bundle.crt \
      ${OPS_INTER_CA}/${OPS_STATUS_HOST}/${OPS_STATUS_HOST}.crt \
      ${OPS_INTER_CA}/${OPS_STATUS_HOST}/${OPS_STATUS_HOST}.pem \
      ${CONFIG}/status

mkdir -p ${CONFIG}/alerts
cp -f ${OPS_ALERTS_WRITER_CA}/${OPS_ALERTS_WRITER}.bundle.crt \
      ${OPS_INTER_CA}/${OPS_ALERTS_HOST}/${OPS_ALERTS_HOST}.crt \
      ${OPS_INTER_CA}/${OPS_ALERTS_HOST}/${OPS_ALERTS_HOST}.pem \
      ${CONFIG}/alerts

mkdir -p ${CONFIG}/gitwh
cp -f ${OPS_GWH_WRITER_CA}/${OPS_GWH_WRITER}.bundle.crt \
      ${OPS_GWH_READER_CA}/${OPS_GWH_READER}.bundle.crt \
      ${OPS_INTER_CA}/${OPS_GWH_HOST}/${OPS_GWH_HOST}.crt \
      ${OPS_INTER_CA}/${OPS_GWH_HOST}/${OPS_GWH_HOST}.pem \
   -f ${CONFIG}/gitwh

find ${CONFIG} -type d -exec chmod o+rx {} \;
find ${CONFIG} -type f -exec chmod o+r {} \;

# #########################
# 
# PKI for Console
#
# #########################
echo "Consoles ..."

#
# Allows Console sign files and read status from the status MM
#

# Signing PKI
USERS_CERTS=./PKI/users/certs
USERS_ROOT_CA=${USERS_CERTS}/ctxd-users-root-ca
USERS_ADMINS_CA=${USERS_ROOT_CA}/ctxd-users-admins-ca

OPS_CERTS=./PKI/ops/certs
OPS_ROOT_CA=${OPS_CERTS}/root-ca.ops.ctxd
OPS_INTER_CA=${OPS_ROOT_CA}/intermediate-ca.ops.ctxd

OPS_STATUS_READER_CA=${OPS_INTER_CA}/reader-ca.status.ops.ctxd
OPS_STATUS_HOST=status.ops.ctxd

OPS_ALERTS_WRITER_CA=${OPS_INTER_CA}/writer-ca.alerts.ops.ctxd
OPS_ALERTS_HOST=alerts.ops.ctxd

OPS_GWH_WRITER_CA=${OPS_INTER_CA}/writer-ca.gitwh.ops.ctxd
OPS_GWH_HOST=gitwh.ops.ctxd

HOST=console.ops.ctxd 

# Get the list of users
USERS=""
DIR=${USERS_ADMINS_CA}
for UserDir in `find $DIR -type d`; do

    USER=${UserDir##${DIR}}
    case ${USER} in
        /certs|/db|/SystemCrypto|/GroupCrypto)
            ;;
        *)
            USERS="${USERS} ${USER##/}"
    esac
    
done

for USER in ${USERS}; do
    echo "   ${USER}..."

    USER_DIR=volumes/ops/console/${USER}
    
    CONFIG=${USER_DIR}/config
    if [[ ! -d ${CONFIG} ]]; then
        mkdir -p ${CONFIG}
    fi
    cp -ru templates/ops/console/* ${CONFIG}
    sed -i -e "s/<USERNAME>/${USER}/" ${CONFIG}/settings.sfjs
    sed -i -e "s/<USERNAME>/${USER}/" ${CONFIG}/user.sfjs
    
    find ${CONFIG} -type d -exec chmod o+rx {} \;
    find ${CONFIG} -type f -exec chmod o+r {} \;

    CERTS=${USER_DIR}/certs
    if [[ ! -d $CERTS ]]; then
        mkdir -p ${CERTS}
    fi

    # Keys and certs used for Signing
    CRYPTO=GroupCrypto
    mkdir -p ${CERTS}/signing
    cp -f ${USERS_ADMINS_CA}/${USER}/${USER}.crt \
          ${USERS_ADMINS_CA}/${USER}/${USER}.pem \
          ${USERS_ADMINS_CA}/${CRYPTO}/${CRYPTO}.ecdh.pem \
          ${USERS_ADMINS_CA}/${CRYPTO}/${CRYPTO}.ecdh.pub.pem \
          ${CERTS}/signing

    # Keys and certs used to access the local git webhook server
    mkdir -p ${CERTS}/gitWebHook
    cp -f ${OPS_GWH_WRITER_CA}/${HOST}/${HOST}.crt \
          ${OPS_GWH_WRITER_CA}/${HOST}/${HOST}.pem \
          ${OPS_INTER_CA}/${OPS_GWH_HOST}/${OPS_GWH_HOST}.bundle.crt \
          ${CERTS}/gitWebHook
    

    # Keys and certs used to access the Status MM
    mkdir -p ${CERTS}/status
    cp -f ${OPS_STATUS_READER_CA}/${HOST}/${HOST}.crt \
          ${OPS_STATUS_READER_CA}/${HOST}/${HOST}.pem \
          ${OPS_INTER_CA}/${OPS_STATUS_HOST}/${OPS_STATUS_HOST}.bundle.crt \
          ${CERTS}/status
    
    # Keys and certs used to access the Alerts MM
    mkdir -p ${CERTS}/alerts
    cp -f ${OPS_ALERTS_WRITER_CA}/${HOST}/${HOST}.crt \
          ${OPS_ALERTS_WRITER_CA}/${HOST}/${HOST}.pem \
          ${OPS_INTER_CA}/${OPS_ALERTS_HOST}/${OPS_ALERTS_HOST}.bundle.crt \
          ${CERTS}/alerts
    
    find ${CERTS} -type d -exec chmod o+rx {} \;
    find ${CERTS} -type f -exec chmod o+r {} \;

done

#
# Done
#
echo
echo "Config Generated"
echo
echo "Remember to update the Git configuration in:"
for ZONE in $ZONE_VOLS; do
    echo "  ${ZONE}/git.sfjs"
done
for USER in $USERS; do
    echo "  volumes/ops/console/${USER}/config/git.sfjs"
done

echo
echo "Remember to create the following files."
echo "  secrets/high/git"
echo "  secrets/high/slack (optional)"
for USER in $USERS; do
    echo "  secrets/ops/console/${USER}/config/password"
    echo "  secrets/ops/console/${USER}/config/git"
done



