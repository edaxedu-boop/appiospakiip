$newFlutter = "C:\flutter\flutter\bin"
$current = [Environment]::GetEnvironmentVariable('PATH', 'User')
$cleaned = $current -replace [regex]::Escape(";$newFlutter"), "" -replace [regex]::Escape("$newFlutter;"), ""
$final = "$newFlutter;$cleaned"
[Environment]::SetEnvironmentVariable('PATH', $final, 'User')
Write-Host "PATH actualizado. El nuevo Flutter esta primero." -ForegroundColor Green
Write-Host "Ruta: $newFlutter" -ForegroundColor Cyan
