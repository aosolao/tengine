FROM alpine:3.15.0 as builder
LABEL maintainer laihh

#定义环境变量
ENV TENGINE_VERSION=2.3.3

#定义编译参数
ENV CONFIG "\
            --user=www \
            --group=www \
            --with-http_secure_link_module \
            --with-http_image_filter_module \
            --with-http_random_index_module \
            --with-threads \
            --with-http_ssl_module \
            --with-http_sub_module \
            --with-http_stub_status_module \
            --with-http_gunzip_module \
            --with-http_gzip_static_module \
            --with-http_realip_module \
            --with-compat \
            --with-file-aio \
            --with-http_dav_module \
            --with-http_degradation_module \
            --with-http_flv_module \
            --with-http_mp4_module \
            --with-http_xslt_module \
            --with-http_auth_request_module \
            --with-http_addition_module \
            --with-http_v2_module \
            --add-module=./modules/ngx_http_upstream_check_module \
            --add-module=./modules/ngx_http_upstream_session_sticky_module \
            --add-module=./modules/ngx_http_upstream_dynamic_module \
            --add-module=./modules/ngx_http_upstream_consistent_hash_module \
            --add-module=./modules/ngx_http_upstream_dyups_module \
            --add-module=./modules/ngx_http_user_agent_module \
            --add-module=./modules/ngx_http_proxy_connect_module \
            --add-module=./modules/ngx_http_concat_module \
            --add-module=./modules/ngx_http_footer_filter_module \
            --add-module=./modules/ngx_http_sysguard_module \
            --add-module=./modules/ngx_http_slice_module \
            --add-module=../nginx_cookie_flag_module-1.1.0 \
            --with-http_geoip_module=dynamic \
            --prefix=/service/nginx/ \
            --sbin-path=/usr/sbin/nginx \
            --modules-path=/usr/lib64/nginx/modules \
            --conf-path=/service/nginx/nginx.conf \
            --http-log-path=/var/log/nginx/access.log \
            --error-log-path=/var/log/nginx/error.log \
            --pid-path=/var/run/nginx.pid \
            --lock-path=/var/run/nginx.lock \
            --http-client-body-temp-path=/var/cache/nginx/client_temp \
            --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
            --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
            --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
            --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        "
COPY  repositories /etc/apk/repositories
#编译安装
RUN \
    mkdir -p /usr/src \
    && cd /usr/src \
    && apk add --no-cache --virtual .build-deps \
        gcc \
        geoip \
        geoip-dev \
        libxslt-dev \
        libxml2-dev \
        gd-dev \
        libc-dev \
        make \
        openssl-dev \
        pcre-dev \
        zlib-dev \
        linux-headers \
        curl \
        wget \
        unzip \
        g++ \
        file \
        perl \
        pcre \
        binutils \
    && wget https://github.com/AirisX/nginx_cookie_flag_module/archive/v1.1.0.tar.gz \
    && tar zxf v1.1.0.tar.gz \
    && curl "https://tengine.taobao.org/download/tengine-$TENGINE_VERSION.tar.gz" -o tengine.tar.gz \
    && tar zxf tengine.tar.gz \
    && cd tengine-$TENGINE_VERSION \
    && ./configure $CONFIG \
    && make \
    && make install \
    && rm -f /service/nginx/html/* /service/nginx/*.default \
    && strip /usr/sbin/nginx

#===== 多阶段构建 ==========================

FROM alpine:3.15.0
ENV TENGINE_VERSION=2.3.3
ENV WWW_ROOT=/service/webindex/
ENV LANG="en_US.UTF-8"
ENV GLIBC_PKG_VERSION=2.24-r0
COPY  repositories /etc/apk/repositories


COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /service/nginx /service/nginx
COPY --from=builder /usr/lib64/nginx /usr/lib64/nginx

RUN \
    apk add --no-cache \
    unzip \
    curl \
    wget \
    vim \
    htop \
    zip \
    bzip2 \
    bash   


RUN \
    addgroup -S www \
    && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G www www \
    && mkdir -p ${WWW_ROOT}/demo/ /var/log/nginx /var/cache/nginx \
    && runDeps="$( \
        scanelf --needed --nobanner /usr/sbin/nginx \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
        )" \
    && apk add --no-cache --virtual .nginx-rundeps $runDeps gd libxslt geoip pcre\
    && apk add --no-cache gettext curl vim bash ca-certificates\
    \
    #设置中国时区
    && apk add --no-cache tzdata \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    \
    #安装中文字体库
    && mkdir -p /usr/src \
    && cd /usr/src \
    && curl -Lo /etc/apk/keys/sgerrand.rsa.pub "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_PKG_VERSION}/sgerrand.rsa.pub" \
    && curl -Lo glibc-${GLIBC_PKG_VERSION}.apk "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_PKG_VERSION}/glibc-${GLIBC_PKG_VERSION}.apk" \
    && curl -Lo glibc-bin-${GLIBC_PKG_VERSION}.apk "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_PKG_VERSION}/glibc-bin-${GLIBC_PKG_VERSION}.apk" \
    && curl -Lo glibc-i18n-${GLIBC_PKG_VERSION}.apk "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_PKG_VERSION}/glibc-i18n-${GLIBC_PKG_VERSION}.apk" \
    && apk add glibc-${GLIBC_PKG_VERSION}.apk glibc-bin-${GLIBC_PKG_VERSION}.apk glibc-i18n-${GLIBC_PKG_VERSION}.apk \
    && /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 "$LANG" || true \
    && echo "export LANG=$LANG" > /etc/profile.d/locale.sh \
    \
    #清理临时文件
    && rm -fr /usr/src /var/cache/apk/*

COPY nginx.conf /service/nginx/nginx.conf
CMD ["nginx", "-g", "daemon off;"]
