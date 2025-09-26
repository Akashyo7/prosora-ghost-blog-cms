# Use the official Ghost image as base
FROM ghost:5-alpine

# Install additional packages for PostgreSQL and utilities
RUN apk add --no-cache postgresql-client curl

# Set working directory
WORKDIR $GHOST_INSTALL

# Copy package.json and install additional dependencies
COPY package.json ./
RUN npm install --production

# Copy custom configuration
COPY config.production.json ./

# Create content directory and set permissions
RUN mkdir -p /var/lib/ghost/content && \
    chown -R node:node /var/lib/ghost/content && \
    chown -R node:node $GHOST_INSTALL

# Switch to node user for security
USER node

# Expose port
EXPOSE 2368

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:2368/ghost/api/v4/admin/site/ || exit 1

# Start Ghost
CMD ["node", "current/index.js"]