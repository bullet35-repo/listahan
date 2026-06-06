# Botoy's Listahan

A compact Flutter app for tracking orders, sales, and commissions. Ideal for small sellers who need a simple local app to record transactions and export reports.

Quick highlights
- Add, edit, and delete orders (customer, item, price, commission, date, due date, paid amount, payment status).
- Filter by month/year, search by customer/item, and filter by payment status (paid/partial/unpaid).
- Customer list with per-customer stats and balances.
- Export orders to CSV or PDF and share via the platform share dialog.
- Local storage using sqflite with web-compatible support and automatic migrations.
- Light/dark theme with persisted preference.

Quick start
1. Install Flutter (>=3.10) and Dart.
2. Install dependencies: `flutter pub get`
3. Run locally: `flutter run`
4. Run on web: `flutter run -d chrome`

Screenshots
- Replace the example images in `assets/` with your screenshots and update paths below.
- Example (suggested):
  - `assets/screenshots/home.png`
  - `assets/screenshots/orders_list.png`
  - `assets/screenshots/add_order.png`

License
This project is released under the MIT License — see `LICENSE` for details.

Contributing
PRs and issues are welcome. Keep changes focused and describe behavior in the PR body.