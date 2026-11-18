@echo off
setlocal

if not "%~1"=="" if /i not "%~1"=="chrome" if /i not "%~1"=="android" (
    echo Uso: iniciar.bat [chrome ^| android [SERIAL]]
    pause
    exit /b 1
)

if not defined FLUTTER_ROOT (
    for /f "delims=" %%F in ('where flutter.bat 2^>nul') do (
        if not defined FLUTTER_ROOT set "FLUTTER_ROOT=%%~dpF.."
    )
)

if not exist "%FLUTTER_ROOT%\bin\flutter.bat" (
    echo Flutter SDK nao encontrado.
    echo Instale o Flutter e adicione a pasta bin ao PATH, ou defina FLUTTER_ROOT.
    pause
    exit /b 1
)

call "%FLUTTER_ROOT%\bin\flutter.bat" --version
if errorlevel 1 goto erro

if not exist "%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe" (
    echo Dart SDK nao encontrado dentro do Flutter SDK: "%FLUTTER_ROOT%"
    echo Execute flutter doctor para concluir a instalacao do Flutter.
    goto erro
)

if /i "%~1"=="android" (
    call :configurar_java
    if errorlevel 1 goto erro
)

set "DART=%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe"
pushd "%~dp0backend_dart"
call "%DART%" pub get
if errorlevel 1 (
    popd
    goto erro
)
popd

pushd "%~dp0aplicativo_flutter"
call "%FLUTTER_ROOT%\bin\flutter.bat" pub get
if errorlevel 1 (
    popd
    goto erro
)
popd

if /i "%~1"=="android" (
    call :android_reverse "%~2"
    if errorlevel 1 (
        echo Conecte um dispositivo Android ou inicie um emulador. Se houver mais de um, informe o serial.
        goto erro
    )
)

powershell.exe -NoProfile -Command "$listener = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Any, 8080); try { $listener.Start(); $listener.Stop() } catch { Write-Error $_; exit 1 }"
if errorlevel 1 (
    echo A porta 8080 nao esta disponivel. Encerre o processo que a utiliza antes de iniciar.
    goto erro
)

set "PORT=8080"
start "API - Catalogo de Veiculos" /D "%~dp0backend_dart" cmd /k ""%DART%" run bin\servidor.dart"
if errorlevel 1 goto erro

for /l %%I in (1,1,30) do (
    for /f "delims=" %%S in ('curl.exe -s -o nul -w "%%{http_code}" --max-time 1 http://127.0.0.1:8080/veiculos') do if "%%S"=="401" goto api_pronta
    powershell.exe -NoProfile -Command "Start-Sleep -Seconds 1"
)
echo A API nao respondeu como esperado. Verifique a janela da API e a porta 8080.
goto erro

:api_pronta
pushd "%~dp0aplicativo_flutter"
if /i "%~1"=="android" (
    if "%~2"=="" (
        call "%FLUTTER_ROOT%\bin\flutter.bat" run -d android
    ) else (
        call "%FLUTTER_ROOT%\bin\flutter.bat" run -d "%~2"
    )
) else (
    call "%FLUTTER_ROOT%\bin\flutter.bat" run -d chrome
)
if errorlevel 1 (
    popd
    goto erro
)
popd
pause
exit /b 0

:configurar_java
if defined JAVA_HOME if exist "%JAVA_HOME%\bin\javac.exe" (
    "%JAVA_HOME%\bin\java.exe" -version >nul 2>&1
    if not errorlevel 1 exit /b 0
)
for /d %%J in ("%USERPROFILE%\.jdks\ms-17*") do (
    if exist "%%~J\bin\javac.exe" (
        "%%~J\bin\java.exe" -version >nul 2>&1
        if not errorlevel 1 (
            set "JAVA_HOME=%%~fJ"
            set "PATH=%%~fJ\bin;%PATH%"
            echo Usando JDK: %%~fJ
            exit /b 0
        )
    )
)
for /f "delims=" %%J in ('where java.exe 2^>nul') do (
    if exist "%%~dpJjavac.exe" (
        "%%~J" -version >nul 2>&1
        if not errorlevel 1 (
            set "JAVA_HOME=%%~dpJ.."
            set "PATH=%%~dpJ;%PATH%"
            echo Usando JDK: %%~dpJ..
            exit /b 0
        )
    )
)
echo JDK nao encontrado ou invalido. Instale o JDK 17 e configure JAVA_HOME.
exit /b 1

:android_reverse
set "ADB=adb"
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" set "ADB=%ANDROID_SDK_ROOT%\platform-tools\adb.exe"
if defined ANDROID_HOME if exist "%ANDROID_HOME%\platform-tools\adb.exe" set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
if "%~1"=="" (
    "%ADB%" reverse tcp:8080 tcp:8080
) else (
    "%ADB%" -s "%~1" reverse tcp:8080 tcp:8080
)
exit /b %errorlevel%

:erro
echo Nao foi possivel iniciar o aplicativo. Verifique as mensagens acima.
pause
exit /b 1
