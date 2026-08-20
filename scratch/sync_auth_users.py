import urllib.request
import json

SUPABASE_URL = "https://ymqtrsnikcicywxtfjsx.supabase.co"
SECRET_KEY = "REDACTED_SB_SECRET"

def fetch_auth_users():
    url = f"{SUPABASE_URL}/auth/v1/admin/users"
    req = urllib.request.Request(url)
    req.add_header("apikey", SECRET_KEY)
    req.add_header("Authorization", f"Bearer {SECRET_KEY}")
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        return data.get("users", [])

def upsert_public_user(user_data):
    url = f"{SUPABASE_URL}/rest/v1/users"
    body = json.dumps(user_data).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("apikey", SECRET_KEY)
    req.add_header("Authorization", f"Bearer {SECRET_KEY}")
    req.add_header("Content-Type", "application/json")
    req.add_header("Prefer", "resolution=merge-duplicates,return=representation")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))

def upsert_captain_profile(captain_data):
    url = f"{SUPABASE_URL}/rest/v1/captain_profiles"
    body = json.dumps(captain_data).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("apikey", SECRET_KEY)
    req.add_header("Authorization", f"Bearer {SECRET_KEY}")
    req.add_header("Content-Type", "application/json")
    req.add_header("Prefer", "resolution=merge-duplicates,return=representation")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        print(f"Captain profile notice for {captain_data.get('userId')}: {e}")

if __name__ == "__main__":
    print("Fetching all users from Supabase Auth...")
    auth_users = fetch_auth_users()
    print(f"Found {len(auth_users)} users in auth.users.")

    synced_count = 0
    for u in auth_users:
        user_id = u["id"]
        email = u.get("email", "")
        raw_phone = u.get("phone") or ""
        meta = u.get("user_metadata", {}) or {}

        phone = meta.get("phone") or raw_phone
        if not phone and email and "@twsil.com" in email:
            # extract phone from user059...@twsil.com
            parts = email.split("@")[0]
            if parts.startswith("user"):
                phone = parts[4:]

        first_name = meta.get("first_name") or meta.get("firstName") or ""
        if not first_name:
            if email and "@" in email:
                first_name = email.split("@")[0]
            else:
                first_name = "مستخدم"

        last_name = meta.get("last_name") or meta.get("lastName") or ""
        role = meta.get("role") or "customer"
        if email == "admin@twsil.ps":
            role = "admin"

        public_user = {
            "id": user_id,
            "firstName": first_name,
            "lastName": last_name,
            "phone": phone if phone else f"059{user_id[:6]}",
            "email": email,
            "role": role,
            "locale": "ar"
        }

        try:
            res = upsert_public_user(public_user)
            synced_count += 1
            print(f"Synced user: {first_name} {last_name} ({phone}) - Role: {role}")
            
            if role == "captain":
                upsert_captain_profile({
                    "id": user_id,
                    "userId": user_id,
                    "transportType": "car",
                    "plateNumber": meta.get("plateNumber", "6-0000-99"),
                    "nationalId": meta.get("nationalId", "000000000"),
                    "city": meta.get("city", "نابلس"),
                    "bio": "كابتن توصيل معتمد",
                    "verificationStatus": "pending",
                    "subscriptionStatus": "pending"
                })
        except Exception as e:
            print(f"Error syncing user {user_id}: {e}")

    print(f"\nSuccessfully synced {synced_count}/{len(auth_users)} users into public.users!")
