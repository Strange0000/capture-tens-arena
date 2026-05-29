# API Documentation

Base URL: `http://localhost:8080`

## Health

`GET /health`

Response:

```json
{ "ok": true }
```

## Authentication

### Guest Login

`POST /auth/guest`

Creates a guest account and returns a JWT.

```json
{
  "token": "jwt",
  "user": { "id": "userId", "username": "GuestABC123", "roles": ["player"] }
}
```

### Google Login

`POST /auth/google`

Request:

```json
{
  "googleId": "provider-sub",
  "email": "player@example.com",
  "username": "Player",
  "avatarUrl": "https://example.com/avatar.png"
}
```

Production integration should verify the Google ID token before calling `loginWithGoogle`.

## User Profile

`GET /users/me`

Headers:

```text
Authorization: Bearer <jwt>
```

Returns user payload, ranking, and statistics.

## Leaderboard

`GET /users/leaderboard`

Returns top 100 ranked players for the current UTC quarter season.

## Admin

Admin endpoints require a JWT user with the `admin` role.

- `GET /admin/matches`
- `GET /admin/replays/:matchId`
