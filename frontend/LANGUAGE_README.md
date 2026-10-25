# QNX Mart – English / मराठी / हिंदी

## How it works

- **Home header** has a language dropdown button (EN / मरा / हिं). Picking a language switches the whole app at once, and the choice is saved on the phone (it stays after logout).
- On the first launch the app shows a "Choose your language" screen after the splash.
- You can also change the language from **Account → Help & support → Language** and from the **Drawer → Language**.
- All app text uses `tr('English text')`. The English text is the key. If a translation is missing, the English text is shown.
- Backend text (product, property, ReMart and order names / descriptions) uses `trData(...)`. It shows the original text until the backend translate API exists (see below). After that, it shows the translation.

## Files

| File | What it is |
|---|---|
| `lib/l10n/app_language.dart` | `AppLanguage` (load / change / save), `tr()`, `trN()`, `trData()` |
| `lib/l10n/strings_mr.dart` | English → मराठी (about 2,700 texts) |
| `lib/l10n/strings_hi.dart` | English → हिंदी (about 2,700 texts) |
| `lib/widgets/language_button.dart` | Header dropdown button |
| `lib/screens/language_screen.dart` | First-run language screen and `showLanguagePicker()` sheet |
| `lib/main.dart` | Loads the saved language; `MaterialApp` gets the locale and Material translations |
| `lib/constants/design_tokens.dart` | Noto Sans Devanagari fallback so मराठी / हिंदी letters render correctly |
| `pubspec.yaml` | Adds `flutter_localizations` (sdk) |
| `lib/services/api_urls.dart` | Adds `translateTexts = '/accounts/translate/'` |
| All other screens / widgets / services | Text wrapped in `tr(...)`. Some `const` keywords were removed where needed. |

## If you applied the earlier `language_setup.zip`

Delete these files, otherwise the build fails:

- `frontend/l10n.yaml`
- `lib/l10n/app_en.arb`, `app_mr.arb`, `app_hi.arb`
- `lib/l10n/app_localizations*.dart` (generated)
- `lib/utils/locale_controller.dart`
- `lib/utils/l10n_ext.dart`

Then run `flutter clean` and `flutter pub get`.

## Adding a new text

1. Write the text in the screen with `tr`:
   ```dart
   Text(tr('Proceed to pay'))
   Text(tr('{0} items in cart', [count]))   // {0}, {1} … are filled in order
   ```
2. Add the same English key to **both** `strings_mr.dart` and `strings_hi.dart`:
   ```dart
   'Proceed to pay': 'पेमेंट करा',          // strings_mr.dart
   'Proceed to pay': 'भुगतान करें',          // strings_hi.dart
   ```
   The key must match the English text exactly, including dots and spaces.
3. For names that come from the backend, use `trData(product.name)`.

Do not wrap values that are sent to the backend, such as `payment_method`, status codes or map keys. Wrap only text that is shown on screen.

## Backend: translate API (for product / property / ReMart / order names)

The app calls:

```
POST /accounts/translate/
{"texts": ["Exide 150Ah Inverter Battery", "2 BHK Flat in Wakad"], "target": "mr"}
→ {"translations": ["एक्साइड 150Ah इन्व्हर्टर बॅटरी", "वाकडमधील 2 BHK फ्लॅट"]}
```

- The list must have the same length and order as `texts`.
- If this API does not exist (404), the app stops calling it and shows the original text.
- The app caches results on the phone and sends at most 80 texts per call.

Example implementation (Django REST, Google Cloud Translation v2). Put the key in `.env` as `GOOGLE_TRANSLATE_API_KEY`, never in code.

```python
# accounts/models.py
class TranslationCache(models.Model):
    source_hash = models.CharField(max_length=64, db_index=True)
    target = models.CharField(max_length=5)
    source_text = models.TextField()
    translated_text = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("source_hash", "target")
```

```python
# accounts/translate_views.py
import hashlib, os, requests
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from rest_framework.throttling import AnonRateThrottle
from rest_framework.response import Response
from .models import TranslationCache

GOOGLE_KEY = os.getenv("GOOGLE_TRANSLATE_API_KEY")


class TranslateThrottle(AnonRateThrottle):
    rate = "60/min"


class TranslateTextsAPIView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [TranslateThrottle]

    def post(self, request):
        target = request.data.get("target")
        texts = request.data.get("texts") or []
        if target not in ("mr", "hi") or not isinstance(texts, list):
            return Response({"message": "texts (list) and target (mr|hi) are required"}, status=400)
        texts = [str(t)[:500] for t in texts[:100]]

        def h(t):
            return hashlib.sha256(t.encode("utf-8")).hexdigest()

        out = [None] * len(texts)
        cached = {
            c.source_hash: c.translated_text
            for c in TranslationCache.objects.filter(target=target, source_hash__in=[h(t) for t in texts])
        }
        todo = []
        for i, t in enumerate(texts):
            hit = cached.get(h(t))
            if hit is not None:
                out[i] = hit
            else:
                todo.append(i)

        if todo and GOOGLE_KEY:
            r = requests.post(
                "https://translation.googleapis.com/language/translate/v2",
                params={"key": GOOGLE_KEY},
                json={"q": [texts[i] for i in todo], "target": target, "source": "en", "format": "text"},
                timeout=15,
            )
            if r.ok:
                items = r.json().get("data", {}).get("translations", [])
                for i, item in zip(todo, items):
                    tx = item.get("translatedText", "")
                    out[i] = tx
                    TranslationCache.objects.get_or_create(
                        source_hash=h(texts[i]), target=target,
                        defaults={"source_text": texts[i], "translated_text": tx},
                    )

        # anything not translated → original text
        return Response({"translations": [o if o else t for o, t in zip(out, texts)]})
```

```python
# accounts/urls.py
path("translate/", TranslateTextsAPIView.as_view(), name="translate-texts"),
```

Then run `python manage.py makemigrations accounts && python manage.py migrate`.

Google Cloud Translation is a paid API (it has a monthly free quota). The cache table means each product name is translated only once.
