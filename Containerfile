# Chukar Containerfile

ARG IMAGE_NAME="${IMAGE_NAME:-chukar}"
ARG IMAGE_MAJOR_VERSION="${IMAGE_MAJOR_VERSION:-rawhide}"

ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-kinoite}"
ARG BASE_IMAGE_REGISTRY="${BASE_IMAGE_NAME:-quay.io/fedora-ostree-desktops}"
ARG BASE_IMAGE="${BASE_IMAGE_REGISTRY}/${BASE_IMAGE_NAME}"

FROM ${BASE_IMAGE}:${IMAGE_MAJOR_VERSION} AS chukar

# Remove the rpm provided Firefox, Discover backend and other things we don't want
COPY --from=ghcr.io/ublue-os/config:latest /rpms /tmp/rpms
RUN rpm-ostree override remove \
        firefox \
        firefox-langpacks \
        plasma-discover-rpm-ostree \
        filelight \
        krfb \
        krfb-libs \
        kwrite \
        fedora-flathub-remote \
        toolbox && \
    rpm-ostree install \
        distrobox \
        /tmp/rpms/*.rpm

# Install flathub repo definition file
RUN mkdir -p /usr/share/chukar && \
    wget -q https://dl.flathub.org/repo/flathub.flatpakrepo -P /usr/share/chukar

# Starship Shell Prompt
RUN curl -Lo /tmp/starship.tar.gz "https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz" && \
    tar -zxf /tmp/starship.tar.gz -C /tmp && \
    install -c -m 0755 /tmp/starship /usr/bin && \
    echo 'eval "$(starship init bash)"' >> /etc/bashrc

# Copy files into Container
COPY usr /usr
COPY etc/skel/.config/autostart/ /etc/skel/.config/autostart/
COPY just /tmp/just


RUN find /tmp/just -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just && \
    pip install --prefix=/usr/ topgrade

# Clean up temp files and finalize container build.
RUN rm -rf \
        /tmp/* \
        /var/* && \
    ostree container commit
