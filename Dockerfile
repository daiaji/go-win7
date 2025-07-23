#
# NOTE: THIS DOCKERFILE IS MODIFIED TO BUILD A PATCHED GO SDK FOR WINDOWS 7 COMPATIBILITY.
#
# Base image logic is from the official Go Docker image.
# Patches are from https://github.com/XTLS/go-win7
#

# Stage 1: Build the patched Go SDK
FROM alpine:3.22 AS build

# Install build dependencies
RUN apk add --no-cache bash ca-certificates curl git patch

# Clone the Go source code from the specified branch
WORKDIR /usr/src
RUN git clone --depth 1 --branch release-branch.go1.24 https://github.com/golang/go.git .

# Download and apply the patch for Windows 7 compatibility
RUN curl -L -o win7.patch https://github.com/XTLS/go-win7/raw/refs/heads/build/unified-1-24-patch.diff && \
    patch -p1 < win7.patch

# Build the Go SDK
# This will build Go from the patched source code.
WORKDIR /usr/src/src
RUN ./make.bash

# Set Go environment variables for the final image
ENV GOLANG_VERSION 1.24.5
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/src/bin:$PATH
# Prevent auto-upgrading the Go toolchain, as it would break the patch
# https://github.com/docker-library/golang/issues/472
ENV GOTOOLCHAIN=local

# Stage 2: Create the final, smaller image with the patched Go SDK
FROM alpine:3.22

# Install runtime dependencies
RUN apk add --no-cache ca-certificates

# Copy the patched Go SDK from the build stage
COPY --from=build /usr/src /usr/local/go

# Set Go environment variables
ENV GOLANG_VERSION 1.24.5
ENV GOTOOLCHAIN=local
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

# Create the GOPATH directory and set permissions
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 1777 "$GOPATH"

# Set the working directory
WORKDIR $GOPATH

# Verify the Go version to confirm the build was successful
RUN go version