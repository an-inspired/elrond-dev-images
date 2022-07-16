# ===== FIRST STAGE ======
FROM ubuntu:20.04 as builder

RUN \
    apt-get update && \
    apt-get install -y \
        wget \
        git \
        python3.8 \
        python3.8-venv \
        python3-venv
RUN groupadd -r elrond && useradd --no-log-init --uid 1001 -m -g elrond elrond
USER elrond:elrond
WORKDIR /home/elrond
RUN wget -O erdpy-up.py https://raw.githubusercontent.com/ElrondNetwork/elrond-sdk-erdpy/master/erdpy-up.py
RUN python3.8 ~/erdpy-up.py
ENV PATH="/home/elrond/elrondsdk:${PATH}"
RUN erdpy deps install rust
RUN erdpy deps install nodejs
RUN erdpy deps install wasm-opt
RUN rm -rf ~/elrondsdk/*.tar.gz
RUN rm ~/erdpy-up.py

RUN git clone https://github.com/ElrondNetwork/elrond-config-testnet

# ===== SECOND STAGE ======
FROM ubuntu:20.04

# Increase the memory limit for VS Code
RUN echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf

RUN \
    apt-get update && \
    apt-get install -y \
        build-essential \
        git \
        curl \
        python3.8 \
        python3.8-venv \
        python3-venv -y

RUN groupadd -r elrond && useradd --no-log-init --uid 1001 -m -g elrond elrond
USER elrond:elrond
WORKDIR /home/elrond

COPY --from=builder --chown=elrond:elrond /home/elrond/elrondsdk /home/elrond/elrondsdk
ENV PATH="/home/elrond/elrondsdk:${PATH}"
ADD --chown=elrond:elrond testnet.toml .

RUN \
    erdpy config set dependencies.golang.tag go1.17.6 && \
    erdpy config set dependencies.elrond_proxy_go.tag master && \
    erdpy testnet prerequisites

COPY --from=builder --chown=elrond:elrond ./elrond-config-testnet/economics.toml ./elrondsdk/elrond_proxy_go/master/elrond-proxy-go-master/cmd/proxy/config/
RUN erdpy config set chainID local-testnet && \
    erdpy config set proxy http://localhost:7950 && \
    erdpy testnet config

EXPOSE 7950
