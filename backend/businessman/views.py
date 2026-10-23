from email.mime import message
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.parsers import MultiPartParser, FormParser

from .services import CSVImportService


class BusinessmanCSVUploadAPIView(APIView):

    parser_classes = [
        MultiPartParser,
        FormParser
    ]

    def post(self, request):

        # ==========================================
        # GET CSV FILE
        # ==========================================

        csv_file = request.FILES.get('csv_file')

        if not csv_file:

            return Response(
                {
                    'success': False,
                    'message': 'csv_file is required.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ==========================================
        # FILE EXTENSION CHECK
        # ==========================================

        if not csv_file.name.lower().endswith('.csv'):

            return Response(
                {
                    'success': False,
                    'message': 'Only CSV files are allowed.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ==========================================
        # CHECK EMPTY FILE
        # ==========================================

        if csv_file.size == 0:

            return Response(
                {
                    'success': False,
                    'message': 'CSV file is empty.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ==========================================
        # IMPORT
        # ==========================================

        result = CSVImportService.import_from_file(
            csv_file,
            batch_size=500,
            chunk_size=5000
        )

        # ==========================================
        # ERROR
        # ==========================================

        if not result.get('success'):

            return Response(
                result,
                status=status.HTTP_400_BAD_REQUEST
            )

        # ==========================================
        # SUCCESS
        # ==========================================

        return Response(
            result,
            status=status.HTTP_201_CREATED
        )
        
        
 

import os
import mimetypes

from django.core.mail import EmailMultiAlternatives
from django.conf import settings
from django.utils import timezone

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from .models import Businessman


class BusinessmanEmailSendAPIView(APIView):

    def post(self, request):

        # -----------------------------------------
        # 1. GET REQUEST DATA
        # -----------------------------------------
        limit = request.data.get("limit")
        resend = request.data.get("resend", False)

        subject = request.data.get(
            "subject",
            "QNX Mart से जुड़ें | Grow Your Business Online"
        )

        # -----------------------------------------
        # 2. VALIDATE LIMIT
        # -----------------------------------------
        try:
            limit = int(limit)
        except (TypeError, ValueError):
            return Response(
                {
                    "success": False,
                    "message": "कृपया सही limit प्रदान करें।"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if limit <= 0:
            return Response(
                {
                    "success": False,
                    "message": "Limit शून्य से अधिक होनी चाहिए।"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # -----------------------------------------
        # 3. CONVERT RESEND TO BOOLEAN
        # -----------------------------------------
        if isinstance(resend, str):
            resend = resend.strip().lower() in (
                "true", "1", "yes"
            )
        else:
            resend = resend is True

        # -----------------------------------------
        # 4. QNX MART GST + BUSINESS CARD
        # -----------------------------------------
        gst_number = getattr(
            settings,
            "QNX_MART_GST_NUMBER",
            ""
        )

        business_card_path = getattr(
            settings,
            "QNX_MART_BUSINESS_CARD_PATH",
            None
        )

        if not gst_number:
            return Response(
                {
                    "success": False,
                    "message": (
                        "settings.py में QNX_MART_GST_NUMBER "
                        "कॉन्फ़िगर करें।"
                    )
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        if (
            not business_card_path
            or not os.path.isfile(str(business_card_path))
        ):
            return Response(
                {
                    "success": False,
                    "message": (
                        "QNX Mart का बिज़नेस कार्ड नहीं मिला। "
                        "कृपया image path चेक करें।"
                    ),
                    "business_card_path": str(
                        business_card_path or ""
                    )
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        try:
            with open(business_card_path, "rb") as image_file:
                business_card_data = image_file.read()

            image_filename = os.path.basename(
                str(business_card_path)
            )

            mime_type, _ = mimetypes.guess_type(
                str(business_card_path)
            )

            if not mime_type or not mime_type.startswith("image/"):
                mime_type = "image/jpeg"

        except OSError as exc:
            return Response(
                {
                    "success": False,
                    "message": (
                        "QNX Mart का बिज़नेस कार्ड पढ़ने में समस्या हुई।"
                    ),
                    "error": str(exc)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        # -----------------------------------------
        # 5. HTML EMAIL TEMPLATE - HINDI
        # -----------------------------------------
        html_message = """
        <!DOCTYPE html>
        <html lang="hi">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport"
                  content="width=device-width, initial-scale=1.0">
            <title>QNX Mart से जुड़ें</title>
        </head>

        <body style="
            margin:0;
            padding:0;
            background-color:#f1f5f9;
            font-family:Arial,Helvetica,sans-serif;
        ">

        <table width="100%" cellpadding="0" cellspacing="0"
               role="presentation"
               style="background-color:#f1f5f9;padding:25px 10px;">

            <tr>
                <td align="center">

                    <table width="600" cellpadding="0" cellspacing="0"
                           role="presentation"
                           style="
                               width:100%;
                               max-width:600px;
                               background:#ffffff;
                               border-radius:12px;
                               overflow:hidden;
                           ">

                        <!-- HEADER -->
                        <tr>
                            <td align="center"
                                style="
                                    background:#3525cd;
                                    padding:30px 20px;
                                    color:#ffffff;
                                ">

                                <h1 style="
                                    margin:0;
                                    font-size:30px;
                                    font-weight:bold;
                                ">
                                    QNX Mart
                                </h1>

                                <p style="
                                    margin:10px 0 0;
                                    font-size:15px;
                                    color:#ffffff;
                                ">
                                    अपने व्यवसाय को ऑनलाइन बढ़ाएँ
                                </p>

                            </td>
                        </tr>

                        <!-- BODY -->
                        <tr>
                            <td style="
                                padding:30px 25px;
                                color:#334155;
                                font-size:15px;
                                line-height:1.8;
                            ">

                                <h2 style="
                                    color:#1e293b;
                                    font-size:22px;
                                    margin-top:0;
                                ">
                                    नमस्कार व्यवसायिक मित्रों!
                                </h2>

                                <p>
                                    अपने व्यवसाय को डिजिटल मंच पर ले जाने
                                    के लिए QNX Mart के साथ जुड़ें।
                                </p>

                                <p>
                                    QNX Mart के माध्यम से अपने व्यवसाय की
                                    ऑनलाइन उपस्थिति बढ़ाएँ और नए ग्राहकों
                                    तक पहुँचने का अवसर प्राप्त करें।
                                </p>

                                <p>
                                    अपने उत्पादों और व्यवसाय को अधिक से
                                    अधिक ग्राहकों तक पहुँचाने के लिए
                                    आज ही QNX Mart पर विज़िट करें।
                                </p>

                                <!-- BENEFITS -->
                                <table width="100%" cellpadding="0"
                                       cellspacing="0" role="presentation"
                                       style="
                                           background:#f8fafc;
                                           border:1px solid #e2e8f0;
                                           border-radius:8px;
                                           margin:22px 0;
                                       ">

                                    <tr>
                                        <td style="padding:18px;">

                                            <h3 style="
                                                margin:0 0 12px;
                                                color:#3525cd;
                                                font-size:18px;
                                            ">
                                                QNX Mart से जुड़ने के लाभ
                                            </h3>

                                            <p style="margin:7px 0;">
                                                &#10003; ऑनलाइन व्यवसाय की पहचान
                                            </p>

                                            <p style="margin:7px 0;">
                                                &#10003; नए ग्राहकों तक पहुँचने का अवसर
                                            </p>

                                            <p style="margin:7px 0;">
                                                &#10003; डिजिटल मंच पर व्यवसाय बढ़ाने का अवसर
                                            </p>

                                        </td>
                                    </tr>

                                </table>

                                <!-- CALL TO ACTION -->
                                <table width="100%" cellpadding="0"
                                       cellspacing="0" role="presentation"
                                       style="
                                           margin:25px 0;
                                           background:#eff6ff;
                                           border-radius:8px;
                                       ">

                                    <tr>
                                        <td align="center"
                                            style="padding:25px 15px;">

                                            <h2 style="
                                                color:#1e3a8a;
                                                font-size:21px;
                                                margin-top:0;
                                            ">
                                                आज ही QNX Mart पर विज़िट करें!
                                            </h2>

                                            <p style="
                                                color:#475569;
                                                line-height:1.7;
                                            ">
                                                अपने व्यवसाय की डिजिटल यात्रा
                                                आज ही शुरू करें।
                                            </p>

                                            <!-- WEBSITE BUTTON -->
                                            <table cellpadding="0"
                                                   cellspacing="0"
                                                   role="presentation"
                                                   style="margin:8px auto;">
                                                <tr>
                                                    <td align="center"
                                                        bgcolor="#1d4ed8"
                                                        style="border-radius:6px;">

                                                        <a href="https://qnxmartb2b.com/"
                                                           target="_blank"
                                                           style="
                                                               display:inline-block;
                                                               background:#1d4ed8;
                                                               color:#ffffff;
                                                               padding:14px 24px;
                                                               text-decoration:none;
                                                               border-radius:6px;
                                                               font-weight:bold;
                                                               font-size:14px;
                                                           ">
                                                            QNX MART पर जाएँ
                                                        </a>

                                                    </td>
                                                </tr>
                                            </table>

                                            <!-- COMPANY INFO BUTTON -->
                                            <table cellpadding="0"
                                                   cellspacing="0"
                                                   role="presentation"
                                                   style="margin:8px auto;">
                                                <tr>
                                                    <td align="center"
                                                        bgcolor="#15803d"
                                                        style="border-radius:6px;">

                                                        <a href="https://qnxmartb2b.com/company_info"
                                                           target="_blank"
                                                           style="
                                                               display:inline-block;
                                                               background:#15803d;
                                                               color:#ffffff;
                                                               padding:14px 24px;
                                                               text-decoration:none;
                                                               border-radius:6px;
                                                               font-weight:bold;
                                                               font-size:14px;
                                                           ">
                                                            हमारी कंपनी के बारे में
                                                        </a>

                                                    </td>
                                                </tr>
                                            </table>

                                            <p style="
                                                font-size:13px;
                                                line-height:2;
                                                margin-top:18px;
                                            ">
                                                <a href="https://qnxmartb2b.com/"
                                                   style="
                                                       color:#1d4ed8;
                                                       text-decoration:none;
                                                   ">
                                                    https://qnxmartb2b.com/
                                                </a>

                                                <br>

                                                <a href="https://qnxmartb2b.com/company_info"
                                                   style="
                                                       color:#15803d;
                                                       text-decoration:none;
                                                   ">
                                                    https://qnxmartb2b.com/company_info
                                                </a>
                                            </p>

                                        </td>
                                    </tr>

                                </table>

                                <!-- QNX MART GST DETAILS -->
                                <table width="100%" cellpadding="0"
                                       cellspacing="0" role="presentation"
                                       style="
                                           margin:22px 0;
                                           background:#f8fafc;
                                           border:1px solid #e2e8f0;
                                           border-radius:8px;
                                       ">
                                    <tr>
                                        <td style="padding:18px;">

                                            <h3 style="
                                                margin:0 0 10px;
                                                color:#3525cd;
                                                font-size:18px;
                                            ">
                                                QNX Mart का GST विवरण
                                            </h3>

                                            <p style="margin:5px 0;">
                                                <strong>GST नंबर:</strong>
                                                __QNX_GST_NUMBER__
                                            </p>

                                            <p style="margin:10px 0 0;">
                                                QNX Mart का बिज़नेस कार्ड
                                                इस ईमेल के साथ अटैचमेंट
                                                के रूप में संलग्न है।
                                            </p>

                                        </td>
                                    </tr>
                                </table>

                                <p>
                                    आइए, मिलकर अपने व्यवसाय को डिजिटल
                                    रूप से आगे बढ़ाएँ!
                                </p>

                                <p style="margin-bottom:0;">
                                    सादर,<br>
                                    <strong>QNX Mart टीम</strong>
                                </p>

                            </td>
                        </tr>

                        <!-- FOOTER -->
                        <tr>
                            <td align="center"
                                style="
                                    background:#f8fafc;
                                    border-top:1px solid #e2e8f0;
                                    padding:20px;
                                    color:#64748b;
                                    font-size:12px;
                                    line-height:1.8;
                                ">

                                <p style="margin:0;">
                                    QNX Mart B2B
                                </p>

                                <p style="margin:5px 0;">
                                    <a href="https://qnxmartb2b.com/"
                                       style="
                                           color:#3525cd;
                                           text-decoration:none;
                                       ">
                                        qnxmartb2b.com
                                    </a>
                                </p>

                                <p style="margin:8px 0 0;">
                                    यह ईमेल व्यावसायिक संपर्क के लिए भेजा गया है।
                                </p>

                            </td>
                        </tr>

                    </table>

                </td>
            </tr>

        </table>

        </body>
        </html>
        """

        # Insert QNX Mart GST number into HTML
        html_message = html_message.replace(
            "__QNX_GST_NUMBER__",
            gst_number
        )

        # -----------------------------------------
        # 6. PLAIN TEXT EMAIL - HINDI
        # -----------------------------------------
        plain_message = f"""
नमस्कार व्यवसायिक मित्रों,

QNX Mart के साथ जुड़कर अपने व्यवसाय की ऑनलाइन पहचान
बनाएँ और नए ग्राहकों तक पहुँचने का अवसर प्राप्त करें।

QNX Mart वेबसाइट:
https://qnxmartb2b.com/

QNX Mart के बारे में अधिक जानकारी:
https://qnxmartb2b.com/company_info

QNX Mart GST नंबर:
{gst_number}

QNX Mart का बिज़नेस कार्ड इस ईमेल के साथ
अटैचमेंट के रूप में संलग्न है।

आइए, मिलकर अपने व्यवसाय को डिजिटल रूप से आगे बढ़ाएँ!

सादर,
QNX Mart टीम
"""

        # -----------------------------------------
        # 7. GET BUSINESSMEN
        # -----------------------------------------
        businessmen_query = (
            Businessman.objects
            .filter(email__isnull=False)
            .exclude(email__exact="")
            .order_by("id")
        )

        if not resend:
            businessmen_query = businessmen_query.filter(
                email_sent=False
            )

        businessmen = list(businessmen_query[:limit])
        total_selected = len(businessmen)

        if total_selected == 0:
            return Response(
                {
                    "success": False,
                    "message": (
                        "ईमेल भेजने के लिए कोई योग्य व्यवसायी नहीं मिला।"
                    ),
                    "resend": resend,
                    "total_selected": 0,
                    "success_count": 0,
                    "failed_count": 0,
                    "errors": []
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # -----------------------------------------
        # 8. EMAIL SENDER
        # -----------------------------------------
        from_email = (
            getattr(settings, "DEFAULT_FROM_EMAIL", "")
            or getattr(settings, "EMAIL_HOST_USER", "")
        )

        if not from_email:
            return Response(
                {
                    "success": False,
                    "message": (
                        "settings.py में DEFAULT_FROM_EMAIL "
                        "या EMAIL_HOST_USER कॉन्फ़िगर करें।"
                    )
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        # -----------------------------------------
        # 9. SEND EMAILS + ATTACH BUSINESS CARD
        # -----------------------------------------
        success_count = 0
        failed_count = 0
        errors = []

        for businessman in businessmen:

            email = (businessman.email or "").strip()

            if not email:
                failed_count += 1

                if len(errors) < 50:
                    errors.append({
                        "businessman_id": businessman.id,
                        "error": "ईमेल पता खाली है।"
                    })

                continue

            try:
                mail = EmailMultiAlternatives(
                    subject=subject,
                    body=plain_message,
                    from_email=from_email,
                    to=[email]
                )

                mail.attach_alternative(
                    html_message,
                    "text/html"
                )

                # Attach the same QNX Mart business card
                mail.attach(
                    image_filename,
                    business_card_data,
                    mime_type
                )

                mail.send(fail_silently=False)

                # Update tracking only after successful send
                businessman.email_sent = True
                businessman.email_sent_at = timezone.now()

                businessman.save(
                    update_fields=[
                        "email_sent",
                        "email_sent_at",
                        "updated_at"
                    ]
                )

                success_count += 1

            except Exception as exc:
                failed_count += 1

                if len(errors) < 50:
                    errors.append({
                        "businessman_id": businessman.id,
                        "email": email,
                        "error": str(exc)
                    })

        # -----------------------------------------
        # 10. FINAL RESPONSE
        # -----------------------------------------
        return Response(
            {
                "success": failed_count == 0,
                "message": "ईमेल भेजने की प्रक्रिया पूरी हुई।",
                "resend": resend,
                "total_selected": total_selected,
                "success_count": success_count,
                "failed_count": failed_count,
                "qnx_mart_gst_number": gst_number,
                "business_card_attached": True,
                "errors": errors
            },
            status=status.HTTP_200_OK
        )
