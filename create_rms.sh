#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="RMS"
ZIP_NAME="RMS.zip"

echo "Creating project structure..."

mkdir -p "${PROJECT_NAME}"
cd "${PROJECT_NAME}"

# Directories
mkdir -p project accounts accounts/migrations templates templates/accounts static static/css media staticfiles

# Files
cat > manage.py <<'PY'
#!/usr/bin/env python
import os
import sys

def main():
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'project.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise
    execute_from_command_line(sys.argv)

if __name__ == '__main__':
    main()
PY
chmod +x manage.py

mkdir -p project
cat > project/__init__.py <<'PY'
# empty
PY

cat > project/settings.py <<'PY'
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = 'replace-this-with-a-secure-key'
DEBUG = True
ALLOWED_HOSTS = ['*']

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'accounts',
]

AUTH_USER_MODEL = 'accounts.User'

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'project.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                'accounts.context_processors.sidebar_metrics',
            ],
        },
    },
]

WSGI_APPLICATION = 'project.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator','OPTIONS': {'min_length': 8}},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/static/'
STATICFILES_DIRS = [BASE_DIR / 'static']
STATIC_ROOT = BASE_DIR / 'staticfiles'

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

LOGIN_REDIRECT_URL = 'dashboard'
LOGOUT_REDIRECT_URL = 'login'
LOGIN_URL = 'login'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
PY

cat > project/urls.py <<'PY'
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('accounts.urls')),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
PY

cat > project/wsgi.py <<'PY'
import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'project.settings')
application = get_wsgi_application()
PY

mkdir -p accounts accounts/migrations

cat > accounts/__init__.py <<'PY'
# empty
PY

cat > accounts/apps.py <<'PY'
from django.apps import AppConfig

class AccountsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'accounts'

    def ready(self):
        from . import signals  # noqa
PY

cat > accounts/managers.py <<'PY'
from django.contrib.auth.base_user import BaseUserManager

class UserManager(BaseUserManager):
    use_in_migrations = True

    def _create_user(self, email, password, **extra_fields):
        if not email:
            raise ValueError('Email must be set')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', False)
        extra_fields.setdefault('is_superuser', False)
        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        return self._create_user(email, password, **extra_fields)
PY

cat > accounts/models.py <<'PY'
from django.db import models
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.utils import timezone
from .managers import UserManager

class User(AbstractBaseUser, PermissionsMixin):
    email = models.EmailField(unique=True)
    first_name = models.CharField(max_length=120, blank=True)
    last_name = models.CharField(max_length=120, blank=True)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(default=timezone.now)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = []
    objects = UserManager()

    def __str__(self):
        return self.email

class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    phone = models.CharField(max_length=32, blank=True)
    occupation = models.CharField(max_length=120, blank=True)
    nationality = models.CharField(max_length=120, blank=True)
    motto = models.TextField(blank=True)
    county = models.CharField(max_length=120, blank=True)
    avatar = models.ImageField(upload_to='avatars/', blank=True, null=True)
    last_seen = models.DateTimeField(default=timezone.now)

    def __str__(self):
        return f'Profile({self.user.email})'

class Landlord(models.Model):
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    name = models.CharField(max_length=200)
    email = models.EmailField(blank=True)
    phone = models.CharField(max_length=32, blank=True)
    address = models.CharField(max_length=255, blank=True)

    def __str__(self):
        return self.name

class Apartment(models.Model):
    name = models.CharField(max_length=200)
    address = models.CharField(max_length=255)
    landlord = models.ForeignKey(Landlord, on_delete=models.SET_NULL, null=True, blank=True)

    def __str__(self):
        return self.name

class House(models.Model):
    apartment = models.ForeignKey(Apartment, on_delete=models.CASCADE, related_name='houses')
    unit_number = models.CharField(max_length=50)
    bedrooms = models.PositiveIntegerField(default=1)
    bathrooms = models.PositiveIntegerField(default=1)
    rent = models.DecimalField(max_digits=10, decimal_places=2)
    is_available = models.BooleanField(default=True)

    def __str__(self):
        return f'{self.apartment.name} - {self.unit_number}'

class Tenant(models.Model):
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    name = models.CharField(max_length=200)
    email = models.EmailField(blank=True)
    phone = models.CharField(max_length=32, blank=True)
    house = models.ForeignKey(House, on_delete=models.SET_NULL, null=True, blank=True)
    move_in_date = models.DateField(null=True, blank=True)

    def __str__(self):
        return self.name

class Invoice(models.Model):
    tenant = models.ForeignKey(Tenant, on_delete=models.CASCADE, related_name='invoices')
    house = models.ForeignKey(House, on_delete=models.SET_NULL, null=True, blank=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=32, choices=[('unpaid', 'Unpaid'), ('paid', 'Paid')], default='unpaid')
    issued_on = models.DateField(default=timezone.now)
    due_on = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True)

    def __str__(self):
        return f'Invoice #{self.id} - {self.tenant.name}'

class CompanyIncome(models.Model):
    date = models.DateField(default=timezone.now)
    description = models.CharField(max_length=255)
    amount = models.DecimalField(max_digits=10, decimal_places=2)

    def __str__(self):
        return f'{self.date} - {self.amount}'
PY

