import httpx

def fetch_data(base_url: str):
    login_url = f"{base_url}/login"
    posture_url = f"{base_url}/compliance/posture"

    with httpx.Client(timeout=30.0) as client:
        # 1) Login
        login_resp = client.post(
            login_url,
            headers={
                "accept": "application/json; charset=UTF-8",
                "content-type": "application/json",
            },
            json={
                "username": "testuser",
                "password": "testpassword",
            },
        )
        login_resp.raise_for_status()
        token = login_resp.json().get("token")
        if not token:
            raise ValueError("No token received from login endpoint")

        # 2) Fetch posture
        posture_resp = client.get(
            posture_url,
            headers={
                "token": token,
                "content-type": "application/json",
                "accept": "application/json;charset=UTF-8",
            },
            params={
                "timeType": "relative",
                "timeAmount": 15,
                "timeUnit": "minute",
            },
        )
        posture_resp.raise_for_status()
        return posture_resp.json()