# RHEL

# In order to list all users on Linux, use the cat command as follows:
`cat /etc/passwd`

# yum (no proxy)
```
yum update
yum install git
```

# Proxy
```
export http_proxy=http://<proxy>:8080
export https_proxy=http://<proxy>:8080:8080

echo "$http_proxy"
echo "$https_proxy"
```

# Install Git
```
https://gitlab.com/CGFootman-BASH/rhel-upgrade-git/-/blob/master/rhel-upgrade-git.sh
sudo git config --global user.name "User"
sudo git config --global user.email "mail@server.com"
```

# Install Terraform
```
wget https://raw.githubusercontent.com/segraef/Scripts/snippets/terraform_1.3.4_linux_amd64.zip
unzip terraform_1.3.4_linux_amd64.zip
mv terraform /usr/bin/ or /usr/local/bin/
chmod 777 /usr/bin/terraform
terraform --version
```

# Install PowerShell

```
sudo yum install https://github.com/PowerShell/PowerShell/releases/download/v7.3.0/powershell-7.3.0-1.rh.x86_64.rpm
```

```
sudo yum install azure-cli
sudo yum install telnet
```


# Show current services

```
service --status-all
```

# Create proxybypass file

```
echo $'dev.azure.com
management.azure.com
login.microsoftonline.com
tcp0000vsn9025devba.blob.core.windows.net
10.54.177.149' > .proxybypass
```

# Remove directory

```
rm -rf directory/
```
