    @echo %DBGI% off
::  Purpose:
::    Fast user switch
::
set Usage = %0 [/T] [menu-selection]
::
::  Use "/T" to get more informational message 
::
::  Returns:
::    RC=0|1
::
::  Notes:
::  .  Before first use customise value of passwlist.
::  .  If user is not logged it will do "tsdiscon" and then your need 
::     to login as that user.
::  .  Github version of fus.bat (no pwd list) 
::     https://github.com/sryper/2-click-fus
::  .  http://stackoverflow.com/questions/36244439/windows-batch-file-for-login-shortcut#comment60129622_36244439
::
::  Files used or called:
::    tasklist
::    tscon
::    tsdiscon
::    TMPFILE
::    TMPFILE2
::
::  Modifications:
::
::  TIME/DATE        MOD  AUTHOR/DESCRIPTION
::  ---------------- ---- ------------------
::  03:23 28/03/2016 1.01 S. Ryper
::                        First release, tested on WIN XP
::  09:06 31/03/2016 1.02 S. Ryper
::                        add commandline option for menu
::  03:28 03/04/2016 1.03 S. Ryper
::                        missing quote on sort
::
    :: set a dummy nonzero errorlevel
    VERIFY OTHER 2>nul
    Setlocal EnableExtensions EnableDelayedExpansion
    IF ERRORLEVEL 1 goto errmsg1  

    set TMPFILE=%temp%\%~nx0_%random%.txt
    set TMPFILE2=%temp%\%~nx0_%random%.txt
    set rc=1
    set menuselect=

:step1
    if /I "%~1"=="/T" (
        set verbose=y
        shift /1
    )
    if "%~1"=="" goto step1a
    set "menuselect=%~1"
    goto step1a

:step1a
    rem =========================================================
    rem PUTTING PASSWORDS HERE AT YOUR OWN RISK (NOT RECOMMENDED)
    rem =========================================================
    set passwlist="yourcomputername\user1" "password1" "yourcomputername\user2" "password2"


    if "%verbose%"=="y" tasklist /FI "imagename eq explorer.exe" /v /fo list & Pause
    tasklist /FI "imagename eq explorer.exe" /v /fo list > "%TMPFILE%"
    rem field 1=image name 4=sess number and col 7=sess name
    for /f "tokens=1-2 usebackq delims=:" %%k in ( "%TMPFILE%" ) do (
        if "%%k"=="Image Name" (
            call :lstrip iname="%%l" 
        ) else if "%%k"=="Session Name" (
            call :lstrip sessname="%%l"
        ) else if "%%k"=="Session#" (
            call :lstrip sessnum="%%l"
        ) else if "%%k"=="User Name" (
            rem last field to collect
            call :lstrip uname="%%l"
            echo "!uname!" "!sessnum!" "!sessname!">> "%tmpfile2%"
            rem set showlist=!showlist! "!uname!" "!sessnum!" "!sessname!" 
            if "%verbose%"=="y" (
                echo iname="!iname!"
                echo sessname="!sessname!"
                echo sessnum="!sessnum!"
                echo uname="!uname!"
            )
        )
    )
    rem sort by username so can pass selection number on shortcut
    sort "%tmpfile2%" /O "%tmpfile%"
    for /f "tokens=1 usebackq delims=:" %%k in ( "%TMPFILE%" ) do (
        rem showlist=!showlist! "!uname!" "!sessnum!" "!sessname!" 
        set showlist=!showlist! %%k
    )
    echo.
    echo Fast user switch.
    echo -----------------
    call :showusers max=%showlist%

:step2
    echo.
    if defined menuselect (
        set "select=%menuselect%"
        set menuselect=
        goto step2b
    )
    goto step2a

:step2a
    set /p select="Select a user (0=quit, N=new login): "
    
:step2b
    if "%select%" equ "0" goto fin
    if /I "%select%"=="N" (
        tsdiscon
        set rc=0
        goto fin
    )
    if "%select%" gtr "%max%" goto step2

    call :selectuser %select% max=%showlist%
    goto fin

::-- begin subroutine --
:--------------------------------------------------
:lstrip var="quoted-string-to-strip-leading-spaces"
:--------------------------------------------------
    Setlocal EnableExtensions EnableDelayedExpansion
    @echo %dbgi% off
    set result=%~1
    set str=%~2

:loop1
    if "%str:~0,1%"==" " (
        set str=%str:~1%
    ) else (
        goto done1
    )
    goto loop1

:done1
    endlocal & set "%result%=%str%"
    goto :eof
:-- end subroutine --


::-- begin subroutine --
:------------------------------------------------
:showusers var=("uname" "sessnum" "sessname") ...
:------------------------------------------------
    rem returns tuple count
    Setlocal EnableExtensions EnableDelayedExpansion
    @echo %dbgi% off
    set result=%~1
    shift /1
    set i=0

:loop2
    if "%~1"=="" goto done2
    set /A i+=1
    set uname=%~1
    set sessnum=%~2
    if /I "%~3"=="console" (
        echo %i%.		In foreground: !uname:*\=!
    ) else (
        echo %i%.		In background: !uname:*\=! 
    )
    shift /1
    shift /1
    shift /1
    goto loop2

:done2
    endlocal & set "%result%=%i%"
    goto :eof
:-- end subroutine --


::-- begin subroutine --
:--------------------------------------------------------
:selectuser rownum var=("uname" "sessnum" "sessname") ...
:--------------------------------------------------------
    rem returns tuple count
    Setlocal EnableExtensions EnableDelayedExpansion
    @echo %dbgi% off
    set select=%~1
    set result=%~2
    shift /1
    shift /1
    set i=0

:loop3
    if "%~1"=="" goto done3
    set /A i+=1
    set uname=%~1
    set sessnum=%~2
    set sessname=%~3
    set psswd=
    if "!i!"=="%select%" (
        if /I "!sessname!"=="console" (
            echo You can't switch to the console - your already there
            set i=0
            goto done3
        )
        if "%verbose%"=="y" echo Selected %i%:	!uname!  session:!sessnum! 
        call :getpass psswd="%uname%" %passwlist% 
        if not defined psswd set /p psswd="Enter password: "
        tscon !sessnum! /dest:console /password:!psswd!
        set rc=0
        goto done3
    )
    shift /1
    shift /1
    shift /1
    goto loop3
    
:done3
    endlocal & set "%result%=%i%"
    goto :eof
:-- end subroutine --


::-- begin subroutine --
:-----------------------------------------
:getpass selection var=("uname" "pw" ) ...
:-----------------------------------------
    rem returns tuple count
    Setlocal EnableExtensions EnableDelayedExpansion
    @echo %dbgi% off
    set result=%~1
    set selection=%~2
    shift /1
    shift /1
    set i=0
    set match=

:loop4
    if "%~1"=="" goto done4
    set /A i+=1
    set uname=%~1
    set passval=%~2
    if /I "%selection%"=="%uname%" (
        set match=%passval%
        if "%verbose%"=="y" echo %uname% found in password list
        goto done4
    )
    shift /1
    shift /1
    goto loop4

:done4   
    endlocal & set "%result%=%match%"
    goto :eof
:-- end subroutine --

    
:errmsg1    
    echo Unable to enable extensions
    pause
    goto fin
       
:usage
    echo %Usage: %usage%
    goto fin

:fin  
    del "%tmpfile%"
    del "%tmpfile2%"
    endlocal & exit /b %rc%
