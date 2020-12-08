FROM buildpack-deps:focal as builder
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y make automake autoconf libtool flex bison \
    pkg-config libssl-dev libxml2-dev python-dev libaio-dev \
    libibverbs-dev librdmacm-dev libreadline-dev liblvm2-dev \
    libglib2.0-dev liburcu-dev libcmocka-dev libsqlite3-dev \
    libacl1-dev ca-certificates curl libgssglue-dev libssl-dev \
    libnfs-dev doxygen lsb cmake gcc git cmake \
    libkrb5-dev gss-ntlmssp-dev libgss-dev libfuse-dev \
    libfuse3-dev librpcsecgss-dev libnfsidmap-dev libnfs-dev

RUN mkdir -p /build/gfs && \
    curl -sL "https://github.com/gluster/glusterfs/archive/v8.3.tar.gz" > /build/gfs/glusterfs.tar.gz && \
    cd /build/gfs && tar -xvzf glusterfs.tar.gz --strip-components=1 && rm glusterfs.tar.gz

WORKDIR /build
RUN cd gfs && ./autogen.sh && \
    mkdir -p /dist && ./configure --enable-gnfs && \
    make && \
    DESTDIR=/dist make install
RUN cp -r /dist/* / || true

RUN git clone --recurse-submodules --depth 1 --branch V3.3 "https://github.com/nfs-ganesha/nfs-ganesha.git"
RUN cd nfs-ganesha && \
    cmake src/ \
    -DUSE_FSAL_GLUSTER=ON \
    -DUSE_FSAL_XFS=OFF \
    -DUSE_FSAL_PROXY=OFF \
    -DUSE_FSAL_VFS=OFF \
    -DUSE_FSAL_CEPH=OFF \
    -DUSE_FSAL_GPFS=OFF \
    -DUSE_FSAL_LUSTRE=OFF \
    -DUSE_FSAL_PANFS=OFF \
    -DUSE_FSAL_NULL=OFF \
    -DUSE_FSAL_MEM=OFF \
    -DUSE_GUI_ADMIN_TOOLS=OFF && \
    make && DESTDIR=/dist make install

FROM homelabs/base:focal
#TODO delete cache
RUN apt-get update && apt-get install -y \
    libgssapi-krb5-2 && \
    rm -rf /var/lib/apt/lists/*
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
COPY --from=builder /dist/ /
COPY /rootfs/ /

ENTRYPOINT [ "/bin/bash" ]
