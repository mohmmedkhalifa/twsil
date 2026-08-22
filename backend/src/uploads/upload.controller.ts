import {
  BadRequestException,
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
  return (process.env.BASE_URL ?? 'http://localhost:4000').replace(/\/$/, '');
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
  ) {
    if (!file) throw new BadRequestException('File is required');
    const targetFolder = (folder || category || '').toLowerCase();
    const folderName = targetFolder === 'receipts' ? 'receipts' : 'uploads';
    const key = `${Date.now()}-${uuid()}${extname(file.originalname ?? '')}`;
    const fileName = `${folderName}/${key}`;

    if (this.s3.enabled) {
      const url = await this.s3.put(fileName, file.buffer, file.mimetype);
      return { url };
    }

    const dest = join(process.cwd(), UPLOAD_DIR, folderName);
    fs.mkdirSync(dest, { recursive: true });
    fs.writeFileSync(join(dest, key), file.buffer);
    return { url: `${baseUrl()}/${UPLOAD_DIR}/${folderName}/${key}` };
  }
}