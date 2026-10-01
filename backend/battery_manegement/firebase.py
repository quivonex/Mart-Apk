import firebase_admin

from firebase_admin import credentials, messaging
from django.conf import settings

from accounts.models import FCMToken


if not firebase_admin._apps:

    cred = credentials.Certificate(
        str(settings.FIREBASE_CREDENTIALS)
    )

    firebase_admin.initialize_app(cred)


def send_fcm_notification(user, title, body, data=None):

    try:

        fcm_token_obj = FCMToken.objects.filter(
            user=user,
            is_active=True
        ).first()

        if not fcm_token_obj:
            print("FCM Token not found for user:", user.username)
            return False

        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={
                str(key): str(value)
                for key, value in (data or {}).items()
            },
            token=fcm_token_obj.token,
        )

        response = messaging.send(message)

        print("FCM notification sent:", response)

        return True

    except Exception as e:

        print("FCM Notification Error:", str(e))
        return False

