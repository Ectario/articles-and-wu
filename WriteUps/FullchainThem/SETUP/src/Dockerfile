FROM python:3.11.9

RUN true \
    && mkdir /var/log/ctf /startup \
    && apt update \
    && apt install -y xinetd tini \
    && rm -rf /var/cache/apt/archives \
    && useradd -m ctf \
    && true

COPY 00-create-xinetd-service /startup
COPY 99-start-xinetd /startup
COPY handler.sh /home/ctf/handler.sh
COPY entrypoint.sh /entrypoint.sh
COPY solve-pow.py /home/ctf/
RUN chmod +x /home/ctf/handler.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["tini", "-g", "--"]
CMD ["/entrypoint.sh"]

RUN true \
    && curl -L https://foundry.paradigm.xyz | bash \
    && curl -L get.huff.sh | bash \
    && bash -c "source /root/.bashrc && foundryup && huffup" \
    && chmod 755 -R /root \
    && true

COPY 98-start-gunicorn /startup

ENV PYTHONPATH /usr/lib/python

COPY deploy/ /home/ctf/

COPY contracts /tmp/contracts

COPY requirements.txt /root

RUN python3 -m pip install -r /root/requirements.txt 

COPY eth_sandbox /usr/lib/python/eth_sandbox

COPY foundry.toml /tmp/foundry.toml

RUN true \
    && mkdir /home/ctf/compiled \
    && cd /tmp \
    && /root/.foundry/bin/forge init --force --no-commit \
    && /root/.foundry/bin/forge install https://github.com/OpenZeppelin/openzeppelin-contracts@v5.1.0 --no-commit \
    && /root/.foundry/bin/forge build --out /home/ctf/compiled \
    && rm -rf /tmp/contracts \
    && true
