# Use an official, lightweight Python base image
FROM python:3.12-slim

# Set environment paths and behaviors
# 1. Prevents Python from writing .pyc files to disk
# 2. Prevents Python from buffering stdout/stderr (vital for docker logs)
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set the working directory inside the container
WORKDIR /app

# Install system dependencies required to compile the mysqlclient binary
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    default-libmysqlclient-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install Python packages
COPY requirements.txt /app/
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copy the rest of your local Django project into the container
COPY . /app/

# Open up port 8000 for standard web traffic
EXPOSE 8000