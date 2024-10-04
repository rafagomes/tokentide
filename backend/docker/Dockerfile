# Stage 1: Build
FROM golang:1.23-alpine AS build

# Set environment variables for Go build
ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64

WORKDIR /app

# Copy the Go module files first to leverage Docker layer caching
COPY go.mod go.sum ./

# Download Go modules
RUN go mod download

# Now copy the rest of the application source code
COPY . .

# Build the application and place binary in /app directory
RUN go build -o /app/tokentide ./cmd/api

# Stage 2: Run
FROM alpine:latest

WORKDIR /root/

# Copy the compiled binary from the build stage
COPY --from=build /app/tokentide .

# Expose the port for the application
EXPOSE 3000

# Run the application
CMD ["./tokentide"]