# Plasma Bluefin Testing Containerfile

ARG IMAGE_NAME="${IMAGE_NAME:-plasma-bluefin-testing}"
ARG IMAGE_MAJOR_VERSION="${IMAGE_MAJOR_VERSION:-rawhide}"

ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-kinoite}"
ARG BASE_IMAGE_REGISTRY="${BASE_IMAGE_NAME:-quay.io/fedora-ostree-desktops}"
ARG BASE_IMAGE="${BASE_IMAGE_REGISTRY}/${BASE_IMAGE_NAME}"

FROM ${BASE_IMAGE}:${IMAGE_MAJOR_VERSION} AS plasma-bluefin-testing

# Remove the rpm provided Firefox, Discover backend and other things we don't want
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
        distrobox

# Install flathub repo definition file
RUN mkdir -p /usr/share/placeholder && \
    wget -q https://dl.flathub.org/repo/flathub.flatpakrepo -P /usr/share/placeholder

# Install usr and etc files into Container
COPY usr /
COPY etc/skel/.config/autostart/placeholder-firstboot.desktop /

# Clean up temp files and finalize container build.
RUN rm -rf \
        /tmp/* \
        /var/* && \
    ostree container commit
