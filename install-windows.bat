@echo off
rem Interactive installer for the mytstack skills (Windows, runs from cmd).
rem
rem Links each chosen skill folder into each chosen agent tool's skills folder,
rem so "git pull" in the clone updates every tool at once. Re-run it to add or
rem remove skills. It only ever creates or removes links that point into the
rem clone; your own skills are never touched.
rem
rem Links are directory junctions (mklink /J), so no admin rights and no
rem Developer Mode are needed.
rem
rem   install-windows.bat                  interactive
rem   install-windows.bat --help           flags
rem
rem No clone yet? Download just this file, run it, and it clones the repo first:
rem   curl -fsSLo install-windows.bat RAW_URL ^&^& install-windows.bat

setlocal EnableExtensions EnableDelayedExpansion

set "REPO_URL=https://github.com/busFred/mytstack.git"
if defined MYTSTACK_REPO_URL set "REPO_URL=%MYTSTACK_REPO_URL%"
set "H=%USERPROFILE%"
set "DEFAULT_DIR=%USERPROFILE%\mytstack"
if defined MYTSTACK_DIR set "DEFAULT_DIR=%MYTSTACK_DIR%"

rem ---------- flags ----------
rem cmd splits arguments on commas and equals signs, so "--skills a,b" and
rem "--skills=a,b" both arrive as "--skills" followed by "a" and "b".
set "OPT_SKILLS="
set "OPT_TOOLS="
set "OPT_ALL=0"
set "OPT_YES=0"
set "OPT_UNINSTALL=0"
set "DRY=0"
set "MODE="
:args
if "%~1"=="" goto args_done
set "A=%~1"
if "!A:~0,1!"=="-" goto arg_flag
if "!A!"=="/?" goto arg_flag
if "!MODE!"=="skills" (set "OPT_SKILLS=!OPT_SKILLS! !A!" & shift & goto args)
if "!MODE!"=="tools" (set "OPT_TOOLS=!OPT_TOOLS! !A!" & shift & goto args)
set "ERRMSG=unexpected argument: !A! (see --help)"
goto die
:arg_flag
set "MODE="
set "KNOWN="
if /i "!A!"=="--skills" set "MODE=skills" & set "KNOWN=1"
if /i "!A!"=="--tools" set "MODE=tools" & set "KNOWN=1"
if /i "!A!"=="--all" set "OPT_ALL=1" & set "KNOWN=1"
if /i "!A!"=="-y" set "OPT_YES=1" & set "KNOWN=1"
if /i "!A!"=="--yes" set "OPT_YES=1" & set "KNOWN=1"
if /i "!A!"=="--uninstall" set "OPT_UNINSTALL=1" & set "KNOWN=1"
if /i "!A!"=="--dry-run" set "DRY=1" & set "KNOWN=1"
if /i "!A!"=="-h" call :usage & exit /b 0
if /i "!A!"=="--help" call :usage & exit /b 0
if /i "!A!"=="/?" call :usage & exit /b 0
if not defined KNOWN (
  set "ERRMSG=unknown option: !A! (see --help)"
  goto die
)
shift
goto args
:args_done
if defined OPT_SKILLS set "OPT_SKILLS=!OPT_SKILLS:,= !"
if defined OPT_TOOLS set "OPT_TOOLS=!OPT_TOOLS:,= !"

set "INTERACTIVE=1"
if "!OPT_YES!"=="1" set "INTERACTIVE=0"
if "!OPT_ALL!"=="1" set "INTERACTIVE=0"
if "!OPT_UNINSTALL!"=="1" set "INTERACTIVE=0"

rem ---------- find or clone the repo ----------
set "REPO="
for %%i in ("%~dp0.") do call :is_repo "%%~fi" && set "REPO=%%~fi"
if not defined REPO call :is_repo "!DEFAULT_DIR!" && set "REPO=!DEFAULT_DIR!"
if defined REPO goto have_repo

where git >nul 2>&1
if errorlevel 1 (
  set "ERRMSG=git is required to clone !REPO_URL!"
  goto die
)
if exist "!DEFAULT_DIR!" (
  set "ERRMSG=!DEFAULT_DIR! exists but has no skills folder; set MYTSTACK_DIR"
  goto die
)
echo No mytstack clone found. Cloning into !DEFAULT_DIR! ...
if "!DRY!"=="1" (
  echo would run: git clone !REPO_URL! !DEFAULT_DIR!
  exit /b 0
)
git clone --quiet "!REPO_URL!" "!DEFAULT_DIR!"
if errorlevel 1 (
  set "ERRMSG=git clone failed"
  goto die
)
set "REPO=!DEFAULT_DIR!"
:have_repo
for %%i in ("!REPO!") do set "REPO=%%~fi"
set "SKILLS_SRC=!REPO!\skills"
set "SRC_PREFIX=!SKILLS_SRC!\"
rem Length of SRC_PREFIX, for "starts with" checks.
set "s=!SRC_PREFIX!#"
set "LEN=0"
for %%P in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
  if not "!s:~%%P,1!"=="" (
    set /a LEN+=%%P
    set "s=!s:~%%P!"
  )
)

