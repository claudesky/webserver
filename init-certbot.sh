#!/bin/bash

if ! [ -f "./.env" ]; then
  echo 'Error: no .env file found.' >&2
  exit 1
fi

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

# parse .env file using BASH
# https://gist.github.com/judy2k/7656bfe3b322d669ef75364a46327836#gistcomment-2786081
HOST_DOMAIN=$(grep HOST_DOMAIN .env | cut -d '=' -f 2-)
EMAIL_ADDRESS=$(grep EMAIL_ADDRESS .env | cut -d '=' -f 2-)
KEY_SIZE=$(grep KEY_SIZE .env | cut -d '=' -f 2-)

domains=(${HOST_DOMAIN})
rsa_key_size=${KEY_SIZE}
data_path="./certbot"
email="${EMAIL_ADDRESS}" # Adding a valid address is strongly recommended
staging=${FAKE_CERT} # Set to 1 if you're testing your setup to avoid hitting request limits

if [[ -d "$data_path/conf/live/$domains" ]]; then
  read -p "Existing data found for $domains. Continue and replace existing certificate? (y/N) " decision
  if [[ $decision != "Y" ]] && [[ $decision != "y" ]]; then
    exit
  fi
fi

echo "### Creating dummy certificate for $domains ..."
path="/etc/letsencrypt/live/$domains"
mkdir -p "$data_path/conf/live/$domains"
docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo

echo "### Starting nginx ..."
docker-compose up --force-recreate -d nginx
echo

echo "### Deleting dummy certificate for $domains ..."
docker-compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
echo


echo "### Requesting Let's Encrypt certificate for $domains ..."
#Join $domains to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Select appropriate email arg
case $email in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging mode if needed
if [[ $staging != "0" ]]; then staging_arg="--staging"; fi

docker-compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
echo

echo "### Reloading nginx ..."
docker-compose exec nginx nginx -s reload
echo

echo "### Starting certbot ..."
docker-compose up -d certbot
