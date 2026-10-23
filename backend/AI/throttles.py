from rest_framework.throttling import UserRateThrottle


class AIChatThrottle(UserRateThrottle):
    rate = "30/min"