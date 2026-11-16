@echo off
setlocal
set "ZEPP_NVM_ROOT=%NVM_HOME%"
if not defined ZEPP_NVM_ROOT set "ZEPP_NVM_ROOT=%LOCALAPPDATA%\nvm"
set "ZEPP_NODE=%ZEPP_NVM_ROOT%\v20.20.2\node.exe"
if not exist "%ZEPP_NODE%" (
  echo Node 20.20.2 non trovato in "%ZEPP_NODE%".
  exit /b 1
)
set "ZEPP_CLI=%APPDATA%\npm\node_modules\@zeppos\zeus-cli\bin\main.js"
if not exist "%ZEPP_CLI%" (
  echo Zeus CLI non trovato in "%ZEPP_CLI%".
  exit /b 1
)
set "PATH=%ZEPP_NVM_ROOT%\v20.20.2;%PATH%"
pushd "%~dp0"
"%ZEPP_NODE%" "%ZEPP_CLI%" %*
set "ZEPP_EXIT=%ERRORLEVEL%"
popd
exit /b %ZEPP_EXIT%