rem ---------- read skills, descriptions and dependencies ----------
set /a NS=0
for /d %%d in ("!SKILLS_SRC!\*") do if exist "%%d\SKILL.md" (
  set /a NS+=1
  set "SK_!NS!=%%~nxd"
  set "SIDX_%%~nxd=!NS!"
)
if !NS! lss 1 (
  set "ERRMSG=no skills found in !SKILLS_SRC!"
  goto die
)

rem Plain-English summaries from the README table: | `name` | say | what it does |
if exist "!REPO!\README.md" (
  for /f "tokens=1,3 delims=|" %%a in ('findstr /R /C:"^| `[a-z0-9-]*` |" "!REPO!\README.md"') do (
    set "n=%%a"
    set "n=!n:`=!"
    set "n=!n: =!"
    if defined SIDX_!n! (
      set "w="
      for /f "tokens=*" %%x in ("%%b") do set "w=%%x"
      if "!w:~-1!"==" " set "w=!w:~0,-1!"
      call :setdesc "!n!"
    )
  )
  rem Lines like: - `a` uses `b`, `c`.   or   - `a`, `b`, and `c` use `d`.
  for /f "tokens=*" %%L in ('findstr /R /C:"^- `[a-z0-9-]*`.* use[s]* `" "!REPO!\README.md"') do (
    set "L=%%L"
    set "L=!L: uses = | !"
    set "L=!L: use = | !"
    set "U="
    set "D="
    for /f "tokens=1,2 delims=|" %%p in ("!L!") do (
      set "U=%%p"
      set "D=%%q"
    )
    set "U=!U:`= !"
    set "U=!U:,= !"
    set "U=!U:.= !"
    set "D=!D:`= !"
    set "D=!D:,= !"
    set "D=!D:.= !"
    for %%u in (!U!) do if defined SIDX_%%u (
      for %%e in (!D!) do if defined SIDX_%%e call :adddep "%%u" "%%e"
    )
  )
)

rem ---------- tools ----------
set "CODEX_DIR=!H!\.codex"
if defined CODEX_HOME set "CODEX_DIR=%CODEX_HOME%"
set "KIMI_HOME=!H!\.kimi-code"
if defined KIMI_CODE_HOME set "KIMI_HOME=%KIMI_CODE_HOME%"
set "KIMI_DIR=!H!\.kimi\skills"
if not exist "!H!\.kimi" if exist "!KIMI_HOME!" set "KIMI_DIR=!KIMI_HOME!\skills"

set /a NT=0
call :deftool claude "Claude Code" "!H!\.claude\skills"
call :deftool codex "Codex" "!CODEX_DIR!\skills"
call :deftool antigravity "Antigravity" "!H!\.gemini\config\skills"
call :deftool gemini "Gemini CLI" "!H!\.gemini\skills"
call :deftool muse "Muse Code" "!H!\.config\muse\skills"
call :deftool kimi "Kimi Code CLI" "!KIMI_DIR!"
call :deftool kilo "Kilo Code" "!H!\.kilo\skills"
call :deftool opencode "OpenCode" "!H!\.config\opencode\skills"
call :deftool shared "Shared folder" "!H!\.agents\skills"

rem ---------- choose tools ----------
rem DT_k = index of the k-th candidate tool; TST_k = 1 if ticked.
set /a NDT=0
if defined OPT_TOOLS (
  for %%t in (!OPT_TOOLS!) do (
    if not defined TIDX_%%t (
      set "ERRMSG=unknown tool id: %%t"
      goto die
    )
    set /a NDT+=1
    set "DT_!NDT!=!TIDX_%%t!"
    set "TST_!NDT!=1"
  )
) else (
  for /l %%i in (1,1,!NT!) do (
    call :detect %%i
    if "!FOUND!"=="1" (
      set /a NDT+=1
      set "DT_!NDT!=%%i"
      set "TST_!NDT!=1"
      rem The shared folder is opt-in unless something is already linked there.
      if "!TID_%%i!"=="shared" (
        set "TST_!NDT!=0"
        call :any_linked_in %%i && set "TST_!NDT!=1"
      )
    )
  )
)

