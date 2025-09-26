# Use official Ghost 6 Alpine image as base
FROM ghost:6-alpine

# Set working directory
WORKDIR /var/lib/ghost

# Install additional dependencies for Ghost Pro features
RUN apk add --no-cache \
    curl \
    wget \
    unzip \
    nodejs \
    npm

# Create necessary directories
RUN mkdir -p /var/lib/ghost/content/themes \
    && mkdir -p /var/lib/ghost/content/images \
    && mkdir -p /var/lib/ghost/content/files \
    && mkdir -p /var/lib/ghost/content/apps \
    && mkdir -p /var/lib/ghost/logs

# Copy custom configuration if exists (optional)
# COPY config.production.json /var/lib/ghost/
# Uncomment above line if you have a custom config file

# Set proper permissions
RUN chown -R node:node /var/lib/ghost

# Switch to node user for security
USER node

# Expose Ghost port
EXPOSE 2368

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:2368/ghost/api/v4/admin/site/ || exit 1

# Start Ghost
CMD ["node", "current/index.js"]