FROM ubuntu:18.04

LABEL com.github.actions.name="cpp-clang-check"
LABEL com.github.actions.description="Check your pull requests against cppcheck, clang and flawfinder."
LABEL com.github.actions.icon="check-circle"
LABEL com.github.actions.color="green"

LABEL repository="https://github.com/naubryGV/cpp-clang-check/"
LABEL maintainer="naubryGV <73480455+naubryGV@users.noreply.github.com>"

WORKDIR /build
RUN apt-get update
RUN apt-get -qq -y install curl clang-tidy cmake jq clang cppcheck clang-format flawfinder

ADD checkall.sh /entrypoint.sh
COPY . .
CMD ["bash", "/entrypoint.sh"]