echo mytstack skills installer
echo Clone: !REPO!
echo.

if "!INTERACTIVE!"=="1" if not defined OPT_TOOLS (
  echo Found these tools on this machine. The shared folder ^(%%USERPROFILE%%\.agents\skills^)
  echo is an open standard several tools read; tick it to cover tools not listed here.
  echo Tools that read several folders may list a skill twice if you tick both.
  set /a MN=0
  for /l %%k in (1,1,!NDT!) do call :tool_to_menu %%k
  call :menu "Install into which tools?"
  for /l %%k in (1,1,!NDT!) do set "TST_%%k=!M_ST_%%k!"
)

set /a NSEL=0
for /l %%k in (1,1,!NDT!) do if "!TST_%%k!"=="1" (
  set /a NSEL+=1
  set "SEL_!NSEL!=!DT_%%k!"
)

rem ---------- uninstall ----------
if "!OPT_UNINSTALL!"=="1" (
  set /a REMOVED=0
  for /l %%t in (1,1,!NT!) do for /l %%s in (1,1,!NS!) do call :is_ours %%t %%s && call :uninstall_one %%t %%s
  echo Removed !REMOVED! link^(s^). The clone at !REPO! was left in place.
  exit /b 0
)

if !NSEL! lss 1 (
  set "ERRMSG=no tools selected"
  goto die
)

rem ---------- choose skills ----------
set "ANY_LINKED=0"
for /l %%k in (1,1,!NSEL!) do for /l %%s in (1,1,!NS!) do call :is_ours !SEL_%%k! %%s && set "ANY_LINKED=1"

if defined OPT_SKILLS (
  for %%x in (!OPT_SKILLS!) do if not defined SIDX_%%x (
    set "ERRMSG=unknown skill: %%x"
    goto die
  )
)
for /l %%s in (1,1,!NS!) do call :default_skill_state %%s

if "!INTERACTIVE!"=="1" if not defined OPT_SKILLS (
  set /a MN=0
  for /l %%s in (1,1,!NS!) do (
    set /a MN+=1
    set "M_NAME_!MN!=!SK_%%s!"
    set "M_DESC_!MN!=!SDESC_%%s!"
    set "M_ST_!MN!=!SST_%%s!"
  )
  call :menu "Install which skills?"
  for /l %%s in (1,1,!NS!) do set "SST_%%s=!M_ST_%%s!"
)

rem Add skills that chosen skills call, until nothing changes.
:closure
set "CHANGED=0"
for /l %%s in (1,1,!NS!) do call :closure_one %%s
if "!CHANGED!"=="1" goto closure

rem ---------- apply ----------
set /a ADDED=0
set /a KEPT=0
set /a REMOVED=0
set /a SKIPPED=0
for /l %%k in (1,1,!NSEL!) do call :apply_tool !SEL_%%k!

echo.
echo Linked !ADDED!, already linked !KEPT!, removed !REMOVED!, skipped !SKIPPED!.
if !SKIPPED! gtr 0 echo Move or delete the skipped folders, then re-run to link them.
echo To update later: git -C "!REPO!" pull. Restart open sessions to load changes.
exit /b 0


rem ======================================================================
rem Subroutines
rem ======================================================================

:die
>&2 echo error: !ERRMSG!
exit /b 1

:usage
echo Usage: install-windows.bat [options]
echo.
echo Options:
echo   --skills a,b,c   Install these skills (others already linked are removed).
echo   --tools  x,y     Link into these tools (ids below).
echo   --all            All skills into every detected tool (shared folder excluded).
echo   --yes, -y        Don't prompt; use the defaults or the lists given above.
echo   --uninstall      Remove every link that points into this clone.
echo   --dry-run        Show what would change without changing anything.
echo   -h, --help       Show this help.
echo.
echo Tool ids: claude codex antigravity gemini muse kimi kilo opencode shared
echo Env: MYTSTACK_DIR (clone location, default %%USERPROFILE%%\mytstack), MYTSTACK_REPO_URL.
echo Links are directory junctions, so no admin rights are needed.
exit /b 0

rem :is_repo DIR - errorlevel 0 if DIR\skills holds at least one SKILL.md
:is_repo
if not exist "%~1\skills\" exit /b 1
for /d %%d in ("%~1\skills\*") do if exist "%%d\SKILL.md" exit /b 0
exit /b 1

rem :setdesc NAME - store the description held in %w%
:setdesc
for %%j in (!SIDX_%~1!) do set "SDESC_%%j=!w!"
exit /b 0

rem :adddep USER USED
:adddep
set "DEPS_%~1=!DEPS_%~1! %~2"
exit /b 0

