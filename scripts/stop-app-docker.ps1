Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$containers = @(
    "college-erp-frontend-run",
    "college-erp-backend-run",
    "college-erp-db-run"
)

$existing = docker ps -a --format "{{.Names}}"
foreach ($container in $containers) {
    if ($existing -contains $container) {
        docker rm -f $container | Out-Null
        Write-Host "Removed $container"
    }
}

Write-Host "Docker run containers stopped."
