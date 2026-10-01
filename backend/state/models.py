
# Create your models here.
from django.db import models # type: ignore

class State(models.Model):
    state_code = models.CharField(max_length=5, unique=True, help_text="Example: MH for Maharashtra")
    state_name = models.CharField(max_length=100, unique=True)

    is_active = models.BooleanField(default=True)
    flag = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'state_master'
        verbose_name = 'State'
        verbose_name_plural = 'States'
        ordering = ['state_name']

    def __str__(self):
        return f"{self.state_name} ({self.state_code})"
    

# District Taluka

class District(models.Model):
    district_name = models.CharField(max_length=100, unique=True)
    state = models.ForeignKey(State, on_delete=models.CASCADE, related_name='districts')

    is_active = models.BooleanField(default=True)
    flag = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'district_master'
        verbose_name = 'District'
        verbose_name_plural = 'Districts'
        ordering = ['district_name']

    def __str__(self):
        return f"{self.district_name} ({self.state.state_name})"
    



class Taluka(models.Model):
    taluka_name = models.CharField(max_length=100)
    state = models.ForeignKey(State, on_delete=models.CASCADE, related_name='talukas')
    district = models.ForeignKey(District, on_delete=models.CASCADE, related_name='talukas')

    is_active = models.BooleanField(default=True)
    flag = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'taluka_master'
        verbose_name = 'Taluka'
        verbose_name_plural = 'Talukas'
        ordering = ['taluka_name']

    def __str__(self):
        return f"{self.taluka_name} - {self.district.district_name}, {self.state.state_name}"




class Village(models.Model):
    village_name = models.CharField(max_length=100)
    state = models.ForeignKey(State, on_delete=models.CASCADE, related_name='villages')
    district = models.ForeignKey(District, on_delete=models.CASCADE, related_name='villages')
    taluka = models.ForeignKey(Taluka, on_delete=models.CASCADE, related_name='villages')
    
    is_active = models.BooleanField(default=True)
    flag = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'village_master'
        verbose_name = 'Village'
        verbose_name_plural = 'Villages'
        ordering = ['village_name']

    def __str__(self):
        return f"{self.village_name} - {self.taluka.taluka_name}, {self.district.district_name}, {self.state.state_name}"