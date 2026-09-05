# Log Pengujian Image Generation melalui Antigravity OAuth

Log ini mencatat pengujian langsung endpoint image generation pada instance 9Router.

## Tujuan

Membuktikan bahwa image generation native Antigravity dapat diakses melalui 9Router tanpa Gemini API key.

Acceptance criteria:

1. Model image Antigravity tersedia.
2. Request menggunakan API key 9Router dan OAuth Antigravity di sisi server.
3. Endpoint mengembalikan HTTP `200`.
4. Output bukan base64 kosong.
5. Base64 dapat didecode menjadi image valid.
6. Image mempunyai dimensi yang dapat dibaca.
7. Binary response mempunyai MIME dan filename yang benar.

## Environment

```text
Tanggal       : 4 September 2026
Timezone      : Asia/Jakarta (UTC+7)
Base URL      : https://9router.adoetz52.my.id/v1
9Router       : 0.5.65
Model         : ag/gemini-3.1-flash-image
Authentication: Bearer <REDACTED_9ROUTER_API_KEY>
```

API key asli tidak dimasukkan ke file ini.

## Ringkasan

| Test | Mode | HTTP | Bytes | Dimensi | Waktu | Hasil |
|---:|---|---:|---:|---:|---:|---|
| 1 | Model discovery | 200 | — | — | — | PASS |
| 2 | JSON `b64_json` | 200 | 116,921 | 1024×1024 | 14.305s | PASS |
| 3 | Binary JPEG | 200 | 395,756 | 1024×1024 | 19.479s | PASS |

---

## Log 01 — Version check

Request:

```http
GET /api/version HTTP/1.1
Host: 9router.adoetz52.my.id
Authorization: Bearer <REDACTED_9ROUTER_API_KEY>
```

Response:

```json
{
  "currentVersion": "0.5.65",
  "latestVersion": "0.5.65",
  "hasUpdate": false
}
```

Status: **PASS**.

## Log 02 — Image model discovery

Timestamp:

```text
2026-09-04T20:31:24+07:00
```

Request:

```http
GET /v1/models/image HTTP/1.1
Host: 9router.adoetz52.my.id
Authorization: Bearer <REDACTED_9ROUTER_API_KEY>
```

Response:

```json
{
  "object": "list",
  "data": [
    {
      "id": "gemini/gemini-3.1-flash-image-preview",
      "object": "model",
      "owned_by": "gemini"
    },
    {
      "id": "gemini/gemini-3-pro-image-preview",
      "object": "model",
      "owned_by": "gemini"
    },
    {
      "id": "gemini/gemini-2.5-flash-image",
      "object": "model",
      "owned_by": "gemini"
    },
    {
      "id": "ag/gemini-3.1-flash-image",
      "object": "model",
      "owned_by": "ag"
    }
  ]
}
```

Transport:

```text
HTTP_STATUS=200
```

Status: **PASS**.

## Log 03 — Model capability

Request:

```http
GET /v1/models/info?id=ag%2Fgemini-3.1-flash-image HTTP/1.1
Host: 9router.adoetz52.my.id
Authorization: Bearer <REDACTED_9ROUTER_API_KEY>
```

Response:

```json
{
  "id": "ag/gemini-3.1-flash-image",
  "name": "Gemini 3.1 Flash (Image)",
  "kind": "image",
  "owned_by": "ag",
  "endpoint": "/v1/images/generations",
  "capabilities": ["textToImage"]
}
```

Transport:

```text
HTTP_STATUS=200
```

Status: **PASS**.

---

## Log 04 — JSON `b64_json`

Completion timestamp:

```text
2026-09-04T20:32:25.6631625+07:00
```

Endpoint:

```text
POST /v1/images/generations
```

Payload:

```json
{
  "model": "ag/gemini-3.1-flash-image",
  "prompt": "A clean minimalist illustration of a small blue robot holding a magnifying glass, white background, no text",
  "n": 1,
  "response_format": "b64_json"
}
```

Response structure:

```json
{
  "created": 1788528742,
  "data": [
    {
      "b64_json": "<155896_BASE64_CHARACTERS>"
    }
  ]
}
```

