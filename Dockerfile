FROM nginx:1.23.2-alpine AS builder

ARG FANCYINDEX_VERSION=0.5.2
ARG FANCYINDEX_URL="https://github.com/aperezdc/ngx-fancyindex"
# NGINX_VERSION is exposed by nginx:alpine

# For latest build deps, see https://github.com/nginxinc/docker-nginx/blob/master/mainline/alpine/Dockerfile
RUN apk add --no-cache --virtual .build-deps \
    gcc \
    libc-dev \
    make \
    openssl-dev \
    pcre-dev \
    zlib-dev \
    linux-headers \
    curl \
    gnupg \
    libxslt-dev \
    gd-dev \
    geoip-dev

# Download sources
RUN wget "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -O nginx.tar.gz && \
    wget "${FANCYINDEX_URL}/archive/refs/tags/v${FANCYINDEX_VERSION}.tar.gz" -O nginx-fancyindex.tar.gz

# Reuse same cli arguments as the nginx:alpine image used to build
RUN CONFARGS=$(nginx -V 2>&1 | sed -n -e "s/^.*arguments: //p") \
    && CONFARGS=${CONFARGS/-Os -fomit-frame-pointer -g/-Os} \
    && FANCYINDEX_DIR="$(pwd)/ngx-fancyindex-${FANCYINDEX_VERSION}" \
    && CONFIG="\
        --with-compat $CONFARGS \
        --with-http_addition_module \
        --add-dynamic-module=$FANCYINDEX_DIR \
    " \
    && mkdir -p /usr/src \
    && tar -zxC /usr/src -f nginx.tar.gz \
    && tar -xzvf nginx-fancyindex.tar.gz \
    && rm -f nginx.tar.gz nginx-fancyindex.tar.gz \
    && cd /usr/src/nginx-$NGINX_VERSION \
    && ./configure $CONFIG \
    && make && make install

FROM nginx:1.23.2-alpine

LABEL maintainer="y0nei <y0nei@proton.me>"

# Extract the dynamic module from the builder image
COPY --from=builder /usr/lib/nginx/modules/ngx_http_fancyindex_module.so /usr/lib/nginx/modules/ngx_http_fancyindex_module.so

# Copy new nginx binary if needed, due to patching for other modules
# COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx

RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/nginx.conf

STOPSIGNAL SIGQUIT
