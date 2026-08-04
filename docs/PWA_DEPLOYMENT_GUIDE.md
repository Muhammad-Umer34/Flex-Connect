# 📱 Flex Connect - iOS / iPhone PWA Deployment Guide

This guide explains how to compile **Flex Connect** as a Progressive Web App (PWA) and host it completely **free of cost** so iPhone (iOS) users can use and install the native-like app directly onto their home screens without needing an Apple Developer Account or the App Store.

---

## 🛠️ Step 1: Build the Web App

1. Open your terminal in the project directory:
   ```bash
   cd app
   ```

2. Run the Flutter web release build command:
   ```bash
   flutter build web --release
   ```

3. Once complete, the production web bundle will be generated in:
   ```
   app/build/web/
   ```

---

## 🌐 Step 2: Host the Web App for Free

You can host the compiled web bundle (`app/build/web`) on any free static hosting provider. Here are the 3 simplest options:

### Option A: Vercel (Recommended - Easiest & Fastest)
1. Sign up / log in to [Vercel](https://vercel.com) (Free account).
2. Install Vercel CLI or connect your GitHub repository:
   * **Via GitHub**: Push your repository to GitHub, click **New Project** on Vercel, select your repository, set Root Directory to `app/build/web`, and click **Deploy**.
   * **Via Vercel CLI**:
     ```bash
     npm i -g vercel
     cd app/build/web
     vercel --prod
     ```
3. Vercel will give you a free production HTTPS link (e.g. `https://flex-connect.vercel.app`).

---

### Option B: Netlify (Free Drag-and-Drop Hosting)
1. Go to [Netlify](https://app.netlify.com/drop).
2. Simply drag and drop your `app/build/web` folder into the Netlify dashboard.
3. Netlify will generate a live HTTPS URL instantly!

---

### Option C: GitHub Pages
1. Push the contents of `app/build/web` to a `gh-pages` branch on your GitHub repository.
2. In your GitHub Repo Settings $\rightarrow$ **Pages**, set source to `gh-pages` branch.
3. Access your app at `https://<your-username>.github.io/Flex-Connect-App/`.

---

## 📲 Step 3: Instructions for iPhone (iOS) Users

Share your live web link (e.g., `https://flex-connect.vercel.app`) with iPhone users along with these simple instructions:

1. **Open link in Safari**: iPhone users must open the URL in **Safari** (iOS default browser).
2. **Tap Share Icon**: Tap the **Share** button (the box with an upward arrow at the bottom of Safari).
3. **Add to Home Screen**: Scroll down and select **"Add to Home Screen"**.
4. **Launch & Use**: The **Flex Connect** icon will appear on their iPhone home screen. Tapping it opens the app full-screen, cleanly isolated like a native iOS application!

---

## 🔒 Safety Note
* Compiling and deploying the PWA does **not** alter, modify, or break any native Android app builds (`.apk`) or underlying Flutter application code.
