# Build the release exe, deploy Qt next to it and drop everything the app never loads.
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot)
$env:QMAKE = "D:\Qt\6.10.3\msvc2022_64\bin\qmake.exe"
$env:Path = "D:\Qt\6.10.3\msvc2022_64\bin;$env:Path"
cargo build --release
if (Test-Path stage) { Remove-Item stage -Recurse -Force }
New-Item -ItemType Directory stage | Out-Null
Copy-Item target\release\cloud-music.exe stage\
windeployqt6 --release --qmldir qml --no-translations --no-system-d3d-compiler --no-opengl-sw --skip-plugin-types iconengines,generic,networkinformation stage\cloud-music.exe | Out-Null
# the app uses only the Basic Quick Controls style; the other styles are never loaded
foreach ($s in "FluentWinUI3", "Fusion", "Imagine", "Material", "Universal", "Windows") {
    Remove-Item "stage\qml\QtQuick\Controls\$s" -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem stage -Filter "Qt6QuickControls2${s}*.dll" | Remove-Item -Force
}
Remove-Item stage\qmltooling -Recurse -Force -ErrorAction SilentlyContinue
"stage: {0} files, {1} MB" -f (Get-ChildItem stage -Recurse -File).Count, [math]::Round((Get-ChildItem stage -Recurse -File | Measure-Object Length -Sum).Sum / 1MB)
