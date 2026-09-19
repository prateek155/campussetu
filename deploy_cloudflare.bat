@echo off
echo ===================================================
echo   CampusSetu - Cloudflare Pages Deployer
echo ===================================================
echo.
echo Make sure you have already run build_all_web.bat!
echo.

echo [1/4] Deploying User Web Portal to Cloudflare Pages...
call npx -y wrangler pages deploy build/web_user --project-name campussetu-user --commit-dirty=true

echo.
echo [2/4] Deploying Admin Web Portal to Cloudflare Pages...
call npx -y wrangler pages deploy build/web_admin --project-name campussetu-admin --commit-dirty=true

echo.
echo [3/4] Deploying Enterprise Web Portal to Cloudflare Pages...
call npx -y wrangler pages deploy build/web_enterprise --project-name campussetu-enterprise --commit-dirty=true

echo.
echo [4/4] Deploying Faculty Web Portal to Cloudflare Pages...
call npx -y wrangler pages deploy build/web_faculty --project-name campussetu-faculty --commit-dirty=true

echo.
echo ===================================================
echo   All 4 Web Portals Deployed to Cloudflare Pages!
echo   - User:       https://campussetu-user.pages.dev
echo   - Admin:      https://campussetu-admin.pages.dev
echo   - Enterprise: https://campussetu-enterprise.pages.dev
echo   - Faculty:    https://campussetu-faculty.pages.dev
echo ===================================================
pause
