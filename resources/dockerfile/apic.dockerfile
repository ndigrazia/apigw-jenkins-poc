FROM node:8.11.4

ENV http_proxy=http://10.1.1.23:48798
ENV https_proxy=http://10.1.1.23:48798

RUN npm config -g set strict-ssl false

RUN npm config set proxy http://10.1.1.23:48798
RUN npm config set https-proxy http://10.1.1.23:48798

RUN npm install -g apiconnect

CMD [ "node" ]