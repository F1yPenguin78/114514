$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$projectsDir = Join-Path $root "projects"
$indexPath = Join-Path $root "index.html"

if (-not (Test-Path -LiteralPath $projectsDir)) {
    New-Item -ItemType Directory -Path $projectsDir | Out-Null
}

$files = @(Get-ChildItem -LiteralPath $projectsDir -File -ErrorAction SilentlyContinue | Sort-Object Name)
if ($files.Count -eq 0) {
    Write-Host "当前没有可删除的项目文件。"
    exit 0
}

Write-Host ""
Write-Host "当前项目文件："
for ($i = 0; $i -lt $files.Count; $i++) {
    Write-Host ("  [{0}] {1}" -f ($i + 1), $files[$i].Name)
}

$choice = Read-Host "请输入要删除的项目编号"
$index = -1
if ($choice -match '^\d+$') {
    $index = [int]$choice - 1
}
if ($index -lt 0 -or $index -ge $files.Count) {
    Write-Host "编号无效，操作已取消。"
    exit 1
}

$secure = Read-Host "请输入删除密码" -AsSecureString
$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
if ($plain -ne "03021128") {
    Write-Host "密码错误，操作已取消。"
    exit 1
}

$fileToDelete = $files[$index]
Remove-Item -LiteralPath $fileToDelete.FullName -Force

$remaining = @(Get-ChildItem -LiteralPath $projectsDir -File -ErrorAction SilentlyContinue | Sort-Object Name)
if ($remaining.Count -eq 0) {
    $cardsHtml = '        <p style="grid-column: 1 / -1; text-align: center; color: var(--muted); padding: 30px 0;">暂无项目</p>'
} else {
    $cards = @()
    foreach ($file in $remaining) {
        $name = $file.Name
        $encodedName = [uri]::EscapeDataString($name)
        $displayName = [System.Security.SecurityElement]::Escape($name)
        $ext = $file.Extension.ToLowerInvariant()
        $icon = "📄"
        if ($ext -eq ".zip" -or $ext -eq ".rar" -or $ext -eq ".7z") { $icon = "📦" }
        elseif ($ext -eq ".html" -or $ext -eq ".htm") { $icon = "🌐" }
        elseif ($ext -in @(".jpg", ".jpeg", ".png", ".gif", ".svg", ".webp")) { $icon = "🖼️" }

        $cards += @"
        <article class="card project" data-file="$displayName">
          <div class="project-top">
            <div class="project-icon">$icon</div>
            <span class="tag">项目</span>
          </div>
          <h3>$displayName</h3>
          <p>点击下方按钮打开项目。</p>
          <p class="project-note" hidden></p>
          <a class="btn btn-primary project-open" href="projects/$encodedName" target="_blank" rel="noopener">打开项目 →</a>
          <div class="project-actions">
            <button type="button" class="note-btn">编辑注释</button>
            <button type="button" class="delete-btn">删除</button>
          </div>
        </article>
"@
    }
    $cardsHtml = ($cards -join "`n")
}

$indexContent = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8
$startMarker = "<!-- PROJECTS_START -->"
$endMarker = "<!-- PROJECTS_END -->"
$startIdx = $indexContent.IndexOf($startMarker)
$endIdx = $indexContent.IndexOf($endMarker)
if ($startIdx -lt 0 -or $endIdx -lt 0) {
    throw "未找到 index.html 中的项目标记，无法更新页面。"
}
$head = $indexContent.Substring(0, $startIdx + $startMarker.Length)
$tail = $indexContent.Substring($endIdx)
$newIndex = $head + "`n" + $cardsHtml + "`n      " + $tail
[System.IO.File]::WriteAllText($indexPath, $newIndex, (New-Object System.Text.UTF8Encoding($false)))

Set-Location $root
& git add -A
if ($LASTEXITCODE -ne 0) { throw "git add 失败" }

& git commit -m ("删除项目: " + $fileToDelete.Name)
if ($LASTEXITCODE -ne 0) { throw "git commit 失败" }

& git push
if ($LASTEXITCODE -ne 0) { throw "git push 失败" }

Write-Host ""
Write-Host ("已删除项目并发布：{0}" -f $fileToDelete.Name)
