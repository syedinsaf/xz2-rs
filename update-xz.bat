@echo off
setlocal enabledelayedexpansion

echo ========================================
echo  lzma-sys XZ Utils Updater
echo ========================================
echo.

:: Move into lzma-sys subdirectory
cd xz2-rs\lzma-sys
if errorlevel 1 (
    echo [ERROR] Could not find xz2-rs\lzma-sys - make sure you run this from the folder containing xz2-rs
    pause & exit /b 1
)

:: Get latest XZ version from GitHub API
echo [1/6] Fetching latest XZ Utils version...
for /f "delims=" %%i in ('powershell -NoProfile -Command "(Invoke-RestMethod \"https://api.github.com/repos/tukaani-project/xz/releases/latest\").tag_name.TrimStart(\"v\")"') do set XZ_VERSION=%%i

if "%XZ_VERSION%"=="" (
    echo [ERROR] Failed to fetch latest XZ version. Check your internet connection.
    pause & exit /b 1
)
echo [1/6] Latest XZ version: %XZ_VERSION%

:: Check old directory exists
echo.
echo [2/6] Removing old bundled XZ source...
if exist xz-5.2.5 (
    rmdir /s /q xz-5.2.5
    echo [2/6] Removed xz-5.2.5
) else (
    echo [2/6] xz-5.2.5 not found - may have already been removed, continuing...
)

:: Download new XZ tarball
echo.
echo [3/6] Downloading xz-%XZ_VERSION%.tar.gz...
powershell -NoProfile -Command "Invoke-WebRequest \"https://github.com/tukaani-project/xz/releases/download/v%XZ_VERSION%/xz-%XZ_VERSION%.tar.gz\" -OutFile \"xz-%XZ_VERSION%.tar.gz\""
if errorlevel 1 (
    echo [ERROR] Download failed.
    pause & exit /b 1
)
echo [3/6] Download complete.

:: Extract
echo.
echo [4/6] Extracting...
tar -xzf "xz-%XZ_VERSION%.tar.gz"
if errorlevel 1 (
    echo [ERROR] Extraction failed.
    pause & exit /b 1
)
del "xz-%XZ_VERSION%.tar.gz"
echo [4/6] Extracted xz-%XZ_VERSION%

:: Patch build.rs
echo.
echo [5/6] Patching build.rs...
powershell -NoProfile -Command "(Get-Content build.rs) -replace 'xz-5\.2\.5', 'xz-%XZ_VERSION%' | Set-Content build.rs"
if errorlevel 1 (
    echo [ERROR] Failed to patch build.rs.
    pause & exit /b 1
)

:: Verify - make sure 5.2.5 is gone and new version is present
echo.
echo [6/6] Verifying...
powershell -NoProfile -Command "if (Select-String -Path build.rs -Pattern 'xz-5\.2\.5' -Quiet) { Write-Host '[ERROR] build.rs still contains xz-5.2.5!' -ForegroundColor Red; exit 1 } else { Write-Host '[OK] No reference to xz-5.2.5 found in build.rs' -ForegroundColor Green }"
if errorlevel 1 ( pause & exit /b 1 )

powershell -NoProfile -Command "if (Select-String -Path build.rs -Pattern 'xz-%XZ_VERSION%' -Quiet) { Write-Host '[OK] build.rs correctly references xz-%XZ_VERSION%' -ForegroundColor Green } else { Write-Host '[ERROR] build.rs does not reference xz-%XZ_VERSION%' -ForegroundColor Red; exit 1 }"
if errorlevel 1 ( pause & exit /b 1 )

if exist "xz-%XZ_VERSION%\src\liblzma\api\lzma\version.h" (
    echo [OK] New XZ source directory exists
) else (
    echo [ERROR] xz-%XZ_VERSION% source directory missing or incomplete
    pause & exit /b 1
)

:: Confirm bundled version in version.h
echo.
echo Bundled version header says:
powershell -NoProfile -Command "Select-String -Path 'xz-%XZ_VERSION%\src\liblzma\api\lzma\version.h' -Pattern 'LZMA_VERSION_MAJOR|LZMA_VERSION_MINOR|LZMA_VERSION_PATCH' | ForEach-Object { $_.Line.Trim() }"

:: Commit and push
echo.
echo ========================================
echo  All checks passed!
echo ========================================
echo.
set /p DOPUSH="Commit and push to GitHub now? (y/n): "
if /i "%DOPUSH%"=="y" (
    git add -A
    git commit -m "bump bundled XZ Utils from 5.2.5 to %XZ_VERSION%"
    git push
    echo.
    echo [DONE] Pushed to GitHub.
) else (
    echo.
    echo [DONE] Changes are ready but not pushed. Run git push when ready.
)

echo.
pause
