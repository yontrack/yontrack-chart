# Backend image under test: the image of the chart, with one more expand and one more contract migration,
# so that every upgrade test has both kinds pending. /app/resources is the first entry of the Jib classpath.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
COPY migration/ /app/resources/db/migration/
COPY contract/ /app/resources/db/contract/
