#!/bin/bash
#
# Asks about the method of installation and produces a config file accordingly.
#
# By now we should have:
# - a working RHSSO instance
# - a realm called "sample"
# - a client called "sample-client"
#
RHBK_HOST_OCP=rhbk.apps.ocp4.example.com:443
RHBK_HOST_LOC=rhbk.lab.example.com:8444
RHBK_ADMIN_USER=admin
RHBK_ADMIN_PASS_LOC='rhbk'
RHBK_ADMIN_PASS_OCP=''

# Ask about the installation method.
echo "Please enter the type of installation you are using:"
select TYPE in "traditional service installation (local)" "operator-based installation (OpenShift)"; do
    if [ ${REPLY} -eq 1 ]; then
	RHBK_HOST="${RHBK_HOST_LOC}"
	RHBK_ADMIN_PASS="${RHBK_ADMIN_PASS_LOC}"
	break
    elif [ ${REPLY} -eq 2 ]; then
	RHBK_HOST="${RHBK_HOST_OCP}"
	RHBK_ADMIN_PASS="${RHBK_ADMIN_PASS_OCP}"
	break
    else
	echo "Incorrect response. Please try again."
    fi
done

echo "Thank you. Proceeding with settings for ${TYPE}."
echo

# If the installation method is OCP, try obtaining admin user's password.
if [ ${REPLY} -eq 2 ]; then
    echo -n " - attempting to obtain password for user \"admin\"... "
    oc login -u admin -p redhat https://api.ocp4.example.com:6443/ >/dev/null 2>&1
    if [ $? -ne 0 ]; then
	echo "ERROR: could not log into OpenShift."
	echo
	echo "Please make sure OCP cluster is in ready state by issuing \"ssh lab@utility ./wait.sh\", then re-run this script."
	exit 1
    fi
    RHBK_ADMIN_PASS="$(oc -n rhsso extract secrets/credential-rhsso --keys=ADMIN_PASSWORD --to=- 2>/dev/null)"
    if [ $? -ne 0 ]; then
	echo "ERROR: could not extract RHSSO admin password."
	echo
	echo "Please make sure a Keycloak resource exists in project \"rhsso\" and its deployment was successful, then re-run this script."
	exit 1
    fi
    echo OK
fi

# Make a test to see the master realm authenticates, and store the token.
echo -n " - obtaining access token for \"admin-cli\"... "
RSPNS=$(curl -ksf -XPOST -H "Content-Type: application/x-www-form-urlencoded" \
		-H "Accept: application/json" \
		-d "client_id=admin-cli&grant_type=password&username=${RHBK_ADMIN_USER}&password=${RHBK_ADMIN_PASS}" \
		https://${RHBK_HOST}/realms/master/protocol/openid-connect/token)
if [ $? -ne 0 ]; then
    echo "ERROR: Could not authenticate against \"master\" realm as user \"${RHBK_ADMIN_USER}\"."
    echo
    echo "Make sure the admin username is \"${RHBK_ADMIN_USER}\" and its password is \"${RHBK_ADMIN_PASS}\" and re-run this script."
    exit 1
fi

TOKEN=$(echo "${RSPNS}" | jq -r .access_token)
if [ $? -ne 0 ] || [ -z "${TOKEN}" ]; then
    echo "ERROR: Can not parse access token out of server response."
    echo
    echo "Server response was: ${RSPNS}"
    exit 1
fi
echo OK

# Make sure that the realm "sample" exists.
# echo -n " - checking for realm \"sample\"... "
# RSPNS="$(curl -ksf -XGET -H "Authorization: Bearer ${TOKEN}" \
# 		-H "Accept: application/json" \
# 		https://${RHBK_HOST}/auth/admin/realms/sample)"
# if [ $? -ne 0 ]; then
#     echo "ERROR: Server rejected query."
#     echo
#     echo "Server response was: ${RSPNS}"
#     exit 1
# fi
# if [ -z "$(echo "${RSPNS}" | jq .realm)" ]; then
#     echo "ERROR: Realm \"sample\" not found."
#     echo
#     echo "Make sure realm \"sample\" exists in \"${RHBK_HOST}\" and re-run this script."
#     exit 1
# fi
# echo OK

# # Make sure that the client "sample-client" exists.
# echo -n " - checking for client \"sample-client\"... "
# RSPNS="$(curl -ksf -XGET -H "Authorization: Bearer ${TOKEN}" \
# 		-H "Accept: application/json" \
# 		https://${RHBK_HOST}/auth/admin/realms/sample/clients)"
# if [ $? -ne 0 ]; then
#     echo "ERROR: Server rejected query."
#     echo
#     echo "Server response was: ${RSPNS}"
#     exit 1
# fi
# if [ -z "$(echo "${RSPNS}" | jq '.[] | select(.clientId == "sample-client") | .id')" ]; then
#     echo "ERROR: Client \"sample-client\" not found."
#     echo
#     echo "Make sure client \"sample-client\" exists in realm \"sample\" at \"${RHBK_HOST}\" and re-run this script."
#     exit 1
# fi
echo OK

echo
echo "Proceeding with these settings:"
echo " - RHBK_HOST       = ${RHBK_HOST}"
echo " - RHBK_ADMIN_USER = ${RHBK_ADMIN_USER}"
echo " - RHBK_ADMIN_PASS = ${RHBK_ADMIN_PASS}"
echo

cat > ${HOME}/rhbk.conf <<EOF
export RHBK_HOST="${RHBK_HOST}"
export RHBK_ADMIN_USER="${RHBK_ADMIN_USER}"
export RHBK_ADMIN_PASS="${RHBK_ADMIN_PASS}"
export KEYCLOAK_ADMIN="${RHBK_ADMIN_USER}"
export KEYCLOAK_ADMIN_PASSWORD="${RHBK_ADMIN_PASS}"
EOF

echo "Done, your configuration is now stored in ${HOME}/rhbk.conf!"
echo
echo "Any time you open a new terminal window, remember to load it like this:"
echo
echo "    source ${HOME}/rhbk.conf"
echo
echo "You can also add this line at the end of your .bashrc to make it automatic."
