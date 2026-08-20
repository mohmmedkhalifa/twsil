import { Injectable, Logger } from '@nestjs/common';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';

@Injectable()
export class S3StorageService {
  private readonly logger = new Logger(S3StorageService.name);
  private client: S3Client | null = null;

  get enabled(): boolean {
    return (process.env.STORAGE_DRIVER ?? 'local') === 's3';
  }

  private getClient(): S3Client {
    if (!this.client) {
      this.client = new S3Client({
        region: process.env.S3_REGION ?? 'auto',
        endpoint: process.env.S3_ENDPOINT || undefined,
        credentials: {
          accessKeyId: process.env.S3_ACCESS_KEY_ID ?? '',
          secretAccessKey: process.env.S3_SECRET_ACCESS_KEY ?? '',
        },
        forcePathStyle: Boolean(process.env.S3_FORCE_PATH_STYLE ?? true),
      });
    }
    return this.client;
  }

  /** Uploads a file into the bucket, returns the public URL. */
  async put(key: string, body: Buffer, contentType: string): Promise<string> {
    const bucket = process.env.S3_BUCKET;
    if (!bucket) throw new Error('S3_BUCKET is not set');
    await this.getClient().send(
      new PutObjectCommand({
        Bucket: bucket,
        Key: key,
        Body: body,
        ContentType: contentType,
      }),
    );
    const withSlash = (v: string) => v.replace(/\/$/, '');
    const base = withSlash(process.env.S3_PUBLIC_URL ?? `https://${bucket}.s3.amazonaws.com`);
    return `${base}/${key}`;
  }
}