FROM ubuntu:latest
LABEL Maxfiles monitor for ONTAP volumes

WORKDIR maxfile-monitor

COPY maxfile-monitor.sh .
RUN chmod +x maxfile-monitor.sh
RUN apt update -y && apt upgrade -y
RUN apt install -y curl
CMD ["./maxfile-monitor.sh"]
