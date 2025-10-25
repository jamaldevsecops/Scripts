#!/bin/bash

# Set your domain name
#DOMAIN="yourdomain.com"
echo "Enter Your Domain Name:"
read DOMAIN

# Print the domain to verify which domain you are working on
echo "Working with domain: $DOMAIN"

# Set the directory path
YEAR=$(date +%Y)
TODAY=$(date +%Y-%m-%d)
DOMAIN_DIR="/etc/ssl/certs/SSL/$DOMAIN/$YEAR/$TODAY"

# Create the directory if it doesn't exist
if [ ! -d "$DOMAIN_DIR" ]; then
  mkdir -p "$DOMAIN_DIR"
fi

# Prompt the user to choose the type of SSL certificate
echo "Choose the type of SSL certificate:"
echo "1. Single SSL certificate (www.example.com)"
echo "2. Sub-domain of a Domain (subdomain.rootdoamin.com)"
echo "3. Wildcard SSL certificate (*.example.com)"
read -p "Enter your choice (1 or 2): " CERT_TYPE

# Check the user's choice and set the COMMON_NAME accordingly
if [ "$CERT_TYPE" == "1" ]; then
  COMMON_NAME="www.$DOMAIN"
elif [ "$CERT_TYPE" == "2" ]; then
  COMMON_NAME="$DOMAIN"
elif [ "$CERT_TYPE" == "3" ]; then
  COMMON_NAME="*.$DOMAIN"
else
  echo "Invalid choice. Exiting."
  exit 1
fi

# Subject information
COUNTRY="BD"
STATE="BD"
CITY="Dhaka"
ORGANIZATION="Dhaka"
ORG_UNIT="Apsis Solutions Ltd"
EMAIL="infra@apsissolutions.com"

# Set CSR and private key file paths within the domain directory
CSR_PATH="$DOMAIN_DIR/${DOMAIN}.csr"
KEY_PATH="$DOMAIN_DIR/${DOMAIN}.key"

# Generate the CSR with subject information
openssl req -new -newkey rsa:2048 -nodes -keyout "$KEY_PATH" -out "$CSR_PATH" -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=$ORG_UNIT/CN=$COMMON_NAME/emailAddress=$EMAIL"

# Check the exit status of the openssl command
if [ $? -eq 0 ]; then
  echo "CSR and private key have been generated."
  echo "CSR: $CSR_PATH"
  echo "Private Key: $KEY_PATH"
else
  echo "Failed to generate CSR and private key."
fi

# CSR Decoder to decode your Certificate Signing Request
echo "Do you want to decode your CSR? (y/n): " 
read decode

if [ "$decode" == "y" ]; then
  openssl req -in $CSR_PATH -noout -text
else
  echo "Exiting the decoder, thank you.Bye......."
  exit 1
fi