cat > accounts/admin.py <<'PY'
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, UserProfile, Landlord, Apartment, House, Tenant, Invoice, CompanyIncome

class UserAdmin(BaseUserAdmin):
    ordering = ['email']
    list_display = ['email', 'first_name', 'last_name', 'is_staff']
    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal info', {'fields': ('first_name', 'last_name')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Important dates', {'fields': ('last_login', 'date_joined')}),
    )
    add_fieldsets = (
        (None, {'classes': ('wide',), 'fields': ('email', 'password1', 'password2')}),
    )
    search_fields = ('email',)

admin.site.register(User, UserAdmin)
admin.site.register(UserProfile)
admin.site.register(Landlord)
admin.site.register(Apartment)
admin.site.register(House)
admin.site.register(Tenant)
admin.site.register(Invoice)
admin.site.register(CompanyIncome)
PY

cat > accounts/forms.py <<'PY'
from django import forms
from django.contrib.auth.forms import AuthenticationForm
from .models import User, UserProfile, Landlord, Apartment, House, Tenant, Invoice, CompanyIncome

class LoginForm(AuthenticationForm):
    username = forms.EmailField(widget=forms.EmailInput(attrs={'class': 'form-control', 'placeholder': 'Email'}))
    password = forms.CharField(widget=forms.PasswordInput(attrs={'class': 'form-control', 'placeholder': 'Password'}))

class SignupForm(forms.ModelForm):
    password = forms.CharField(widget=forms.PasswordInput(attrs={'class': 'form-control'}))
    confirm_password = forms.CharField(widget=forms.PasswordInput(attrs={'class': 'form-control'}))

    class Meta:
        model = User
        fields = ['email', 'first_name', 'last_name']

        widgets = {
            'email': forms.EmailInput(attrs={'class': 'form-control'}),
            'first_name': forms.TextInput(attrs={'class': 'form-control'}),
            'last_name': forms.TextInput(attrs={'class': 'form-control'}),
        }

    def clean(self):
        data = super().clean()
        if data.get('password') != data.get('confirm_password'):
            raise forms.ValidationError('Passwords do not match.')
        return data

    def save(self, commit=True):
        user = super().save(commit=False)
        user.set_password(self.cleaned_data['password'])
        if commit:
            user.save()
        return user

class ProfileForm(forms.ModelForm):
    class Meta:
        model = UserProfile
        fields = ['phone', 'occupation', 'nationality', 'motto', 'county', 'avatar']
        widgets = {
            'phone': forms.TextInput(attrs={'class': 'form-control'}),
            'occupation': forms.TextInput(attrs={'class': 'form-control'}),
            'nationality': forms.TextInput(attrs={'class': 'form-control'}),
            'motto': forms.Textarea(attrs={'class': 'form-control'}),
            'county': forms.TextInput(attrs={'class': 'form-control'}),
        }

class LandlordForm(forms.ModelForm):
    class Meta:
        model = Landlord
        fields = ['name', 'email', 'phone', 'address']

class ApartmentForm(forms.ModelForm):
    class Meta:
        model = Apartment
        fields = ['name', 'address', 'landlord']

class HouseForm(forms.ModelForm):
    class Meta:
        model = House
        fields = ['apartment', 'unit_number', 'bedrooms', 'bathrooms', 'rent', 'is_available']

class TenantForm(forms.ModelForm):
    class Meta:
        model = Tenant
        fields = ['name', 'email', 'phone', 'house', 'move_in_date']

class InvoiceForm(forms.ModelForm):
    class Meta:
        model = Invoice
        fields = ['tenant', 'house', 'amount', 'status', 'issued_on', 'due_on', 'notes']

class CompanyIncomeForm(forms.ModelForm):
    class Meta:
        model = CompanyIncome
        fields = ['date', 'description', 'amount']
PY

cat > accounts/filters.py <<'PY'
from django import forms

class DateRangeForm(forms.Form):
    start = forms.DateField(required=False)
    end = forms.DateField(required=False)
PY

cat > accounts/signals.py <<'PY'
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils import timezone
from .models import User, UserProfile

@receiver(post_save, sender=User)
def create_profile(sender, instance, created, **kwargs):
    if created:
        UserProfile.objects.create(user=instance, last_seen=timezone.now())
PY

cat > accounts/context_processors.py <<'PY'
from .models import Tenant, Landlord, Apartment, House

def sidebar_metrics(request):
    try:
        return {
            'sidebar_tenants': Tenant.objects.count(),
            'sidebar_landlords': Landlord.objects.count(),
            'sidebar_properties': Apartment.objects.count(),
            'sidebar_units': House.objects.count(),
        }
    except Exception:
        return {}
PY

cat > accounts/views.py <<'PY'
from django.contrib.auth.decorators import login_required
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages
from django.utils import timezone
from django.db.models import Count
from .forms import (
    SignupForm, ProfileForm,
    LandlordForm, ApartmentForm, HouseForm, TenantForm,
    InvoiceForm, CompanyIncomeForm
)
from .models import (
    UserProfile, Landlord, Apartment, House, Tenant, Invoice, CompanyIncome, User
)