Validation log:

```text
STATUS=SUCCESS
MODEL=ag/gemini-3.1-flash-image
CREATED=1788528742
DATA_COUNT=1
B64_LENGTH=155896
BYTE_LENGTH=116921
MAGIC=FF D8 FF E0 00 10 4A 46 49 46 00 01
DIMENSIONS=1024x1024
SHA256=5cf43391e85382585416b2737142377f89da883b2c5ef63be53e7047da748072
TOTAL_TIME=14.305s
```

Status: **PASS**.

Validasi yang dilakukan:

1. `data` berisi satu item.
2. `b64_json` tidak kosong.
3. Base64 berhasil didecode.
4. Binary berukuran 116,921 bytes.
5. Image parser berhasil membaca file.
6. Dimensi terbaca sebagai 1024×1024.
7. SHA-256 berhasil dihitung.

Temuan format:

```text
FF D8 FF
```

adalah signature JPEG. Walaupun field response bernama `b64_json`, payload image yang diterima adalah JPEG, bukan PNG.

---

## Log 05 — Binary JPEG

Completion timestamp:

```text
2026-09-04T20:33:22.9594429+07:00
```

Endpoint:

```text
POST /v1/images/generations?response_format=binary
```

Payload:

```json
{
  "model": "ag/gemini-3.1-flash-image",
  "prompt": "A simple red circle centered on a plain white background, no text",
  "n": 1,
  "size": "1024x1024",
  "output_format": "jpeg"
}
```

Response headers:

```http
HTTP/1.1 200 OK
Content-Type: image/jpeg
Content-Disposition: inline; filename="image.jpg"
```

Validation log:

```text
HTTP_STATUS=200
CONTENT_TYPE=image/jpeg
CONTENT_DISPOSITION=inline; filename="image.jpg"
BYTE_LENGTH=395756
MAGIC=FF D8 FF E0 00 10 4A 46 49 46 00 01
DIMENSIONS=1024x1024
SHA256=eaa095a35a6af1c16b94dfc566a0983aab7d09f68ca8ad5e95fb0bfdb97803de
TOTAL_TIME=19.479s
```

Status: **PASS**.

Validasi yang dilakukan:

1. HTTP status `200`.
2. `Content-Type` sesuai dengan actual bytes.
3. `Content-Disposition` memberi filename `.jpg`.
4. Magic bytes valid JPEG.
5. Image parser berhasil membuka bytes.
6. Dimensi 1024×1024.
7. Checksum SHA-256 berhasil dihitung.

---

## Temuan teknis

### OAuth Antigravity berhasil

Tidak ada Gemini API key yang diberikan ke endpoint. Client menggunakan API key 9Router, kemudian 9Router menggunakan credential OAuth provider `ag`.

### Model khusus image diperlukan

Model yang digunakan:

```text
ag/gemini-3.1-flash-image
```

`ag/gemini-3.8-flash-high` adalah chat/reasoning model dan bukan model image yang diumumkan oleh capability endpoint.

### HTTP `200` harus tetap divalidasi

Adapter dapat mengembalikan JSON dengan `b64_json` kosong apabila upstream response tidak berisi image part. Oleh karena itu, acceptance test memeriksa panjang base64, decoded bytes, magic bytes, dan dimensi.

### MIME perlu diperhatikan

Mode JSON tidak memberikan MIME type per item. Test menunjukkan image merupakan JPEG. Mode binary dengan `output_format: "jpeg"` menghasilkan metadata yang konsisten:

```text
Content-Type: image/jpeg
filename: image.jpg
actual bytes: JPEG
```

## Final verdict

```text
PASS — image generation melalui 9Router dan Antigravity OAuth berfungsi.
```

Output yang telah diverifikasi:

```text
JSON base64 : valid JPEG, 1024×1024, 116,921 bytes
Binary JPEG : valid JPEG, 1024×1024, 395,756 bytes
```

Tidak diperlukan Gemini API key untuk model `ag/gemini-3.1-flash-image` selama akun Antigravity OAuth tersedia dan sehat di 9Router.

