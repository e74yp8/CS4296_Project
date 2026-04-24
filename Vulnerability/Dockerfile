FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y nginx=1.18*

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]