FROM golang:1.25-alpine AS builder

WORKDIR /app
COPY go.mod ./
COPY go.sum* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /api ./cmd/api

FROM alpine:3.21

RUN apk --no-cache add ca-certificates
RUN mkdir -p /data
COPY --from=builder /api /api

EXPOSE 8080

ENTRYPOINT ["/api"]

