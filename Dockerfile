FROM fedora:latest
RUN dnf install -y httpd; dnf clean all; systemctl enable httpd
RUN mkdir -p /var/www/html/download
EXPOSE 80
CMD [ "/usr/sbin/init" ]
