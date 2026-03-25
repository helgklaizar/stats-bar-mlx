# TODO — Antigravity Bar
*Обновлено: 2026-03-25*

## 🔧 Задачи

- [ ] **Оптимизация polling**: сейчас данные обновляются каждые 30 сек — добавить adaptive interval (чаще пока открыто меню, реже в фоне)
- [ ] **Поддержка новых моделей**: добавить новые квоты/иконки в UI при появлении новых моделей Antigravity (сейчас: Flash, Pro, Claude)
- [ ] **Новые macOS API**: проверить и мигрировать устаревшие AppKit API на актуальные (macOS 14/15)
- [ ] **Daemon discovery**: защита от зависаний — добавить timeout + retry при чтении JSON из `~/.gemini/antigravity/daemon/`

## 💡 Tech Debt

- [ ] Бинарник называется `StellarBar` — переименовать в `AntigravityBar` в `Package.swift` и `build-app.sh`
