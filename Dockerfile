FROM ubuntu:focal

ENV RUBY_MAJOR=2.7 \
    RUBY_VERSION=2.7.0 \
    BUNDLE_SILENCE_ROOT_WARNING=1 \
    GOSU_VERSION=1.11 \
    GPG_KEYS=0C49F3730359A14518585931BC711F9BA15703C6 
    

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
                python-dev \
                software-properties-common \
                ssh \
	            tar \
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
# Java 8
#
RUN set -eux; \
    add-apt-repository ppa:openjdk-r/ppa; \            
    apt-get update; \
    apt-get install -y openjdk-8-jdk; 

#
# Ruby
#
RUN set -eux; \
    apt-get update; \
    apt-get install -y ruby-full;\
    gem install bundler;

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
# Dockerize
#
ENV DOCKERIZE_VERSION v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz;

#
# App specific
#

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh /entrypoint.sh; \
    mkdir /app; \
    ruby --version; \
    gem --version; \
    bundle --version; \
    git --version; \
    ssh -V; \
    tar --version; \
    gzip --version;
ENTRYPOINT ["docker-entrypoint.sh"]

WORKDIR /app
