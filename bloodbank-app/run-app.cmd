@echo off
setlocal
pushd "%~dp0"
where java >nul 2>&1
if errorlevel 1 (
  echo Java 17 or newer is required. Install Java or add it to PATH.
  pause
  popd
  exit /b 1
)
if not exist "app.jar" (
  echo app.jar is missing. Rebuild the package with build-and-test.cmd.
  pause
  popd
  exit /b 1
)
java -jar "app.jar" "%~dp0db.properties"
set "BB_APP_RESULT=%ERRORLEVEL%"
if not "%BB_APP_RESULT%"=="0" pause
popd
exit /b %BB_APP_RESULT%
