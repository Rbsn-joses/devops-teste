FROM node:14-alpine

WORKDIR /app
RUN npm install
USER node
COPY --chown=node:node ./app/* .

EXPOSE 3000

CMD [ "npm", "start" ]