# Build the jar first with: mvn -pl notification-worker -am package
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY target/notification-worker.jar app.jar

# --- eG Java APM agent (add manually) ---------------------------------------
#   COPY eg-apm-agent /opt/eg-apm-agent
#   ENV JAVA_OPTS="-javaagent:/opt/eg-apm-agent/eg-apm.jar"
ENV JAVA_OPTS=""
# ----------------------------------------------------------------------------

EXPOSE 8082
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
