# Running Shuup with Docker

## 1. Build the image

From the repo root:

```bash
docker compose -f docker-compose-dev.yml build
```

The first build takes about 10 minutes (frontend assets are compiled). Later builds reuse cached layers.

## 2. Start the container

Port 8000 is used by the `portainer` container on this machine, so the app is mapped to 8001.

```bash
docker run -d --name shuup-check -p 8001:8000 \
  -v "$(pwd)":/app \
  -v /app/.sqlite -v /app/shuup/admin/static -v /app/shuup/front/static \
  -v /app/shuup/gdpr/static -v /app/shuup/notify/static -v /app/shuup/regions/static \
  -v /app/shuup/themes/classic_gray/static -v /app/shuup/xtheme/static \
  shuup-shuup
```

Open http://localhost:8001/ and the admin at http://localhost:8001/sa/ (login `admin` / `admin`).

## 3. Load demo content (one time)

Run these after the container is up. They create 30 products in 5 categories, make them purchasable, and build the homepage carousel.

```bash
docker exec -i shuup-check python3 -m shuup_workbench shell <<'EOF'
from django.conf import settings
from django.core.management import call_command
from django.utils import translation
from shuup.core.models import Shop, Supplier, SupplierModule
from shuup.simple_supplier.module import SimpleSupplierModule
from shuup.simple_supplier.tasks import index_shop_product
from shuup.core.models import ShopProduct
from shuup.testing.mock_population import Populator
from shuup.testing.modules.sample_data import manager as sample_manager
from shuup.testing.modules.sample_data.views import SampleObjectsWizardPane

translation.activate(settings.LANGUAGES[0][0])

# products and categories
Populator().populate()

# attach the stock module to the default supplier so products are purchasable
supplier = Supplier.objects.get(pk=1)
module, _ = SupplierModule.objects.get_or_create(module_identifier=SimpleSupplierModule.identifier)
module.suppliers.add(supplier)
for sp in ShopProduct.objects.all():
    index_shop_product(sp)

# homepage carousel and front-page layout
shop = Shop.objects.first()
carousel = SampleObjectsWizardPane._create_sample_carousel(shop, "default")
if carousel:
    sample_manager.save_carousel(shop, carousel.pk)

call_command("reindex_product_catalog")
EOF
```

Running it a second time adds duplicate products. Only run it again after recreating the container.

## 4. Check it

```bash
curl -sS -o /dev/null -w '%{http_code}\n' http://localhost:8001/      # expect 200
curl -sS http://localhost:8001/c/ | grep -c 'href="/c/'            # category links
```

## 5. Useful commands

```bash
docker logs -f shuup-check          # server log
docker exec -it shuup-check bash    # shell inside the container
docker rm -f shuup-check            # stop and remove (deletes demo data)
```

## Notes

- Demo data is stored in the container's SQLite volume. `docker rm -f shuup-check` deletes it. Use a named volume instead of `-v /app/.sqlite` to keep it.
- Local source changes show up immediately because `/app` is mounted from this repo.
- The changes to `Dockerfile`, `setup.py`, and `requirements-tests.txt` are not committed yet.
