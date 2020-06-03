ARG jdkVersion
FROM jdk:${jdkVersion}
WORKDIR /home/admin
ARG JAR_PATH
ARG JAR_FILE
ADD ${JAR_PATH} ./${JAR_FILE}
ADD ./entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