rem :deftool ID LABEL DIR
:deftool
set /a NT+=1
set "TID_!NT!=%~1"
set "TLABEL_!NT!=%~2"
set "TDIR_!NT!=%~3"
set "TIDX_%~1=!NT!"
exit /b 0

rem :detect TOOL_INDEX - sets FOUND=1 if the tool looks installed
:detect
set "FOUND=0"
set "dn=!TID_%~1!"
if "!dn!"=="claude" call :chk "!H!\.claude" cmd:claude
if "!dn!"=="codex" call :chk "!CODEX_DIR!" cmd:codex
if "!dn!"=="antigravity" call :chk "!H!\.gemini\antigravity" "!H!\.gemini\antigravity-cli" "!H!\.gemini\config" cmd:agy
if "!dn!"=="gemini" call :chk "!H!\.gemini\settings.json" cmd:gemini
if "!dn!"=="muse" call :chk "!H!\.config\muse" cmd:muse
if "!dn!"=="kimi" call :chk "!H!\.kimi" "!KIMI_HOME!" cmd:kimi
if "!dn!"=="kilo" call :chk "!H!\.kilo" "!H!\.config\kilo" "!H!\.kilocode" cmd:kilo
if "!dn!"=="opencode" call :chk "!H!\.config\opencode" cmd:opencode
if "!dn!"=="shared" set "FOUND=1"
exit /b 0

rem :chk ITEM... - an item is a path or cmd:NAME
:chk
for %%x in (%*) do (
  set "it=%%~x"
  if "!it:~0,4!"=="cmd:" (
    where "!it:~4!" >nul 2>&1 && set "FOUND=1"
  ) else (
    if exist "!it!" set "FOUND=1"
  )
)
exit /b 0

rem :gettarget DIR NAME - sets TGT to the link target of DIR\NAME (empty if not a link)
:gettarget
set "TGT="
if not exist "%~1\%~2" exit /b 0
for /f "tokens=*" %%a in ('dir /AL "%~1" 2^>nul ^| findstr /C:"<JUNCTION>" /C:"<SYMLINKD>"') do (
  set "ln=%%a"
  if not "!ln: %~2 [=!"=="!ln!" (
    set "gt=!ln:* %~2 [=!"
    set "TGT=!gt:~0,-1!"
  )
)
exit /b 0

rem :is_ours TOOL_INDEX SKILL_INDEX - errorlevel 0 if it is a link into this clone
:is_ours
call :gettarget "!TDIR_%~1!" "!SK_%~2!"
if not defined TGT exit /b 1
if /i "!TGT:~0,%LEN%!"=="!SRC_PREFIX!" exit /b 0
exit /b 1

rem :any_linked_in TOOL_INDEX
:any_linked_in
for /l %%s in (1,1,!NS!) do call :is_ours %~1 %%s && exit /b 0
exit /b 1

rem :default_skill_state SKILL_INDEX
:default_skill_state
set "SST_%~1=0"
if defined OPT_SKILLS (
  for %%x in (!OPT_SKILLS!) do if /i "%%x"=="!SK_%~1!" set "SST_%~1=1"
  exit /b 0
)
if "!OPT_ALL!"=="1" set "SST_%~1=1"
if "!ANY_LINKED!"=="0" set "SST_%~1=1"
if "!SST_%~1!"=="1" exit /b 0
for /l %%k in (1,1,!NSEL!) do call :is_ours !SEL_%%k! %~1 && set "SST_%~1=1"
exit /b 0

rem :closure_one SKILL_INDEX - tick the skills that this one calls
:closure_one
if not "!SST_%~1!"=="1" exit /b 0
set "cn=!SK_%~1!"
if not defined DEPS_!cn! exit /b 0
for %%n in (!cn!) do set "cd=!DEPS_%%n!"
for %%d in (!cd!) do call :closure_dep "%%d" "!cn!"
exit /b 0

:closure_dep
if not defined SIDX_%~1 exit /b 0
for %%j in (!SIDX_%~1!) do if not "!SST_%%j!"=="1" (
  set "SST_%%j=1"
  set "CHANGED=1"
  echo + added %~1 ^(needed by %~2^)
)
exit /b 0

rem :tool_to_menu K - add the k-th candidate tool to the menu arrays
:tool_to_menu
set /a MN+=1
for %%t in (!DT_%~1!) do (
  set "M_NAME_!MN!=!TLABEL_%%t!"
  set "td=!TDIR_%%t!"
  set "td=!td:%H%=~!"
  set "M_DESC_!MN!=!td!"
)
set "M_ST_!MN!=!TST_%~1!"
exit /b 0

