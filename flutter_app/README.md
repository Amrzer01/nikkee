# Try the Look — Runway (Flutter)

A Flutter implementation recreating the **Try the Look. — Runway** streetwear outfit carousel design, spring kinematics, and local styling bag.

## Features
- **Responsive Header**: 88px desktop / 68px mobile header with the Nike swoosh SVG, `Home` / `Nike Orbit` / `Hand Rail Pro` / `Runway` navigation, and live styling bag counter.
- **3D Ring & Diagonal Classic Stage**:
  - Desktop (`>=750px`): 12-body 3D ring (`STIFFNESS = 95`, critically damped, `FOLLOW_LAG = 0.04`) with depth blur, horizon perspective, alpha-row feet grounding, `01`–`06` expanding ticks, 5s autoplay, keyboard arrows, horizontal drag momentum, light sweep, and frosted `DRAG / VIEW` cursor.
  - Mobile (`<=749px`): Classic diagonal line layout with bottom progress walk bar, docked rounded panel (`20px` top radius), and horizontal snap product cards.
- **View Look Lightbox & Hot-Linking**: Zoom overlay displaying `1080w` look imagery with numbered pins, pulsing ripple rings, glass tooltips, and bidirectional pin-to-row reveal.
- **Size Pickers & Local Styling Bag**: Inline desktop size pills (`Shoe size` `40–46`, `Size` `S, L, M, XL`), mobile modal bottom size sheet, `"Pick a size for: [items]"` validation, `"Full look in your bag"` completion state, `SharedPreferences` (`runway-styling-bag-v3`) styling bag dialog, and shortlist copy export.

## Running Locally
```bash
cd flutter_app
flutter pub get
flutter test
flutter run
```
