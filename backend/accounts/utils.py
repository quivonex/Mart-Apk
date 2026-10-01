import random
from django.core.mail import EmailMultiAlternatives, send_mail
from django.conf import settings

def generate_otp():
    return str(random.randint(100000, 999999))


def send_otp_email(email, otp):

    subject = "QNX Mart B2B - OTP Verification"

    text_content = f"""
Hello,

Your OTP for QNX Mart B2B verification is:

{otp}

This OTP is valid for 10 minutes.
Please do not share this OTP with anyone.

Regards,
QNX Mart B2B Team
"""

    html_content = f"""
    <html>
        <body style="font-family: Arial, sans-serif; background:#f5f7fa; padding:30px;">
            <div style="
                max-width:500px;
                margin:auto;
                background:white;
                padding:30px;
                border-radius:10px;
            ">

                <h2 style="text-align:center;">
                    QNX Mart B2B
                </h2>

                <p>Hello,</p>

                <p>Your verification OTP is:</p>

                <div style="
                    text-align:center;
                    font-size:32px;
                    font-weight:bold;
                    letter-spacing:8px;
                    margin:25px 0;
                ">
                    {otp}
                </div>

                <p>
                    This OTP is valid for <strong>10 minutes</strong>.
                </p>

                <p>
                    Please do not share this OTP with anyone.
                </p>

                <p>
                    Regards,<br>
                    <strong>QNX Mart B2B Team</strong>
                </p>

            </div>
        </body>
    </html>
    """

    email_message = EmailMultiAlternatives(
        subject=subject,
        body=text_content,
        from_email=settings.DEFAULT_FROM_EMAIL,
        to=[email],
    )

    email_message.attach_alternative(html_content, "text/html")

    email_message.send()