def signup_view(request):
    if request.user.is_authenticated:
        return redirect('dashboard')
    if request.method == 'POST':
        form = SignupForm(request.POST)
        if form.is_valid():
            user = form.save()
            messages.success(request, 'Account created. Please log in.')
            return redirect('login')
    else:
        form = SignupForm()
    return render(request, 'accounts/signup.html', {'form': form})

@login_required
def dashboard(request):
    metrics = {
        'tenants': Tenant.objects.count(),
        'landlords': Landlord.objects.count(),
        'properties': Apartment.objects.count(),
        'units': House.objects.count(),
    }
    units_per_apartment = Apartment.objects.annotate(total=Count('houses')).values('name', 'total')
    featured = Tenant.objects.select_related('house').order_by('-id')[:5]
    return render(request, 'accounts/dashboard.html', {
        'metrics': metrics,
        'units_per_apartment': units_per_apartment,
        'featured': featured,
    })

@login_required
def profile_view(request):
    profile = request.user.profile
    profile.last_seen = timezone.now()
    profile.save(update_fields=['last_seen'])
    return render(request, 'accounts/profile.html', {'profile': profile})

@login_required
def profile_edit(request):
    profile = request.user.profile
    if request.method == 'POST':
        form = ProfileForm(request.POST, request.FILES, instance=profile)
        if form.is_valid():
            form.save()
            messages.success(request, 'Profile updated.')
            return redirect('profile')
    else:
        form = ProfileForm(instance=profile)
    return render(request, 'accounts/profile_edit.html', {'form': form})

@login_required
def landlords_list(request):
    items = Landlord.objects.all()
    return render(request, 'accounts/landlords_list.html', {'items': items})

@login_required
def landlord_create(request):
    if request.method == 'POST':
        form = LandlordForm(request.POST)
        if form.is_valid():
            form.save()
            return redirect('landlords_list')
    else:
        form = LandlordForm()
    return render(request, 'accounts/form_generic.html', {'form': form, 'title': 'Create Landlord'})

@login_required
def landlord_update(request, pk):
    obj = get_object_or_404(Landlord, pk=pk)
    if request.method == 'POST':
        form = LandlordForm(request.POST, instance=obj)
        if form.is_valid():
            form.save()
            return redirect('landlords_list')
    else:
        form = LandlordForm(instance=obj)
    return render(request, 'accounts/form_generic.html', {'form': form, 'title': 'Edit Landlord'})

@login_required
def landlord_delete(request, pk):
    obj = get_object_or_404(Landlord, pk=pk)
    if request.method == 'POST':
        obj.delete()
        return redirect('landlords_list')
    return render(request, 'accounts/confirm_delete.html', {'obj': obj})

@login_required
def apartments_list(request):
    items = Apartment.objects.select_related('landlord').all()
    return render(request, 'accounts/apartments_list.html', {'items': items})

@login_required
def apartment_create(request):
    if request.method == 'POST':
        form = ApartmentForm(request.POST)
        if form.is_valid():
            form.save()
            return redirect('apartments_list')
    else:
        form = ApartmentForm()
    return render(request, 'accounts/form_generic.html', {'form': form, 'title': 'Create Apartment'})

@login_required
def apartment_update(request, pk):
    obj = get_object_or_404(Apartment, pk=pk)
    if request.method == 'POST':
        form = ApartmentForm(request.POST, instance=obj)
        if form.is_valid():
            form.save()
            return redirect('apartments_list')
    else:
        form = ApartmentForm(instance=obj)
    return render(request, 'accounts/form_generic.html', {'form': form, 'title': 'Edit Apartment'})

@login_required
def apartment_delete(request, pk):
    obj = get_object_or_404(Apartment, pk=pk)
    if request.method == 'POST':
        obj.delete()
        return redirect('apartments_list')
    return render(request, 'accounts/confirm_delete.html', {'obj': obj})

@login_required
def houses_list(request):
    items = House.objects.select_related('apartment').all()
    return render(request, 'accounts/houses_list.html', {'items': items})

@login_required
def house_create(request):
    if request.method == 'POST':
        form = HouseForm(request.POST)
        if form.is_valid():
            form.save()
            return redirect('houses_list')
    else:
        form = HouseForm()
    return render(request, 'accounts/form_generic.html', {'form': form, 'title': 'Create House'})

@login_required
def house_update(request, pk):
    obj = get_object_or_404(House, pk=pk)
    if request.method == 'POST':
        form = HouseForm(request.POST, instance=obj)
        if form.is_valid():
            form.save()
            return redirect('houses_list')
    else:
        form = HouseForm(instance=obj)
    return render(request, 'accounts/form_generic.html', {'form': form, 'title': 'Edit House'})

@login_required
def house_delete(request, pk):
    obj = get_object_or_404(House, pk=pk)
    if request.method == 'POST':
        obj.delete()
        return redirect('houses_list')
    return render(request, 'accounts/confirm_delete.html', {'obj': obj})

@login_required
def tenants_list(request):
    items = Tenant.objects.select_related('house').all()
    return render(request, 'accounts/tenants_list.html', {'items': items})

@login_required
def tenant_create(request):
    if request.method == 'POST':
        form = TenantForm(request.POST)
        if form.is_valid():
            form.save()
            return redirect('tenants_list')
    else:
        form = TenantForm()
    return render(request, 'accounts/form_generic.html', {'form': form, 'title': 'Create Tenant'})

