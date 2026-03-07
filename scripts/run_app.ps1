$ErrorActionPreference = "Stop"

& ".\flutter\bin\flutter.bat" run --dart-define-from-file=env/supabase.local.json
