FROM nginx:alpine

# Update installed Alpine packages.
RUN apk upgrade --no-cache

# Configure Nginx to listen on port 8080.
RUN sed -i \
    -e 's/listen 80;/listen 8080;/' \
    -e 's/listen \[::\]:80;/listen [::]:8080;/' \
    /etc/nginx/conf.d/default.conf \
    && sed -i \
    -e 's|pid /var/run/nginx.pid;|pid /tmp/nginx.pid;|' \
    /etc/nginx/nginx.conf \
    && chown -R nginx:nginx /var/cache/nginx

# Application release metadata.
ARG RELEASE_SHA=local

# Copy application.
COPY --chown=nginx:nginx ./index.html /usr/share/nginx/html/index.html

# Inject Git commit SHA.
RUN sed -i "s/RELEASE_PLACEHOLDER/${RELEASE_SHA}/g" \
    /usr/share/nginx/html/index.html

# Nginx listens on 8080.
EXPOSE 8080

# Run as an unprivileged user.
USER nginx

# Start Nginx in foreground.
CMD ["nginx", "-g", "daemon off;"]
