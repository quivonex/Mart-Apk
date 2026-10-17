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
        
        
        
        
from django.core.mail import EmailMultiAlternatives
from django.conf import settings
from django.utils import timezone

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from .models import Businessman


class BusinessmanEmailSendAPIView(APIView):

    def post(self, request):

        # ==========================================
        # GET LIMIT
        # ==========================================

        limit = request.data.get('limit')

        if limit is None:
            return Response(
                {
                    'success': False,
                    'message': 'limit is required.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            limit = int(limit)
        except (ValueError, TypeError):

            return Response(
                {
                    'success': False,
                    'message': 'limit must be a valid integer.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if limit <= 0:

            return Response(
                {
                    'success': False,
                    'message': 'limit must be greater than 0.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ==========================================
        # EMAIL CONTENT
        # ==========================================

        subject = request.data.get(
            'subject',
            'QNX Mart मध्ये सहभागी व्हा'
        )

        message = request.data.get(
            'message',
            '''
नमस्कार,

QNX Mart सोबत सहभागी होऊन आपल्या व्यवसायाला
नवीन ग्राहक आणि नवीन बाजारपेठ मिळवा.

आजच QNX Mart सोबत सहभागी व्हा.

धन्यवाद,
QNX Mart Team
'''
        )

        # ==========================================
        # GET EMAILS
        # ==========================================

        businessmen = Businessman.objects.filter(
            email__isnull=False,
            email__gt='',
            email_sent=False
        ).order_by('id')[:limit]

        total_selected = businessmen.count()

        if total_selected == 0:

            return Response(
                {
                    'success': False,
                    'message': 'No unsent valid email records found.',
                    'total_selected': 0,
                    'success_count': 0,
                    'failed_count': 0
                },
                status=status.HTTP_404_NOT_FOUND
            )

        success_count = 0
        failed_count = 0
        errors = []

        # ==========================================
        # SEND EMAIL
        # ==========================================

        for businessman in businessmen:

            try:

                email = businessman.email.strip()

                mail = EmailMultiAlternatives(
                    subject=subject,
                    body=message,
                    from_email=settings.DEFAULT_FROM_EMAIL,
                    to=[email]
                )

                mail.send(fail_silently=False)

                businessman.email_sent = True
                businessman.email_sent_at = timezone.now()

                businessman.save(
                    update_fields=[
                        'email_sent',
                        'email_sent_at',
                        'updated_at'
                    ]
                )

                success_count += 1

            except Exception as e:

                failed_count += 1

                if len(errors) < 50:
                    errors.append({
                        'businessman_id': businessman.id,
                        'email': businessman.email,
                        'error': str(e)
                    })

        # ==========================================
        # RESPONSE
        # ==========================================

        return Response(
            {
                'success': True,
                'message': 'Email sending completed.',
                'total_selected': total_selected,
                'success_count': success_count,
                'failed_count': failed_count,
                'errors': errors
            },
            status=status.HTTP_200_OK
        )