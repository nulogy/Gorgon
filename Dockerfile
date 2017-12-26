FROM ruby:2.1.6-slim

RUN apt-get update -y && apt-get install -y \
  build-essential \
  git \
  net-tools # we need ifconfig

RUN mkdir -p ~/.ssh \
  && ssh-keygen -f ~/.ssh/id_rsa -t rsa -N '' \
  && cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

WORKDIR '/opt/gorgon'

RUN gem install bundler
ADD ["Gemfile", "Gemfile.lock", "gorgon.gemspec", "./"]
ADD ["lib/gorgon/version.rb", "lib/gorgon/"]
RUN bundle install

ADD . .

RUN gem build gorgon.gemspec && gem install gorgon
RUN cd tests/end_to_end

ENTRYPOINT ["/bin/bash", "-c", "sleep infinity"]
