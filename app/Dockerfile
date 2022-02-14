FROM node:14.18.2-alpine3.14
EXPOSE 3000
RUN mkdir /server
RUN chown -R 1000:1000 /server
WORKDIR /server
USER 1000
COPY package.json package-lock.json ./
RUN npm install
COPY . .
ENTRYPOINT ["node", "/server/server.js"]
