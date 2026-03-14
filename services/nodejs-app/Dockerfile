# Stage 1: install dependencies
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
 
# Stage 2: run the app
FROM node:20-alpine
WORKDIR /app
 
# Create a non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
 
COPY --from=builder /app/node_modules ./node_modules
COPY src/ ./src/
COPY package.json ./
 
USER appuser
EXPOSE 3000
 
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -q -O /dev/null http://localhost:3000/health || exit 1
 
CMD ["node", "src/index.js"]
