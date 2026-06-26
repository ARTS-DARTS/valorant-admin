# Архитектурные правила — Valorant Lineups

## Производительность UI (Flutter)

### Запрещено в горячих путях (скролл, анимация)

| Запрещено | Почему | Замена |
|---|---|---|
| `Opacity(opacity: x)` где `0 < x < 1` | Вызывает `saveLayer` → offscreen рендер на каждый кадр | `ColoredBox` оверлей с нужной альфой поверх виджета |
| `color` + `colorBlendMode` на `CachedNetworkImage` | `ColorFilter` внутри вызывает `saveLayer` | Прозрачный `ColoredBox` поверх изображения в `Stack` |
| `BackdropFilter` в скроллящихся списках | Тоже `saveLayer`, очень дорого | Статичный градиент или тонированный фон |
| `precacheImage(...)` | Декодирует PNG в GPU-память синхронно на UI-потоке → фриз | `AppImageCache.manager.downloadFile(url)` — только диск, без декодирования |

### Правила для списков и гридов

- **Кэшировать вычисляемые списки в полях State** — не пересчитывать в `get`-геттерах при каждом `build()`. Пересчёт только при реальном изменении данных (`setState` + вызов метода пересчёта).
- **`RepaintBoundary`** вокруг каждой карточки в длинных гридах — изолирует перерисовку одной карточки от остальных.
- **`ValueKey`** на всех карточках в `SliverChildBuilderDelegate` — Flutter правильно переиспользует виджеты при `setState`.
- **`StatefulWidget` с `AnimationController`** — только если анимация реально используется в этом виджете. `SingleTickerProviderStateMixin` создаёт `Ticker` при каждом инстансе.

---

## Архитектура прогрева (SuperCell-стиль)

Цель: к моменту открытия экрана изображения уже лежат на диске.

### Как работает

1. **`_MapsTabState.initState()`** (главная вкладка, загружается при старте)  
   → `addPostFrameCallback` → `_prewarmMapImages()`  
   → последовательно вызывает `AppImageCache.manager.downloadFile(url)` для каждого splash  
   → только HTTP → диск, без декодирования, не нагружает GPU/CPU

2. **`MapPickerScreen` открывается** → `CachedNetworkImage` находит файл на диске → мгновенная отрисовка без плейсхолдера

3. **Entrance animation** (`_entranceCtrl`, 1800ms) запускается сразу в `initState`  
   → элементы появляются stagger'ом через `_fadeSlide(globalIndex, child)`  
   → globalIndex: 0 = заголовок, 1..N = рейтинговые карты, N+1 = второй заголовок, N+2.. = другие карты

### Правила прогрева

- Прогрев всегда **последовательный** (`await` в for-цикле), не параллельный — не перегружает сеть.
- Прогрев — только **диск-кэш** (`downloadFile`), никогда не `precacheImage`.
- Прогрев запускается с `addPostFrameCallback` — не блокирует первый кадр.

---

## Архитектура карт (InteractiveMapScreen)

### Минимапы
- **Первичный источник**: `MapData.minimapUrl(mapName)` → `https://media.valorant-api.com/maps/{uuid}/displayicon.png`
- **Fallback**: локальный asset (`assets/maps/{name}_minimap.png`) — только при ошибке сети
- **Summit** не имеет локального asset — только network
- Все UUID, калибровочные коэффициенты и URL хранятся в `lib/config/map_data.dart`

### Радиусы абилок
- Определены в `MapData.abilityRangesGU` (в игровых единицах, источник: game data)
- Конвертация в долю минимапа: `gameUnits * mapConfig.xMult.abs()`
- Среднее: 1000 gu ≈ 7.5% ширины карты
- `range_radius` в Firestore хранится уже в долях (0.0–1.0 от ширины минимапа)
- При добавлении нового лайнапа можно получить дефолт: `MapData.rangeForAbility(abilityName, mapName)`

### Визуальный дизайн (_TrajectoryPainter)
Правило SuperCell: эффекты должны быть визуально богатыми но технически дешёвыми.

**Линия траектории:**
- 2 прохода: сначала glow (`strokeWidth: 9, alpha: 0.22, MaskFilter.blur(3)`), потом основная линия (`strokeWidth: 2.8`)
- `MaskFilter.blur` допустим — рисуется только во время 600ms анимации, не при скролле

**Точки waypoint:**
- 3 слоя: glow circle (r=5.5) + solid dot (r=3.5) + white center (r=1.2)

**Стрелка:**
- 2 слоя: glow + solid

**Круг дальности (range circle):**
- Фаза 1 (rangeProgress 0→0.85): расширяющееся кольцо-пульс (pulse ring) — создаёт "радар" эффект
- Фаза 2 (rangeProgress 0.5→1.0): статичный круг с `RadialGradient` fill + border glow + solid border
- Всё фидится из `_rangeAnim` (AnimationController, 400ms), запускается после завершения траектории

## Список карт и маппул

**`MapPickerScreen.allMaps`** — публичный static const, все 13 карт игры.  
Обновлять при добавлении новой карты в игру: добавить запись `{name, splash}` с UUID из `valorant-api.com/v1/maps`.

**`_pool`** в `_MapPickerScreenState` — рейтинговый маппул текущего патча (хардкод).  
Текущий патч **13.00** (24 июня 2026): `Ascent, Bind, Breeze, Haven, Lotus, Split, Summit, Sunset`.  
Обновлять при смене патча, **не тянуть из Firestore** — Firestore хранит устаревшие данные и перебивает хардкод.

---

## Firebase / Firestore

- **Никогда не переходить на Blaze** — платим только на Selectel (русский сервер).
- Маппул в Firestore (`settings/map_pool`) устарел и не используется — источник правды это `_pool` в коде.

---

## Flutter-проект

- **Не пушить Flutter файлы** в репозиторий valorant-admin — там только HTML-сайты.
- `android/`, `lib/`, `pubspec.yaml` и т.д. — только локально.
