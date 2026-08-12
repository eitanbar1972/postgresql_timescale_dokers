param(
    [switch]$StatusOnly,
    [switch]$RecoverAfterRestart,
    [switch]$StartKubernetesManifests,
    [int]$DockerWaitSeconds = 120,
    [int]$KubernetesWaitSeconds = 120
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$DockerDesktopExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
$DockerServiceName = "com.docker.service"
$ClusterNamespaces = @("default", "timescaledb")
$Summary = [System.Collections.Generic.List[string]]::new()

$DockerClusters = @(
    @{
        Name = "cluster1"
        ComposeFile = Join-Path $RepoRoot "docker\pgclusters\cluster1\docker-compose.yml"
        Containers = @("pg1-primary", "pg1-replica")
    },
    @{
        Name = "cluster2"
        ComposeFile = Join-Path $RepoRoot "docker\pgclusters\cluster2\docker-compose.yml"
        Containers = @("pg2-primary", "pg2-replica")
    }
)

$KubernetesFiles = @(
    (Join-Path $RepoRoot "kubernetes\namespace.yaml"),
    (Join-Path $RepoRoot "kubernetes\imagecatalog-timescaledb.yaml"),
    (Join-Path $RepoRoot "kubernetes\cluster-timescaledb.yaml")
)

function Write-Section {
    param([string]$Title)

    Write-Host ""
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Add-Summary {
    param([string]$Message)

    $Summary.Add($Message) | Out-Null
}

function Test-CommandAvailable {
    param([string]$Name)

    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-DockerComposeCommand {
    if (-not (Test-CommandAvailable "docker")) {
        return $null
    }

    try {
        & docker compose version *> $null
        return @("docker", "compose")
    }
    catch {
        if (Test-CommandAvailable "docker-compose") {
            return @("docker-compose")
        }
    }

    return $null
}

function Invoke-Compose {
    param(
        [string[]]$ComposeCommand,
        [string]$ComposeFile,
        [string[]]$Arguments
    )

    if ($ComposeCommand.Count -eq 2) {
        & $ComposeCommand[0] $ComposeCommand[1] -f $ComposeFile @Arguments
        return
    }

    & $ComposeCommand[0] -f $ComposeFile @Arguments
}

function Test-DockerReady {
    if (-not (Test-CommandAvailable "docker")) {
        return $false
    }

    try {
        & docker info *> $null
        return $true
    }
    catch {
        return $false
    }
}

function Wait-Until {
    param(
        [scriptblock]$Condition,
        [int]$TimeoutSeconds,
        [int]$PollSeconds = 5,
        [string]$WaitingMessage
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (& $Condition) {
            return $true
        }

        if ($WaitingMessage) {
            Write-Host $WaitingMessage
        }

        Start-Sleep -Seconds $PollSeconds
    }

    return $false
}

function Ensure-DockerDesktop {
    Write-Section "Docker Engine"

    if (-not (Test-CommandAvailable "docker")) {
        Write-Warning "docker CLI is not installed or not in PATH."
        Add-Summary "Docker CLI not available."
        return $false
    }

    if (Test-DockerReady) {
        Write-Host "Docker engine is already running." -ForegroundColor Green
        Add-Summary "Docker engine already running."
        return $true
    }

    $service = Get-Service -Name $DockerServiceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "Docker Desktop service status: $($service.Status)"
    }

    if (-not (Test-Path $DockerDesktopExe)) {
        Write-Warning "Docker Desktop executable not found at $DockerDesktopExe"
        Add-Summary "Docker Desktop executable not found."
        return $false
    }

    Write-Host "Launching Docker Desktop..."
    Start-Process -FilePath $DockerDesktopExe -WindowStyle Hidden

    if (Wait-Until -Condition { Test-DockerReady } -TimeoutSeconds $DockerWaitSeconds -WaitingMessage "Waiting for Docker engine...") {
        Write-Host "Docker engine is ready." -ForegroundColor Green
        Add-Summary "Docker engine started successfully."
        return $true
    }

    Write-Warning "Docker engine did not become ready within $DockerWaitSeconds seconds."
    Add-Summary "Docker engine did not become ready within timeout."
    return $false
}

function Get-ContainerStatus {
    param([string]$ContainerName)

    return (& docker ps -a --filter "name=^/$ContainerName$" --format "{{.Names}}|{{.Status}}") 2>$null
}

function Show-DockerStatus {
    param([string[]]$ComposeCommand)

    Write-Section "Docker PostgreSQL Clusters"

    if (-not $ComposeCommand) {
        Write-Warning "Docker Compose is not available."
        Add-Summary "Docker Compose not available."
        return
    }

    if (-not (Test-DockerReady)) {
        Write-Warning "Docker engine is not reachable."
        Add-Summary "Docker engine not reachable during status check."
        return
    }

    foreach ($cluster in $DockerClusters) {
        Write-Host ""
        Write-Host "[$($cluster.Name)]"

        foreach ($container in $cluster.Containers) {
            $status = Get-ContainerStatus -ContainerName $container
            if ([string]::IsNullOrWhiteSpace($status)) {
                Write-Host "  $container : not created" -ForegroundColor Yellow
            }
            else {
                Write-Host "  $status"
            }
        }
    }
}

function Start-DockerClusters {
    param([string[]]$ComposeCommand)

    Write-Section "Starting Docker PostgreSQL Clusters"

    if (-not $ComposeCommand) {
        Write-Warning "Skipping Docker cluster startup because Docker Compose is not available."
        Add-Summary "Skipped Docker cluster startup because Docker Compose is unavailable."
        return
    }

    if (-not (Test-DockerReady)) {
        Write-Warning "Skipping Docker cluster startup because Docker engine is not ready."
        Add-Summary "Skipped Docker cluster startup because Docker engine is not ready."
        return
    }

    foreach ($cluster in $DockerClusters) {
        Write-Host "Starting $($cluster.Name)..."
        Invoke-Compose -ComposeCommand $ComposeCommand -ComposeFile $cluster.ComposeFile -Arguments @("up", "-d")
    }

    Add-Summary "Docker Compose clusters started."
}

function Test-KubectlReady {
    if (-not (Test-CommandAvailable "kubectl")) {
        return $false
    }

    try {
        & kubectl get nodes *> $null
        return $true
    }
    catch {
        return $false
    }
}

function Ensure-KubernetesApi {
    Write-Section "Kubernetes API"

    if (-not (Test-CommandAvailable "kubectl")) {
        Write-Warning "kubectl is not installed or not in PATH."
        Add-Summary "kubectl not available."
        return $false
    }

    $context = & kubectl config current-context 2>$null
    if ([string]::IsNullOrWhiteSpace($context)) {
        Write-Warning "kubectl has no current context."
        Add-Summary "kubectl has no current context."
        return $false
    }

    Write-Host "kubectl context: $context"

    if (Test-KubectlReady) {
        Write-Host "Kubernetes API is reachable." -ForegroundColor Green
        Add-Summary "Kubernetes API reachable on context $context."
        return $true
    }

    Write-Host "Kubernetes API is not reachable yet. Waiting for it to recover..."
    if (Wait-Until -Condition { Test-KubectlReady } -TimeoutSeconds $KubernetesWaitSeconds -WaitingMessage "Waiting for Kubernetes API...") {
        Write-Host "Kubernetes API is ready." -ForegroundColor Green
        Add-Summary "Kubernetes API recovered on context $context."
        return $true
    }

    Write-Warning "Kubernetes API did not become ready within $KubernetesWaitSeconds seconds."
    Add-Summary "Kubernetes API did not become ready within timeout."
    return $false
}

function Get-ImageNameFromClusterManifest {
    $clusterManifest = Join-Path $RepoRoot "kubernetes\cluster-timescaledb.yaml"
    if (-not (Test-Path $clusterManifest)) {
        return $null
    }

    $line = Select-String -Path $clusterManifest -Pattern "^\s*imageName:\s*(.+)$" | Select-Object -First 1
    if (-not $line) {
        return $null
    }

    return $line.Matches[0].Groups[1].Value.Trim()
}

function Show-KubernetesStatus {
    Write-Section "Kubernetes Status"

    if (-not (Test-KubectlReady)) {
        Write-Warning "Skipping Kubernetes status because the API is not reachable."
        Add-Summary "Skipped Kubernetes status because the API is not reachable."
        return
    }

    Write-Host ""
    Write-Host "[CloudNativePG operator pods]"
    & kubectl get pods -A -l app.kubernetes.io/name=cloudnative-pg

    foreach ($namespace in $ClusterNamespaces) {
        Write-Host ""
        Write-Host "[Pods in namespace: $namespace]"
        try {
            & kubectl get pods -n $namespace
        }
        catch {
            Write-Warning "Namespace '$namespace' is not available."
        }

        Write-Host ""
        Write-Host "[CloudNativePG clusters in namespace: $namespace]"
        try {
            & kubectl get cluster -n $namespace
        }
        catch {
            Write-Warning "No CloudNativePG Cluster resources found in namespace '$namespace'."
        }
    }
}

function Start-KubernetesManifestsIfRequested {
    if (-not $StartKubernetesManifests) {
        Add-Summary "Kubernetes manifests were not applied in this run."
        return
    }

    Write-Section "Applying Kubernetes Manifests"

    if (-not (Test-KubectlReady)) {
        Write-Warning "Skipping manifest apply because the Kubernetes API is not reachable."
        Add-Summary "Skipped Kubernetes manifest apply because the API is not reachable."
        return
    }

    $imageName = Get-ImageNameFromClusterManifest
    if ($imageName -match "your-registry\.example\.com|REGISTRY/IMAGE_NAME|IMAGE_TAG") {
        Write-Warning "The image in kubernetes\cluster-timescaledb.yaml still looks like a placeholder: $imageName"
        Write-Warning "Update the image reference before applying the cluster manifest."
        Add-Summary "Skipped Kubernetes manifest apply because the cluster image is still a placeholder."
        return
    }

    foreach ($file in $KubernetesFiles) {
        if (-not (Test-Path $file)) {
            Write-Warning "Skipping missing manifest: $file"
            continue
        }

        Write-Host "Applying $file..."
        & kubectl apply -f $file
    }

    Add-Summary "Kubernetes manifests applied."
}

function Show-Summary {
    Write-Section "Summary"

    foreach ($line in $Summary) {
        Write-Host "- $line"
    }
}

Write-Host "Repository root: $RepoRoot"
$composeCommand = Get-DockerComposeCommand

if ($StatusOnly) {
    Show-DockerStatus -ComposeCommand $composeCommand
    Show-KubernetesStatus
    Show-Summary
    return
}

if (-not $RecoverAfterRestart) {
    $RecoverAfterRestart = $true
}

if ($RecoverAfterRestart) {
    $dockerReady = Ensure-DockerDesktop
    if ($dockerReady) {
        Start-DockerClusters -ComposeCommand $composeCommand
    }

    $kubernetesReady = Ensure-KubernetesApi
    if ($kubernetesReady) {
        Start-KubernetesManifestsIfRequested
    }
}

Write-Host ""
Write-Host "Refreshing final status..." -ForegroundColor Cyan
Show-DockerStatus -ComposeCommand $composeCommand
Show-KubernetesStatus
Show-Summary
