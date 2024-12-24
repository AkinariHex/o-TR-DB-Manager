$scriptPath = ".\oTR DB management GUI.ps1"
$exePath = ".\oTR DB Manager.exe"

Invoke-ps2exe -InputFile $scriptPath -OutputFile $exePath `
    -Title "osu! Tournament Rating DB Manager" `
    -Version "1.0" `
    -IconFile $null `
    -NoConsole `
    -RequireAdmin