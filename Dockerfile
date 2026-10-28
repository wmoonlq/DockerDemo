# syntax 指令和 frontend 镜像都不需要，Docker 26 自带 BuildKit，
# 少拉一个 docker/dockerfile 镜像，弱网下能省一次超时。

# ========== 阶段一：构建（镜像内编译，产物可复现，CI 友好） ==========
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /build

# 国内加速：阿里云中央仓库镜像（无凭证，可安全提交）
COPY maven-settings.xml /build/maven-settings.xml

# 先只拷 pom：只要依赖没变，这一层和下一步直接命中缓存
COPY pom.xml /build/pom.xml
# 这一步只是预热本地库（失败不影响后续编译，后续 package 会补齐），
# 真正保证速度的是 /root/.m2 的缓存挂载
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -s /build/maven-settings.xml dependency:go-offline || true

# 再拷源码：改业务代码只会让这层之后失效，依赖层仍然复用
COPY src /build/src
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -s /build/maven-settings.xml -DskipTests package

# ========== 阶段二：运行（只留 JRE + jar） ==========
FROM eclipse-temurin:17-jre-alpine AS runtime
WORKDIR /app

# 非 root 运行：容器逃逸时的影响面小很多
RUN addgroup -S app && adduser -S -G app app

COPY --from=builder --chown=app:app /build/target/*.jar /app/app.jar

USER app
EXPOSE 8080

# 容器内存感知 + OOM 退出而非僵死 + 时区 + UTF-8
ENV TZ=Asia/Shanghai \
    JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError -Duser.timezone=Asia/Shanghai -Dfile.encoding=UTF-8"

# exec 形式：java 直接是 PID 1，SIGTERM 能收到，配合 server.shutdown=graceful 正常停机
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
