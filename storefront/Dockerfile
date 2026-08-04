# Build the jar first with: mvn -pl storefront -am package
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY target/storefront.jar app.jar

# --- eG Java APM agent (add manually) ---------------------------------------
# Drop the agent jar into the image and prepend it to JAVA_OPTS, e.g.:
#   COPY eg-apm-agent /opt/eg-apm-agent
#   ENV JAVA_OPTS="-javaagent:/opt/eg-apm-agent/eg-apm.jar"
ENV JAVA_OPTS=""
# ----------------------------------------------------------------------------

EXPOSE 8080
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
