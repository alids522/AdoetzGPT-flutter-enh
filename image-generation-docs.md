# 9Router + Antigravity OAuth: Image Generation

Dokumen ini menjelaskan cara menjalankan image generation melalui 9Router dengan akun Google Antigravity yang terhubung menggunakan OAuth.

## Ringkasan

Image generation melalui Antigravity OAuth **berhasil tanpa Gemini API key**.

Client hanya mengirim API key 9Router:

```http
Authorization: Bearer <9ROUTER_API_KEY>
```

9Router kemudian menggunakan credential OAuth Antigravity yang sudah tersimpan untuk mengakses image model Google.

Model yang terverifikasi:

```text
ag/gemini-3.1-flash-image
```

Endpoint:

```text
POST /v1/images/generations
```

## Hasil verifikasi

| Mode | HTTP | Output | Dimensi | Status |
|---|---:|---|---:|---|
| JSON `b64_json` | 200 | JPEG dalam base64 | 1024×1024 | Berhasil |
| Binary | 200 | `image/jpeg` | 1024×1024 | Berhasil |

## Model discovery

Cek model image yang tersedia:

```bash
curl "$NINEROUTER_BASE_URL/models/image" \
  -H "Authorization: Bearer $NINEROUTER_API_KEY"
```

Response pada saat pengujian:

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

Model berprefix `gemini/` menggunakan provider Gemini API dan biasanya membutuhkan Gemini API key. Model berprefix `ag/` menggunakan provider Antigravity dan credential OAuth yang dikelola 9Router.

Untuk skenario OAuth tanpa Gemini API key, gunakan:

```text
ag/gemini-3.1-flash-image
```

Detail capability:

```bash
curl "$NINEROUTER_BASE_URL/models/info?id=ag%2Fgemini-3.1-flash-image" \
  -H "Authorization: Bearer $NINEROUTER_API_KEY"
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

## Persiapan environment

### Bash

```bash
export NINEROUTER_BASE_URL="https://9router.adoetz52.my.id/v1"
export NINEROUTER_API_KEY="<9ROUTER_API_KEY>"
```

### PowerShell

```powershell
$env:NINEROUTER_BASE_URL = "https://9router.adoetz52.my.id/v1"
$env:NINEROUTER_API_KEY = "<9ROUTER_API_KEY>"
```

Jangan menaruh API key asli di repository, source code, atau dokumentasi.

## Metode 1 — JSON dengan `b64_json`

Request:

```bash
curl "$NINEROUTER_BASE_URL/images/generations" \
  -H "Authorization: Bearer $NINEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ag/gemini-3.1-flash-image",
    "prompt": "A clean minimalist illustration of a small blue robot holding a magnifying glass, white background, no text",
    "n": 1,
    "response_format": "b64_json"
  }'
```

Response:

```json
{
  "created": 1788528742,
  "data": [
    {
      "b64_json": "<BASE64_IMAGE>"
    }
  ]
}
```

### Catatan format

Field response bernama `b64_json`, tetapi binary image yang diterima saat tes mempunyai magic bytes:

```text
FF D8 FF E0 00 10 4A 46 49 46 00 01
```

Signature tersebut menunjukkan file **JPEG/JFIF**, bukan PNG.

Jangan melakukan hal berikut tanpa memeriksa format:

```js
writeFileSync("output.png", Buffer.from(result.data[0].b64_json, "base64"));
```

File mungkin berisi JPEG tetapi memakai extension `.png`.

Gunakan salah satu solusi:

1. Simpan sebagai `.jpg` jika output diketahui JPEG.
2. Deteksi magic bytes sebelum menentukan extension.
3. Gunakan mode binary dan tentukan `output_format: "jpeg"` secara eksplisit.

## Metode 2 — Binary response

Untuk menerima raw image bytes, tambahkan query parameter:

```text
?response_format=binary
```

Request:

```bash
curl "$NINEROUTER_BASE_URL/images/generations?response_format=binary" \
  -H "Authorization: Bearer $NINEROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ag/gemini-3.1-flash-image",
    "prompt": "A simple red circle centered on a plain white background, no text",
    "n": 1,
    "size": "1024x1024",
    "output_format": "jpeg"
  }' \
  --output generated-image.jpg
```

Response headers yang terverifikasi:

```http
HTTP/1.1 200 OK
Content-Type: image/jpeg
Content-Disposition: inline; filename="image.jpg"
```

Mode binary direkomendasikan jika client ingin langsung menyimpan atau menampilkan gambar.

## Payload fields

| Field | Wajib | Contoh | Keterangan |
|---|---|---|---|
| `model` | Ya | `ag/gemini-3.1-flash-image` | Model image Antigravity |
| `prompt` | Ya | `A blue robot...` | Deskripsi gambar |
| `n` | Tidak | `1` | Jumlah yang diminta; adapter/upstream dapat tetap mengembalikan satu gambar |
| `size` | Tidak | `1024x1024` | Dipakai untuk menentukan aspect ratio |
| `response_format` | Tidak | `b64_json` | JSON response normal berisi base64 |
| `output_format` | Tidak | `jpeg` | Gunakan bersama binary mode agar MIME dan extension eksplisit |
| `image` | Tidak | Data URI/base64 | Input image untuk jalur image-to-image/editing |
| `images` | Tidak | Array base64 | Adapter memakai item pertama jika `image` tidak tersedia |

Capability yang diumumkan instance saat tes hanya `textToImage`. Walaupun adapter source menerima input `image`, image editing belum diverifikasi dalam pengujian ini.

## Implementasi Node.js — JSON base64

```js
import { writeFile } from "node:fs/promises";

