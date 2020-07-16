FROM ruby:2.3-slim

RUN apt-get update -y && apt-get install -y \
  build-essential \
  git \
  net-tools # we need ifconfig

RUN mkdir -p ~/.ssh

ADD spec/dummy/test_gorgon.pem .
RUN mv test_gorgon.pem ~/.ssh/id_rsa && chmod 400 ~/.ssh/id_rsa

WORKDIR '/opt/gorgon'

RUN gem install bundler
ADD ["Gemfile", "Gemfile.lock", "gorgon.gemspec", "./"]
ADD ["lib/gorgon/version.rb", "lib/gorgon/"]
RUN bundle install

ADD . .

RUN gem build gorgon.gemspec && gem install gorgon
RUN cd spec/dummy

ENTRYPOINT ["/bin/bash", "-c", "sleep infinity"]
