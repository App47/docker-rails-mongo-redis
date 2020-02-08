FROM ubuntu:bionic

# Allow build-time overrides (eg. to build image with MongoDB Enterprise version)
# Options for MONGO_PACKAGE: mongodb-org OR mongodb-enterprise
# Options for MONGO_REPO: repo.mongodb.org OR repo.mongodb.com
# Example: docker build --build-arg MONGO_PACKAGE=mongodb-enterprise --build-arg MONGO_REPO=repo.mongodb.com .
ARG MONGO_PACKAGE=mongodb-org
ARG MONGO_REPO=repo.mongodb.org

ENV RUBY_MAJOR=2.4 \
    RUBY_VERSION=2.4.1 \
    RUBY_DOWNLOAD_SHA256=25da31b9815bfa9bba9f9b793c055a40a35c43c6adfb1fdbd81a09099f9b529c \
    RUBYGEMS_VERSION=3.0.3 \
    BUNDLE_SILENCE_ROOT_WARNING=1 \
    GOSU_VERSION=1.11 \
    REDIS_VERSION=5.0.5 \
    REDIS_DOWNLOAD_URL=http://download.redis.io/releases/redis-5.0.5.tar.gz \
    REDIS_DOWNLOAD_SHA=2139009799d21d8ff94fc40b7f36ac46699b9e1254086299f8d3b223ca54a375 \
    JSYAML_VERSION=3.13.0 \
    GPG_KEYS=0C49F3730359A14518585931BC711F9BA15703C6 \
    MONGO_MAJOR=4.0 \
    MONGO_VERSION=4.0.12
ENV MONGO_PACKAGE=${MONGO_PACKAGE} \
    MONGO_REPO=${MONGO_REPO} 
    

#
# Dependencies
#

