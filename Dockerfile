FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        binutils \
        gcc \
        libc6-dev \
        make \
        time \
        util-linux \
        valgrind \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["bash"]
