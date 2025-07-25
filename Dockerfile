#
# FINAL CORRECTED DOCKERFILE - Handles correct archive top-level directory per official docs
#

# --- 第一阶段：构建 ---
FROM alpine:3.22 AS build

ARG LEGACY_GO_TAG=v1.24.5-1

ENV LEGACY_GO_TAG=${LEGACY_GO_TAG}
ENV PATH /usr/local/go/bin:$PATH
ENV GOLANG_VERSION 1.24.5

RUN set -eux; \
	now="$(date '+%s')"; \
	apk add --no-cache --virtual .fetch-deps \
		ca-certificates \
		wget \
		tar \
	; \
	arch="$(apk --print-arch)"; \
	goArch=; \
	case "$arch" in \
		'x86_64')  goArch='amd64'; ;; \
		'armhf')   goArch='arm'; ;; \
		'armv7')   goArch='arm'; ;; \
		'aarch64') goArch='arm64'; ;; \
		'x86')     goArch='386'; ;; \
		*) echo >&2 "error: unsupported architecture '$arch' for go-legacy-win7 build"; exit 1 ;; \
	esac; \
	\
	fileName="go-legacy-win7-${LEGACY_GO_TAG#v}.linux_${goArch}.tar.gz"; \
	url="https://github.com/thongtech/go-legacy-win7/releases/download/${LEGACY_GO_TAG}/${fileName}"; \
	\
	echo "Downloading Go from: $url"; \
	wget -O go.tgz "$url"; \
	\
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	\
	# 关键修正：根据官方文档，解压后的目录是 'go-legacy-win7'，我们将其重命名为 'go'
	mv /usr/local/go-legacy-win7 /usr/local/go; \
	\
	SOURCE_DATE_EPOCH="$(stat -c '%Y' /usr/local/go)"; \
	export SOURCE_DATE_EPOCH; \
	touchy="$(date -d "@$SOURCE_DATE_EPOCH" '+%Y%m%d%H%M.%S')"; \
	date --date "@$SOURCE_DATE_EPOCH" --rfc-2822; \
	[ "$SOURCE_DATE_EPOCH" -lt "$now" ]; \
	\
	if [ "$arch" = 'armv7' ]; then \
		[ -s /usr/local/go/go.env ]; \
		before="$(go env GOARM)"; [ "$before" != '7' ]; \
		{ \
			echo; \
			echo '# https://github.com/docker-library/golang/issues/494'; \
			echo 'GOARM=7'; \
		} >> /usr/local/go/go.env; \
		after="$(go env GOARM)"; [ "$after" = '7' ]; \
		touch -t "$touchy" /usr/local/go/go.env /usr/local/go; \
	fi; \
	\
	mkdir /target /target/usr /target/usr/local; \
	mv -vT /usr/local/go /target/usr/local/go; \
	ln -svfT /target/usr/local/go /usr/local/go; \
	touch -t "$touchy" /target/usr/local /target/usr /target; \
	\
	apk del --no-network .fetch-deps; \
	\
	go version; \
	epoch="$(stat -c '%Y' /target/usr/local/go)"; \
	[ "$SOURCE_DATE_EPOCH" = "$epoch" ]; \
	find /target -newer /target/usr/local/go -exec sh -c 'ls -ld "$@" && exit "$#"' -- '{}' +

# --- 第二阶段：最终镜像 ---
FROM alpine:3.22

ENV GOLANG_VERSION 1.24.5
ENV GOTOOLCHAIN=local
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

COPY --from=build --link /target/ /

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 1777 "$GOPATH"
WORKDIR $GOPATH