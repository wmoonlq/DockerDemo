# demo

最小可启动的 Spring Boot 工程（Spring Boot 3.5.7 / Java 17 / Maven）。

## 结构

```
pom.xml
src/main/java/com/example/demo/DemoApplication.java   # 启动类
src/main/resources/application.yml                    # 端口 8080、应用名 demo
```

## 运行

```bash
# 开发模式
mvn spring-boot:run

# 打包后运行
mvn -DskipTests package
java -jar target/demo-0.0.1-SNAPSHOT.jar
```

启动成功后访问 http://localhost:8080 （当前无 Controller，返回 404 属正常）。
目前仅引入 `spring-boot-starter-web`，未接数据库、未加 Controller，按需再扩展。
