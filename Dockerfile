FROM debian:trixie-slim

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# jq/openssh-client/shellcheck: tooling the scripts themselves need (NAS SSH
# access, JSON parsing in speedtest/backup scripts) or that lints them.
RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo git ca-certificates curl \
        jq openssh-client shellcheck \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME
