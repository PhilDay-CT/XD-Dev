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
    echo "| Generating high PKI |"
    echo "+---------------------+"
    mkdir -p ops/certs
    export PKI_ENV=ops; docker-compose up

    echo
    echo "+---------------------+"
    echo "| Generating User PKI |"
    echo "+---------------------+"
    mkdir -p users/certs
    export PKI_ENV=users; docker-compose up 
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
echo "+-----------------------------+"
echo "| Copying PKI files to config |"
echo "+-----------------------------+"
    

# #########################
# 
# PKI for High Import to send status to the status MM
#
# #########################

echo "High:Import ..."
CONFIG=volumes/high/import
CERTS=./PKI/ops/certs
ROOT_CA=ctxd-ops-root-ca
INTER_CA=ctxd-ops-intermediate-ca
STATUS_WRITER_CA=ctxd-ops-status-writer-ca
STATUS=status.ops.ctxd
ALERTS_WRITER_CA=ctxd-ops-alerts-writer-ca
ALERTS=alerts.ops.ctxd
HOST=import.high.ctxd

mkdir -p ${CONFIG}

# Status
mkdir -p ${CONFIG}/certs/status
cp -f ${CERTS}/${ROOT_CA}/${INTER_CA}/${STATUS_WRITER_CA}/${HOST}/${HOST}.crt \
      ${CERTS}/${ROOT_CA}/${INTER_CA}/${STATUS_WRITER_CA}/${HOST}/${HOST}.pem \
      ${CERTS}/${ROOT_CA}/${INTER_CA}/${STATUS}/${STATUS}.bundle.crt \
      ${CONFIG}/certs/status

# Alerts
mkdir -p ${CONFIG}/certs/alerts
cp -f ${CERTS}/${ROOT_CA}/${INTER_CA}/${ALERTS_WRITER_CA}/${HOST}/${HOST}.crt \
      ${CERTS}/${ROOT_CA}/${INTER_CA}/${ALERTS_WRITER_CA}/${HOST}/${HOST}.pem \
      ${CERTS}/${ROOT_CA}/${INTER_CA}/${ALERTS}/${ALERTS}.bundle.crt \
      ${CONFIG}/certs/alerts

find ${CONFIG} -type d -exec chmod o+rx {} \;
find ${CONFIG} -type f -exec chmod o+r {} \;

# #########################
#
# PKI for High Export
#
# #########################
echo "High:Export ..."

#
# System crypto keys and users CA for signature checking
#
CONFIG=volumes/high/export
CERTS=./PKI/users/certs
ROOT_CA=ctxd-users-root-ca
ADMINS_CA=ctxd-users-admins-ca
KEYS=SystemCrypto

mkdir -p ${CONFIG}

