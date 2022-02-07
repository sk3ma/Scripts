#!/usr/bin/env bash

#############################################################################
# The purpose of the script is to automate a Tomcat installation on Ubuntu. #          
# The script installs Java, Tomcat and creates a systemd service.           # 
#############################################################################

# Declaring variables.
VERSION=9.0.56
#USERID=$(id -u)

# Sanity checking.
#if [[ ${USERID} -ne "0" ]]; then
#    echo -e "\e[1;3mYou must be root, exiting.\e[m"
#    exit 1
#fi

# Java installation.
java() {
    echo -e "\e[1;3mInstalling Java\e[m"
    cd /tmp
    sudo apt update
    sudo apt install openjdk-11-jdk -qy
}

# Tomcat installation.
tomcat() {
    echo -e "\e[1;3mInstalling Tomcat\e[m"
    sudo mkdir /opt/tomcat
    sudo useradd -mUd /opt/tomcat -s /bin/false tomcat
    sudo wget --progress=bar:force https://dlcdn.apache.org/tomcat/tomcat-9/v${VERSION}/bin/apache-tomcat-${VERSION}.tar.gz
    sudo tar -xvzf apache-tomcat-${VERSION}.tar.gz
    sudo mv apache-tomcat-${VERSION} /opt/tomcat
    sudo ln -s /opt/tomcat/apache-tomcat-${VERSION} /opt/tomcat/latest
}

# Changing permissions.
permissions() {
    echo -e "\e[1;3mAdjusting permissions\e[m"
    sudo chown -R tomcat: /opt/tomcat
    sudo bash -c 'chmod +x /opt/tomcat/latest/bin/*.sh'
}

# Adding exception.
firewall() {
    echo -e "\e[1;3mAdjusting firewall\e[m"
    sudo sed -ie 's/port="8080"/port="8090"/g' /opt/tomcat/latest/conf/server.xml
    sudo ufw allow 8090/tcp
    echo "y" | sudo ufw enable
    sudo ufw reload
}

# Creating unit file.
create() {
    echo -e "\e[1;3mCreating service\e[m"
    cd /etc/systemd/system/
    sudo tee tomcat-ubuntu << STOP
[Unit]
Description=Tomcat 9 servlet container
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64"
Environment="JAVA_OPTS=-Djava.security.egd=file:///dev/urandom -Djava.awt.headless=true"

Environment="CATALINA_BASE=/opt/tomcat/latest"
Environment="CATALINA_HOME=/opt/tomcat/latest"
Environment="CATALINA_PID=/opt/tomcat/latest/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"

ExecStart=/opt/tomcat/latest/bin/startup.sh
ExecStop=/opt/tomcat/latest/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
STOP
    sudo mv tomcat-ubuntu tomcat.service
    sudo systemctl daemon-reload
    sudo systemctl start tomcat
}

# Tomcat users.
users() {
    echo -e "\e[1;3mCreating users\e[m"
    sudo cp /opt/tomcat/latest/conf/tomcat-users.xml /opt/tomcat/latest/conf/tomcat-users.orig
    sudo rm -f /opt/tomcat/latest/conf/tomcat-users.xml
    sudo tee -a /opt/tomcat/latest/conf/tomcat-users.xml << STOP
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">
 <role rolename="manager-gui"/>
 <role rolename="manager-script"/>
 <role rolename="manager-jmx"/>
 <role rolename="manager-status"/>
 <user username="admin" password="adm1n" roles="manager-gui, manager-script, manager-jmx, manager-status"/>
 <user username="deployer" password="depl0yer" roles="manager-script"/>
 <user username="tomcat" password="s3cret" roles="manager-gui"/>
</tomcat-users>
STOP
}

# Enabling service.
start() {
    echo -e "\e[1;3mEnabling service\e[m"
    sudo systemctl enable tomcat
    sudo systemctl restart tomcat  
    echo -e "\e[1;3;5mInstallation is complete\e[m"
    exit
}

# Calling functions.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[1;3mUbuntu detected...\e[m"
    java
    tomcat
    permissions
    firewall
    create
    users
    start
fi
