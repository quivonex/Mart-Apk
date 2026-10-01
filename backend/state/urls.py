from django.urls import path # type: ignore
from . import views

urlpatterns = [

    # State

    path('state_create/',views.StateCreateAPIView.as_view()),
    path('state_retrieve/',views.StateRetrieveAPIView.as_view()),
    path('state_update/',views.StateUpdateAPIView.as_view()),
    path('state_delete/',views.StateDeleteAPIView.as_view()),
    path('state_retrieveAll/',views.StateListAPIView.as_view()),
    path('state_retrieveAll_Active/',views.StateListActiveAPIView.as_view()),

    # District

    path('distict_create/',views.DistrictCreateAPIView.as_view()),
    path('distict_retrieve/',views.DistrictRetrieveAPIView.as_view()),
    path('distict_update/',views.DistrictUpdateAPIView.as_view()),
    path('distict_delete/',views.DistrictDeleteAPIView.as_view()),
    path('distict_retrieveAll/',views.DistrictListAPIView.as_view()),
    path('distict_retrieveAll_Active/',views.DistrictListActiveAPIView.as_view()),

    # Taluka

    path('taluka_create/',views.TalukaCreateAPIView.as_view()),
    path('taluka_retrieve/',views.TalukaRetrieveAPIView.as_view()),
    path('taluka_update/',views.TalukaUpdateAPIView.as_view()),
    path('taluka_delete/',views.TalukaDeleteAPIView.as_view()),
    path('taluka_retrieveAll/',views.TalukaListAPIView.as_view()),
    path('taluka_retrieveAll_Active/',views.TalukaListActiveAPIView.as_view()),

    # Villages

    path('village_create/', views.VillageCreateAPIView.as_view(), name='create-village'),
    path('api/villages/delete/',views.VillageDeleteAPIView.as_view(), name='village-delete'),


    path('get_state/', views.StateListAPIView.as_view(), name='get-state'),
    path('get_districts/', views.StateDistrictAPIView.as_view(), name='get-districts-form-state'),
    path('get_talukas/', views.DistrictTalukaAPIView.as_view(), name='get-talukas-form-district'),
    path('get_villages/', views.TalukaVillageAPIView.as_view(), name='get-villages-form-taluka'),


]