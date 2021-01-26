FROM ubuntu:18.04

LABEL com.github.actions.name="cpp-multicheck"
LABEL com.github.actions.description="Check your pull requests against cppcheck, clang-format and flawfinder."
LABEL com.github.actions.icon="check-circle"
LABEL com.github.actions.color="green"

LABEL repository="https://github.com/naubryGV/cpp-clang-check/"
LABEL maintainer="naubryGV <73480455+naubryGV@users.noreply.github.com>"

WORKDIR /build
RUN apt-get update
RUN apt-get -qq -y install python curl clang-tidy cmake jq clang cppcheck clang-format flawfinder

COPY checkall.sh /entrypoint.sh
COPY run-clang-format.py /run-clang-format.py
COPY . .
CMD ["bash", "/entrypoint.sh"]
