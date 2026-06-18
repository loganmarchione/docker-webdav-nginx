# WebDAV Admin API

The WebDAV Admin API provides a REST interface for managing WebDAV users. It allows listing, creating, and removing users, each of whom receives their own isolated storage directory and credentials.

## Base URL

```
http://<host>:<port>/admin/api
```

## Authentication

All API requests require **HTTP Basic Auth**. Credentials are configured via environment variables:

| Variable      | Description              |
|---------------|--------------------------|
| `ADMIN_USER`  | Admin username           |
| `ADMIN_PASS`  | Admin password           |

Include credentials in every request using the `-u` flag with curl, or the `Authorization` header with a Base64-encoded `username:password` pair.

---

## Endpoints

### List Users

Returns a list of all configured WebDAV usernames.

**Request**

```
GET /admin/api/users
```

**Response** `200 OK`

```json
{
  "users": ["user1", "user2"]
}
```

**Example**

```bash
curl -s -u admin:changeme http://localhost:8888/admin/api/users
```

---

### Add User

Creates a new WebDAV user with their own credentials and storage directory.

**Request**

```
POST /admin/api/users
Content-Type: application/json
```

```json
{
  "username": "user3",
  "password": "password3"
}
```

**Validation Rules**

- `username` and `password` are both required.
- `username` must be alphanumeric (hyphens and underscores are allowed).
- `username` must not already exist.

**Response** `201 Created`

```json
{
  "success": true,
  "message": "User 'user3' created successfully"
}
```

**Response** `400 Bad Request`

```json
{
  "success": false,
  "message": "User 'user3' already exists"
}
```

**Side Effects**

1. Creates an htpasswd credential file at `/etc/nginx/webdav_credentials/<username>`.
2. Creates a storage directory at `/var/www/webdav/<username>`.
3. Regenerates the nginx configuration and reloads nginx.
4. Persists the user to `/var/www/webdav/.users`.

**Example**

```bash
curl -s -X POST -u admin:changeme \
  -H "Content-Type: application/json" \
  -d '{"username":"user3","password":"password3"}' \
  http://localhost:8888/admin/api/users
```

---

### Remove User

Deletes a WebDAV user and all of their stored files.

**Request**

```
DELETE /admin/api/users/<username>
```

**Path Parameters**

| Parameter  | Description             |
|------------|-------------------------|
| `username` | The user to remove      |

**Response** `200 OK`

```json
{
  "success": true,
  "message": "User 'user3' removed successfully"
}
```

**Response** `404 Not Found`

```json
{
  "success": false,
  "message": "User 'user3' does not exist"
}
```

**Side Effects**

1. Deletes the htpasswd credential file.
2. Deletes the user's storage directory and all files within it.
3. Regenerates the nginx configuration and reloads nginx.
4. Removes the user from `/var/www/webdav/.users`.

**Example**

```bash
curl -s -X DELETE -u admin:changeme \
  http://localhost:8888/admin/api/users/user3
```

---

## Admin UI

A web-based management interface is available at:

```
http://<host>:<port>/admin
```

It uses the same Basic Auth credentials as the API (`ADMIN_USER` / `ADMIN_PASS`) and provides a browser interface to list, add, and remove WebDAV users without using the command line.
