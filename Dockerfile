# 第一阶段：maven编译源码，打出jar包
FROM maven:3.8.8-eclipse-temurin-17 AS builder
WORKDIR /build
# 先复制pom，缓存依赖，加速构建
COPY pom.xml .
RUN mvn dependency:go-offline
# 复制源代码
COPY src ./src
# 打包，跳过测试
RUN mvn package -DskipTests

# 第二阶段：运行阶段，轻量jre镜像，只保留jar
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
# 从builder阶段拷贝打好的jar
COPY --from=builder /build/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","app.jar"]
