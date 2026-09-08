<<<<<<< HEAD
FROM node:22-alpine AS build
=======
FROM node:22-alpine

# Patch OS-level packages to their latest available fixes
RUN apk update && apk upgrade --no-cache

>>>>>>> beab515bb1cbd55cf940ac190ab1a908bb91847b
WORKDIR /app
COPY package.json ./
COPY server.js ./

<<<<<<< HEAD
FROM node:22-alpine AS final
RUN apk update && apk upgrade --no-cache && \
    rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx /opt/yarn-v1.22.22
WORKDIR /app
COPY --from=build /app/server.js ./
COPY --from=build /app/package.json ./
CMD ["node", "server.js"]
=======
USER node

EXPOSE 8080

CMD ["node", "server.js"]
>>>>>>> beab515bb1cbd55cf940ac190ab1a908bb91847b
