# Getting started: run Pin on another machine

Copy-paste commands to start the whole project from a fresh `git clone`.
Pin has four parts: `backend` (Spring Boot API), `merchant-app` and `user-app` (Flutter, Android),
and `admin-panal` (Vue web page).

## 0. Install once

| Tool | Version | Used for |
|---|---|---|
| Git | any | cloning |
| JDK | **21 or newer** | the backend |
| Docker Desktop | running | the backend's database (PostgreSQL) and its tests |
| Flutter SDK | **3.47 or newer** (Dart 3.13.7+) | the two apps |
| Android Studio (SDK + an emulator) | any recent | running the apps. Or a real Android phone with USB debugging |
| Node.js | **20.19+ or 22.12+** | the admin panel |

Check them:

```bash
git --version
java -version          # must say 21 or higher
docker info            # must not print an error (start Docker Desktop first)
flutter doctor         # fix anything it marks with an [✗] for Android
node --version
```

## 1. Get the code

```bash
git clone https://github.com/Takaguya/ticket-app.git
cd ticket-app
```

## 2. Start the backend (do this first)

Leave Docker Desktop running. This starts the database by itself, creates the tables and
loads demo data. The server listens on **http://localhost:8080**.

**Windows (PowerShell or cmd):**

```powershell
cd backend
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=dev"
```

**macOS / Linux:**

```bash
cd backend
chmod +x mvnw
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

It is ready when the log says `Started PinBackendApplication` and
`Demo data ready`. Keep this window open. The first start downloads Maven and the
libraries, so it takes a few minutes.

Check it from another window (`401` means it is up):

```bash
curl -i http://localhost:8080/merchant/events
```

> The `dev` profile turns on development-only settings (the sign-in code `123456` for every phone,
> demo data). The server refuses to start with them anywhere that is not a development machine.

## 3. Run the apps

Open a **new** terminal for each. Start an Android emulator in Android Studio
(Device Manager > Play), or plug in a phone with USB debugging, then check Flutter sees it:

```bash
flutter devices
```

### Fastest: demo mode (no backend needed)

The apps carry their own sample data, so this works even without step 2:

```bash
cd merchant-app
flutter pub get
flutter run
```

```bash
cd user-app
flutter pub get
flutter run
```

### Real: connected to the backend

**On the Android emulator** (it reaches your computer as `10.0.2.2`, already the default):

```bash
cd merchant-app
flutter pub get
flutter run --dart-define=USE_MOCK_API=false
```

```bash
cd user-app
flutter pub get
flutter run --dart-define=USE_MOCK_API=false
```

**On a real phone, over USB** (simplest: the phone reaches the backend through the cable):

```bash
adb reverse tcp:8080 tcp:8080
cd merchant-app
flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

(Same for `user-app`.)

**On a real phone, over Wi-Fi** (phone and computer on the same network):

1. Find the computer's address: `ipconfig` (Windows) or `ifconfig` / `ip a` (macOS / Linux). Say it is `192.168.1.8`.
2. Allow port 8080 through the computer's firewall.
3. Run:

```bash
cd merchant-app
flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=http://192.168.1.8:8080
```

(Same for `user-app`.)

**Make an APK to send to a phone** (debug build; plain `http` only works in debug builds):

```bash
cd merchant-app
flutter build apk --debug --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=http://192.168.1.8:8080
# the file: build/app/outputs/flutter-apk/app-debug.apk
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

The merchant app and the user app have different package names, so both can be installed together.

> A build without `--dart-define=USE_MOCK_API=false` is demo mode: it shows built-in sample data and never
> talks to the backend.

## 4. Run the admin panel

```bash
cd admin-panal
npm install
npm run dev
```

Open **http://localhost:5173**. It talks to the backend on port 8080 by itself.

## 5. Demo logins

The sign-in code is **`123456`** for every phone number. Enter the number without the `+855`.

| App | Who | Phone / email |
|---|---|---|
| Merchant app | Owner, Khmer Runners Club (events) | `12 345 678` |
| Merchant app | Scanner of that business | `98 765 432` |
| Merchant app | Owner, Giant Ibis (bus trips) | `17 905 662` |
| Merchant app | Owner, Legend Cinema (screenings) | `15 300 418` |
| Merchant app | Owner, Wildlife Alliance (places) | `78 315 940` |
| User app | Buyer Sokha Chan | `10 222 333` |
| Admin panel | Admin | `moniroth@pin.example` / password `pin-demo-admin` |

A quick tour: sign in as the buyer in the user app and book a ticket, then sign in as the owner in the
merchant app to see the booking, scan it, and sell at the door. Approve new events in the admin panel.

## 6. Run the tests

```bash
cd backend        && ./mvnw test        # needs Docker running; .\mvnw.cmd test on Windows
cd merchant-app   && flutter test
cd user-app       && flutter test
cd admin-panal    && npm test && npm run typecheck
```

## 7. If something goes wrong

| Problem | Fix |
|---|---|
| Backend: `Could not find a valid Docker environment` / connection refused | Start Docker Desktop, wait until it says running, start the backend again |
| Backend: `Port 8080 was already in use` | Stop the other program on 8080 |
| Backend: port `5434` in use | Something else uses 5434, the dev database's port; stop it |
| macOS / Linux: `Permission denied` on `./mvnw` | `chmod +x backend/mvnw` |
| App says it can't reach Pin | The backend isn't running, or `API_BASE_URL` is wrong for this device (see step 3) |
| Merchant app says "Welcome to Pin Merchant" for a demo number | It is a demo-mode build; rebuild with `--dart-define=USE_MOCK_API=false` |
| `Too many requests` when signing in | Sign-in is limited to 30 a minute per device; wait a minute |
| Flutter: `Android licenses not accepted` | `flutter doctor --android-licenses` |
| The demo bookings look old | Demo data is rebuilt the first time the backend starts on a new day: restart it |
| Start fresh (delete all data) | `docker compose -f backend/compose.yaml down -v`, then start the backend again |

## 8. Run it like a real server (Docker)

`backend/compose.prod.yaml` starts nginx, the backend and PostgreSQL. It needs an HTTPS certificate,
a domain and a `.env` file; see `backend/.env.example` and `backend/nginx/certs/README.md`:

```bash
cd backend
cp .env.example .env        # fill in the domain, a database password and the first admin
docker compose -f compose.prod.yaml up -d --build
```
