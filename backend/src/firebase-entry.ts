// Firebase Cloud Functions entrypoint (v2, supports WebSockets/Socket.io).
// Deploy: `firebase deploy --only functions` (after `npm run build`).
// Serves the same NestJS app as dist/src/main, but as a request handler.
import 'reflect-metadata';
import 'dotenv/config';
import * as functions from 'firebase-functions/v2/https';
import express from 'express';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

const expressApp = express();

async function bootstrap() {
  const app = await NestFactory.create(AppModule, expressApp as any);

  app.setGlobalPrefix('api');
  app.enableCors({ origin: true, credentials: true });
  app.useGlobalPipes(new ValidationPipe({ transform: true }));

  // Allow receipt images up to 10MB through JSON bodies when needed.
  expressApp.use(express.json({ limit: '10mb' }));

  await app.init();
  return app;
}

let ready = false;
export const api = functions.onRequest(
  { region: 'us-central1', timeoutSeconds: 120, minInstances: 0, concurrency: 80 },
  async (req: any, res: any) => {
    if (!ready) {
      await bootstrap();
      ready = true;
    }
    expressApp(req as any, res as any);
  },
);