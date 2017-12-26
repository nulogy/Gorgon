FROM rastasheep/ubuntu-sshd:16.04

RUN apt-get update && apt-get install -y rsync

ADD test_gorgon.pem.pub .

RUN mkdir -p ~/.ssh \
  && cat test_gorgon.pem.pub >> ~/.ssh/authorized_keys
