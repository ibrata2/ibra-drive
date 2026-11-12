; IBRA DRIVE — ملف التنصيب
Unicode true
!include "MUI2.nsh"

!define APPNAME "IBRA DRIVE"
!ifndef VERSION
  !define VERSION "1.1.0"
!endif
!define PUBLISHER "برمجة وتطوير إبراهيم الخزرجي - t.me/ibraprogram"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\IBRA_DRIVE"

Name "${APPNAME}"
OutFile "..\build\IBRA_DRIVE_Setup_${VERSION}.exe"
InstallDir "$PROGRAMFILES64\IBRA DRIVE"
InstallDirRegKey HKLM "Software\IBRA_DRIVE" "InstallDir"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
BrandingText "IBRA DRIVE ${VERSION} • برمجة وتطوير إبراهيم الخزرجي • t.me/ibraprogram"

!define MUI_ICON "icon.ico"
!define MUI_UNICON "icon.ico"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\IBRA_DRIVE.exe"
!define MUI_FINISHPAGE_RUN_TEXT "شغّل IBRA DRIVE هسه"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Arabic"
!insertmacro MUI_LANGUAGE "English"

VIProductVersion "${VERSION}.0"
VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductName" "${APPNAME}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "CompanyName" "${PUBLISHER}"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileDescription" "IBRA DRIVE Setup"

Section "Install"
  SetOutPath "$INSTDIR"
  File "..\build\IBRA_DRIVE.exe"
  File "icon.ico"
  File "..\README.md"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\IBRA DRIVE"
  CreateShortcut "$SMPROGRAMS\IBRA DRIVE\IBRA DRIVE.lnk" "$INSTDIR\IBRA_DRIVE.exe" "" "$INSTDIR\icon.ico"
  CreateShortcut "$SMPROGRAMS\IBRA DRIVE\إزالة IBRA DRIVE.lnk" "$INSTDIR\Uninstall.exe"
  CreateShortcut "$DESKTOP\IBRA DRIVE.lnk" "$INSTDIR\IBRA_DRIVE.exe" "" "$INSTDIR\icon.ico"
  WriteRegStr HKLM "Software\IBRA_DRIVE" "InstallDir" "$INSTDIR"
  WriteRegStr HKLM "${UNINSTKEY}" "DisplayName" "${APPNAME}"
  WriteRegStr HKLM "${UNINSTKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${UNINSTKEY}" "Publisher" "${PUBLISHER}"
  WriteRegStr HKLM "${UNINSTKEY}" "DisplayIcon" "$INSTDIR\icon.ico"
  WriteRegStr HKLM "${UNINSTKEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\IBRA_DRIVE.exe"
  Delete "$INSTDIR\icon.ico"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$DESKTOP\IBRA DRIVE.lnk"
  Delete "$SMPROGRAMS\IBRA DRIVE\IBRA DRIVE.lnk"
  Delete "$SMPROGRAMS\IBRA DRIVE\إزالة IBRA DRIVE.lnk"
  RMDir "$SMPROGRAMS\IBRA DRIVE"
  DeleteRegKey HKLM "${UNINSTKEY}"
  DeleteRegKey HKLM "Software\IBRA_DRIVE"
SectionEnd
