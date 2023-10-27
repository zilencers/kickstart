FROM fedora:latest
RUN dnf install -y httpd; dnf clean all; systemctl enable httpd
RUN mkdir -p /var/www/html/download
COPY ks.cfg /var/www/html/download/ks.cfg
COPY index.html /var/www/html/index.html
EXPOSE 80
CMD [ "/usr/sbin/init" ]
