#!/bin/bash

# Define your variables
echo "Note: Please make sure CA_Bundle.crt contains the intermediate and root certificates before generating the PFX certificate."
echo "CA_Bundle contains the required certificates? (y/n)"
read CONFIRM
if [[ "${CONFIRM,,}" != "y" ]]; then
    exit 0
fi

echo "Enter Your Domain Name:"
read DOMAIN

YEAR=$(date +%Y)
TODAY=$(date +%Y-%m-%d)

CERTS_PATH="/etc/ssl/certs/SSL/$DOMAIN/$YEAR/$TODAY/"
KEY_FILE="${CERTS_PATH}${DOMAIN}.key"
CERT_FILE="${CERTS_PATH}${DOMAIN}.crt"
CA_BUNDLE_FILE="${CERTS_PATH}CA_Bundle.crt"
PFX_FILE="${CERTS_PATH}${DOMAIN}.pfx"
PASSWORD_FILE="${CERTS_PATH}${DOMAIN}_pfx_pass.txt"
ZIP_FILE="/tmp/${DOMAIN}_certs.zip"
EMAIL_ADDRESS="jamal.hossain@apsissolutions.com"

# Check if the key, certificate, and CA bundle files exist
missing_file=""

if [ ! -f "$KEY_FILE" ]; then
    missing_file="$missing_file $KEY_FILE"
fi

if [ ! -f "$CERT_FILE" ]; then
    missing_file="$missing_file $CERT_FILE"
fi

if [ ! -f "$CA_BUNDLE_FILE" ]; then
    missing_file="$missing_file $CA_BUNDLE_FILE"
fi

if [ -n "$missing_file" ]; then
    echo "One or more of the required files do not exist:$missing_file. Please make sure all files are available."
    exit 1
fi

# Generate a random password
PASSWORD=$(openssl rand -base64 12)

# Save the password to a file
echo "$PASSWORD" > "$PASSWORD_FILE"

# Use 'expect' to automate the password entry
expect << EOF
spawn openssl pkcs12 -export -out "$PFX_FILE" -inkey "$KEY_FILE" -in "$CERT_FILE" -certfile "$CA_BUNDLE_FILE"
expect "Enter Export Password:"
send "$PASSWORD\r"
expect "Verifying - Enter Export Password:"
send "$PASSWORD\r"
expect eof
EOF

if [ $? -eq 0 ]; then
    echo "PKCS12 certificate ($PFX_FILE) has been generated successfully."
    echo "Password has been saved in $PASSWORD_FILE."
else
    echo "Failed to generate PKCS12 certificate. Please check your files and try again."
    rm -f "$PASSWORD_FILE"
    exit 1
fi

echo "Do you want to send the certificates as an email attachment? (y/n)"
read CONFIRM
if [[ "${CONFIRM,,}" != "y" ]]; then 
    exit 0
fi 

# Create a zip file
zip -r "$ZIP_FILE" "$CERTS_PATH"

# Check if zip file creation is successful
if [ $? -eq 0 ]; then
    # Send email with the zip file as an attachment
    echo "Certificate files attached." | mutt -s "Certificate Files for $DOMAIN" -a "$ZIP_FILE" -- "$EMAIL_ADDRESS"
    MAIL_RESULT=$?

    # Check if the email sending was successful
    if [ $MAIL_RESULT -eq 0 ]; then
        echo "Email sent successfully."
    else
        echo "Failed to send email. Please check your mail configuration. (Exit code: $MAIL_RESULT)"
    fi
else
    echo "Failed to create zip file. Please check your directory and file permissions."
fi

# Remove the temporary zip file
rm -f "$ZIP_FILE"
