param(
  [string]$DeployDir = "$env:USERPROFILE\admin-pages-deploy"
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$deployPath = [System.IO.Path]::GetFullPath($DeployDir)

if (Test-Path -LiteralPath $deployPath) {
  Remove-Item -LiteralPath $deployPath -Recurse -Force
}

New-Item -ItemType Directory -Path $deployPath | Out-Null

$commit = (git -C $repoRoot rev-parse --short HEAD).Trim()
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$versionLabel = "$commit · $stamp"
$adminHtml = Get-Content -LiteralPath (Join-Path $repoRoot 'admin_panel.html') -Raw
$adminHtml = $adminHtml -replace '(<span class="admin-version" id="admin-build-version">).*?(</span>)', "`$1$versionLabel`$2"
Set-Content -LiteralPath (Join-Path $deployPath 'admin_panel.html') -Value $adminHtml -Encoding UTF8
Set-Content -LiteralPath (Join-Path $deployPath 'index.html') -Value $adminHtml -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $repoRoot 'admin_favicon.svg') -Destination (Join-Path $deployPath 'admin_favicon.svg')
New-Item -ItemType File -Path (Join-Path $deployPath '.nojekyll') | Out-Null

Push-Location $deployPath
try {
  git init
  git checkout -B gh-pages
  git remote add origin https://github.com/ARTS-DARTS/valorant-admin.git
  git add .

  $commitResult = git commit -m 'deploy admin site' 2>&1
  if ($LASTEXITCODE -ne 0 -and ($commitResult -join "`n") -notmatch 'nothing to commit') {
    throw ($commitResult -join "`n")
  }

  git push origin gh-pages --force
}
finally {
  Pop-Location
}
