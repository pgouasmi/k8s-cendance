#!/bin/bash

# generate_docker_config() {
#     local auth=$(printf "%s:%s" "$GITLAB_USERNAME" "$GITLAB_TOKEN" | base64)
#     printf '{
#         "auths": {
#             "registry.gitlab.com": {
#                 "username": "%s",
#                 "password": "%s",
#                 "email": "%s",
#                 "auth": "%s"
#             }
#         }
#     }' "$GITLAB_USERNAME" "$GITLAB_TOKEN" "$GITLAB_EMAIL" "$auth"
# }

# generate_docker_config | base64 | tr -d '\n'

echo "Generating SSL secrets..."

# Vérifions que les fichiers SSL existent
if [ ! -f "ssl/certificate.crt" ] || [ ! -f "ssl/private.key" ]; then
    echo "Error: SSL certificate files not found in ssl/ directory"
    exit 1
fi

# Encodage des fichiers SSL en base64
SSL_CERTIFICATE=$(base64 -w 0 ssl/certificate.crt)
SSL_PRIVATE_KEY=$(base64 -w 0 ssl/private.key)

# Création du fichier de secret SSL à partir du template
cat ssl-secret.yml | \
    sed "s|\${SSL_CERTIFICATE}|${SSL_CERTIFICATE}|g" | \
    sed "s|\${SSL_PRIVATE_KEY}|${SSL_PRIVATE_KEY}|g" \
    > ssl-secret.generated.yaml

echo "SSL secrets generated successfully"