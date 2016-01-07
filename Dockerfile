FROM nordstrom/java:8

ENV KAFKA_VERSION=0.9.0.0 \
    SCALA_VERSION=2.11.7

COPY confluent_platform_2_0.key /tmp/
RUN echo "deb http://packages.confluent.io/deb/2.0 stable main" > /etc/apt/sources.list.d/confluent.list \
 && apt-key add /tmp/confluent_platform_2_0.key
RUN mkdir -p /kafka/config /kafka/data /kafka/logs /kafka/templates \
 && apt-get update -qy \
 && apt-get install -qy confluent-kafka-${SCALA_VERSION}=${KAFKA_VERSION}-1 \
 && rm /etc/kafka/server.properties /etc/kafka/log4j.properties /etc/kafka/tools-log4j.properties

ADD  config /kafka/templates/
COPY entrypoint.sh /

ENV JMX_PORT=7203 \
    KAFKA_JVM_PERFORMANCE_OPTS="-XX:MetaspaceSize=48m -XX:MaxMetaspaceSize=48m -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+DisableExplicitGC -Djava.awt.headless=true"

#USER kafka

ENTRYPOINT [ "/entrypoint.sh" ]

CMD [ "kafka-server-start", "/etc/kafka/server.properties" ]

# Kafka, JMX
EXPOSE 9092 7203
