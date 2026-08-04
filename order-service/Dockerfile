# Build the jar first with: mvn -pl order-service -am package
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY target/order-service.jar app.jar

# --- eG Java APM agent (add manually) ---------------------------------------
# This is the most important tier to instrument (Checkout business transaction,
# slow method, SQL exit call, downstream exit call). Example:
#   COPY eg-apm-agent /opt/eg-apm-agent
#   ENV JAVA_OPTS="-javaagent:/opt/eg-apm-agent/eg-apm.jar"
ENV JAVA_OPTS=""
# ----------------------------------------------------------------------------

EXPOSE 8081
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
