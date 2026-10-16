# Cloudflare R2 Storage Setup Guide (10 GB Free Forever)

This worker connects EduPeak directly to your **Cloudflare R2** bucket, giving you:
- **10 GB of free storage every month** (10x Supabase!).
- **$0.00 bandwidth fees** (unlimited downloads for teachers & students).
- High-speed CDN delivery for exam answers, images, and compiled PDFs.

---

## ⚡ Option A: Quick 2-Minute Setup in Cloudflare Dashboard (No Terminal Required)

1. Log in to [dash.cloudflare.com](https://dash.cloudflare.com/).
2. On the left sidebar, click **R2**.
3. Click **Create bucket**:
   - Bucket name: `edupeak-submissions`
   - Location: Automatic
   - Click **Create Bucket**.
4. On the left sidebar, click **Workers & Pages** -> **Create application** -> **Create Worker**.
   - Name: `edupeak-r2-storage`
   - Click **Deploy**.
5. Click **Edit code**:
   - Delete whatever is in `worker.js` and paste the full contents of `worker.js` from this folder.
   - Click **Deploy**.
6. Bind the R2 bucket to your worker:
   - Go to your Worker's **Settings** tab -> **Variables** (or **Bindings**).
   - Under **R2 Bucket Bindings**, click **Add binding**:
     - Variable name: `R2_BUCKET` *(exact spelling)*
     - R2 bucket: Select `edupeak-submissions`
   - Click **Save and Deploy**.
7. Copy your Worker URL:
   - Example: `https://edupeak-r2-storage.yourname.workers.dev`

---

## 💻 Option B: Deploy via Command Line (Wrangler CLI)

From this folder (`D:\Dessert\dessert_app\cloudflare-r2-worker`):

```bash
# 1. Login to Cloudflare
npx wrangler login

# 2. Create the R2 bucket
npx wrangler r2 bucket create edupeak-submissions

# 3. Deploy the worker
npx wrangler deploy
```

It will print your live worker URL:
`https://edupeak-r2-storage.<subdomain>.workers.dev`

---

## 🔗 Linking to EduPeak

Paste your worker URL into `storage-service.js` or set it in your browser / admin panel:
- In `web/js/storage-service.js`:
  Set `DEFAULT_R2_URL = "https://edupeak-r2-storage.yourname.workers.dev"`