@login_required
def tenant_update(request, pk):
    obj = get_object_or_404(Tenant, pk=pk)
    if request.method == 'POST':
        form = TenantForm(request.POST, instance=obj)
        if form.is_valid():
            form.save()
            return redirect('tenants_list')
    else:
        form = TenantForm(instance=obj)
    return render(request, 'accounts/form_generic.html', {'form': form, 'title': 'Edit Tenant'})

@login_required
def tenant_delete(request, pk):
    obj = get_object_or_404(Tenant, pk=pk)
    if request.method == 'POST':
        obj.delete()
        return redirect('tenants_list')
    return render(request, 'accounts/confirm_delete.html', {'obj': obj})

@login_required
def invoices_list(request):
    items = Invoice.objects.select_related('tenant', 'house').all()
    return render(request, 'accounts/invoices_list.html', {'items': items})

@login_required
def invoice_create(request):
    if request.method == 'POST':
        form = InvoiceForm(request.POST)
        if form.is_valid():
            form.save()
            return redirect('invoices_list')
    else:
        form = InvoiceForm()
    return render(request, 'accounts/form_generic.html', {'form': form, 'title': 'Create Invoice'})

@login_required
def invoice_update(request, pk):
    obj = get_object_or_404(Invoice, pk=pk)
    if request.method == 'POST':
        form = InvoiceForm(request.POST, instance=obj)
        if form.is_valid():
            form.save()
            return redirect('invoices_list')
    else:
        form = InvoiceForm(instance=obj)
    return render(request, 'accounts/form_generic.html', {'form': form, 'title': 'Edit Invoice'})

@login_required
def invoice_delete(request, pk):
    obj = get_object_or_404(Invoice, pk=pk)
    if request.method == 'POST':
        obj.delete()
        return redirect('invoices_list')
    return render(request, 'accounts/confirm_delete.html', {'obj': obj})

@login_required
def company_income_list(request):
    items = CompanyIncome.objects.all()
    return render(request, 'accounts/income_list.html', {'items': items})

@login_required
def company_income_create(request):
    if request.method == 'POST':
        form = CompanyIncomeForm(request.POST)
        if form.is_valid():
            form.save()
            return redirect('income_list')
    else:
        form = CompanyIncomeForm()
    return render(request, 'accounts/form_generic.html', {'form': form, 'title': 'Add Company Income'})

@login_required
def company_income_update(request, pk):
    obj = get_object_or_404(CompanyIncome, pk=pk)
    if request.method == 'POST':
        form = CompanyIncomeForm(request.POST, instance=obj)
        if form.is_valid():
            form.save()
            return redirect('income_list')
    else:
        form = CompanyIncomeForm(instance=obj)
    return render(request, 'accounts/form_generic.html', {'form': form, 'title': 'Edit Company Income'})

@login_required
def company_income_delete(request, pk):
    obj = get_object_or_404(CompanyIncome, pk=pk)
    if request.method == 'POST':
        obj.delete()
        return redirect('income_list')
    return render(request, 'accounts/confirm_delete.html', {'obj': obj})
PY

cat > accounts/tests.py <<'PY'
from django.test import TestCase
from django.urls import reverse

class AuthTests(TestCase):
    def test_signup_login_flow(self):
        resp = self.client.post(reverse('signup'), {
            'email': 'user@example.com',
            'first_name': 'First',
            'last_name': 'Last',
            'password': 'password123',
            'confirm_password': 'password123',
        })
        self.assertEqual(resp.status_code, 302)
        login = self.client.post(reverse('login'), {'username': 'user@example.com', 'password': 'password123'})
        self.assertEqual(login.status_code, 302)
PY

cat > accounts/urls.py <<'PY'
from django.urls import path
from django.contrib.auth.views import LoginView, LogoutView
from .views import (
    signup_view, dashboard, profile_view, profile_edit,
    landlords_list, landlord_create, landlord_update, landlord_delete,
    apartments_list, apartment_create, apartment_update, apartment_delete,
    houses_list, house_create, house_update, house_delete,
    tenants_list, tenant_create, tenant_update, tenant_delete,
    invoices_list, invoice_create, invoice_update, invoice_delete,
    company_income_list, company_income_create, company_income_update, company_income_delete,
)

