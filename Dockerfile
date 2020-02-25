FROM dev-env:latest

WORKDIR /kubemark-performance-tests-on-azure

COPY . /kubemark-performance-tests-on-azure

ENV PRIVATE_KEY id_rsa

ENTRYPOINT ["bash", "automation/runner.sh"]
