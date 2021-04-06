FROM adoptopenjdk:11.0.10_9-jdk-hotspot

ADD target/!PROJECT_NAME*.jar /app.jar

ENTRYPOINT ["sh","-c","java -jar /app.jar"]