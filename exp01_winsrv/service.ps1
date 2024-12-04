param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('install', 'remove', 'start', 'stop', 'status')]
    [string]$Action
)

$ServiceName = "Exp01WinService"
$BinaryPath = Join-Path $PSScriptRoot "target\release\exp01_winsrv.exe"
$DisplayName = "Experiment 01 Windows Service"
$Description = "A Rust-based Windows Service Example"

# Ensure running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

function Install-Service {
    if (-not (Test-Path $BinaryPath)) {
        Write-Error "Service executable not found at: $BinaryPath. Please build the project first with 'cargo build --release'"
        exit 1
    }

    try {
        $existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($existingService) {
            Write-Warning "Service already exists. Please remove it first."
            return
        }

        Write-Host "Installing service..."
        New-Service -Name $ServiceName `
                   -BinaryPathName $BinaryPath `
                   -DisplayName $DisplayName `
                   -Description $Description `
                   -StartupType Automatic
        
        Write-Host "Service installed successfully"
    }
    catch {
        Write-Error "Failed to install service: $_"
    }
}

function Remove-WinService {
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if (-not $service) {
            Write-Warning "Service does not exist"
            return
        }

        if ($service.Status -eq 'Running') {
            Write-Host "Stopping service first..."
            Stop-Service -Name $ServiceName -Force
            Start-Sleep -Seconds 2
        }

        Write-Host "Removing service..."
        Remove-Service -Name $ServiceName -Force
        Write-Host "Service removed successfully"
    }
    catch {
        Write-Error "Failed to remove service: $_"
    }
}

function Start-WinService {
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if (-not $service) {
            Write-Error "Service does not exist. Please install it first."
            return
        }

        if ($service.Status -eq 'Running') {
            Write-Host "Service is already running"
            return
        }

        Write-Host "Starting service..."
        Start-Service -Name $ServiceName
        Write-Host "Service started successfully"
    }
    catch {
        Write-Error "Failed to start service: $_"
    }
}

function Stop-WinService {
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if (-not $service) {
            Write-Error "Service does not exist"
            return
        }

        if ($service.Status -eq 'Stopped') {
            Write-Host "Service is already stopped"
            return
        }

        Write-Host "Stopping service..."
        Stop-Service -Name $ServiceName -Force
        Write-Host "Service stopped successfully"
    }
    catch {
        Write-Error "Failed to stop service: $_"
    }
}

function Get-ServiceStatus {
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if (-not $service) {
            Write-Host "Service does not exist"
            return
        }

        Write-Host "Service Status:"
        Write-Host "---------------"
        Write-Host "Name: $($service.Name)"
        Write-Host "Display Name: $($service.DisplayName)"
        Write-Host "Status: $($service.Status)"
        Write-Host "Start Type: $($service.StartType)"
        
        # Get additional details if available
        try {
            $wmiService = Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'"
            if ($wmiService) {
                Write-Host "Description: $($wmiService.Description)"
                Write-Host "Path: $($wmiService.PathName)"
                Write-Host "Process ID: $($wmiService.ProcessId)"
            }
        }
        catch {
            # Ignore WMI errors
        }
    }
    catch {
        Write-Error "Failed to get service status: $_"
    }
}

# Execute the requested action
switch ($Action) {
    'install' { Install-Service }
    'remove' { Remove-WinService }
    'start' { Start-WinService }
    'stop' { Stop-WinService }
    'status' { Get-ServiceStatus }
}
