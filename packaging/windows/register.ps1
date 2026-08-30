param([string]$Executable = (Join-Path $PSScriptRoot 'sutoriraita.exe'))
$ErrorActionPreference = 'Stop'
$appPath = (Resolve-Path -LiteralPath $Executable).Path
$classes = 'HKCU:\Software\Classes'
$formatKey = "$classes\Sutoriraita.Project"
New-Item -Path "$classes\.sutoriraita\OpenWithProgids" -Force | Out-Null
New-ItemProperty -Path "$classes\.sutoriraita\OpenWithProgids" -Name 'Sutoriraita.Project' -Value '' -PropertyType String -Force | Out-Null
New-Item -Path "$formatKey\shell\open\command" -Force | Out-Null
Set-Item -Path $formatKey -Value 'Sutōrīraitā Project'
Set-Item -Path "$formatKey\shell\open\command" -Value ('"' + $appPath + '" "%1"')
New-Item -Path "$classes\.sutoriraita" -Force | Out-Null
Set-Item -Path "$classes\.sutoriraita" -Value 'Sutoriraita.Project'
Write-Host 'Registered for this user. Windows may ask you to choose Sutōrīraitā in Open With.'
