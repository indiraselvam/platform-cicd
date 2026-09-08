FROM node:22-alpine

# Patch OS-level packages to their latest available fixes
RUN apk update && apk upgrade --no-cache

WORKDIR /app

COPY package.json ./
COPY server.js ./

USER node

EXPOSE 8080

CMD ["node", "server.js"]
