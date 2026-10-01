"""
URL configuration for battery_manegement project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.0/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin# type: ignore

from django.urls import path, include# type: ignore

from django.conf import settings # type: ignore

from django.conf.urls.static import static # type: ignore

urlpatterns = [
    path('admin/', admin.site.urls),
    path('admin_profile/', include('admin_profile.urls')),  # Include admin_profile app URLs
    path('company/', include('company.urls')),  # Include company app URLs
    path('product/', include('product.urls')),  # Include product app URLs
    path('state/', include('state.urls')),  # Include state app URLs
    path('offer/', include('offer.urls')),  # Include offer app URLs
    path('enquiry/', include('enquiry.urls')),  # Include enquiry app URLs
    path('accounts/', include('accounts.urls')),  # Include accounts app URLs
    path('cart/', include('cart.urls')), 
    path('branch/', include('branch.urls')),  # Include branch app URLs   
    path('agreement/', include('agreement.urls')),  # Include agreement app URLs
    path('seller/', include('seller.urls')),  # Include seller app URLs
    path('order/', include('order.urls')),  # Include order app URLs
    path('franchicies/', include('Franchicies.urls')),  # Include franchicies app URLs
    path('payment/', include('payment.urls')),  # Include payment app URLs
    path('contact/', include('contact.urls')),  # Include contact app URLs
    path('shiprocket/', include('shiprocket.urls')),  # Include shipping app URLs
    path('olx/', include('olx.urls')),  # Include olx app URLs
    path('real_estate/', include('real_estate.urls')),  # Include real estate app URLs
    path('loan/', include('loan.urls')),  # Include loan app URLs
    path('AI/', include('AI.urls')),  # Include AI app URLs
    path('commission/', include('commission.urls')),  # Include commission app URLs

]
if settings.DEBUG:
    urlpatterns += static(
        settings.MEDIA_URL,
        document_root=settings.MEDIA_ROOT
    )