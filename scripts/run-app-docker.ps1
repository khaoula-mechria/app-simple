Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-EnvMap {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $map = @{}
    foreach ($line in Get-Content $Path) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        if ($line.TrimStart().StartsWith("#")) {
            continue
        }

        $parts = $line -split "=", 2
        if ($parts.Count -eq 2) {
            $map[$parts[0].Trim()] = $parts[1].Trim()
        }
    }

    return $map
}

function Test-ExactValue {
    param(
        [string[]]$Values,
        [string]$Expected
    )

    return @($Values) -contains $Expected
}

function Ensure-DockerObject {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("network", "volume")]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $existing = docker $Type ls --format "{{.Name}}"
    if (-not (Test-ExactValue -Values $existing -Expected $Name)) {
        docker $Type create $Name | Out-Null
    }
}

function Remove-ContainerIfExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $existing = docker ps -a --format "{{.Names}}"
    if (Test-ExactValue -Values $existing -Expected $Name) {
        docker rm -f $Name | Out-Null
    }
}

function Wait-ForPostgres {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContainerName,

        [Parameter(Mandatory = $true)]
        [string]$User,

        [Parameter(Mandatory = $true)]
        [string]$Database,

        [int]$TimeoutSeconds = 60
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $status = docker inspect -f "{{.State.Status}}" $ContainerName 2>$null
        if ($status -eq "running") {
            docker exec $ContainerName pg_isready -U $User -d $Database *> $null
            if ($LASTEXITCODE -eq 0) {
                return
            }
        } elseif ($status -eq "exited") {
            $logs = docker logs $ContainerName 2>&1
            throw "PostgreSQL container '$ContainerName' exited before becoming ready.`n$logs"
        }

        if (-not $status) {
            throw "PostgreSQL container '$ContainerName' could not be inspected."
        }

        Start-Sleep -Seconds 2
    }

    $logs = docker logs $ContainerName 2>&1
    throw "PostgreSQL container '$ContainerName' did not become ready within $TimeoutSeconds seconds.`n$logs"
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$envPath = Join-Path $projectRoot ".env"
$nginxConfig = (Resolve-Path (Join-Path $projectRoot "docker\nginx\default.conf")).Path

if (-not (Test-Path $envPath)) {
    throw "Missing .env file at $envPath. Create it first from .env.example."
}

$envMap = Get-EnvMap -Path $envPath
$frontendPort = if ($envMap.ContainsKey("FRONTEND_PORT") -and $envMap["FRONTEND_PORT"]) {
    $envMap["FRONTEND_PORT"]
} else {
    "8081"
}
$postgresUser = if ($envMap.ContainsKey("POSTGRES_USER") -and $envMap["POSTGRES_USER"]) {
    $envMap["POSTGRES_USER"]
} else {
    "postgres"
}
$postgresDb = if ($envMap.ContainsKey("POSTGRES_DB") -and $envMap["POSTGRES_DB"]) {
    $envMap["POSTGRES_DB"]
} else {
    "postgres"
}

if (Get-NetTCPConnection -LocalPort ([int]$frontendPort) -ErrorAction SilentlyContinue) {
    throw "Port $frontendPort is already in use. Update FRONTEND_PORT in .env or free that port."
}

$networkName = "college-erp-run-net"
$dbVolume = "college-erp-run-postgres-data"
$staticVolume = "college-erp-run-static"
$mediaVolume = "college-erp-run-media"

$dbContainer = "college-erp-db-run"
$backendContainer = "college-erp-backend-run"
$frontendContainer = "college-erp-frontend-run"
$backendImage = "college-erp-backend:latest"

Write-Host "Building backend image..."
docker build -t $backendImage $projectRoot

Write-Host "Preparing network and volumes..."
Ensure-DockerObject -Type network -Name $networkName
Ensure-DockerObject -Type volume -Name $dbVolume
Ensure-DockerObject -Type volume -Name $staticVolume
Ensure-DockerObject -Type volume -Name $mediaVolume

Write-Host "Removing previous containers if they exist..."
Remove-ContainerIfExists -Name $frontendContainer
Remove-ContainerIfExists -Name $backendContainer
Remove-ContainerIfExists -Name $dbContainer

Write-Host "Starting PostgreSQL..."
docker run -d `
    --name $dbContainer `
    --network $networkName `
    --network-alias db `
    --restart unless-stopped `
    --env-file $envPath `
    -v "${dbVolume}:/var/lib/postgresql/data" `
    postgres:16-alpine | Out-Null

Wait-ForPostgres -ContainerName $dbContainer -User $postgresUser -Database $postgresDb

Write-Host "Starting Django backend..."
docker run -d `
    --name $backendContainer `
    --network $networkName `
    --network-alias backend `
    --restart unless-stopped `
    --env-file $envPath `
    -e STATIC_ROOT=/app/staticfiles `
    -e MEDIA_ROOT=/app/media `
    -e STATICFILES_STORAGE=whitenoise.storage.CompressedStaticFilesStorage `
    -v "${staticVolume}:/app/staticfiles" `
    -v "${mediaVolume}:/app/media" `
    $backendImage | Out-Null

Write-Host "Starting nginx frontend on port $frontendPort..."
docker run -d `
    --name $frontendContainer `
    --network $networkName `
    --restart unless-stopped `
    -p "${frontendPort}:80" `
    -v "${nginxConfig}:/etc/nginx/conf.d/default.conf:ro" `
    -v "${staticVolume}:/app/staticfiles:ro" `
    -v "${mediaVolume}:/app/media:ro" `
    nginx:1.27-alpine | Out-Null

Write-Host ""
Write-Host "Application started successfully."
Write-Host "App URL: http://localhost:$frontendPort"
Write-Host "Admin URL: http://localhost:$frontendPort/admin/"
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  docker logs -f $backendContainer"
Write-Host "  docker logs -f $frontendContainer"
Write-Host "  docker exec -it $backendContainer python manage.py createsuperuser"
