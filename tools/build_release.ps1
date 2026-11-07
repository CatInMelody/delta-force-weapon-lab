param(
    [Parameter(Mandatory=$true)][string]$GodotEditor,
    [int]$Jobs = 4,
    [switch]$CompileTemplate
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$scratchRoot = Join-Path $projectRoot '.build'
$sourceRoot = Join-Path $scratchRoot 'godot-4.7.1-stable'
$templatePath = Join-Path $projectRoot 'export_templates/tool.plain.windows.template_release.x86_64.exe'
$outputPath = Join-Path $PSScriptRoot '三角洲武器实验室.exe'
New-Item -ItemType Directory -Path $scratchRoot -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $scratchRoot '.gdignore') -Force | Out-Null
# Never read private keys or export credentials; do not create a ZIP.
$previousCompileKey = $env:SCRIPT_AES256_ENCRYPTION_KEY
$previousExportKey = $env:GODOT_SCRIPT_ENCRYPTION_KEY
try {
    $env:SCRIPT_AES256_ENCRYPTION_KEY = $null
    $env:GODOT_SCRIPT_ENCRYPTION_KEY = $null
    if ($CompileTemplate) {
        if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot 'SConstruct'))) {
            $archive = Join-Path $scratchRoot 'godot-4.7.1-stable.zip'
            Invoke-WebRequest 'https://codeload.github.com/godotengine/godot/zip/refs/tags/4.7.1-stable' -OutFile $archive
            Expand-Archive -LiteralPath $archive -DestinationPath $scratchRoot -Force
        }
        Push-Location $sourceRoot
        try {
            & scons platform=windows target=template_release arch=x86_64 msvc_version=14.3 optimize=size lto=full debug_symbols=no modules_enabled_by_default=no module_gdscript_enabled=yes module_freetype_enabled=yes module_text_server_adv_enabled=yes module_mbedtls_enabled=yes module_webp_enabled=yes module_jpg_enabled=yes module_svg_enabled=yes "build_profile=$projectRoot/feature_profiles/tool-release.gdbuild" "-j$Jobs"
            if ($LASTEXITCODE -ne 0) { throw 'Godot template compilation failed' }
        } finally { Pop-Location }
        New-Item -ItemType Directory -Path (Split-Path $templatePath) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $sourceRoot 'bin/godot.windows.template_release.x86_64.exe') -Destination $templatePath -Force
    }
    if (-not (Test-Path -LiteralPath $templatePath)) { throw 'Plain template missing. Run once with -CompileTemplate, or use the official Godot 4.7.1 release template in export_presets.cfg.' }
    & $GodotEditor --headless --path $projectRoot --export-release 'Windows Desktop' $outputPath
    if ($LASTEXITCODE -ne 0) { throw 'Project export failed' }
    Get-Item -LiteralPath $outputPath | Select-Object Name,Length
    Get-FileHash -LiteralPath $outputPath -Algorithm SHA256
} finally {
    $env:SCRIPT_AES256_ENCRYPTION_KEY = $previousCompileKey
    $env:GODOT_SCRIPT_ENCRYPTION_KEY = $previousExportKey
}
