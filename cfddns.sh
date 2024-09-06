#!/bin/bash

################################################################
#                         CONFIGURATION                        #
################################################################

ZONE_ID="CHANGE_ME"
ACCOUNT_ID="CHANGE_ME"
API_KEY="CHANGE_ME"

# The domain which you want to update
DOMAIN="CHANGE_ME"

# The DNS used to retrieve the current A record associated to the $DOMAIN
RESOLVER="1.1.1.1"

# The website used to retrieve the current pubblic IP
IPRETREIVER="ipinfo.io/ip"
# If you change the IPRETREIVER variable, make sure that curl will output only an IP.
# You might have to do some text manipulation to do that, depending which provider you use.

# If set to 0 there will not be any logging (previously created logs will be kept)
LOGGING=1

# If set to 1 there will not be any text output
SILENT=0




################################################################
#                           FUNCTIONS                          #
################################################################

create_log() {
    [ ! -f ./cfddns.log ] && touch cfddns.log && chmod 440 cfddns.log
}

logger() {
    if [ "$LOGGING" -eq 0 ]; then
        if [ "$SILENT" -eq 0 ]; then
            # LOGGING 0 SILENT 0
            echo "$@"
        else
            # LOGGIN 0 SILENT 1
            :
        fi

    else
        create_log
        if [ "$SILENT" -eq 0 ]; then
            # LOGGING 1 SILENT 0
            echo "cfddns.sh: $1"
            echo -e "$(date --rfc-email) \t $@" >> cfddns.log
        else
            # LOGGING 1 SILENT 1
            echo -e "$(date --rfc-email) \t $@" >> cfddns.log
        fi
    fi
}




################################################################
#                             SCRIPT                           #
################################################################

IPREGEX='(^([1-9]|[1-9][0-9]|[1][0-9][0-9]|[2][0-4][0-9]|[2][5][0-5])\.([0-9]|[1-9][0-9]|[1][0-9][0-9]|[2][0-4][0-9]|[2][5][0-5])\.([0-9]|[1-9][0-9]|[1][0-9][0-9]|[2][0-4][0-9]|[2][5][0-5])\.([0-9]|[1-9][0-9]|[1][0-9][0-9]|[2][0-4][0-9]|[2][5][0-5]))$'

# Get the dns record id from response
DNS_RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$DOMAIN" -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" | grep -o '"id":"[^"]*' | cut -d'"' -f4)

# Get the public IP
PUBLIC_IP=$(curl -s "$IPRETREIVER")
if [[ ! $PUBLIC_IP =~ ^$IPREGEX ]]; then
    logger "Error, problems retreiving your public IP using $IPRETREIVER"
    exit 0
fi

# Get the current IP associated with $DOMAIN
CURRENT_IP=$(dig +short @"$RESOLVER" "$DOMAIN" 2>/dev/null)
if [[ ! $CURRENT_IP =~ ^$IPREGEX ]]; then
    logger "Error, problems retreiving your current IP from A record using $RESOLVER"
    exit 1
fi

# Send PUT request to cloudflare API if the IPs do not match
if [ "$CURRENT_IP" != "$PUBLIC_IP" ]; then
    dns_update_request=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DNS_RECORD_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        --data "{\"comment\":\"Updated with CFDDNS.sh\",\"type\":\"A\",\"name\":\"$DOMAIN\",\"proxied\":false,\"content\":\"$PUBLIC_IP\",\"ttl\":1}")
else
    logger "The IP is still the same, no need to update. Quitting..."
    exit 0
fi

if [[ ${dns_update_request} == *"\"success\":false"* ]]; then
    logger "Error, failed to update the DNS record!"
    exit 1
else
    logger "DNS record updated correctly!"
fi
