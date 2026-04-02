<div align="center">
  <h1>🛡️ Nirbhaya: Women's Safety Application</h1>
  <p>Your ultimate safety companion, engineered efficiently across a connected Flutter frontend and a scalable NodeJS backend.</p>
</div>

---

## 🚀 Features at a Glance

* **🌍 Dynamic Embedded Maps:** Search for routes between locations and see them intelligently mapped out dynamically inside the app natively using `flutter_map` and OSRM logic.
* **🔒 Secure Authentication:** Deeply enforced JWT-based user lifecycle management natively verified against MongoDB and parsed silently in standard generic services.
* **👩🏻‍💻 Dynamic Profiles:** Add, modify, and render unique backend profile assets in runtime with custom edit pipelines built directly against Express models.
* **📣 Action-Oriented Network:** A responsive UI that adapts and provides aggressive actions such as instant SMS triggers or safety pings locally.
* **💪 Sleek Design Language:** Elegant Auth, Safety checks, Profiles, and Home layouts rendered to run seamlessly.

---

## 🛠️ System Architecture

Our repository incorporates **three distinct modules** strictly containerized for clarity and rapid development:

| Directory   | Purpose  |
|-------------|----------|
| `WomenSafetyApp/` | The core **Flutter Web/Mobile** interface responsible for routing rendering, UI logic, layouts, and HTTP REST parsing.  |
| `backend/` | An autonomous **Express Node.JS** service managing routes, `mongoose` models, user validation, and security protocols. |
| `mongo-db/` | The encapsulated state directory retaining absolute snapshots of the live **MongoDB** data fragments and local caches. |

---

## 🧱 Setup & Execution

### 1️⃣ Database Node
Simply clone the repository and execute an encapsulated daemon instance:
```bash
cd mongo-db
# Trigger the DB locally pointing to this cache path:
mongod --dbpath . --fork --logpath ./mongo-log.log
```

### 2️⃣ Backend REST Engine
Shift over to the server architecture and unleash the runtime API listeners:
```bash
cd ../backend
npm install
node server.js
```

### 3️⃣ Flutter Interface
Navigate to the root frontend interface, resolve properties and inject instances safely:
```bash
cd ../WomenSafetyApp
flutter pub get
flutter run -d chrome
```

---

<p align="center"><i>Proudly coded, maintained, and implemented as an integrated safety package.</i></p>
