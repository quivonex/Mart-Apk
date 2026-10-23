from rest_framework import status
from rest_framework.exceptions import APIException


class AIServiceException(APIException):
    status_code = status.HTTP_400_BAD_REQUEST
    default_detail = "Unable to process AI request."
    default_code = "ai_service_error"


class AIServiceDisabledException(AIServiceException):
    default_detail = "AI assistant is currently disabled."
    default_code = "ai_disabled"


class AIConversationNotFoundException(AIServiceException):
    default_detail = "Conversation not found."
    default_code = "conversation_not_found"


class AIMessageLimitException(AIServiceException):
    default_detail = "You have reached the AI message limit."
    default_code = "message_limit_reached"