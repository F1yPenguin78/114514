$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$uploadDir = Join-Path $root "上传"
$projectsDir = Join-Path $root "projects"
$indexPath = Join-Path $root "index.html"

if (-not (Test-Path -LiteralPath $uploadDir)) {
    New-Item -ItemType Directory -Path $uploadDir | Out-Null
}
if (-not (Test-Path -LiteralPath $projectsDir)) {
    New-Item -ItemType Directory -Path $projectsDir | Out-Null
}

$files = @(Get-ChildItem -LiteralPath $uploadDir -File -ErrorAction SilentlyContinue)
if ($files.Count -eq 0) {
    Write-Host "没有发现需要上传的文件。请把文件放入“上传”文件夹后再次运行。"
    exit 0
}

$moved = @()
foreach ($file in $files) {
    $dest = Join-Path $projectsDir $file.Name
    Move-Item -LiteralPath $file.FullName -Destination $dest -Force
    $moved += $file.Name
}

$allFiles = @(Get-ChildItem -LiteralPath $projectsDir -File -ErrorAction SilentlyContinue | Sort-Object Name)
$cards = @()
foreach ($file in $allFiles) {
    $name = $file.Name
    $encodedName = [uri]::EscapeDataString($name)
    $displayName = [System.Security.SecurityElement]::Escape($name)
    $ext = $file.Extension.ToLowerInvariant()
    $icon = "📄"
    if ($ext -eq ".zip" -or $ext -eq ".rar" -or $ext -eq ".7z") { $icon = "📦" }
    elseif ($ext -eq ".html" -or $ext -eq ".htm") { $icon = "🌐" }
    elseif ($ext -in @(".jpg", ".jpeg", ".png", ".gif", ".svg", ".webp")) { $icon = "🖼️" }

    $cards += @"
        <article class="card project">
          <div class="project-top">
            <div class="project-icon">$icon</div>
            <span class="tag">项目</span>
          </div>
          <h3>$displayName</h3>
          <p>点击下方链接打开文件。</p>
          <a href="projects/$encodedName" target="_blank" rel="noopener">打开 →</a>
        </article>
"@
}

$cardsHtml = ($cards -join "`n")

$indexContent = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8
$startMarker = "<!-- PROJECTS_START -->"
$endMarker = "<!-- PROJECTS_END -->"
$startIdx = $indexContent.IndexOf($startMarker)
$endIdx = $indexContent.IndexOf($endMarker)

if ($startIdx -lt 0 -or $endIdx -lt 0) {
    Write-Warning "未找到 index.html 中的项目标记，页面列表未自动更新。"
} else {
    $head = $indexContent.Substring(0, $startIdx + $startMarker.Length)
    $tail = $indexContent.Substring($endIdx)
    $newIndex = $head + "`n" + $cardsHtml + "`n      " + $tail
    [System.IO.File]::WriteAllText($indexPath, $newIndex, (New-Object System.Text.UTF8Encoding($false)))
}

Set-Location $root
& git add -A
if ($LASTEXITCODE -ne 0) { throw "git add 失败" }

& git commit -m ("上传文件: " + ($moved -join ", "))
if ($LASTEXITCODE -ne 0) { throw "git commit 失败" }

& git push
if ($LASTEXITCODE -ne 0) { throw "git push 失败" }

Write-Host ""
Write-Host "上传完成。文件已移动到 projects 文件夹，并已从“上传”文件夹删除。"
