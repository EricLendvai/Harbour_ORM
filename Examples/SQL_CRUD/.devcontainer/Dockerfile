#To take advantage of Docker caching, we are using the same instructions as other .devcontainer/Dockerfile until the "RUN ldconfig"
FROM ubuntu:22.04

## for apt to be noninteractive
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true

# Used by running apps to detect if inside a docker container. Testing for existence of /.dockerenv may not always work.
ENV InDocker=True

RUN apt-get update && apt-get install -y apt-utils

# Run update again to work around git install failure introduced around April 2023
RUN apt-get update

RUN apt-get install -y \
        libfcgi-dev \
        libapache2-mod-fcgid \
        git \
        build-essential \
        unixodbc-dev \
        apache2 \
        libapache2-mod-fcgid \
        libgpm2 \
        gnupg \
        wget \
        psmisc \
        libcurl4-openssl-dev

# Install Python 3.11 from Deadsnakes PPA
RUN apt-get update && apt-get install -y software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y \
        python3.11 \
        python3.11-dev \
        python3.11-venv \
        python3.11-distutils \
        curl \
        ca-certificates

# Install pip for Python 3.11
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11

# Optionally set python3 → python3.11
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --set python3 /usr/bin/python3.11 && \
    ln -s /usr/local/bin/pip3 /usr/bin/pip || true

# install harbour from src
RUN mkdir /src
WORKDIR /src
RUN git clone --branch master https://github.com/harbour/core.git harbour
WORKDIR /src/harbour
ENV HB_WITH_CURL=/usr/include/x86_64-linux-gnu/
# Will request the make app to use up to 8 core.
RUN make -j 8 install

#To fix symlinks
RUN ldconfig

#Fake command to force not using a cache from this point on.
#ARG CACHEBUST=9

# install Postgresql odbc
RUN apt-get -y install odbc-postgresql
