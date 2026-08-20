import urllib.request
import json
import os

SUPABASE_URL = "https://ymqtrsnikcicywxtfjsx.supabase.co"
ANON_KEY = "REDACTED_SB_PUBLISHABLE_e7cwhdA0"

ID_CARD_PATH = "/home/mohammedk/.gemini/antigravity/brain/f4a59a4a-9819-42b4-bcd8-17fb3f84765a/test_id_card_1786966423708.png"
RECEIPT_PATH = "/home/mohammedk/.gemini/antigravity/brain/f4a59a4a-9819-42b4-bcd8-17fb3f84765a/test_payment_receipt_1786966438966.png"

def upload_file(file_path, folder, storage_name):
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        return None
    
    url = f"{SUPABASE_URL}/storage/v1/object/twsil-images/{folder}/{storage_name}"
    with open(file_path, "rb") as f:
        data = f.read()

    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("apikey", ANON_KEY)
    req.add_header("Authorization", f"Bearer {ANON_KEY}")
    req.add_header("Content-Type", "image/png")
    req.add_header("x-upsert", "true")

    try:
        with urllib.request.urlopen(req) as resp:
            print(f"Uploaded {folder}/{storage_name}: {resp.status}")
            return f"{SUPABASE_URL}/storage/v1/object/public/twsil-images/{folder}/{storage_name}"
    except Exception as e:
        print(f"Error uploading {folder}/{storage_name}: {e}")
        return f"{SUPABASE_URL}/storage/v1/object/public/twsil-images/{folder}/{storage_name}"

def upsert_table(table, records):
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    data = json.dumps(records).encode("utf-8")
    
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("apikey", ANON_KEY)
    req.add_header("Authorization", f"Bearer {ANON_KEY}")
    req.add_header("Content-Type", "application/json")
    req.add_header("Prefer", "resolution=merge-duplicates,return=representation")

    try:
        with urllib.request.urlopen(req) as resp:
            print(f"Upserted into {table}: {resp.status}")
            res_body = resp.read().decode("utf-8")
            print(f"Response: {res_body[:100]}")
    except Exception as e:
        print(f"Error upserting into {table}: {e}")

if __name__ == "__main__":
    print("Uploading demo images to Supabase Storage...")
    id_card_url = upload_file(ID_CARD_PATH, "ids", "demo_id_card.png")
    receipt_url = upload_file(RECEIPT_PATH, "receipts", "demo_payment_receipt.png")

    print("\nPublic URLs:")
    print("ID Card:", id_card_url)
    print("Receipt:", receipt_url)

    # 1. Users
    users = [
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "firstName": "إدارة",
            "lastName": "النظام",
            "phone": "0599000000",
            "email": "admin@twsil.ps",
            "role": "admin",
            "avatarUrl": id_card_url
        },
        {
            "id": "00000000-0000-0000-0000-000000000002",
            "firstName": "أحمد",
            "lastName": "محمود",
            "phone": "0599000111",
            "email": "customer@twsil.ps",
            "role": "customer",
            "avatarUrl": id_card_url
        },
        {
            "id": "00000000-0000-0000-0000-000000000003",
            "firstName": "خالد",
            "lastName": "سامي",
            "phone": "0599000222",
            "email": "captain@twsil.ps",
            "role": "captain",
            "avatarUrl": id_card_url
        }
    ]
    upsert_table("users", users)

    # 2. Captain Profile
    captain_profiles = [
        {
            "id": "00000000-0000-0000-0000-000000000003",
            "userId": "00000000-0000-0000-0000-000000000003",
            "transportType": "car",
            "plateNumber": "6-1234-99",
            "nationalId": "29205100100456",
            "city": "نابلس",
            "bio": "سائق توصيل معتمد في منطقة نابلس والضفة",
            "verificationStatus": "pending",
            "verificationNote": f"صورة الهوية الوطنية مرفقة للمراجعة: {id_card_url}",
            "subscriptionStatus": "submitted"
        }
    ]
    upsert_table("captain_profiles", captain_profiles)

    # 3. Orders
    orders = [
        {
            "id": "00000000-0000-0000-0000-000000000101",
            "orderNumber": "TW20260817-0001",
            "customerId": "00000000-0000-0000-0000-000000000002",
            "pickupLat": 32.2211,
            "pickupLng": 35.2544,
            "pickupAddress": "دوار الشهداء، نابلس",
            "dropoffLat": 32.2260,
            "dropoffLng": 35.2600,
            "dropoffAddress": "جامعة النجاح الوطنية، نابلس",
            "packageDescription": "طرد مستندات وأجهزة إلكترونية تجريبية",
            "packageSize": "medium",
            "weightKg": 2.5,
            "distanceKm": 3.2,
            "deliveryFee": 15.0,
            "serviceFee": 1.0,
            "status": "payment_pending"
        }
    ]
    upsert_table("orders", orders)

    # 4. Order Payments
    order_payments = [
        {
            "id": "00000000-0000-0000-0000-000000000201",
            "orderId": "00000000-0000-0000-0000-000000000101",
            "amount": 16.0,
            "paymentMethod": "jawwal_pay",
            "receiptImageUrl": receipt_url,
            "transactionNumber": "9876543210",
            "note": "تم التحويل عبر محفظة جوال باي بمبلغ 16 شيكل",
            "status": "payment_submitted"
        }
    ]
    upsert_table("order_payments", order_payments)

    # 5. Subscriptions
    subscriptions = [
        {
            "id": "00000000-0000-0000-0000-000000000301",
            "captainId": "00000000-0000-0000-0000-000000000003",
            "amount": 10.0,
            "paymentMethod": "jawwal_pay",
            "receiptImageUrl": receipt_url,
            "transactionNumber": "9876543211",
            "note": "رسوم الاشتراك الشهري للسيارة الكابتن خالد",
            "status": "payment_submitted"
        }
    ]
    upsert_table("subscriptions", subscriptions)

    # 6. Complaints
    complaints = [
        {
            "id": "00000000-0000-0000-0000-000000000401",
            "reporterId": "00000000-0000-0000-0000-000000000002",
            "againstUserId": "00000000-0000-0000-0000-000000000003",
            "orderId": "00000000-0000-0000-0000-000000000101",
            "subject": "استفسار عن موعد التوصيل",
            "description": "يرجى تأكيد التواجد في النقطة المحددة على الخريطة خلال الساعات القادمة",
            "status": "open"
        }
    ]
    upsert_table("complaints", complaints)
