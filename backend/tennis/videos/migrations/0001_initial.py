# Generated by Django 4.2.15 on 2024-08-16 18:41

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('home', '0003_trimspage_userpage_trimpage_framepage'),
    ]

    operations = [
        migrations.CreateModel(
            name='FramesBatch',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('dir_path', models.CharField(max_length=512, unique=True)),
                ('batch_number', models.BigIntegerField()),
                ('trim_page', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='frames_batches', to='home.trimpage')),
            ],
            options={
                'unique_together': {('trim_page', 'batch_number')},
            },
        ),
    ]