rem :menu TITLE - numbered checklist over M_NAME_i, M_DESC_i, M_ST_i (i = 1..MN)
:menu
set "M_TITLE=%~1"
:menu_draw
echo.
echo !M_TITLE!
echo Type numbers to toggle ^(for example 1 3 5^), a = all, n = none, Enter = confirm.
for /l %%i in (1,1,!MN!) do (
  set "mark= "
  if "!M_ST_%%i!"=="1" set "mark=x"
  set "nm=!M_NAME_%%i!                          "
  set "nm=!nm:~0,24!"
  set "ds=!M_DESC_%%i!"
  if not "!ds:~66,1!"=="" set "ds=!ds:~0,63!..."
  set "num= %%i"
  set "num=!num:~-2!"
  echo  !num!  [!mark!] !nm! !ds!
)
set "ans="
set /p "ans=> "
if not defined ans exit /b 0
set "ans=!ans:,= !"
for %%w in (!ans!) do call :menu_tok "%%~w"
goto menu_draw

:menu_tok
set "tk=%~1"
if not defined tk exit /b 0
if /i "!tk!"=="a" (
  for /l %%j in (1,1,!MN!) do set "M_ST_%%j=1"
  exit /b 0
)
if /i "!tk!"=="n" (
  for /l %%j in (1,1,!MN!) do set "M_ST_%%j=0"
  exit /b 0
)
set "nonnum="
for /f "delims=0123456789" %%x in ("!tk!") do set "nonnum=1"
if defined nonnum exit /b 0
if !tk! lss 1 exit /b 0
if !tk! gtr !MN! exit /b 0
for %%k in (!tk!) do (
  if "!M_ST_%%k!"=="1" (set "M_ST_%%k=0") else set "M_ST_%%k=1"
)
exit /b 0

rem :link DEST SRC / :unlink DEST / :mkd DIR  (honour --dry-run)
rem Removing a junction with rmdir deletes only the link, never the target.
:link
if "!DRY!"=="1" (
  echo   would run: mklink /J "%~1" "%~2"
  exit /b 0
)
mklink /J "%~1" "%~2" >nul 2>&1
exit /b

:unlink
if "!DRY!"=="1" (
  echo   would run: rmdir "%~1"
  exit /b 0
)
rmdir "%~1"
exit /b

:mkd
if "!DRY!"=="1" (
  echo   would run: mkdir "%~1"
  exit /b 0
)
mkdir "%~1"
exit /b

:uninstall_one
set "u_dest=!TDIR_%~1!\!SK_%~2!"
call :unlink "!u_dest!"
set "u_show=!u_dest:%H%=~!"
echo removed !u_show!
set /a REMOVED+=1
exit /b 0

rem :apply_tool TOOL_INDEX
:apply_tool
set "a_ti=%~1"
set "a_show=!TDIR_%~1!"
set "a_show=!a_show:%H%=~!"
echo !TLABEL_%~1!  !a_show!
for /l %%s in (1,1,!NS!) do call :apply_skill !a_ti! %%s
exit /b 0

rem :apply_skill TOOL_INDEX SKILL_INDEX
:apply_skill
set "p_dir=!TDIR_%~1!"
set "p_name=!SK_%~2!"
set "p_dest=!p_dir!\!p_name!"
set "p_src=!SKILLS_SRC!\!p_name!"
set "p_ours="
call :is_ours %~1 %~2 && set "p_ours=1"
set "p_tgt=!TGT!"
if "!SST_%~2!"=="1" goto ap_want
if defined p_ours (
  call :unlink "!p_dest!"
  echo   removed !p_name!
  set /a REMOVED+=1
)
exit /b 0
:ap_want
if defined p_ours if /i "!p_tgt!"=="!p_src!" (
  set /a KEPT+=1
  exit /b 0
)
if defined p_ours (
  rem Points at an old path in this clone; refresh it.
  call :unlink "!p_dest!"
  call :link "!p_dest!" "!p_src!"
  echo   relinked !p_name!
  set /a ADDED+=1
  exit /b 0
)
if exist "!p_dest!" (
  >&2 echo   warning: skipped !p_name!: !p_dest! already exists and isn't ours
  set /a SKIPPED+=1
  exit /b 0
)
if not exist "!p_dir!\" call :mkd "!p_dir!"
call :link "!p_dest!" "!p_src!"
if errorlevel 1 (
  >&2 echo   warning: could not link !p_name! into !p_dir!
  set /a SKIPPED+=1
  exit /b 0
)
echo   linked !p_name!
set /a ADDED+=1
exit /b 0
