export const timestampType = (): string =>
  process.env.DATABASE_TYPE === 'postgres' ? 'timestamp' : 'datetime';