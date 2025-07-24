#
# NOTE: THIS DOCKERFILE BUILDS A PATCHED GO SDK FOR WINDOWS 7 COMPATIBILITY.
#
# It uses an official Go image for the build stage to handle bootstrapping
# and creates a minimal final image with the patched SDK.
#

# Stage 1: Build the patched Go SDK using an official Go image as the base
FROM golang:1.24.5-alpine3.22 AS build

# The base image has Go. We need to add bash (for make.bash), git, and patch.
# curl is usually included, but we add it for robustness.
RUN apk add --no-cache bash git patch curl

# Set a working directory for the patched source
WORKDIR /usr/src/go-patched

# Clone the specific Go source branch
RUN git clone --depth 1 https://github.com/Snawoot/go-win7.git .

# Download and apply the Windows 7 compatibility patch
# RUN curl -L -o win7.patch https://github.com/XTLS/go-win7/raw/refs/heads/build/unified-1-24-patch.diff && \
#     patch -p1 < win7.patch

# Build Go from the patched source. The existing Go from the base image will act as the bootstrap compiler.
WORKDIR /usr/src/go-patched/src
RUN ./make.bash

# Stage 2: Create the final, minimal image
FROM alpine:3.22

# Install only essential runtime dependencies
RUN apk add --no-cache ca-certificates

# Copy the newly built, patched Go SDK from the build stage's source tree
# The 'make.bash' script places all necessary files (bin, pkg, etc.) within this tree.
COPY --from=build /usr/src/go-patched /usr/local/go

# Set Go environment variables for the new SDK
ENV GOLANG_VERSION 1.24.5
# GOTOOLCHAIN=local is crucial to prevent Go from automatically replacing our patched toolchain
ENV GOTOOLCHAIN=local
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

# Create the GOPATH directory and set appropriate permissions
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 1777 "$GOPATH"

# Set the default working directory
WORKDIR $GOPATH

# Final verification step to confirm the patched SDK is installed correctly
RUN go version