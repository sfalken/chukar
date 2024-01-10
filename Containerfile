# Chukar Containerfile

ARG IMAGE_NAME="${IMAGE_NAME:-chukar}"
ARG IMAGE_MAJOR_VERSION="${IMAGE_MAJOR_VERSION:-rawhide}"

ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-kinoite}"
ARG BASE_IMAGE_REGISTRY="${BASE_IMAGE_NAME:-quay.io/fedora-ostree-desktops}"
ARG BASE_IMAGE="${BASE_IMAGE_REGISTRY}/${BASE_IMAGE_NAME}"
ARG PACKAGE_LIST="chukar"

FROM ${BASE_IMAGE}:${IMAGE_MAJOR_VERSION} AS chukar

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
    systemctl enable tailscaled.service && \
    systemctl enable dconf-update.service && \
    systemctl enable ublue-update.timer && \
    systemctl --global enable ublue-user-flatpak-manager.service && \
    systemctl --global enable ublue-user-setup.service && \
    fc-cache -f /usr/share/fonts/ubuntu && \
    fc-cache -f /usr/share/fonts/inter && \
    echo "Hidden=true" >> /usr/share/applications/fish.desktop && \
    echo "Hidden=true" >> /usr/share/applications/htop.desktop && \
    echo "Hidden=true" >> /usr/share/applications/nvtop.desktop && \
    sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=15s/' /etc/systemd/user.conf && \
    sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=15s/' /etc/systemd/system.conf && \
    sed -i '/^PRETTY_NAME/s/Kinoite/Chukar/' /usr/lib/os-release


# Clean up temp files and finalize container build.
RUN rm -rf \
        /tmp/* \
        /var/* && \
    ostree container commit && \
    mkdir -p /var/tmp && \
    chmod -R 1777 /var/tmp