urlpatterns = [
    path('', LoginView.as_view(template_name='accounts/login.html'), name='login'),
    path('logout/', LogoutView.as_view(), name='logout'),
    path('signup/', signup_view, name='signup'),
    path('dashboard/', dashboard, name='dashboard'),

    path('profile/', profile_view, name='profile'),
    path('profile/edit/', profile_edit, name='profile_edit'),

    path('landlords/', landlords_list, name='landlords_list'),
    path('landlords/create/', landlord_create, name='landlord_create'),
    path('landlords/<int:pk>/edit/', landlord_update, name='landlord_update'),
    path('landlords/<int:pk>/delete/', landlord_delete, name='landlord_delete'),

    path('apartments/', apartments_list, name='apartments_list'),
    path('apartments/create/', apartment_create, name='apartment_create'),
    path('apartments/<int:pk>/edit/', apartment_update, name='apartment_update'),
    path('apartments/<int:pk>/delete/', apartment_delete, name='apartment_delete'),

    path('houses/', houses_list, name='houses_list'),
    path('houses/create/', house_create, name='house_create'),
    path('houses/<int:pk>/edit/', house_update, name='house_update'),
    path('houses/<int:pk>/delete/', house_delete, name='house_delete'),

    path('tenants/', tenants_list, name='tenants_list'),
    path('tenants/create/', tenant_create, name='tenant_create'),
    path('tenants/<int:pk>/edit/', tenant_update, name='tenant_update'),
    path('tenants/<int:pk>/delete/', tenant_delete, name='tenant_delete'),

    path('invoices/', invoices_list, name='invoices_list'),
    path('invoices/create/', invoice_create, name='invoice_create'),
    path('invoices/<int:pk>/edit/', invoice_update, name='invoice_update'),
    path('invoices/<int:pk>/delete/', invoice_delete, name='invoice_delete'),

    path('income/', company_income_list, name='income_list'),
    path('income/create/', company_income_create, name='income_create'),
    path('income/<int:pk>/edit/', company_income_update, name='income_update'),
    path('income/<int:pk>/delete/', company_income_delete, name='income_delete'),
]
PY

# Templates
mkdir -p templates templates/accounts

cat > templates/base.html <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Deepnet RMS</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
  <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css" rel="stylesheet">
  <link rel="stylesheet" href="{% static 'css/style.css' %}">
</head>
<body>
<div class="d-flex">
  <nav class="sidebar bg-dark text-white p-3">
    <h5 class="mb-3">Deepnet RMS</h5>
    {% if user.is_authenticated %}
    <ul class="nav flex-column">
      <li class="nav-item"><a class="nav-link text-white" href="{% url 'dashboard' %}"><i class="fa fa-home"></i> Home</a></li>
      <li class="nav-item"><a class="nav-link text-white" href="{% url 'profile' %}"><i class="fa fa-user"></i> Profile</a></li>
      <li class="nav-item"><a class="nav-link text-white" href="/admin/"><i class="fa fa-database"></i> Admin</a></li>
      <li class="nav-item"><a class="nav-link text-white" href="{% url 'landlords_list' %}"><i class="fa fa-folder"></i> Landlords</a></li>
      <li class="nav-item"><a class="nav-link text-white" href="{% url 'apartments_list' %}"><i class="fa fa-building"></i> Apartments</a></li>
      <li class="nav-item"><a class="nav-link text-white" href="{% url 'tenants_list' %}"><i class="fa fa-users"></i> Tenants</a></li>
      <li class="nav-item"><a class="nav-link text-white" href="{% url 'houses_list' %}"><i class="fa fa-house"></i> Houses</a></li>
      <li class="nav-item"><a class="nav-link text-white" href="{% url 'invoices_list' %}"><i class="fa fa-file-invoice"></i> Invoices</a></li>
      <li class="nav-item"><a class="nav-link text-white" href="{% url 'income_list' %}"><i class="fa fa-chart-line"></i> Company income</a></li>
      <li class="nav-item"><a class="nav-link text-white" href="{% url 'logout' %}"><i class="fa fa-sign-out-alt"></i> Logout</a></li>
    </ul>
    <hr>
    <small>
      Tenants: {{ sidebar_tenants }} • Landlords: {{ sidebar_landlords }} • Properties: {{ sidebar_properties }} • Units: {{ sidebar_units }}
    </small>
    {% endif %}
  </nav>
  <main class="flex-grow-1 p-3">
    <div class="d-flex justify-content-between align-items-center mb-3">
      <div>
        <strong>Profile</strong>
      </div>
      <div class="text-end">
        <span class="badge text-bg-success">{{ now|date:"H:i:s A" }}</span>
        <span class="badge text-bg-primary">{{ now|date:"D" }}</span>
        <span class="badge text-bg-info">{{ now|date:"d/m/Y" }}</span>
        {% if user.is_authenticated %}
        <span class="badge text-bg-secondary">Welcome, {{ user.email }}</span>
        {% endif %}
      </div>
    </div>
    {% if messages %}
      {% for m in messages %}<div class="alert alert-info">{{ m }}</div>{% endfor %}
    {% endif %}
    {% block content %}{% endblock %}
  </main>
</div>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
HTML

cat > templates/accounts/login.html <<'HTML'
{% extends 'base.html' %}
{% block content %}
<div class="container" style="max-width:420px;">
  <h3 class="mb-3">Login</h3>
  <form method="post">
    {% csrf_token %}
    <div class="mb-3">
      <label>Email</label>
      <input type="email" name="username" class="form-control" required>
    </div>
    <div class="mb-3">
      <label>Password</label>
      <input type="password" name="password" class="form-control" required>
    </div>
    <button class="btn btn-primary w-100">Login</button>
    <p class="mt-3 text-center">No account? <a href="{% url 'signup' %}">Sign up</a></p>
  </form>
</div>
{% endblock %}
HTML

