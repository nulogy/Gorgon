FROM rastasheep/ubuntu-sshd:16.04

ADD test_gorgon.pem.pub .

RUN mkdir -p ~/.ssh \
  && cat test_gorgon.pem.pub >> ~/.ssh/authorized_keys
