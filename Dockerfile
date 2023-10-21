#syntax=docker/dockerfile:1.4
FROM alpine:3.16

RUN apk add bash curl gettext zip
RUN apk add terraform helm kubectl --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community
RUN apk add jq

# to manage helm and kubectl from source: see this https://github.com/alpine-docker/k8s/blob/5c0935e9b7c36e04e354977bb476709a594d8cc9/Dockerfile#L46

RUN adduser --disabled-password --home="/app" --uid 1717 nonroot
# RUN chown -R nonroot:nonroot /app
USER nonroot
WORKDIR /app
COPY --chown=nonroot ./terraform ./terraform
RUN mkdir infrastructure-templates
COPY --chown=nonroot ./infrastructure-templates ./infrastructure-templates
ENV TF_PLUGIN_CACHE_DIR="/app/.terraform.d/plugin-cache"
RUN mkdir -p $TF_PLUGIN_CACHE_DIR
# SHELL ["/bin/bash", "-c"]
# RUN cat > script.sh <<'EOF'
#   for dir in $(ls -d ./infrastructures/templates/*); do
#     pushd $dir
#     terraform init -backend=false
#     popd
#   done
#   tdir=$(basename $(dirname $TF_PLUGIN_CACHE_DIR))
#   zip terraform.zip -r $tdir && rm -rf $tdir
# EOF
RUN mkdir build-scripts
COPY ./build-scripts/terraform-module-cache.sh ./build-scripts/terraform-module-cache.sh
RUN bash build-scripts/terraform-module-cache.sh ./infrastructure-templates
ENV TERRAFORM_ZIPFILE="/app/terraform.zip"
ENV TEMPLATES_DIR="/app/infrastructure-templates"
