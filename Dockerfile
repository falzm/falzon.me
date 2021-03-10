FROM nginx:alpine

COPY . /hugo

RUN curl -sL https://github.com/gohugoio/hugo/releases/download/v0.81.0/hugo_0.81.0_Linux-64bit.tar.gz | tar xzf - -C /bin hugo && \
    hugo -s /hugo -d /usr/share/nginx/html/
