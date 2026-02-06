@echo off
echo 🔨 Building Flutter web...
flutter clean
flutter pub get
flutter build web --release --no-wasm-dry-run

echo 🚀 Deploying to Firebase...
firebase deploy

echo ✅ Deploy completed!
echo 🌐 Your app is live at: https://gp-dri-x.web.app
timeout 10