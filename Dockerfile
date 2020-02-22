FROM ss104301/dev-env:latest

WORKDIR /kubemark-performance-tests-on-azure

COPY . /kubemark-performance-tests-on-azure

ENV PRIVATE_KEY id_rsa

CMD ["bash", "automation/main.sh"]
