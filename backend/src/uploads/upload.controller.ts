import {
  BadRequestException,
  Body,
  Controller,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { extname, join } from 'path';
import * as fs from 'fs';
import * as os from 'os';
import { v4 as uuid } from 'uuid';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { S3StorageService } from './s3.service';

// On serverless (Cloud Functions) the workspace is read-only; use /tmp there.
export const UPLOAD_DIR =
  process.env.UPLOAD_DIR ??
  (process.env.FIREBASE_CONFIG ? join(os.tmpdir(), 'uploads') : 'uploads');

try {
  fs.mkdirSync(join(process.cwd(), UPLOAD_DIR), { recursive: true });
} catch {
  // read-only filesystem (e.g. Cloud Functions): rely on S3 storage
}

export function baseUrl() {
  return (process.env.BASE_URL ?? '').replace(/\/$/, '');
}

/**
 * Canonical storage layout inside the `twsil-images` bucket:
 *
 * identities/captain-id/<front|back>/...
 * driving-licenses/...
 * transfer-receipts/<userId|orderId|anonymous>/
 * delivery-proofs/<orderId>/
 * order-images/<orderId>/
 *
 * Legacy client folders (`receipts`, `identity`, `licenses`, `uploads`)
 * are mapped onto this layout so every image lands in the right place
 * regardless of which app version uploaded it.
 */
export function buildStorageKey(
  rawCategory: string | undefined,
  rawFolder: string | undefined,
  sub: string | undefined,
  orderId: string | undefined,
  fileName: string,
): string {
  const category = String(rawCategory ?? rawFolder ?? '').toLowerCase().trim();
  const subFolder = String(sub ?? '').toLowerCase().trim();

  switch (category) {
    case 'identity':
    case 'identities':
    case 'captain-id': {
      const side = ['front', 'back'].includes(subFolder) ? `/${subFolder}` : '';
      return `identities/captain-id${side}`;
    }
    case 'license':
    case 'licenses':
    case 'driving-license':
      return 'driving-licenses';
    case 'receipt':
    case 'receipts':
    case 'transfer-receipt':
    case 'transfer-receipts':
      return `transfer-receipts/${sanitizeSegment(orderId) ?? 'misc'}`;
    case 'delivery-proof':
      return `delivery-proofs/${sanitizeSegment(orderId) ?? 'misc'}`;
    case 'order-image':
      return `order-images/${sanitizeSegment(orderId) ?? 'misc'}`;
    default:
      // Avatars and any uncategorised upload.
      return 'order-images/misc';
  }
}

function sanitizeSegment(value: string | undefined): string | null {
  if (!value) return null;
  const clean = value.replace(/[^a-zA-Z0-9-_]/g, '');
  return clean.length > 0 ? clean : null;
}

@Controller('upload')
@UseGuards(JwtAuthGuard)
export class UploadController {
  constructor(private readonly s3: S3StorageService) {}

  @Post('image')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: { fileSize: (Number(process.env.MAX_UPLOAD_MB) ?? 10) * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        if (!file.mimetype.startsWith('image/')) {
          cb(new BadRequestException('Only image files are allowed'), false);
          return;
        }
        cb(null, true);
      },
    }),
  )
  async uploadImage(
    @UploadedFile() file: Express.Multer.File,
    @Body('folder') folder?: string,
    @Body('category') category?: string,
    @Body('sub') sub?: string,
    @Body('orderId') orderId?: string,
  ) {
    if (!file) throw new BadRequestException('File is required');
    const key = `${Date.now()}-${uuid()}${extname(file.originalname ?? '')}`;
    const folderName = buildStorageKey(category, folder, sub, orderId, file.originalname ?? '');
    const objectPath = `${folderName}/${key}`;

    if (this.s3.enabled) {
      const url = await this.s3.put(objectPath, file.buffer, file.mimetype);
      return { url, path: objectPath };
    }

    const dest = join(process.cwd(), UPLOAD_DIR, objectPath);
    fs.mkdirSync(dest.substring(0, dest.lastIndexOf('/')), { recursive: true });
    fs.writeFileSync(dest, file.buffer);
    const base = baseUrl();
    return {
      url: base ? `${base}/${UPLOAD_DIR}/${objectPath}` : objectPath,
      path: objectPath,
    };
  }
}
