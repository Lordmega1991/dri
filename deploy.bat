@echo off
echo 🔨 Building Next.js app...
cd dri_web
call npm run build
cd ..

echo 🚀 Deploying to Firebase (Hosting only)...
firebase deploy --only hosting

echo ✅ Deploy completed!
echo 🌐 Your app is live at: https://dri-ufpb.web.app
timeout 10