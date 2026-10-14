# Build native Linux/amd64 co CGO de SQLite hoat dong.
# Dockerfile khong lay binary x-ui hay tai nguyen tu repo cua tac gia goc.
FROM golang:1.26-bookworm AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN test "$(go env GOARCH)" = amd64 && \
    CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -mod=readonly -trimpath -o /out/x-ui .

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /usr/local/x-ui
COPY --from=builder /out/x-ui ./x-ui
COPY bin/xray-linux-amd64 bin/geoip.dat bin/geosite.dat ./bin/
RUN chmod 755 ./x-ui ./bin/xray-linux-amd64
VOLUME ["/etc/x-ui"]
EXPOSE 54321
CMD ["./x-ui"]
