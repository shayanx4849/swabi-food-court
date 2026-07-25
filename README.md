# BachaoKhana

A Flutter + Firebase mobile app that connects restaurants, bakeries, and marts
with customers to sell surplus/leftover food at a discount — reducing food
waste in Pakistan. This is the working codebase for the FYP proposal
("BachaoKhana: A Flutter-Based Mobile Application for Rescuing Surplus Food").

## Tech Stack (No Credit/Debit Card Required)

| Purpose | Technology | Why |
|---|---|---|
| Frontend | Flutter (Android & iOS) | — |
| Auth | Firebase Authentication | Free on Spark plan, no card |
| **Database** | **Firebase Realtime Database** | Free on Spark plan, no card — used instead of Cloud Firestore, which now requires a billing account (Blaze plan) even for free-tier usage |
| **Image storage** | **Cloudinary** | Free tier, no card required — used instead of Firebase Storage |
| Location | Geolocator + Google Maps API | — |
| QR codes | `qr_flutter` / `mobile_scanner` | — |

> **Why not Firestore / Firebase Storage?** Google now requires a linked
> billing account (a card) to enable Cloud Firestore and Firebase Storage on
> new projects, even though usage stays free within the Spark quota. Realtime
> Database and Cloudinary both offer generous free tiers with **no card
> required at all**, so this codebase uses them instead.

---

## 1. Prerequisites

| Tool | Purpose | Link |
|---|---|---|
| Flutter SDK (3.x+) | Build the app | https://docs.flutter.dev/get-started/install |
| Android Studio | Android emulator + SDK | https://developer.android.com/studio |
| Node.js (18+) | Needed for the Firebase CLI | https://nodejs.org |
| Git | Version control | https://git-scm.com |
| A Google account | To create the Firebase project | — |

Verify Flutter is installed correctly:

```bash
flutter doctor
```

---

## 2. Get the Project Running Locally

This folder contains only the `lib/` source code and `pubspec.yaml` — set it
up like this:

```bash
# 1. Create a fresh Flutter project shell
flutter create bachaokhana
cd bachaokhana

# 2. Delete the default lib/ and pubspec.yaml Flutter generated
rm -rf lib
rm pubspec.yaml

# 3. Copy in this project's lib/ folder and pubspec.yaml
cp -r /path/to/downloaded/bachaokhana_app/lib .
cp /path/to/downloaded/bachaokhana_app/pubspec.yaml .

# 4. Install dependencies
flutter pub get
```

---

## 3. Set Up Firebase (Auth + Realtime Database — No Card Needed)

1. Go to https://console.firebase.google.com → **Add project** → name it
   e.g. `bachaokhana-app`.
2. Install the Firebase CLI and the FlutterFire CLI:

   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   ```

3. From inside your project folder, log in and connect:

   ```bash
   firebase login
   flutterfire configure
   ```

   Select the Firebase project you created, and select Android + iOS as
   platforms. This automatically overwrites the placeholder
   `lib/firebase_options.dart` with your real project's configuration —
   don't edit that file by hand.

4. In the Firebase Console, enable these two services (both free, no card):

   **Authentication:**
   - If "Authentication" isn't visible directly in the sidebar, use the
     search bar at the top of the console and type "Authentication".
   - Click **Get started** → **Sign-in method** tab → enable
     **Email/Password** → **Save**.

   **Realtime Database** (NOT Cloud Firestore):
   - Search for "Realtime Database" in the console search bar, or find it
     under **Databases and storage**.
   - Click **Create Database**.
   - Choose a location.
   - Select **Start in test mode** (fine for development/demo; tighten
     rules before any public deployment).
   - This should enable with **no billing prompt**. If you accidentally
     click into "Firestore" instead and hit a billing error, that's the
     wrong database — go back and select "Realtime Database" specifically.

5. `lib/main.dart` already initializes Firebase correctly:

   ```dart
   await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
   );
   ```

---

## 4. Set Up Cloudinary (Image Uploads — Free, No Card)

1. Create a free account at https://cloudinary.com/users/register/free
   (email only, no card needed).
2. On your Cloudinary dashboard, copy your **Cloud name**.
3. Go to **Settings → Upload → Upload presets → Add upload preset**:
   - Set **Signing Mode** to **Unsigned** (this lets the app upload
     directly without embedding a secret key).
   - Save, and copy the preset's name.
4. Open `lib/services/cloudinary_service.dart` and replace the two
   placeholders:

   ```dart
   static const String cloudName = 'YOUR_CLOUD_NAME';
   static const String uploadPreset = 'YOUR_UNSIGNED_UPLOAD_PRESET';
   ```

   with your actual values from steps 2–3.

If you skip this setup, the app still works — businesses just won't be able
to attach a photo when creating a listing (the upload silently fails and the
listing is published without an image).

---

## 5. Set Up Google Maps API (for distance calculations)

1. Go to https://console.cloud.google.com → APIs & Services → enable
   **Maps SDK for Android** and **Maps SDK for iOS**.
2. Create an API key under **Credentials**.
   (Note: enabling Google Maps APIs on Google Cloud may itself prompt for
   billing on some accounts. If you hit that and don't have a card, you can
   skip this step for now — the app's distance *sorting* in
   `location_service.dart` uses raw lat/lng math and doesn't strictly
   require the Maps SDK unless you later add a visual map view.)
3. If you do set it up, add the key to:
   - **Android:** `android/app/src/main/AndroidManifest.xml`
     ```xml
     <meta-data
         android:name="com.google.android.geo.API_KEY"
         android:value="YOUR_API_KEY_HERE"/>
     ```
   - **iOS:** `ios/Runner/AppDelegate.swift`
     ```swift
     GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
     ```

---

## 6. Realtime Database Data Structure

Unlike Firestore's collections, Realtime Database stores everything as one
big JSON tree. The app organizes it like this automatically:

```
bachaokhana-app-default-rtdb
 ├── users
 │    └── {uid}: { uid, email, name, role, phone }
 │
 ├── businesses
 │    └── {businessId}: { ownerId, name, category, address, lat, lng, verified }
 │
 ├── listings
 │    └── {listingId}: { businessId, businessName, title, description,
 │                        price, originalPrice, quantityAvailable,
 │                        pickupStart, pickupEnd, status, lat, lng, imageUrl }
 │
 └── orders
      └── {orderId}: { listingId, businessId, businessName, listingTitle,
                        customerId, customerName, price, qrCode, status,
                        createdAt }
