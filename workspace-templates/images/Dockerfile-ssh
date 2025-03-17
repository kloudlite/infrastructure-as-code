FROM ubuntu:24.04

# Install OpenSSH Server
RUN apt-get update && apt-get install -y openssh-server && \
    mkdir /var/run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'root:rootpassword' | chpasswd

# Expose SSH Port
EXPOSE 22

# Start SSH Daemon
CMD ["/usr/sbin/sshd", "-D"]