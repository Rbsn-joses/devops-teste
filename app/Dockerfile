FROM node:14-alpine

WORKDIR /app
COPY . .
RUN npm install
USER node
COPY --chown=node:node . .

EXPOSE 3000

CMD [ "npm", "start" ]