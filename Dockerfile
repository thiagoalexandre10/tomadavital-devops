# Tomada Vital - imagem da API Java
# Etapa 1: compila o projeto com o Maven Wrapper que ja vem no repositorio
FROM eclipse-temurin:25-jdk AS build
WORKDIR /build
COPY . .
RUN chmod +x mvnw && ./mvnw -q -DskipTests package

# Etapa 2: imagem final, so com o Java para rodar (menor e mais segura)
FROM eclipse-temurin:25-jre
WORKDIR /app
RUN groupadd --system tomadavital \
 && useradd --system --gid tomadavital --no-create-home tomadavital
COPY --from=build /build/target/*.jar app.jar
RUN chown -R tomadavital:tomadavital /app
USER tomadavital
ENV SPRING_PROFILES_ACTIVE=docker
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
