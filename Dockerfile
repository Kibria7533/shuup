FROM node:12.21.0-buster-slim as base

# This image is NOT made for production use.
LABEL maintainer="Eero Ruohola <eero.ruohola@shuup.com>"

RUN sed -i \
        -e 's|deb.debian.org/debian|archive.debian.org/debian|g' \
        -e 's|security.debian.org|archive.debian.org|g' \
        -e '/buster-updates/d' \
        /etc/apt/sources.list \
    && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

RUN apt-get update \
    && apt-get --assume-yes install \
        libcairo2-dev \
        libffi-dev \
        libpangocairo-1.0-0 \
        pkg-config \
        python3 \
        python3-dev \
        python3-pil \
        python3-pip \
    && rm -rf /var/lib/apt/lists/ /var/cache/apt/

# These invalidate the cache every single time but
# there really isn't any other obvious way to do this.
COPY . /app
WORKDIR /app

# The dev compose file sets this to 1 to support development and editing the source code.
# The default value of 0 just installs the demo for running.
ARG editable=0

RUN pip3 install --upgrade pip setuptools wheel

# pip's PEP 660 editable install runs the custom "build" command (which needs
# django-admin before Django is installed) and the legacy-editable mode doesn't
# register the package on sys.path. Install dependencies with pip, then register
# the source tree with setup.py develop into the directory Python actually uses.
RUN if [ "$editable" -eq 1 ]; then \
        tail -n +2 requirements-tests.txt > /tmp/requirements-deps.txt \
        && pip3 install -r /tmp/requirements-deps.txt \
        && python3 setup.py egg_info \
        && pip3 install -r shuup.egg-info/requires.txt \
        && python3 setup.py develop --no-deps --install-dir=/usr/local/lib/python3.7/dist-packages \
        && python3 setup.py build_resources; \
    else pip3 install shuup; fi

RUN python3 -m shuup_workbench migrate
RUN python3 -m shuup_workbench shuup_init

RUN echo '\
from django.contrib.auth import get_user_model\n\
from django.db import IntegrityError\n\
try:\n\
    get_user_model().objects.create_superuser("admin", "admin@admin.com", "admin")\n\
except IntegrityError:\n\
    pass\n'\
| python3 -m shuup_workbench shell

CMD ["python3", "-m", "shuup_workbench", "runserver", "0.0.0.0:8000"]
