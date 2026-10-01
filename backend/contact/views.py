from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from .models import ContactUs


from .serializers import ContactUsSerializer


class ContactUsCreateAPIView(APIView):

    def post(self, request):

        serializer = ContactUsSerializer(data=request.data)

        if serializer.is_valid():
            serializer.save()

            return Response(
                {
                    "status": True,
                    "message": "Your message has been sent successfully.",
                    "data": serializer.data
                },
                status=status.HTTP_201_CREATED
            )

        return Response(
            {
                "status": False,
                "message": "Validation failed.",
                "errors": serializer.errors
            },
            status=status.HTTP_400_BAD_REQUEST
        )
        
        
class ContactUsListAPIView(APIView):

    def get(self, request):

        contacts = ContactUs.objects.filter(is_active=True).order_by('-created_at')

        serializer = ContactUsSerializer(contacts, many=True)

        return Response(
            {
                "status": True,
                "message": "Contact messages fetched successfully.",
                "count": contacts.count(),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )        