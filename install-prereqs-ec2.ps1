# Direct-download installer for EC2 / Windows Server where winget's msstore
# source fails (error 0x8a15005e). Installs JDK 17, Maven, kubectl, minikube.
# Run in an ELEVATED PowerShell:  Run as administrator.
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   .\install-prereqs-ec2.ps1
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$tools = "C:\tools"
New-Item -ItemType Directory -Force -Path $tools | Out-Null

function Add-ToUserPath($dir) {
    $cur = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($cur -notlike "*$dir*") {
        [Environment]::SetEnvironmentVariable("Path", "$cur;$dir", "Machine")
    }
    $env:Path = "$env:Path;$dir"
}

# ---- JDK 17 (Eclipse Temurin, MSI sets JAVA_HOME + PATH) --------------------
Write-Host "==> Installing Temurin JDK 17" -ForegroundColor Cyan
$jdkMsi = "$env:TEMP\temurin17.msi"
Invoke-WebRequest -UseBasicParsing `
  "https://api.adoptium.net/v3/installer/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse" `
  -OutFile $jdkMsi
Start-Process msiexec.exe -Wait -ArgumentList `
  "/i `"$jdkMsi`" ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJavaHome /quiet"

# ---- Maven -----------------------------------------------------------------
Write-Host "==> Installing Maven 3.9.9" -ForegroundColor Cyan
$mvnZip = "$env:TEMP\maven.zip"
Invoke-WebRequest -UseBasicParsing `
  "https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip" `
  -OutFile $mvnZip
Expand-Archive -Path $mvnZip -DestinationPath $tools -Force
Add-ToUserPath "$tools\apache-maven-3.9.9\bin"

# ---- kubectl ---------------------------------------------------------------
Write-Host "==> Installing kubectl" -ForegroundColor Cyan
$kver = (Invoke-WebRequest -UseBasicParsing "https://dl.k8s.io/release/stable.txt").Content.Trim()
Invoke-WebRequest -UseBasicParsing `
  "https://dl.k8s.io/release/$kver/bin/windows/amd64/kubectl.exe" `
  -OutFile "$tools\kubectl.exe"

# ---- minikube --------------------------------------------------------------
Write-Host "==> Installing minikube" -ForegroundColor Cyan
Invoke-WebRequest -UseBasicParsing `
  "https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe" `
  -OutFile "$tools\minikube.exe"

Add-ToUserPath $tools

Write-Host ""
Write-Host "Done. CLOSE this PowerShell window and open a NEW one, then verify:" -ForegroundColor Green
Write-Host "  java -version ; mvn -version ; kubectl version --client ; minikube version"
Write-Host ""
Write-Host "NOTE: Docker is NOT installed by this script - see the EC2 note from Claude." -ForegroundColor Yellow
