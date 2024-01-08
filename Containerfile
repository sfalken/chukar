# Plasma Bluefin Testing Containerfile

ARG IMAGE_NAME="${IMAGE_NAME:-plasma-bluefin-testing}"
ARG IMAGE_MAJOR_VERSION="${IMAGE_MAJOR_VERSION:-rawhide}"

ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-kinoite}"
ARG BASE_IMAGE_REGISTRY="${BASE_IMAGE_NAME:-quay.io/fedora-ostree-desktops}"
ARG BASE_IMAGE="${BASE_IMAGE_REGISTRY}/${BASE_IMAGE_NAME}"

FROM ${BASE_IMAGE}:${IMAGE_MAJOR_VERSION} AS plasma-bluefin-testing

# Clean up temp files and finalize container build.
RUN rm -rf \
        /tmp/* \
        /var/* && \
    ostree container commit
