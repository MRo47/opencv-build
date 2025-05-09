# Dockerfile.test
FROM alpine:latest
WORKDIR /app
# Copy some files - the workflow will checkout your repo, so we can copy the Dockerfile itself
COPY . /app/

# Add a simple test file
RUN echo "This is a tiny test image based on Alpine Linux." > /app/test_message.txt

# Set a simple default command
CMD ["cat", "/app/test_message.txt"]