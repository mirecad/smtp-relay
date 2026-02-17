FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY main.go .
RUN CGO_ENABLED=0 go build -o /smtp-relay .

FROM alpine:3.19
COPY --from=build /smtp-relay /smtp-relay
EXPOSE 587
ENTRYPOINT ["/smtp-relay"]
