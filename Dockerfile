# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy dependency definitions
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy all source files
COPY . .

# Build web distribution with html renderer or canvaskit
RUN flutter build web --release

# Stage 2: Production Nginx Server
FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy build artifacts from previous stage
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