cat > templates/accounts/signup.html <<'HTML'
{% extends 'base.html' %}
{% block content %}
<div class="container" style="max-width:520px;">
  <h3 class="mb-3">Sign up</h3>
  <form method="post">
    {% csrf_token %}
    <div class="mb-3">
      <label>Email</label>
      {{ form.email }}
    </div>
    <div class="mb-3">
      <label>First name</label>
      {{ form.first_name }}
    </div>
    <div class="mb-3">
      <label>Last name</label>
      {{ form.last_name }}
    </div>
    <div class="mb-3">
      <label>Password</label>
      {{ form.password }}
    </div>
    <div class="mb-3">
      <label>Confirm password</label>
      {{ form.confirm_password }}
    </div>
    <button class="btn btn-primary w-100">Create account</button>
  </form>
</div>
{% endblock %}
HTML

cat > templates/accounts/dashboard.html <<'HTML'
{% extends 'base.html' %}
{% block content %}
<div class="row g-3 mb-4">
  <div class="col-md-3">
    <div class="card card-stat bg-info text-white">
      <div class="card-body">
        <div class="display-6">{{ metrics.tenants }}</div>
        <div>Registered Tenants</div>
        <a class="text-white" href="{% url 'tenants_list' %}">More info <i class="fa fa-circle-info"></i></a>
      </div>
    </div>
  </div>
  <div class="col-md-3">
    <div class="card card-stat bg-success text-white">
      <div class="card-body">
        <div class="display-6">{{ metrics.landlords }}</div>
        <div>Registered Landlords</div>
        <a class="text-white" href="{% url 'landlords_list' %}">More <i class="fa fa-circle-info"></i></a>
      </div>
    </div>
  </div>
  <div class="col-md-3">
    <div class="card card-stat bg-warning text-dark">
      <div class="card-body">
        <div class="display-6">{{ metrics.properties }}</div>
        <div>Managed Properties</div>
        <a href="{% url 'apartments_list' %}">More</a>
      </div>
    </div>
  </div>
  <div class="col-md-3">
    <div class="card card-stat bg-danger text-white">
      <div class="card-body">
        <div class="display-6">{{ metrics.units }}</div>
        <div>House Units</div>
        <a class="text-white" href="{% url 'houses_list' %}">More Info</a>
      </div>
    </div>
  </div>
</div>

<div class="row g-3">
  <div class="col-md-8">
    <div class="card">
      <div class="card-header">Data Chart</div>
      <div class="card-body">
        <table class="table table-sm">
          <thead><tr><th>Apartment</th><th>Total Units</th></tr></thead>
          <tbody>
            {% for a in units_per_apartment %}
            <tr><td>{{ a.name }}</td><td>{{ a.total }}</td></tr>
            {% empty %}
            <tr><td colspan="2" class="text-muted">No data</td></tr>
            {% endfor %}
          </tbody>
        </table>
      </div>
    </div>
  </div>
  <div class="col-md-4">
    <div class="card">
      <div class="card-header">Featured</div>
      <div class="card-body">
        <ul class="list-group">
          {% for t in featured %}
          <li class="list-group-item">
            {{ t.name }} {% if t.house %}<span class="text-muted">- {{ t.house }}</span>{% endif %}
          </li>
          {% empty %}
          <li class="list-group-item text-muted">No featured tenants</li>
          {% endfor %}
        </ul>
      </div>
    </div>
  </div>
</div>
{% endblock %}
HTML

cat > templates/accounts/profile.html <<'HTML'
{% extends 'base.html' %}
{% block content %}
<div class="row g-3">
  <div class="col-md-4">
    <div class="card">
      <div class="card-body text-center">
        {% if profile.avatar %}
          <img src="{{ profile.avatar.url }}" alt="Avatar" class="rounded-circle" width="120" height="120">
        {% else %}
          <i class="fa fa-user-circle fa-5x text-secondary"></i>
        {% endif %}
        <p class="mt-2">{{ user.email }}</p>
        <p class="text-muted">Last Seen : {{ profile.last_seen|date:"M d, Y, h:i a" }}</p>
        <hr>
        <div class="text-start">
          <p><strong>First Name</strong> <span class="float-end">{{ user.first_name|default:"None" }}</span></p>
          <p><strong>Last Name</strong> <span class="float-end">{{ user.last_name|default:"None" }}</span></p>
          <p><strong>Email</strong> <span class="float-end">{{ user.email }}</span></p>
        </div>
      </div>
    </div>
    <div class="card mt-3">
      <div class="card-header">About Me</div>
      <div class="card-body">
        <p class="text-muted">Add any personal info in your profile.</p>
      </div>
    </div>
  </div>

  <div class="col-md-8">
    <div class="card">
      <div class="card-body">
        <div class="d-flex justify-content-between align-items-center">
          <h5 class="mb-0">Welcome {{ user.email }}</h5>
          <a class="btn btn-sm btn-outline-primary" href="{% url 'profile_edit' %}"><i class="fa fa-pen"></i> Edit</a>
        </div>
        <hr>
        <div class="row mb-3">
          <div class="col-md-6">
            <p><strong>Phone :</strong> {{ profile.phone|default:"None" }}</p>
            <p><strong>Occupation :</strong> {{ profile.occupation|default:"None" }}</p>
            <p><strong>Nationality :</strong> {{ profile.nationality|default:"None" }}</p>
          </div>
          <div class="col-md-6">
            <p><strong>My Profile Motto</strong></p>
            <div class="form-control" style="min-height:70px;">{{ profile.motto|default:"None" }}</div>
            <p class="mt-3"><strong>County</strong></p>
            <div class="form-control">{{ profile.county|default:"None" }}</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
{% endblock %}
HTML

