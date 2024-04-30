FROM ubuntu:latest

LABEL com.github.actions.name="cpp-multicheck"
LABEL com.github.actions.description="Check your pull request's modified files against cppcheck, clang-format and flawfinder."
LABEL com.github.actions.icon="check-circle"
LABEL com.github.actions.color="green"

LABEL repository="https://github.com/globalvisioninc/cpp-multicheck/"
LABEL maintainer="naubryGV <73480455+naubryGV@users.noreply.github.com>"

WORKDIR /build
RUN apt-get update
RUN apt-get -y install python-is-python3 python3-pip python3-venv curl clang-tidy cmake cppcheck jq clang clang-format

COPY checkall.sh /entrypoint.sh
CMD ["bash", "/entrypoint.sh"]
