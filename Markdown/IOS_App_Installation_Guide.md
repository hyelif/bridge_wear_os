iOS Hobbyist Build Guide (Linux to iPhone Workaround)This guide allows you to build and sign your Flutter iOS app using GitHub Actions and a free personal Apple ID, completely bypassing the need for a local Mac or heavy Virtual Machines on your Intel N100 laptop.
🛠️ Overview of the StrategyExtract Credentials: Use your Linux machine to download your free Apple ID provisioning files.Secret Storage: Upload those files securely to your GitHub repository.Cloud Build: GitHub Actions boots a powerful cloud Mac, signs your app, and builds the .ipa file.Local Install: Download the .ipa to Linux and push it to your iPhone via USB.
📋 Prerequisites on LinuxOpen your Linux terminal and install the tools needed to interact with your iPhone and extract Apple files:bash# Install tools to install apps to iOS over USB
sudo apt update
sudo apt install ruby-full libimobiledevice-utils ideviceinstaller -y


00008120-000E7C8C3A10C01E iphone 14 pro UUID
# Install Fastlane (used to fetch Apple credentials)
sudo gem install fastlane
Use code with caution.
🔓 Step 1: Extract Your Free Profile & CertificateBecause your Apple ID is free, you must extract a specific file called a Provisioning Profile which pairs your unique iPhone to your app.A. Register your App ID and Device manuallyOpen your web browser on Linux and go to Apple Developer Portal.Log in with your free personal Apple ID.Because you are on a free account, you cannot access the advanced certificates dashboard. Instead, we trick Apple by creating a dummy profile:Plug your iPhone into your Linux PC.Open a terminal and run ideviceinfo | grep UniqueDeviceID to get your phone's UDID.Note down this UDID number.B. Extracting the Configuration Files via FastlaneIn your Flutter project root directory, run:bashfastlane sigh download_all --development
Use code with caution.Enter your Apple ID and password when prompted.Fastlane will connect to Apple, generate a temporary 7-day development profile for your account, and download a .mobileprovision file to your folder.Rename this file to profile.mobileprovision.
🔑 Step 2: Convert Files for GitHub SecretsGitHub Actions cannot read raw files directly; they must be encoded into text strings called Base64.Run this command in your Linux terminal to turn your profile file into text:bashbase64 -w 0 profile.mobileprovision > profile_base64.txt
Use code with caution.Open profile_base64.txt and copy the long string of text inside it.Go to your GitHub Repository -> Settings -> Secrets and variables -> Actions.Click New repository secret.Name it: IOS_PROVISION_PROFILE_BASE64Paste the text string as the value and save.
🚀 Step 3: Create the GitHub Actions WorkflowIn your Flutter project folder on Linux, create a new folder structure: .github/workflows/. Inside it, create a file named ios-build.yml.Paste the exact configuration below into .github/workflows/ios-build.yml:yamlname: Build iOS Hobby App

on:
  push:
    branches: [ main ] # Triggers whenever you push code to the main branch
  workflow_dispatch: # Allows you to trigger the build manually from GitHub web UI

jobs:
  build:
    runs-on: macos-latest # Utilizes GitHub's free Mac servers

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Setup Java (For Flutter dependencies)
        uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: Setup Flutter Toolchain
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          architecture: x64

      - name: Install Project Dependencies
        run: flutter pub get

      - name: Inject Free Apple Provisioning Profile
        env:
          PROFILE_BASE64: ${{ secrets.IOS_PROVISION_PROFILE_BASE64 }}
        run: |
          # Recreate the profile folder structure Apple expects
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          echo "$PROFILE_BASE64" | base64 --decode > ~/Library/MobileDevice/Provisioning\ Profiles/profile.mobileprovision

      - name: Build iOS IPA
        run: |
          # Build a development IPA file signed without a paid team profile
          flutter build ipa --development --no-codesign

      - name: Upload Finished App Artifact
        uses: actions/upload-artifact@v4
        with:
          name: ios-app-file
          path: build/ios/ipa/*.ipa
Use code with caution.Commit this file and push your code to GitHub:bashgit add .
git commit -m "Add iOS automated cloud build"
git push origin main
Use code with caution.
📥 Step 4: Download and Install on iPhoneGo to your GitHub repository webpage and click on the Actions tab.Click on the Build iOS Hobby App workflow run that just started.Wait about 5 to 8 minutes for the cloud Mac to finish compiling your Flutter app.Once completed, scroll to the bottom under Artifacts and download the ios-app-file zip archive.Extract the zip file on your Linux laptop to locate your app's file (e.g., Runner.ipa).Sideloading the app over USB to your iPhone:Plug your iPhone into your Linux laptop via USB, tap Trust on your phone screen, and run:bashideviceinstaller -i Runner.ipa
Use code with caution.The app will install directly onto your home screen.
⚠️ Important Limitations for HobbyistsThe 7-Day Expiry: Because your Apple ID is free, Apple automatically cancels the security token after exactly 7 days. The app will crash when you tap it after a week. To fix this, you just need to download a fresh .mobileprovision file (Step 1B) and trigger your GitHub action build again once a week.Enable Developer Mode: On your iPhone, you must go to Settings -> Privacy & Security -> scroll down to Developer Mode and turn it ON for sideloaded apps to open.