cat > templates/accounts/profile_edit.html <<'HTML'
{% extends 'base.html' %}
{% block content %}
<div class="container" style="max-width:720px;">
  <h4>Edit Profile</h4>
  <form method="post" enctype="multipart/form-data">
    {% csrf_token %}
    <div class="row g-3">
      <div class="col-md-6">
        <label>Phone</label>{{ form.phone }}
      </div>
      <div class="col-md-6">
        <label>Occupation</label>{{ form.occupation }}
      </div>
      <div class="col-md-6">
        <label>Nationality</label>{{ form.nationality }}
      </div>
      <div class="col-md-6">
        <label>County</label>{{ form.county }}
      </div>
      <div class="col-12">
        <label>Motto</label>{{ form.motto }}
      </div>
      <div class="col-12">
        <label>Avatar</label>{{ form.avatar }}
      </div>
    </div>
    <button class="btn btn-primary mt-3">Save</button>
    <a href="{% url 'profile' %}" class="btn btn-secondary mt-3">Cancel</a>
  </form>
</div>
{% endblock %}
HTML

cat > templates/accounts/landlords_list.html <<'HTML'
{% extends 'base.html' %}
{% block content %}
<div class="d-flex justify-content-between mb-2">
  <h4>Landlords</h4>
  <a href="{% url 'landlord_create' %}" class="btn btn-primary">Add Landlord</a>
</div>
<table class="table table-striped">
  <thead><tr><th>Name</th><th>Email</th><th>Phone</th><th>Address</th><th></th></tr></thead>
  <tbody>
    {% for x in items %}
      <tr>
        <td>{{ x.name }}</td><td>{{ x.email }}</td><td>{{ x.phone }}</td><td>{{ x.address }}</td>
        <td class="text-end">
          <a class="btn btn-sm btn-outline-secondary" href="{% url 'landlord_update' x.id %}">Edit</a>
          <a class="btn btn-sm btn-outline-danger" href="{% url 'landlord_delete' x.id %}">Delete</a>
        </td>
      </tr>
    {% empty %}
      <tr><td colspan="5" class="text-muted">No landlords</td></tr>
    {% endfor %}
  </tbody>
</table>
{% endblock %}
HTML

cat > templates/accounts/apartments_list.html <<'HTML'
{% extends 'base.html' %}
{% block content %}
<div class="d-flex justify-content-between mb-2">
  <h4>Apartments</h4>
  <a href="{% url 'apartment_create' %}" class="btn btn-primary">Add Apartment</a>
</div>
<table class="table table-striped">
  <thead><tr><th>Name</th><th>Address</th><th>Landlord</th><th></th></tr></thead>
  <tbody>
    {% for x in items %}
      <tr>
        <td>{{ x.name }}</td><td>{{ x.address }}</td><td>{{ x.landlord|default:"-" }}</td>
        <td class="text-end">
          <a class="btn btn-sm btn-outline-secondary" href="{% url 'apartment_update' x.id %}">Edit</a>
          <a class="btn btn-sm btn-outline-danger" href="{% url 'apartment_delete' x.id %}">Delete</a>
        </td>
      </tr>
    {% empty %}
      <tr><td colspan="4" class="text-muted">No apartments</td></tr>
    {% endfor %}
  </tbody>
</table>
{% endblock %}
HTML

cat > templates/accounts/houses_list.html <<'HTML'
{% extends 'base.html' %}
{% block content %}
<div class="d-flex justify-content-between mb-2">
  <h4>Houses</h4>
  <a href="{% url 'house_create' %}" class="btn btn-primary">Add House</a>
</div>
<table class="table table-striped">
  <thead><tr><th>Apartment</th><th>Unit</th><th>Beds</th><th>Baths</th><th>Rent</th><th>Available</th><th></th></tr></thead>
  <tbody>
    {% for x in items %}
      <tr>
        <td>{{ x.apartment }}</td><td>{{ x.unit_number }}</td><td>{{ x.bedrooms }}</td><td>{{ x.bathrooms }}</td><td>{{ x.rent }}</td><td>{{ x.is_available }}</td>
        <td class="text-end">
          <a class="btn btn-sm btn-outline-secondary" href="{% url 'house_update' x.id %}">Edit</a>
          <a class="btn btn-sm btn-outline-danger" href="{% url 'house_delete' x.id %}">Delete</a>
        </td>
      </tr>
    {% empty %}
      <tr><td colspan="7" class="text-muted">No houses</td></tr>
    {% endfor %}
  </tbody>
</table>
{% endblock %}
HTML

cat > templates/accounts/tenants_list.html <<'HTML'
{% extends 'base.html' %}
{% block content %}
<div class="d-flex justify-content-between mb-2">
  <h4>Tenants</h4>
  <a href="{% url 'tenant_create' %}" class="btn btn-primary">Add Tenant</a>
