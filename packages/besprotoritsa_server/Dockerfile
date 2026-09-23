# syntax=docker/dockerfile:1
# Build the Dart AOT executables in the official Dart image, then retain only
# those executables and the small distroless C/C++ runtime.
FROM dart:stable AS build

WORKDIR /app

COPY packages/besprotoritsa_data/pubspec.yaml packages/besprotoritsa_data/pubspec.yaml
COPY packages/besprotoritsa_rules/pubspec.yaml packages/besprotoritsa_rules/pubspec.yaml
COPY packages/besprotoritsa_server/pubspec.yaml packages/besprotoritsa_server/pubspec.yaml

# The repository workspace also contains the Flutter client, while dart:stable
# intentionally contains only Dart. Resolve this server package on its own.
RUN sed -i '/^resolution: workspace$/d' packages/besprotoritsa_server/pubspec.yaml \
 && dart pub get --directory packages/besprotoritsa_server

COPY packages/besprotoritsa_data/lib packages/besprotoritsa_data/lib
COPY packages/besprotoritsa_rules/lib packages/besprotoritsa_rules/lib
COPY packages/besprotoritsa_server/lib packages/besprotoritsa_server/lib
COPY packages/besprotoritsa_server/bin packages/besprotoritsa_server/bin
COPY content content

RUN install -d -o 65532 -g 65532 /out/data \
 && dart compile exe packages/besprotoritsa_server/bin/server.dart -o /out/server

FROM gcr.io/distroless/cc-debian12:nonroot

WORKDIR /app

COPY --from=build --chown=nonroot:nonroot /out/server /app/server
COPY --from=build --chown=nonroot:nonroot /out/data /data
COPY --from=build --chown=nonroot:nonroot /app/content /app/content

ENV PORT=8080 \
    PERSISTENCE_DIRECTORY=/data \
    CONTENT_DIRECTORY=/app/content

VOLUME ["/data"]
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["/app/server", "--healthcheck"]

USER nonroot:nonroot
ENTRYPOINT ["/app/server"]
