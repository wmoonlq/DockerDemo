# DockerDemo

最小可启动的 Spring Boot 服务 + 一套按主流规范写的容器化配置。

- Spring Boot 3.5.7 / Java 17 / Maven
- 代码：`DemoApplication`（启动类）、`DemoController`（`GET /`）
- 容器：多阶段构建、非 root、健康检查、优雅停机、依赖缓存

## 目录

```
pom.xml
Dockerfile              # 多阶段构建：maven 编译 -> temurin JRE 运行
docker-compose.yml      # 服务定义 + 健康检查 + 日志轮转
maven-settings.xml      # 镜像内构建用的阿里云 Maven 源
.dockerignore           # 不把 target/.git 传给构建上下文
src/main/java/com/example/demo/
  DemoApplication.java
  DemoController.java
src/main/resources/application.yml
```

## 本地跑

```bash
mvn spring-boot:run
curl http://localhost:8080/                 # demo is running
curl http://localhost:8080/actuator/health  # {"status":"UP",...}
```

## 容器跑

```bash
docker compose up -d --build      # 首次要拉基础镜像 + 下依赖，之后重建很快
docker compose ps                 # STATUS 应为 healthy
docker compose logs -f demo-backend
curl http://localhost:8080/actuator/health
docker compose down
```

## Dockerfile 为什么这么写

| 做法 | 作用 |
|---|---|
| 多阶段构建 | 构建镜像 500MB+，运行镜像只含 JRE + jar |
| `COPY pom.xml` 先于 `COPY src` | 改代码不会让依赖层失效，重建只重跑编译 |
| `RUN --mount=type=cache,target=/root/.m2` | Maven 本地库挂在 BuildKit 缓存上，**跨构建复用**，不会每次重下 |
| `maven-settings.xml` 阿里云镜像 | 绕开 Maven Central 在国内的龟速/超时 |
| `.dockerignore` | 上下文从几百 MB 降到几十 KB |
| `adduser` + `USER app` | 非 root 运行 |
| `JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=75` | 按容器内存限额算堆，不写死 `-Xmx` |
| `ENTRYPOINT` exec 形式 + `shutdown: graceful` | SIGTERM 能直达 JVM，在途请求处理完再退 |
| compose `healthcheck` + `restart: unless-stopped` | 进程活着但接口不通也能被发现并重启 |
| compose `logging` 限制 | json-file 日志不会把磁盘写满 |

## 两种部署方式：镜像内编译 vs 只拷 jar

**A. 镜像内编译（本仓库默认，推荐）**
自包含、可复现，CI 里一条 `docker build` 就能出镜像，源码和镜像严格对应。
第一次慢是因为要拉基础镜像 + 下依赖；因为有缓存挂载和国内源，**第二次开始只编译，通常 20 秒内**。

**B. 先打包再拷 jar（云端 CI 常见）**
构建机先 `mvn package`，镜像只做 `COPY`，构建 2 秒级、镜像更小；代价是镜像不再自包含，换台机器构建可能因 JDK/Maven 版本不同产出不同产物。

如果你某天只想跑 B（例如弱网、或本机已经有 jar），把 Dockerfile 的构建阶段换掉即可（同时要把 `.dockerignore` 里的 `target` 删掉，否则 jar 传不进构建上下文）：

```dockerfile
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
RUN addgroup -S app && adduser -S -G app app
COPY --chown=app:app target/*.jar /app/app.jar
USER app
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

> 顺带一句：`target/*.jar` 是“fat jar”（含依赖的完整可执行包），不是“炸包”，跟另一种做法没有新旧之分，只有适用场景不同。

## 排障

**拉基础镜像很慢 / 卡住**：问题在 registry，不在 Dockerfile。`/etc/docker/daemon.json` 里 mirror 不要堆几十个，失效的源会逐个超时。留 2~3 个实测可用的即可：

```json
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1panel.live",
    "https://hub.rat.dev"
  ],
  "max-concurrent-downloads": 6
}
```

改完 `systemctl restart docker`。

**Maven 依赖下载超时**：确认构建用的是 `maven-settings.xml`（Dockerfile 里已 `-s` 指定）；本机开发可直接在 `~/.m2/settings.xml` 配同样的 mirror。

**容器 unhealthy**：`docker compose logs demo-backend` 看启动日志；健康检查走 `/actuator/health`，端口或 context-path 改了要同步改 `docker-compose.yml` 的 `test`。