const baseUrl = (
  process.env.NINEROUTER_BASE_URL ||
  "https://9router.adoetz52.my.id/v1"
).replace(/\/$/, "");

const apiKey = process.env.NINEROUTER_API_KEY;

if (!apiKey) {
  throw new Error("NINEROUTER_API_KEY belum diset");
}

const response = await fetch(`${baseUrl}/images/generations`, {
  method: "POST",
  headers: {
    Authorization: `Bearer ${apiKey}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    model: "ag/gemini-3.1-flash-image",
    prompt: "A clean minimalist blue robot, white background, no text",
    n: 1,
    response_format: "b64_json",
  }),
});

const responseText = await response.text();

if (!response.ok) {
  throw new Error(`Image generation gagal: ${response.status} ${responseText}`);
}

const result = JSON.parse(responseText);
const base64 = result.data?.[0]?.b64_json;

if (!base64) {
  throw new Error("Response tidak mempunyai data[0].b64_json");
}

const bytes = Buffer.from(base64, "base64");

const isJpeg =
  bytes.length >= 3 &&
  bytes[0] === 0xff &&
  bytes[1] === 0xd8 &&
  bytes[2] === 0xff;

const isPng =
  bytes.length >= 8 &&
  bytes.subarray(0, 8).equals(
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
  );

const extension = isJpeg ? "jpg" : isPng ? "png" : "bin";
const outputPath = `generated-image.${extension}`;

await writeFile(outputPath, bytes);
console.log(`Saved ${bytes.length} bytes to ${outputPath}`);
```

## Implementasi Node.js — binary

```js
import { writeFile } from "node:fs/promises";

const baseUrl = (
  process.env.NINEROUTER_BASE_URL ||
  "https://9router.adoetz52.my.id/v1"
).replace(/\/$/, "");

const apiKey = process.env.NINEROUTER_API_KEY;

if (!apiKey) {
  throw new Error("NINEROUTER_API_KEY belum diset");
}

const response = await fetch(
  `${baseUrl}/images/generations?response_format=binary`,
  {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "ag/gemini-3.1-flash-image",
      prompt: "A simple geometric poster, blue and white, no text",
      n: 1,
      size: "1024x1024",
      output_format: "jpeg",
    }),
  }
);

if (!response.ok) {
  throw new Error(
    `Image generation gagal: ${response.status} ${await response.text()}`
  );
}

const contentType = response.headers.get("content-type");
const bytes = Buffer.from(await response.arrayBuffer());

if (contentType !== "image/jpeg") {
  throw new Error(`Unexpected Content-Type: ${contentType}`);
}

await writeFile("generated-image.jpg", bytes);
console.log(`Saved ${bytes.length} bytes`);
```

## Menggunakan Gemini 3.8 bersama image model

`ag/gemini-3.8-flash-high` adalah model chat/reasoning. Model tersebut dapat dipakai untuk memperbaiki prompt, tetapi image generation sebaiknya tetap diarahkan ke `ag/gemini-3.1-flash-image`.

Alur yang direkomendasikan:

```text
User prompt
    ↓
ag/gemini-3.8-flash-high memperbaiki prompt
    ↓
POST /v1/images/generations
model = ag/gemini-3.1-flash-image
    ↓
JPEG base64 atau binary
```

Jangan mengandalkan fallback internal dari model chat ke model image. Gunakan model image secara eksplisit agar routing, capability discovery, dan logging konsisten.

## Error handling

### `400 Missing model`

Pastikan body mempunyai:

```json
{
  "model": "ag/gemini-3.1-flash-image"
}
```

### `400 Missing required field: prompt`

Pastikan `prompt` berupa string yang tidak kosong.

### `401` atau `403`

Kemungkinan penyebab:

- API key 9Router tidak valid;
- OAuth Antigravity expired dan refresh gagal;
- account/project Antigravity tidak lengkap;
- upstream menolak credential.

### `429` atau `503`

Anggap sebagai error sementara:

- baca header `Retry-After`;
- gunakan exponential backoff;
- batasi retry, misalnya tiga kali;
- jangan mengubah transport error menjadi output gambar kosong.

### HTTP `200`, tetapi `b64_json` kosong

Validasi selalu:

```js
if (!result.data?.[0]?.b64_json) {
  throw new Error("Image data kosong");
}
```

Adapter dapat menghasilkan placeholder kosong jika upstream response tidak mempunyai image part. HTTP `200` saja belum cukup sebagai indikator bahwa gambar benar-benar dibuat.

## Checklist production

- [ ] Gunakan `ag/gemini-3.1-flash-image`.
- [ ] Gunakan API key 9Router, bukan Gemini API key.
- [ ] Jangan hard-code credential.
- [ ] Validasi HTTP status.
- [ ] Validasi `data[0].b64_json` tidak kosong.
- [ ] Decode base64 dan periksa magic bytes.
- [ ] Simpan JPEG menggunakan extension `.jpg`.
- [ ] Untuk binary mode, set `output_format: "jpeg"`.
- [ ] Periksa `Content-Type` sebelum menyimpan response.
- [ ] Pasang timeout minimal 60–150 detik.
- [ ] Retry terbatas untuk `429` dan `503`.
- [ ] Catat ukuran, dimensi, dan checksum untuk observability.

## Referensi source 9Router

- [Antigravity image adapter](https://github.com/decolua/9router/blob/master/open-sse/handlers/imageProviders/antigravity.js)
- [Image generation core](https://github.com/decolua/9router/blob/master/open-sse/handlers/imageGenerationCore.js)
- [Image generation HTTP handler](https://github.com/decolua/9router/blob/master/src/sse/handlers/imageGeneration.js)
- [Antigravity provider registry](https://github.com/decolua/9router/blob/master/open-sse/providers/registry/antigravity.js)

