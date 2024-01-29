# Chukar Containerfile

ARG IMAGE_NAME="${IMAGE_NAME:-chukar}"
ARG IMAGE_MAJOR_VERSION="${IMAGE_MAJOR_VERSION:-rawhide}"

ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-kinoite}"
ARG BASE_IMAGE_REGISTRY="${BASE_IMAGE_NAME:-quay.io/fedora-ostree-desktops}"
ARG BASE_IMAGE="${BASE_IMAGE_REGISTRY}/${BASE_IMAGE_NAME}"

FROM ${BASE_IMAGE}:${IMAGE_MAJOR_VERSION} AS chukar
ARG IMAGE_NAME="${IMAGE_NAME}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR}"
ARG IMAGE_FLAVOR="${IMAGE_FLAVOR}"
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION}"
ARG PACKAGE_LIST="chukar"

# Remove the rpm provided Firefox, Discover backend and other things we don't want
COPY --from=ghcr.io/ublue-os/config:latest /rpms /tmp/rpms
RUN rpm-ostree install \
        /tmp/rpms/*.rpm

# Install flathub repo definition file
RUN mkdir -p /usr/etc/flatpak/remotes.d && \
    wget -q https://dl.flathub.org/repo/flathub.flatpakrepo -P /usr/etc/flatpak/remotes.d

# Starship Shell Prompt
RUN curl -Lo /tmp/starship.tar.gz "https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz" && \
    tar -zxf /tmp/starship.tar.gz -C /tmp && \
    install -c -m 0755 /tmp/starship /usr/bin && \
    echo 'eval "$(starship init bash)"' >> /etc/bashrc

# Copy files into Container
COPY usr /usr
COPY etc/skel/.config/autostart/ /etc/skel/.config/autostart/
COPY just /tmp/just
COPY build.sh /tmp/build.sh
COPY image-info.sh /tmp/image-info.sh
COPY usr/etc/ublue-update/ublue-update.toml /tmp/ublue-update.toml
COPY packages.json /tmp/packages.json


RUN /tmp/build.sh && \
    /tmp/image-info.sh && \
    find /tmp/just -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just && \
    pip install --prefix=/usr/ topgrade && \
    cp /tmp/ublue-update.toml /usr/etc/ublue-update/ublue-update.toml && \
    systemctl enable rpm-ostree-countme.service && \
    systemctl enable dconf-update.service && \
    systemctl --global enable ublue-user-flatpak-manager.service && \
    systemctl --global enable ublue-user-setup.service && \
    fc-cache -f /usr/share/fonts/ubuntu && \
    fc-cache -f /usr/share/fonts/inter && \
    echo "Hidden=true" >> /usr/share/applications/fish.desktop && \
    echo "Hidden=true" >> /usr/share/applications/htop.desktop && \
    echo "Hidden=true" >> /usr/share/applications/nvtop.desktop && \
    sed -i '/^PRETTY_NAME/s/Kinoite/Chukar/' /usr/lib/os-release


# Clean up temp files and finalize container build.
RUN rm -rf \
        /tmp/* \
        /var/* && \
    ostree container commit && \
    mkdir -p /var/tmp && \
    chmod -R 1777 /var/tmp

# chukar-dx developer experience image
FROM chukar as chukar-dx

ARG IMAGE_NAME="${IMAGE_NAME}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR}"
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME}"
ARG IMAGE_FLAVOR="${IMAGE_FLAVOR}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION}"
ARG PACKAGE_LIST="chukar-dx"

COPY dx/usr /usr
COPY dx/etc/yum.repos.d/ /etc/yum.repos.d/
COPY workarounds.sh \
     packages.json \
     build.sh \
     image-info.sh \
     /tmp

# Apply IP Forwarding before installing Docker to prevent breaking LXC networking
RUN sysctl -p

#  repo to be removed when F40 releases
RUN wget https://copr.fedorainfracloud.org/coprs/ganto/lxc4/repo/fedora-rawhide/ganto-lxc4-fedora-rawhide.repo -O /etc/yum.repos.d/ganto-lxc4-fedora-rawhide.repo && \
    wget https://copr.fedorainfracloud.org/coprs/ublue-os/staging/repo/fedora-rawhide/ublue-os-staging-fedora-rawhide.repo -O /etc/yum.repos.d/ublue-os-staging-fedora-rawhide.repo && \
    wget https://copr.fedorainfracloud.org/coprs/karmab/kcli/repo/fedora-rawhide/karmab-kcli-fedora-rawhide.repo -O /etc/yum.repos.d/karmab-kcli-fedora-rawhide.repo && \
    wget https://copr.fedorainfracloud.org/coprs/sfaulken/chukar/repo/fedora-rawhide/sfaulken-chukar-fedora-rawhide.repo -O /etc/yum.repos.d/sfaulken-chukar-fedora-rawhide.repo

# Handle packages via packages.json
RUN /tmp/build.sh && \
    /tmp/image-info.sh

## power-profiles-deamon with amd p-state support, will be removed when upstreamed.
RUN rpm-ostree override replace --experimental --from repo=copr:copr.fedorainfracloud.org:ublue-os:staging power-profiles-daemon

RUN wget https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -O /tmp/docker-compose && \
    install -c -m 0755 /tmp/docker-compose /usr/bin

COPY --from=cgr.dev/chainguard/dive:latest /usr/bin/dive /usr/bin/dive
COPY --from=cgr.dev/chainguard/flux:latest /usr/bin/flux /usr/bin/flux
COPY --from=cgr.dev/chainguard/helm:latest /usr/bin/helm /usr/bin/helm
COPY --from=cgr.dev/chainguard/ko:latest /usr/bin/ko /usr/bin/ko
COPY --from=cgr.dev/chainguard/minio-client:latest /usr/bin/mc /usr/bin/mc
COPY --from=cgr.dev/chainguard/kubectl:latest /usr/bin/kubectl /usr/bin/kubectl

RUN curl -Lo ./kind "https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-$(uname)-amd64" && \
    chmod +x ./kind && \
    mv ./kind /usr/bin/kind

# Install kns/kctx and add completions for Bash
RUN wget https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx -O /usr/bin/kubectx && \
    wget https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens -O /usr/bin/kubens && \
    chmod +x /usr/bin/kubectx /usr/bin/kubens

# Set up services
RUN systemctl enable docker.socket && \
    systemctl enable podman.socket && \
    systemctl enable swtpm-workaround.service && \
    systemctl enable bluefin-dx-groups.service && \
    systemctl enable --global bluefin-dx-user-vscode.service && \
    systemctl disable pmie.service && \
    systemctl disable pmlogger.service

RUN /tmp/workarounds.sh

# Clean up repos, everything is on the image so we don't need them
RUN rm -f /etc/yum.repos.d/ublue-os-staging-fedora-rawhide.repo && \
    rm -f /etc/yum.repos.d/ganto-lxc4-fedora-rawhide.repo && \
    rm -f /etc/yum.repos.d/karmab-kcli-fedora-rawhide.repo && \
    rm -f /etc/yum.repos.d/sfaulken-chukar-fedora-rawhide.repo && \
    rm -f /etc/yum.repos.d/vscode.repo && \
    rm -f /etc/yum.repos.d/docker-ce.repo && \
    rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:phracek:PyCharm.repo && \
    rm -f /etc/yum.repos.d/fedora-cisco-openh264.repo && \
    rm -rf /tmp/* /var/* && \
    ostree container commit

