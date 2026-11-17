@echo off
setlocal
pushd "%~dp0"
where mvn >nul 2>&1
if errorlevel 1 (
  echo Maven is required for rebuilding. Use your IDE Maven or add Maven to PATH.
  echo To run the already built app, open run-app.cmd instead.
  pause
  popd
  exit /b 1
)
call mvn clean verify
set "BB_BUILD_RESULT=%ERRORLEVEL%"
if "%BB_BUILD_RESULT%"=="0" (
  copy /y "target\bloodbank-app.jar" "app.jar" >nul
  if errorlevel 1 (
    echo Could not replace app.jar. Close the running app and rebuild.
    set "BB_BUILD_RESULT=1"
  )
)
echo.
if "%BB_BUILD_RESULT%"=="0" (echo Build and tests: PASS) else (echo Build or tests: FAIL)
pause
popd
exit /b %BB_BUILD_RESULT%
