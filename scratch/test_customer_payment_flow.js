const { Client } = require('/home/mohammedk/Desktop/FlutterProjects/twsil/backend/node_modules/pg');

const client = new Client({
  host: 'aws-0-ap-south-1.pooler.supabase.com',
  port: 6543,
  user: 'postgres.ymqtrsnikcicywxtfjsx',
  password: 'CHANGE_ME_DB_PASSWORD',
  database: 'postgres',
  ssl: { rejectUnauthorized: false }
});

const SUPABASE_URL = "https://ymqtrsnikcicywxtfjsx.supabase.co";
const ANON_KEY = "REDACTED_SB_PUBLISHABLE_e7cwhdA0";

async function main() {
  await client.connect();

  const phone = '059' + Math.floor(Math.random() * 8999999 + 1000000);
  const email = `cust_${Date.now()}@twsil.com`;

  const signUpResp = await fetch(`${SUPABASE_URL}/auth/v1/signup`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': ANON_KEY,
      'Authorization': `Bearer ${ANON_KEY}`
    },
    body: JSON.stringify({
      email,
      password: 'Password123!',
      data: { first_name: 'زبون', last_name: 'تجربة', phone, role: 'customer' }
    })
  });

  const signUpData = await signUpResp.json();
  const token = signUpData.access_token || signUpData.session?.access_token;
  const userId = signUpData.user?.id || signUpData.id;

  // 1. Create Order with deliveryFee & distanceKm & serviceFee
  console.log('\n--- 1. Creating Order ---');
  const createOrderResp = await fetch(`${SUPABASE_URL}/rest/v1/orders`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': ANON_KEY,
      'Authorization': `Bearer ${token}`,
      'Prefer': 'return=representation'
    },
    body: JSON.stringify({
      customerId: userId,
      pickupLat: 31.5017,
      pickupLng: 34.4668,
      pickupAddress: 'غزة - الرمال',
      dropoffLat: 31.4178,
      dropoffLng: 34.3524,
      dropoffAddress: 'دير البلح - المركز',
      packageDescription: 'طرد تجريبي',
      packageSize: 'medium',
      weightKg: 1,
      distanceKm: 12.5,
      deliveryFee: 15.0,
      serviceFee: 1.0,
      status: 'payment_pending'
    })
  });

  const createOrderText = await createOrderResp.text();
  console.log('Create Order Status:', createOrderResp.status);
  console.log('Create Order Response:', createOrderText);

  let orderId = null;
  try {
    const parsed = JSON.parse(createOrderText);
    orderId = Array.isArray(parsed) ? parsed[0].id : parsed.id;
  } catch (_) {}

  console.log('Created Order ID:', orderId);

  // 2. Submit Payment for Order
  console.log('\n--- 2. Submitting Payment ---');
  const payResp = await fetch(`${SUPABASE_URL}/rest/v1/order_payments`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': ANON_KEY,
      'Authorization': `Bearer ${token}`,
      'Prefer': 'return=representation'
    },
    body: JSON.stringify({
      orderId: orderId,
      amount: 1.0,
      paymentMethod: 'jawwal_pay',
      receiptImageUrl: 'https://example.com/receipt.jpg',
      transactionNumber: 'TX999888',
      transferDate: new Date().toISOString(),
      status: 'payment_submitted'
    })
  });

  const payText = await payResp.text();
  console.log('Submit Payment Status:', payResp.status);
  console.log('Submit Payment Response Body:', payText);

  // 3. Update Order Status to awaiting_captain
  console.log('\n--- 3. Updating Order Status ---');
  const patchResp = await fetch(`${SUPABASE_URL}/rest/v1/orders?id=eq.${orderId}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'apikey': ANON_KEY,
      'Authorization': `Bearer ${token}`,
      'Prefer': 'return=representation'
    },
    body: JSON.stringify({ status: 'awaiting_captain' })
  });

  const patchText = await patchResp.text();
  console.log('Update Order Status Status:', patchResp.status);
  console.log('Update Order Status Response Body:', patchText);

  await client.end();
}

main().catch(console.error);
