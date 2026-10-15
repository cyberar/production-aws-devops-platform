FROM nginx:alpine

# Install dependencies and update packages
RUN apk update && apk upgrade --no-cache

ARG RELEASE_SHA=local

COPY ./index.html /usr/share/nginx/html/index.html

RUN sed -i "s/RELEASE_PLACEHOLDER/${RELEASE_SHA}/g" \
    /usr/share/nginx/html/index.html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