```

**Note on business location:** the signup screen saves a new business with
`lat: 0, lng: 0` as a placeholder. For a real pilot test, manually update
each test business's `lat`/`lng` in the Firebase Console (Realtime Database
→ your data → businesses → {businessId}) so that customer distance sorting
works correctly.

**Recommended indexing:** since the app queries by `ownerId`, `businessId`,
and `customerId`, add this to your Realtime Database rules for better query
performance (Console → Realtime Database → Rules):

```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null",
    "businesses": {
      ".indexOn": ["ownerId"]
    },
    "listings": {
      ".indexOn": ["businessId", "status"]
    },
    "orders": {
      ".indexOn": ["businessId", "customerId"]
    }
  }
}
```

---

## 7. Running the App

```bash
flutter devices        # confirm a device is detected
flutter run
```

Platform-specific:

```bash
flutter run -d android
flutter run -d ios        # macOS + Xcode only
```

Build a release APK (for demo/submission):

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## 8. Trying It Out (manual test flow)

1. Sign up once as a **Business** (fill in name + address).
2. In the Firebase Console → Realtime Database → `businesses` → your new
   business entry, manually set `lat`/`lng` to real coordinates.
3. Sign out, sign up again as a **Customer** using a different email.
4. Log in as **Business** → **+ New listing** → optionally add a photo →
   fill in details → publish.
5. Log in as **Customer** → the listing appears on the home feed → tap it →
   **Reserve this bag** → a QR code appears.
6. Log in as **Business** → tap the QR scan icon → scan the QR code from the
   customer's screen (use two devices/emulators).
7. The order flips to **completed**, visible in both the business's
   **Orders** tab and the customer's **My orders** screen.

---

## 9. Common Issues

| Problem | Fix |
|---|---|
| `flutter doctor` shows Android license errors | `flutter doctor --android-licenses`, accept all |
| App crashes on launch with a Firebase error | Re-run `flutterfire configure`; confirm `lib/firebase_options.dart` no longer says `REPLACE_ME` |
| "This API method requires billing" error | You (or someone) clicked into **Cloud Firestore** instead of **Realtime Database**. This project only needs Realtime Database — go to the Firebase Console, search "Realtime Database", and create that instead. |
| Customer feed is empty | Confirm the listing's `status` is `"active"`; check Realtime Database rules aren't blocking reads |
| Distance sorting looks wrong | The business's `lat`/`lng` is still `0,0` — update it manually (see step 6 above) |
| Photo doesn't upload | Confirm `cloudName` and `uploadPreset` in `cloudinary_service.dart` are correct, and that the preset's Signing Mode is set to **Unsigned** |
| QR scanner shows a black screen | Grant camera permission; on Android, add camera permission to `AndroidManifest.xml` if missing |
| Gradle build fails | `flutter clean && flutter pub get`, then retry |
| iOS build fails | `cd ios && pod install && cd ..` |

---

## 10. Suggested Next Steps (beyond this MVP)

- [ ] Add address-to-coordinates geocoding during business signup
- [ ] Replace the list-based discovery screen with a real Google Map view
- [ ] Wire up Firebase Cloud Messaging for new-listing and pickup-reminder notifications
- [ ] Build the admin panel (business verification, dispute handling)
- [ ] Tighten Realtime Database security rules before any public/pilot deployment
- [ ] Pilot test with 2–3 real local businesses
