import 'dotenv/config';
import { DataSource, DataSourceOptions } from 'typeorm';
import { entities } from './src/database/entities.index';

const isPostgres = process.env.DATABASE_TYPE === 'postgres';

const options: DataSourceOptions = isPostgres
  ? {
      type: 'postgres',
      host: process.env.DB_HOST ?? 'localhost',
      port: Number(process.env.DB_PORT ?? 5432),
      username: process.env.DB_USERNAME,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME ?? 'twsil',
      entities,
      migrations: ['src/database/migrations/*.ts'],
      synchronize: false,
    }
  : {
      type: 'better-sqlite3',
      database: 'twsil.db',
      entities,
      migrations: ['src/database/migrations/*.ts'],
      synchronize: false,
    };

export default new DataSource(options);