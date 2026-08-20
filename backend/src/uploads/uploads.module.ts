import { Module } from '@nestjs/common';
import { ServeStaticModule } from '@nestjs/serve-static';
import { basename, join } from 'path';
import { UploadController, UPLOAD_DIR } from './upload.controller';
import { S3StorageService } from './s3.service';

@Module({
  imports: [
    ServeStaticModule.forRoot({
      rootPath: join(process.cwd(), UPLOAD_DIR),
      serveRoot: `/${basename(UPLOAD_DIR)}`,
    }),
  ],
  controllers: [UploadController],
  providers: [S3StorageService],
})
export class UploadsModule {}