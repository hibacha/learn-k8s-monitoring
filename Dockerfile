FROM node:7.4.0-alpine

WORKDIR /usr/src/app

# Package.json is here to invalidate dependency changes.
ADD package.json /usr/src/app/package.json

RUN npm install --production

ADD index.js /usr/src/app/index.js

ENTRYPOINT ["node", "/usr/src/app/index.js"]
