# Lorry Wood Logger (Flutter)

A simple, offline‑first Flutter app to record wood arriving by lorry, grouped by **Thickness (x)** → **Length (y)** → many **Widths (z)**.

## Screens

- **Home**: list of deliveries (lorry name + date) with counts.
- **Edit Delivery**: change lorry name/notes, add groups (x,y), add widths (z) via comma/space separated input, or use **Quick Entry** like:
  ```
  x=2 => y=3 => z=2,3,4,27,372,23,23
  ```
- **Export CSV**: per delivery, saves a CSV (lorry,date,thickness,length,width).

## Tech
- Flutter (Material 3)
- sqflite + path_provider
- Repository pattern, simple widgets (no login).

## Run
1. Create a new Flutter project or copy this `lib/` and `pubspec.yaml` into a clean folder.
2. `flutter pub get`
3. `flutter run`

Enjoy!
