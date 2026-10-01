from django.urls import path
from .views import (
    AmenityCreateAPIView,
    AmenityListAPIView,
    ApprovedPropertyListAPIView,
    AssignPropertyEnquiryAPIView,
    BuilderCreateAPIView,
    BuilderListAPIView,
    ChannelPartnerEnquiryListAPIView,
    MyEnquiryMarketingPartnerListAPIView,
  
    MyPropertyListAPIView,
    PropertyApproveAPIView,
    ApprovedPropertyListAPIView,
    PropertyCreateAPIView,
    PropertyDetailAPIView, 
    PropertyEnquiryCreateAPIView, 
    PropertyEnquiryListAPIView,
    PropertyEnquiryMultipalFilterListAPIView,
    PropertyListAPIView,
    PropertyEnquiryReferralLinkAPIView,
    PropertyReferralLinkAPIView,
    PropertyUpdateAPIView,

    RealEstateChannelPartnerCreateAPIView,
    RealEstateChannelPartnerListAPIView,
    RealEstatePropertyCommissionCreateAPIView,
    SchedulePropertyMeetingAPIView,
    UpdatePropertyMeetingStatusAPIView,
    UpdatePropertyMeetingStatusAPIView,
    PropertySubscriptionSettingCreateAPIView,
    MyEnquiryMarketingPartnerListAPIView

)

urlpatterns = [
    path("amenity/create/", AmenityCreateAPIView.as_view(), name="amenity-create"),
    path("amenities/list/", AmenityListAPIView.as_view(), name="amenity-list"),
    
    path("builder/create/",BuilderCreateAPIView.as_view(),name="builder-create"),
    path("builders/",BuilderListAPIView.as_view(),name="builder-list"),
            
    path("property/create/", PropertyCreateAPIView.as_view(), name="property-create"),
    path("property-update/",PropertyUpdateAPIView.as_view(),name="property-update"),
    path("properties/list/",PropertyListAPIView.as_view(),name="property-list"),
    path("properties/detail/",PropertyDetailAPIView.as_view(),name="property-detail"),
    
    path("property-subscription-setting/create/",PropertySubscriptionSettingCreateAPIView.as_view(),name="property-subscription-setting-create"),
    
    path("properties/approve/",PropertyApproveAPIView.as_view(),name="property-approve"),
    path("properties/approved/",ApprovedPropertyListAPIView.as_view(),name="property-approved-list"),
    path("my/properties/", MyPropertyListAPIView.as_view(), name="my-properties-list"),
    path("property_referral-link/", PropertyReferralLinkAPIView.as_view(), name="property-referral-link"),
    
    path("create/enquiry/", PropertyEnquiryCreateAPIView.as_view(), name="property-enquiry-create"),
    path("enquiries/", PropertyEnquiryListAPIView.as_view(), name="property-enquiries-list"),
    path("enquiries/filter/", PropertyEnquiryMultipalFilterListAPIView.as_view(), name="property-enquiries-filter"),
    path("property_enquiry/referral-link/", PropertyEnquiryReferralLinkAPIView.as_view(), name="property-referral-link"),

    
    path('real-estate/channel-partner/create/',RealEstateChannelPartnerCreateAPIView.as_view(),name='real-estate-channel-partner-create'),
    path("channel-partner/list/",RealEstateChannelPartnerListAPIView.as_view(),name="channel-partner-list"),
    path('real-estate/property-commission/create/',RealEstatePropertyCommissionCreateAPIView.as_view(),name='real-estate-property-commission-create'),
    
    path("my/enquiries/marketing-partners/", MyEnquiryMarketingPartnerListAPIView.as_view(), name="my-enquiry-marketing-partners"),
    path("property-enquiry/assign/",AssignPropertyEnquiryAPIView.as_view(),name="assign-property-enquiry"),
    path("channel-partner/enquiries/",ChannelPartnerEnquiryListAPIView.as_view(),name="channel-partner-enquiries"),
    
    path("property-enquiry/schedule-meeting/",SchedulePropertyMeetingAPIView.as_view(),name="schedule-property-meeting"),
    path("property-enquiry/update-meeting-status/",UpdatePropertyMeetingStatusAPIView.as_view(),name="update-property-meeting-status"),
]