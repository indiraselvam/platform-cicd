FROM node:22-alpine AS build
WORKDIR /app
COPY package.json ./
COPY server.js ./

FROM node:22-alpine AS final
RUN apk update && apk upgrade --no-cache && \
    rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx /opt/yarn-v1.22.22
WORKDIR /app
COPY --from=build /app/server.js ./
COPY --from=build /app/package.json ./
CMD ["node", "server.js"]