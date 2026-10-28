# Selected design: City

City is the selected Carty interface: Manrope typography, black budget cards, lime accents, and compact shopping controls. The production interface has one design and no theme preview switcher.

The earlier interface study is retained on the `archive/interface-study` branch.
Only the selected City design and its required assets are included in the app.

## Reference renders

These [City Home](previews/city-home.png) and [City basket](previews/city-basket.png) screenshots document the original selection. They use sample groceries and are not a guarantee of every later feature's exact layout.

Regenerate current City screens with `flutter test tool/render_design_previews.dart`. The capture uses bundled fonts and an in-memory basket, without reading or modifying a shopper’s data.

## Assets and licenses

Carty uses its own layouts and vector grocery artwork.

Manrope comes from [Google Fonts](https://github.com/google/fonts/tree/main/ofl/manrope). Its SIL Open Font License is bundled and available in the app’s license screen. No third-party logos, proprietary fonts, or catalog photography are bundled.
