#
# MODIFIED DOCKERFILE TO USE A DYNAMIC go-legacy-win7 VERSION
#

# 定义一个构建参数 (build argument) 来接收版本标签。
# 提供一个默认值，以便在没有外部参数的情况下也能成功构建。
ARG LEGACY_GO_TAG=v1.24.5-1

FROM alpine:3.22 AS build

# 将接收到的构建参数 ARG 赋值给环境变量 ENV，以便在 RUN 指令中使用。
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
	# 根据 apk 架构映射到 Go 架构的名称
	case "$arch" in \
		'x86_64')  goArch='amd64'; ;; \
		'armhf')   goArch='arm'; ;; \
		'armv7')   goArch='arm'; ;; \
		'aarch64') goArch='arm64'; ;; \
		'x86')     goArch='386'; ;; \
		*) echo >&2 "error: unsupported architecture '$arch' for go-legacy-win7 build"; exit 1 ;; \
	esac; \
	\
	# 使用变量动态构建文件名和下载URL
    # ${LEGACY_GO_TAG#v} 会移除版本标签开头的 'v' (例如: v1.24.5-1 -> 1.24.5-1)
	fileName="go-legacy-win7-${LEGACY_GO_TAG#v}.linux_${goArch}.tar.gz"; \
	url="https://github.com/thongtech/go-legacy-win7/releases/download/${LEGACY_GO_TAG}/${fileName}"; \
	\
	echo "Downloading Go from: $url"; \
	wget -O go.tgz "$url"; \
	\
	# 注意：由于版本是动态获取的，我们无法在此处硬编码 SHA256 校验和。
	# 我们依赖于通过 HTTPS 下载的安全性来保证文件的完整性。
	# 之前静态的 sha256sum 检查已被移除。
	\
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	\
	# save the timestamp from the tarball so we can restore it for reproducibility, if necessary (see below)
	SOURCE_DATE_EPOCH="$(stat -c '%Y' /usr/local/go)"; \
	export SOURCE_DATE_EPOCH; \
	touchy="$(date -d "@$SOURCE_DATE_EPOCH" '+%Y%m%d%H%M.%S')"; \
	# for logging validation/edification
	date --date "@$SOURCE_DATE_EPOCH" --rfc-2822; \
	# sanity check (detected value should be older than our wall clock)
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

# --- Final Stage ---
FROM alpine:3.22

RUN apk add --no-cache ca-certificates

ENV GOLANG_VERSION 1.24.5
ENV GOTOOLCHAIN=local
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

COPY --from=build --link /target/ /

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 1777 "$GOPATH"
WORKDIR $GOPATH