# Config files 
cp -rn templates/high/export/* ${CONFIG}

mkdir -p ${CONFIG}/certs/users
cp -f ${CERTS}/${ROOT_CA}/${ADMINS_CA}/${ADMINS_CA}.crt\
      ${CONFIG}/certs/users
      
mkdir -p ${CONFIG}/keys
cp -f ${CERTS}/${ROOT_CA}/${ADMINS_CA}/${KEYS}/${KEYS}.ecdh.pem\
      ${CERTS}/${ROOT_CA}/${ADMINS_CA}/${KEYS}/${KEYS}.ecdh.pub.pem\
      ${CONFIG}/keys

#
# Read access to High GitWebHook 
#
CERTS=./PKI/ops/certs
ROOT_CA=ctxd-ops-root-ca
INTER_CA=ctxd-ops-intermediate-ca
READER_CA=ctxd-ops-gitwh-reader-ca
HOST=export.high.ctxd
GWH=gitwh.ops.ctxd

mkdir -p ${CONFIG}/certs/gitwh
cp -f ${CERTS}/${ROOT_CA}/${INTER_CA}/${READER_CA}/${HOST}/${HOST}.crt\
      ${CERTS}/${ROOT_CA}/${INTER_CA}/${READER_CA}/${HOST}/${HOST}.pem\
      ${CERTS}/${ROOT_CA}/${INTER_CA}/${GWH}/${GWH}.bundle.crt\
      ${CONFIG}/certs/gitwh

find ${CONFIG} -type d -exec chmod o+rx {} \;
find ${CONFIG} -type f -exec chmod o+r {} \;

# #########################
# 
# PKI for Ops Status /Alert MM
#
# #########################
echo "Ops:Status/Alerts ..."

#
# Status High Import to write to it and the Console to read from it
#
CONFIG=volumes/ops/status/certs
CERTS=./PKI/ops/certs
ROOT_CA=ctxd-ops-root-ca
INTER_CA=ctxd-ops-intermediate-ca
S_WRITER_CA=ctxd-ops-status-writer-ca
S_READER_CA=ctxd-ops-status-reader-ca
S_HOST=status.ops.ctxd
A_WRITER_CA=ctxd-ops-alerts-writer-ca
A_HOST=alerts.ops.ctxd

mkdir -p ${CONFIG}/status
cp -f ${CERTS}/${ROOT_CA}/${INTER_CA}/${S_WRITER_CA}/${S_WRITER_CA}.bundle.crt \
      ${CERTS}/${ROOT_CA}/${INTER_CA}/${S_READER_CA}/${S_READER_CA}.bundle.crt \
      ${CERTS}/${ROOT_CA}/${INTER_CA}/${S_HOST}/${S_HOST}.crt \
      ${CERTS}/${ROOT_CA}/${INTER_CA}/${S_HOST}/${S_HOST}.pem \
      ${CONFIG}/status

mkdir -p ${CONFIG}/alerts
cp -f ${CERTS}/${ROOT_CA}/${INTER_CA}/${A_WRITER_CA}/${A_WRITER_CA}.bundle.crt \
      ${CERTS}/${ROOT_CA}/${INTER_CA}/${A_HOST}/${A_HOST}.crt \
      ${CERTS}/${ROOT_CA}/${INTER_CA}/${A_HOST}/${A_HOST}.pem \
      ${CONFIG}/alerts

find ${CONFIG} -type d -exec chmod o+rx {} \;
find ${CONFIG} -type f -exec chmod o+r {} \;

# #########################
# 
# PKI for Ops GitWebHook|
#
# #########################

#
# Allows High Export to read from it and the Console to write to it
#
echo "Ops:GitWebHook ..."
CONFIG=volumes/ops/status/certs
CERTS=./PKI/ops/certs
ROOT_CA=ctxd-ops-root-ca
INTER_CA=ctxd-ops-intermediate-ca
WRITER_CA=ctxd-ops-gitwh-writer-ca
READER_CA=ctxd-ops-gitwh-reader-ca
HOST=gitwh.ops.ctxd


mkdir -p ${CONFIG}/gitwh
cp -f ${CERTS}/${ROOT_CA}/${INTER_CA}/${WRITER_CA}/${WRITER_CA}.bundle.crt \
   -f ${CERTS}/${ROOT_CA}/${INTER_CA}/${READER_CA}/${READER_CA}.bundle.crt \
   -f ${CERTS}/${ROOT_CA}/${INTER_CA}/${HOST}/${HOST}.crt \
   -f ${CERTS}/${ROOT_CA}/${INTER_CA}/${HOST}/${HOST}.pem \
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
U_CERTS=./PKI/users/certs
U_ROOT_CA=ctxd-users-root-ca
U_ADMINS_CA=ctxd-users-admins-ca

# Status PKI
S_CERTS=./PKI/ops/certs
S_ROOT_CA=ctxd-ops-root-ca
S_INTER_CA=ctxd-ops-intermediate-ca
S_READER_CA=ctxd-ops-status-reader-ca
HOST=console.ops.ctxd 
STATUS=status.ops.ctxd

# Alerts PKI
A_CERTS=./PKI/ops/certs
A_ROOT_CA=ctxd-ops-root-ca
A_INTER_CA=ctxd-ops-intermediate-ca
A_WRITER_CA=ctxd-ops-alerts-writer-ca
HOST=console.ops.ctxd 
ALERTS=alerts.ops.ctxd 

# Git Webhook PKI
G_CERTS=./PKI/ops/certs
G_ROOT_CA=ctxd-ops-root-ca
G_INTER_CA=ctxd-ops-intermediate-ca
G_WRITER_CA=ctxd-ops-gitwh-writer-ca
GWH=gitwh.ops.ctxd

# Get the list of users
USERS=""
DIR=${U_CERTS}/${U_ROOT_CA}/${U_ADMINS_CA}
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

    CONFIG=volumes/ops/console/${USER}
    
    if [[ ! -d ${CONFIG} ]]; then
        mkdir -p ${CONFIG}
    fi
    cp -ru templates/ops/console/* ${CONFIG}
    sed -i -e "s/<USERNAME>/${USER}/" ${CONFIG}/user.sfjs
    
    CONFIG=${CONFIG}/certs
    if [[ ! -d $CONFIG ]]; then
        mkdir -p ${CONFIG}
    fi

    # Keys and certs used for Sigining
    CRYPTO=GroupCrypto
    mkdir -p ${CONFIG}/signing
    cp -f ${U_CERTS}/${U_ROOT_CA}/${U_ADMINS_CA}/${USER}/${USER}.crt \
          ${U_CERTS}/${U_ROOT_CA}/${U_ADMINS_CA}/${USER}/${USER}.pem \
          ${U_CERTS}/${U_ROOT_CA}/${U_ADMINS_CA}/${CRYPTO}/${CRYPTO}.ecdh.pem \
          ${U_CERTS}/${U_ROOT_CA}/${U_ADMINS_CA}/${CRYPTO}/${CRYPTO}.ecdh.pub.pem \
          ${CONFIG}/signing

    # Keys and certs used to access the local git webhook server
    mkdir -p ${CONFIG}/gitWebHook
    cp -f ${G_CERTS}/${G_ROOT_CA}/${G_INTER_CA}/${G_WRITER_CA}/${HOST}/${HOST}.crt \
          ${G_CERTS}/${G_ROOT_CA}/${G_INTER_CA}/${G_WRITER_CA}/${HOST}/${HOST}.pem \
          ${G_CERTS}/${G_ROOT_CA}/${G_INTER_CA}/${GWH}/${GWH}.bundle.crt \
          ${CONFIG}/gitWebHook
    

    # Keys and certs used to access the Status MM
    mkdir -p ${CONFIG}/status
    cp -f ${S_CERTS}/${S_ROOT_CA}/${S_INTER_CA}/${S_READER_CA}/${HOST}/${HOST}.crt \
          ${S_CERTS}/${S_ROOT_CA}/${S_INTER_CA}/${S_READER_CA}/${HOST}/${HOST}.pem \
          ${S_CERTS}/${S_ROOT_CA}/${S_INTER_CA}/${STATUS}/${STATUS}.bundle.crt \
          ${CONFIG}/status
    
    # Keys and certs used to access the Alerts MM
    mkdir -p ${CONFIG}/alerts
    cp -f ${A_CERTS}/${A_ROOT_CA}/${A_INTER_CA}/${A_WRITER_CA}/${HOST}/${HOST}.crt \
          ${A_CERTS}/${A_ROOT_CA}/${A_INTER_CA}/${A_WRITER_CA}/${HOST}/${HOST}.pem \
          ${A_CERTS}/${A_ROOT_CA}/${A_INTER_CA}/${ALERTS}/${ALERTS}.bundle.crt \
          ${CONFIG}/alerts
    
    find ${CONFIG} -type d -exec chmod o+rx {} \;
    find ${CONFIG} -type f -exec chmod o+r {} \;

done

#
# Done
#
echo
echo "Config Generated"
echo
echo "Remember to update the Git configuration in:"
echo "  volumes/high/export/git.sfjs"
for USER in $USERS; do
    echo "  volumes/ops/console/${USER}/git.sfjs"
done

echo
echo "Remember to create the following files."
echo "  secrets/high/git"
echo "  secrets/high/slack (optional)"
for USER in $USERS; do
    echo "  secrets/ops/console/${USER}/password"
    echo "  secrets/ops/console/${USER}/git"
done



