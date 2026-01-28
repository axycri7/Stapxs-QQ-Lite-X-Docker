FROM nginx:stable-alpine-slim

LABEL maintainer="axycrio"
LABEL description="Docker image for Chzxxuanzheng/Stapxs-QQ-Lite-X"

RUN rm -rf /etc/nginx/conf.d/default.conf

COPY ./nginx/conf.d/default.conf /etc/nginx/conf.d/

COPY ./dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]