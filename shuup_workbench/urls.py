# This file is part of Shuup.
#
# Copyright (c) 2012-2021, Shuup Commerce Inc. All rights reserved.
#
# This source code is licensed under the OSL-3.0 license found in the
# LICENSE file in the root directory of this source tree.
import os

from django.conf import settings
from django.conf.urls import include, url
from django.conf.urls.static import static
from django.views.static import serve

urlpatterns = [
    url(r"^sa/", include("shuup.admin.urls", namespace="shuup_admin")),
    url(r"^", include("shuup.front.urls", namespace="shuup")),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

if os.getenv("DJANGO_SERVE_MEDIA") == "1":
    urlpatterns += [
        url(r"^media/(?P<path>.*)$", serve, {"document_root": settings.MEDIA_ROOT}),
    ]
