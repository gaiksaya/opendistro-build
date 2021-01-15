#!/usr/bin/env pwsh
Invoke-WebRequest -OutFile yq.exe https://github.com/mikefarah/yq/releases/download/v4.2.1/yq_windows_386.exe
Start-Process -Wait -FilePath yq.exe -Argument "/silent" -PassThru
$Env:yq = "$pwd\yq.exe"
.\yq --version