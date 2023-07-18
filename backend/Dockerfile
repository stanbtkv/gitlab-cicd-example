FROM alpine:3.15.4
ARG VERSION=${VERSION}
WORKDIR .

# создаём пользователя backenduser
RUN addgroup --system backenduser \
    && adduser -S -s /bin/false -G backenduser backenduser -D -H

COPY --chown=backenduser:backenduser bin/api ./api

EXPOSE 8081

# приложение будет запускаться под пользователем backenduser
USER backenduser
CMD [ "./api" ]
