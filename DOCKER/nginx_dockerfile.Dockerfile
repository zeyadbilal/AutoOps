# NGINX Dockerfile

# Base image: Debian-based NGINX
# Include maintainers and version info
LABEL maintainer="NGINX Docker Maintainers <docker-maint@nginx.com>"
ENV NGINX_VERSION=1.29.1
ENV NJS_VERSION=0.9.1
ENV NJS_RELEASE=1~bookworm
ENV PKG_RELEASE=1~bookworm
ENV DYNPKG_RELEASE=1~bookworm

# Set shell options
RUN /bin/sh -c set -x

# Copy custom entrypoint
COPY docker-entrypoint.sh /

# Copy default scripts for container initialization
COPY 10-listen-on-ipv6-by-default.sh /docker-entrypoint.d
COPY 15-local-resolvers.envsh /docker-entrypoint.d
COPY 20-envsubst-on-templates.sh /docker-entrypoint.d
COPY 30-tune-worker-processes.sh /docker-entrypoint.d

# Set entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]

# Expose HTTP port
EXPOSE 80

# Set stop signal
STOPSIGNAL SIGQUIT

# Default command to start NGINX
CMD ["nginx", "-g", "daemon off;"]

# Copy NGINX default configuration
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Cleanup command (if needed)
RUN /bin/sh -c rm -rf

# Copy web content to container
COPY . /usr/share/nginx/html

# Optional extra expose / CMD
EXPOSE 80
CMD ["/bin/sh", "-c", "sleep 10"]