# Windows Setup & Run Guide — eG Converged Application Demo

Follow these steps in order. Everything runs on your Windows machine using
minikube (a local single-node Kubernetes). Total install time is ~20–30 min the
first time, mostly downloads.

> Run every command in **PowerShell** (search Start menu → "PowerShell").
> For the install step, use an **Administrator** PowerShell window.

---

## Part 1 — Install the prerequisites

You need five tools: **Docker Desktop**, **minikube**, **kubectl**, **JDK 17**,
and **Maven**. The easiest way is `winget` (built into Windows 10/11).

### 1.1 Open PowerShell as Administrator
Start menu → type "PowerShell" → right-click → **Run as administrator**.

### 1.2 Install everything with winget
```powershell
winget install -e --id Docker.DockerDesktop
winget install -e --id Kubernetes.minikube
winget install -e --id Kubernetes.kubectl
winget install -e --id EclipseAdoptium.Temurin.17.JDK
winget install -e --id Apache.Maven
```

> No winget? Install [Chocolatey](https://chocolatey.org/install) and run:
> `choco install docker-desktop minikube kubernetes-cli temurin17 maven -y`
> Or download each manually: Docker Desktop, minikube, kubectl, Temurin JDK 17,
> and Maven from their official sites.

### 1.3 Close and reopen PowerShell
Close **all** PowerShell windows and open a **new** one (not necessarily admin)
so the updated PATH is picked up.

### 1.4 Start Docker Desktop
Launch **Docker Desktop** from the Start menu and wait until the whale icon in
the system tray says "Docker Desktop is running". Leave it running — minikube
uses it.

### 1.5 Verify the tools
```powershell
docker --version
minikube version
kubectl version --client
java -version      # must show 17.x
mvn -version       # must show Java version 17
```
If `java -version` shows something other than 17, set JAVA_HOME:
```powershell
# Adjust the path to your installed JDK 17 folder if different
$jdk = "C:\Program Files\Eclipse Adoptium\jdk-17*"
$env:JAVA_HOME = (Get-Item $jdk).FullName
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
java -version
```

---

## Part 2 — Start minikube

### 2.1 Start the cluster (Docker driver)
```powershell
minikube start --driver=docker --cpus=4 --memory=6144
```
This downloads the Kubernetes node image the first time (a few minutes). The
demo needs roughly 4 CPUs and 6 GB RAM; lower only if your machine is small.

### 2.2 Confirm it's up
```powershell
minikube status
kubectl get nodes
```
You should see the node in `Ready` state.

---

## Part 3 — Build & deploy the app

### 3.1 Go to the project folder
```powershell
cd C:\WorkItems\projects\RUMBTM\converged-demo
```

### 3.2 Allow the scripts to run (this session only)
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### 3.3 Run the deploy script
```powershell
.\deploy.ps1
```
This does four things automatically:
1. points Docker at minikube's internal daemon,
2. builds the three service jars with Maven,
3. builds the three container images,
4. applies the Kubernetes manifests and waits for everything to be ready.

When it finishes it prints the **Checkout page URL**, e.g.
`http://192.168.49.2:30080/`.

> **First run is the slowest** — Maven downloads dependencies and Docker pulls
> the MySQL / Artemis / httpbin base images. Later runs are much faster.

### 3.4 Confirm all pods are running
```powershell
kubectl -n converged-demo get pods
```
Wait until every pod shows `Running` and `1/1` ready (MySQL and Artemis take the
longest). Re-run the command until they're all green.

---

## Part 4 — Open and run the demo

### 4.1 Open the checkout page
Use the URL that `deploy.ps1` printed. If you didn't catch it:
```powershell
$ip = (minikube ip).Trim(); Start-Process "http://${ip}:30080/"
```
Open it in **Chrome** so the browser RUM / Session Replay story matches.

What to watch on the page:
- ~1 second after load, the promo banner and "You may also like" strip appear
  and **push the Place-order button downward** — that's the layout shift (CLS).
- Click where the button *was*, then click **Place order**. The page shows a
  "Submitting your order…" overlay for ~3–4 seconds while the slow `/placeOrder`
  Ajax runs (slow method + slow SQL + payment-gateway call).

### 4.2 Generate load so the message queue backs up
```powershell
.\load-test.ps1 40 4
```
This fires 40 checkouts, 4 at a time. Because the notification-worker consumes
slowly, the `order.notifications` queue builds a backlog.

### 4.3 View the Artemis queue backlog
In a **second** PowerShell window:
```powershell
kubectl -n converged-demo port-forward svc/artemis 8161:8161
```
Then open `http://localhost:8161` (login **admin / admin**) →
**Queues → order.notifications** and watch the message count climb and drain.

### 4.4 (Optional) Peek at the database
```powershell
kubectl -n converged-demo exec -it deploy/mysql -- mysql -ushop -pshoppass shopdb -e "SELECT * FROM orders ORDER BY id DESC LIMIT 10;"
```

---

## Part 5 — Tune the demo live (no rebuild)
```powershell
kubectl -n converged-demo set env deploy/order-service PRICING_DELAY_MS=3000
kubectl -n converged-demo set env deploy/order-service SQL_SLEEP_SECONDS=3
kubectl -n converged-demo set env deploy/notification-worker CONSUMER_PROCESSING_MS=8000
```
Each command restarts that pod with the new setting in a few seconds.

---

## Part 6 — Stop / clean up

Stop the cluster but keep it for next time:
```powershell
minikube stop
```
Remove just the demo (keep minikube):
```powershell
kubectl delete namespace converged-demo
```
Delete everything (fresh start next time):
```powershell
minikube delete
```

---

## Troubleshooting

**`deploy.ps1` cannot be loaded / running scripts is disabled**
Run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` first (Part 3.2).

**`mvn` or `java` not found**
Reopen PowerShell after installing (Part 1.3), or set JAVA_HOME (Part 1.5).

**`docker build` can't find the daemon / images don't show up in the pod**
`deploy.ps1` must run `minikube docker-env` in the *same* window. Don't build in
one window and deploy in another. Just re-run `.\deploy.ps1`.

**Pods stuck in `ImagePullBackOff`**
The image wasn't built into minikube. Re-run `.\deploy.ps1` from scratch in one
PowerShell session. The manifests use `imagePullPolicy: IfNotPresent` so they
rely on the locally built image.

**Pods stuck in `Pending` (not enough resources)**
Give minikube more room: `minikube stop; minikube delete; minikube start --driver=docker --cpus=4 --memory=8192`.

**Checkout page won't open**
Confirm the storefront pod is Running, then use a tunnel instead of NodePort:
`kubectl -n converged-demo port-forward svc/storefront 8080:8080` and open
`http://localhost:8080/`.

**Docker Desktop not running**
Start it and wait for "Docker Desktop is running" before `minikube start`.

---

## Quick reference (once everything is installed)
```powershell
minikube start --driver=docker --cpus=4 --memory=6144
cd C:\WorkItems\projects\RUMBTM\converged-demo
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\deploy.ps1
.\load-test.ps1 40 4
```
