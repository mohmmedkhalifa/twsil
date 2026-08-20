const { Client } = require('/home/mohammedk/Desktop/FlutterProjects/twsil/backend/node_modules/pg');

const client = new Client({
  host: 'aws-0-ap-south-1.pooler.supabase.com',
  port: 6543,
  user: 'postgres.ymqtrsnikcicywxtfjsx',
  password: 'CHANGE_ME_DB_PASSWORD',
  database: 'postgres',
  ssl: { rejectUnauthorized: false }
});

async function main() {
  await client.connect();

  const tables = await client.query(`
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public';
  `);
  console.log('Public tables:', tables.rows.map(r => r.table_name));

  const opCols = await client.query(`
    SELECT column_name, is_nullable, data_type 
    FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name IN ('order_payments', 'payments');
  `);
  console.log('Payment Columns:');
  console.table(opCols.rows);

  await client.end();
}

main().catch(console.error);
