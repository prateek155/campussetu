@echo off
echo ===================================================
echo   CampusSetu - Building 4 Web Portals
echo ===================================================

echo [1/4] Building User Web (Student Portal)...
call flutter build web -t lib/main_user.dart
if exist "build\web_user" rmdir /s /q "build\web_user"
xcopy /s /e /i /y "build\web" "build\web_user"

echo.
echo [2/4] Building Admin Web Portal...
call flutter build web -t lib/main_admin.dart
if exist "build\web_admin" rmdir /s /q "build\web_admin"
xcopy /s /e /i /y "build\web" "build\web_admin"

echo.
echo [3/4] Building Enterprise Web Portal...
call flutter build web -t lib/main_enterprise.dart
if exist "build\web_enterprise" rmdir /s /q "build\web_enterprise"
xcopy /s /e /i /y "build\web" "build\web_enterprise"

echo.
echo [4/4] Building Faculty Web Portal...
call flutter build web -t lib/main_faculty.dart
if exist "build\web_faculty" rmdir /s /q "build\web_faculty"
xcopy /s /e /i /y "build\web" "build\web_faculty"

echo.
echo ===================================================
echo   All 4 Web Portals Built Successfully!
echo   - User Web:        build\web_user
echo   - Admin Web:       build\web_admin
echo   - Enterprise Web:  build\web_enterprise
echo   - Faculty Web:     build\web_faculty
echo ===================================================
pause
