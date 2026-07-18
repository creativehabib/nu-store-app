# NU Store Management Clean Architecture

The Flutter app is organized by feature with a shared core layer. Each feature can grow independently while still using the same Riverpod, Dio, and Hive infrastructure.

```text
lib/
  core/
    network/              # Dio client, interceptors, API errors
    storage/              # Hive-backed local persistence
    theme.dart            # App theme tokens
  shared/
    providers/            # Cross-feature Riverpod providers
    widgets/              # Reusable UI widgets
  features/
    auth/
      data/               # AuthRepository and remote/local data source logic
      domain/             # AuthState, entities, validation rules
      presentation/       # Login, reset password, 2FA UI, controllers
    dashboard/
      data/               # DashboardRepository API calls
      domain/             # DashboardStats entity/model
      presentation/       # Dashboard screen, drawer, bottom navigation
    inventory/
      data/               # Category, product, stock entry repositories
      domain/             # Inventory entities and business rules
      presentation/       # Category/product/stock screens and providers
    requisition/
      data/               # Requisition API and cache repositories
      domain/             # Requisition workflow entities
      presentation/       # Create, my requisitions, approval, final print UI
    organization/
      data/               # Department, designation, purpose repositories
      domain/             # Organization setup entities
      presentation/       # Organization management screens
    settings/
      data/               # Profile, language, security, notification settings data
      domain/             # Settings entities and policies
      presentation/       # Profile, security, language switcher UI
```

## Package plan

`pubspec.yaml` includes the baseline packages required for the requested stack:

- `flutter_riverpod`: app state, controllers, async API state, navigation state.
- `dio`: Laravel API communication and bearer token interceptors.
- `hive` and `hive_flutter`: local token/user cache and future offline inventory cache.
- `intl`: localization/date/number formatting groundwork for the language switcher.

## API contract assumptions

The scaffold points to `https://store.creativehabib.com` by default and expects these Laravel endpoints under `/api/v1`:

- `POST /auth/register` for new API user registration.
- `POST /auth/login` with `login`, `password`, and optional `device_name`, returning nested `data.token` and `data.user`.
- `GET /auth/me` for token validation and profile refresh.
- `POST /auth/logout` for server-side token revocation.
- `GET /inventory` for inventory rows used to derive current and low-stock counts.
- `GET /products` and `GET /categories` for inventory management lists.
- `GET /departments`, `GET /designations`, and `GET /purposes` for organization setup lists.
- `GET /requisitions` for My Requisitions, pending requisition counts, and approval queue summaries.
- `GET /stock-entries` for stock-in/entry lists and dashboard stock-entry summaries.
- `GET /settings` for app/backend settings.

The API client accepts `--dart-define=API_BASE_URL=...` and `--dart-define=API_TOKEN=...` overrides. If the user has not logged in yet, the provided bootstrap API token is attached as a bearer token so the configured list endpoints can be validated against the live domain.

The auth controller treats users as approved when the API user payload contains `approved: true`, `is_approved: true`, or a non-null `approved_at`, matching a mobile equivalent of the Laravel `CheckIfApproved` middleware gate.

## Role-based access rules

The mobile UI uses `AppRole` and `RolePermissions` to map backend roles to visible navigation items and workflow actions:

- `Admin`: full access to inventory, organization, settings, requisitions, approvals, forwarding, final approval, and print.
- `Requisitioner`: can create requisitions and view their own requisition status/location.
- `Initiator`: receives the first requisition queue, forwards to the next role, and can print the final requisition letter after completion.
- `Assistant Director`: first verification/review step for requisitions.
- `Deputy Director`: second verification/review step for requisitions.
- `Director`: final approval step for requisitions.