RUN set -eux; \
    mkdir -p /usr/local/etc; \
	{ \
		echo 'install: --no-document'; \
		echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc; \
    ln -fs /usr/share/zoneinfo/UCT /etc/localtime; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
                autoconf \
                automake \
                bison \
                build-essential \
                ca-certificates \
                curl \
                dpkg-dev \
                g++ \
                gcc \
                git \
                gnupg2 \
                gzip \
                jq \
                libreadline-dev \
                libc6-dev \
                libcurl3-dev \
                libfftw3-double3 \
                libffi-dev \
                libgdbm-dev \
                libgmp3-dev \
                libgmp-dev \
                libgsl0-dev \
                libgtkmm-3.0.1 \
                libncurses5-dev \
                libpq-dev \
                libnotify4 \
                libssl-dev \
                libtool \
                libyaml-dev \
                make \
                nodejs \
                numactl \
                pkg-config \
                software-properties-common \
                ssh \
	            tar \
                tcl8.5 \
                unzip \
	            wget \
                zip \
                zlib1g-dev; \
    if ! command -v ps > /dev/null; then \
        apt-get install -y --no-install-recommends procps; \
    fi; \
    if ! command -v gpg > /dev/null; then \
        apt-get install -y --no-install-recommends gnupg2 dirmngr; \
    elif gpg --version | grep -q '^gpg (GnuPG) 1\.'; then \
        apt-get install -y --no-install-recommends gnupg-curl; \
    fi; \
    rm -rf /var/lib/apt/lists/*;

#
# Ruby
#
RUN set -eux; \
    gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB; \
    curl -sSL https://get.rvm.io -o /tmp/rvm.sh; \
    cat /tmp/rvm.sh; \
    cat /tmp/rvm.sh | bash -s stable; 
RUN /bin/bash -l -c "rvm install 2.4.1" 
RUN /bin/bash -l -c "rvm use 2.4.1 --default"
RUN /bin/bash -l -c "gem install bundler"

#
# Gosu
#

RUN savedAptMark="$(apt-mark showmanual)"; \
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
    wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
    wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
    command -v gpgconf && gpgconf --kill all || :; \
    rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
    chmod +x /usr/local/bin/gosu; \
    gosu nobody true;

#
# Redis
# https://github.com/docker-library/redis/blob/master/5.0
#

RUN groupadd -r -g 999 redis && useradd -r -g redis -u 999 redis; \
    wget -O redis.tar.gz "$REDIS_DOWNLOAD_URL"; \
    echo "$REDIS_DOWNLOAD_SHA *redis.tar.gz" | sha256sum -c -; \
    mkdir -p /usr/src/redis; \
    tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1; \
    rm redis.tar.gz; \
# disable Redis protected mode [1] as it is unnecessary in context of Docker
# (ports are not automatically exposed when running inside Docker, but rather explicitly by specifying -p / -P)
# [1]: https://github.com/antirez/redis/commit/edd4d555df57dc84265fdfb4ef59a4678832f6da
    grep -q '^#define CONFIG_DEFAULT_PROTECTED_MODE 1$' /usr/src/redis/src/server.h; \
    sed -ri 's!^(#define CONFIG_DEFAULT_PROTECTED_MODE) 1$!\1 0!' /usr/src/redis/src/server.h; \
    grep -q '^#define CONFIG_DEFAULT_PROTECTED_MODE 0$' /usr/src/redis/src/server.h; \
# for future reference, we modify this directly in the source instead of just supplying a default configuration flag because apparently "if you specify any argument to redis-server, [it assumes] you are going to specify everything"
# see also https://github.com/docker-library/redis/issues/4#issuecomment-50780840
# (more exactly, this makes sure the default behavior of "save on SIGTERM" stays functional by default)
    make -C /usr/src/redis -j "$(nproc)"; \
    make -C /usr/src/redis install; \
# TODO https://github.com/antirez/redis/pull/3494 (deduplicate "redis-server" copies)
    serverMd5="$(md5sum /usr/local/bin/redis-server | cut -d' ' -f1)"; export serverMd5; \
    find /usr/local/bin/redis* -maxdepth 0 \
         -type f -not -name redis-server \
         -exec sh -eux -c ' \
             md5="$(md5sum "$1" | cut -d" " -f1)"; \
             test "$md5" = "$serverMd5"; \
         ' -- '{}' ';' \
         -exec ln -svfT 'redis-server' '{}' ';' \
    ; \
    rm -r /usr/src/redis; \
    mkdir /data && chown redis:redis /data;

VOLUME /data 

#
# Mongo
# https://github.com/docker-library/mongo/blob/master/3.0
#

RUN set -eux; \
    groupadd -r mongodb && useradd -r -g mongodb mongodb; \
    wget -O /js-yaml.js "https://github.com/nodeca/js-yaml/raw/${JSYAML_VERSION}/dist/js-yaml.js"; \
    mkdir /docker-entrypoint-initdb.d; \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 68818C72E52529D4; \
    echo "deb http://$MONGO_REPO/apt/ubuntu bionic/mongodb-org/$MONGO_MAJOR multiverse" | tee "/etc/apt/sources.list.d/$MONGO_PACKAGE.list"; \
    apt-get update; \
    apt-get install -y \
        mongodb-org \
        build-essential \
        python-dev; \
    rm -rf /var/lib/apt/lists/*; \
    rm -rf /var/lib/mongodb; \
    mv /etc/mongod.conf /etc/mongod.conf.orig; \
    mkdir -p /data/db /data/configdb; \
    chown -R mongodb:mongodb /data/db /data/configdb;

VOLUME /data/db /data/configdb

#
# App specific
#

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh /entrypoint.sh; \
    mkdir /app; \
    mongod --version; \
    redis-server --version; \
    ruby --version; \
    gem --version; \
    bundle --version; \
    git --version; \
    ssh -V; \
    tar --version; \
    gzip --version;
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 27017
EXPOSE 6379

WORKDIR /app