</div>
<table class="table table-striped">
  <thead><tr><th>Name</th><th>Email</th><th>Phone</th><th>House</th><th>Move-in</th><th></th></tr></thead>
  <tbody>
    {% for x in items %}
      <tr>
        <td>{{ x.name }}</td><td>{{ x.email }}</td><td>{{ x.phone }}</td><td>{{ x.house|default:"-" }}</td><td>{{ x.move_in_date|date:"Y-m-d" }}</td>
        <td class="text-end">
          <a class="btn btn-sm btn-outline-secondary" href="{% url 'tenant_update' x.id %}">Edit</a>
          <a class="btn btn-sm btn-outline-danger" href="{% url 'tenant_delete' x.id %}">Delete</a>
        </td>
      </tr>
    {% empty %}
      <tr><td colspan="6" class="text-muted">No tenants</td></tr>
    {% endfor %}
  </tbody>
</table>
{% endblock %}
HTML

cat > templates/accounts/invoices_list.html <<'HTML'
{% extends 'base.html' %}
{% block content %}
<div class="d-flex justify-content-between mb-2">
  <h4>Invoices</h4>
  <a href="{% url 'invoice_create' %}" class="btn btn-primary">Add Invoice</a>
</div>
<table class="table table-striped">
  <thead><tr><th>#</th><th>Tenant</th><th>House</th><th>Amount</th><th>Status</th><th>Issued</th><th>Due</th><th></th></tr></thead>
  <tbody>
    {% for x in items %}
      <tr>
        <td>{{ x.id }}</td><td>{{ x.tenant }}</td><td>{{ x.house|default:"-" }}</td><td>{{ x.amount }}</td><td>{{ x.get_status_display }}</td><td>{{ x.issued_on|date:"Y-m-d" }}</td><td>{{ x.due_on|date:"Y-m-d" }}</td>
        <td class="text-end">
          <a class="btn btn-sm btn-outline-secondary" href="{% url 'invoice_update' x.id %}">Edit</a>
          <a class="btn btn-sm btn-outline-danger" href="{% url 'invoice_delete' x.id %}">Delete</a>
        </td>
      </tr>
    {% empty %}
      <tr><td colspan="8" class="text-muted">No invoices</td></tr>
    {% endfor %}
  </tbody>
</table>
{% endblock %}
HTML

cat > templates/accounts/income_list.html <<'HTML'
{% extends 'base.html' %}
{% block content %}
<div class="d-flex justify-content-between mb-2">
  <h4>Company Income</h4>
  <a href="{% url 'income_create' %}" class="btn btn-primary">Add Income</a>
</div>
<table class="table table-striped">
  <thead><tr><th>Date</th><th>Description</th><th>Amount</th><th></th></tr></thead>
  <tbody>
    {% for x in items %}
      <tr>
        <td>{{ x.date|date:"Y-m-d" }}</td><td>{{ x.description }}</td><td>{{ x.amount }}</td>
        <td class="text-end">
          <a class="btn btn-sm btn-outline-secondary" href="{% url 'income_update' x.id %}">Edit</a>
          <a class="btn btn-sm btn-outline-danger" href="{% url 'income_delete' x.id %}">Delete</a>
        </td>
      </tr>
    {% empty %}
      <tr><td colspan="4" class="text-muted">No income entries</td></tr>
    {% endfor %}
  </tbody>
</table>
{% endblock %}
HTML

cat > templates/accounts/form_generic.html <<'HTML'
{% extends 'base.html' %}
{% block content %}
<div class="container" style="max-width:720px;">
  <h4>{{ title }}</h4>
  <form method="post">
    {% csrf_token %}
    {% for field in form %}
      <div class="mb-3">
        <label>{{ field.label }}</label>
        {{ field }}
        {% if field.errors %}
          <div class="text-danger small">{{ field.errors }}</div>
        {% endif %}
      </div>
    {% endfor %}
    <button class="btn btn-primary">Save</button>
    <a href="javascript:history.back()" class="btn btn-secondary">Cancel</a>
  </form>
</div>
{% endblock %}
HTML

cat > templates/accounts/confirm_delete.html <<'HTML'
{% extends 'base.html' %}
{% block content %}
<div class="container" style="max-width:600px;">
  <div class="alert alert-warning">
    Are you sure you want to delete <strong>{{ obj }}</strong>?
  </div>
  <form method="post">
    {% csrf_token %}
    <button class="btn btn-danger">Yes, delete</button>
    <a href="javascript:history.back()" class="btn btn-secondary">Cancel</a>
  </form>
</div>
{% endblock %}
HTML

# Static
mkdir -p static/css
cat > static/css/style.css <<'CSS'
body { background: #f8fafb; }
.sidebar { min-height: 100vh; width: 260px; }
.card-stat { border: 0; border-radius: .5rem; }
CSS

# Requirements and Procfile
cat > requirements.txt <<'REQ'
Django==4.2.11
Pillow==10.4.0
gunicorn==21.2.0
REQ

cat > Procfile <<'TXT'
web: gunicorn project.wsgi
TXT

echo "Setting up Python virtual environment and installing dependencies..."
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "Running migrations..."
python manage.py makemigrations accounts
python manage.py migrate

echo "Packaging zip..."
cd ..
zip -r "${ZIP_NAME}" "${PROJECT_NAME}"

echo "Done!"
echo "Zip created: ${ZIP_NAME}"
echo "To run locally:"
echo "  cd ${PROJECT_NAME}"
echo "  source .venv/bin/activate"
echo "  python manage.py runserver"
