# Use the official Tomcat image as the base image
FROM tomcat:latest

# Remove the default webapps that come with Tomcat
RUN rm -rf /usr/local/tomcat/webapps/*

# Copy the .war file into the Tomcat webapps directory
COPY /SampleWeApp/target/SampleWebApp.war /usr/local/tomcat/webapps/ROOT.war

# Expose port 8080 (the default Tomcat port)
EXPOSE 8080

# Start Tomcat when the container starts
CMD ["catalina.sh", "run"]
