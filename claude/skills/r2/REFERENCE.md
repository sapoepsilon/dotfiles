# R2 Detailed Reference

## Wrangler CLI Commands

### Bucket Commands

| Command | Description |
|---------|-------------|
| `wrangler r2 bucket create <NAME>` | Create a new bucket |
| `wrangler r2 bucket list` | List all buckets |
| `wrangler r2 bucket delete <NAME>` | Delete an empty bucket |
| `wrangler r2 bucket info <NAME>` | Get bucket information |

### Object Commands

| Command | Description |
|---------|-------------|
| `wrangler r2 object put <BUCKET>/<KEY> --file <FILE> --remote` | Upload object |
| `wrangler r2 object get <BUCKET>/<KEY> --file <FILE> --remote` | Download object |
| `wrangler r2 object delete <BUCKET>/<KEY> --remote` | Delete object |

### Domain Commands

| Command | Description |
|---------|-------------|
| `wrangler r2 bucket domain add <BUCKET> --domain <DOMAIN> --zone-id <ID>` | Add custom domain |
| `wrangler r2 bucket domain list <BUCKET>` | List domains |
| `wrangler r2 bucket domain remove <BUCKET> --domain <DOMAIN>` | Remove domain |

### CORS Commands

| Command | Description |
|---------|-------------|
| `wrangler r2 bucket cors put <BUCKET> --file <FILE>` | Set CORS config |
| `wrangler r2 bucket cors get <BUCKET>` | Get CORS config |
| `wrangler r2 bucket cors delete <BUCKET>` | Clear CORS config |

## S3-Compatible API

R2 is S3-compatible. Use endpoint: `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`

### Generate API Tokens

1. Go to Cloudflare Dashboard > R2 > Manage R2 API Tokens
2. Create token with appropriate permissions
3. Use Access Key ID and Secret Access Key with S3 SDKs

### AWS CLI Configuration

```bash
aws configure --profile r2
# Access Key ID: <your-access-key-id>
# Secret Access Key: <your-secret-access-key>
# Region: auto
# Output format: json

# Example usage
aws s3 ls --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com --profile r2
```

### JavaScript/Node.js SDK

```javascript
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';

const client = new S3Client({
  region: 'auto',
  endpoint: `https://${ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: ACCESS_KEY_ID,
    secretAccessKey: SECRET_ACCESS_KEY,
  },
});

// Upload
await client.send(new PutObjectCommand({
  Bucket: 'my-bucket',
  Key: 'my-file.txt',
  Body: 'Hello, R2!',
}));

// Download
const response = await client.send(new GetObjectCommand({
  Bucket: 'my-bucket',
  Key: 'my-file.txt',
}));
const content = await response.Body.transformToString();
```

### Python boto3

```python
import boto3

s3 = boto3.client(
    's3',
    endpoint_url=f'https://{ACCOUNT_ID}.r2.cloudflarestorage.com',
    aws_access_key_id=ACCESS_KEY_ID,
    aws_secret_access_key=SECRET_ACCESS_KEY,
    region_name='auto',
)

# Upload
s3.upload_file('local-file.txt', 'my-bucket', 'remote-file.txt')

# Download
s3.download_file('my-bucket', 'remote-file.txt', 'local-file.txt')

# List objects
response = s3.list_objects_v2(Bucket='my-bucket')
for obj in response.get('Contents', []):
    print(obj['Key'])
```

## Workers Binding

### wrangler.toml Configuration

```toml
name = "my-worker"
main = "src/index.ts"

[[r2_buckets]]
binding = "MY_BUCKET"
bucket_name = "my-bucket-name"
# preview_bucket_name = "my-bucket-preview"  # Optional for dev
```

### Worker Code Example

```typescript
export interface Env {
  MY_BUCKET: R2Bucket;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const key = url.pathname.slice(1);

    switch (request.method) {
      case 'PUT':
        await env.MY_BUCKET.put(key, request.body);
        return new Response(`Put ${key} successfully!`);

      case 'GET':
        const object = await env.MY_BUCKET.get(key);
        if (!object) {
          return new Response('Object Not Found', { status: 404 });
        }
        const headers = new Headers();
        object.writeHttpMetadata(headers);
        headers.set('etag', object.httpEtag);
        return new Response(object.body, { headers });

      case 'DELETE':
        await env.MY_BUCKET.delete(key);
        return new Response('Deleted!');

      default:
        return new Response('Method Not Allowed', { status: 405 });
    }
  },
};
```

## Presigned URLs

Generate temporary URLs for direct upload/download:

```typescript
import { AwsClient } from 'aws4fetch';

const r2 = new AwsClient({
  accessKeyId: ACCESS_KEY_ID,
  secretAccessKey: SECRET_ACCESS_KEY,
});

// Generate presigned URL for upload
const uploadUrl = await r2.sign(
  new Request(`https://${ACCOUNT_ID}.r2.cloudflarestorage.com/bucket/key`, {
    method: 'PUT',
  }),
  { aws: { signQuery: true } }
);

// Use with curl
// curl -X PUT "<presigned-url>" --data-binary "@file.txt"
```

## Public Access Options

### Option 1: Custom Domain (Recommended)

```bash
wrangler r2 bucket domain add my-bucket --domain assets.example.com --zone-id <ZONE_ID>
```

### Option 2: r2.dev Subdomain

Enable in Cloudflare Dashboard > R2 > Bucket Settings > Public Access

URL format: `https://pub-<hash>.r2.dev/<key>`

### Option 3: Worker Proxy

Create a Worker that serves R2 objects with custom logic (auth, transformations, etc.)

## Lifecycle Rules

Configure via Cloudflare Dashboard or API:

- Expire objects after N days
- Transition to Infrequent Access storage class
- Delete incomplete multipart uploads

## Event Notifications

```bash
# Create queue first
wrangler queues create my-queue

# Enable notifications
wrangler r2 bucket notification create my-bucket \
  --event-type object-create \
  --queue my-queue
```

Event types: `object-create`, `object-delete`

## Pricing Notes

- Storage: $0.015/GB-month
- Class A operations (write): $4.50/million
- Class B operations (read): $0.36/million
- **No egress fees** (data transfer out is free)
- Free tier: 10GB storage, 1M Class A, 10M Class B per month
