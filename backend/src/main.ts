import 'reflect-metadata';
import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.setGlobalPrefix('api');

  app.enableCors({
    origin: true,
    credentials: true,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,
    }),
  );

  const port = Number(process.env.PORT || 4000);

  await app.listen(port, '0.0.0.0');

  const baseUrl =
    process.env.BASE_URL || `http://localhost:${port}`;

  Logger.log(`Twsil API running on ${baseUrl}/api`, 'Bootstrap');
  Logger.log(`Socket.io realtime enabled on ${baseUrl}`, 'Bootstrap');
}

void bootstrap();
