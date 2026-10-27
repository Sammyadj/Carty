# Selected design: City

City is the selected Carty interface: Manrope typography, black budget cards, lime accents, and compact shopping controls. The production interface has one design and no theme preview switcher.

The earlier City, Fresh, and Pantry comparison is preserved on the [UI exploration branch](https://github.com/Sammyadj/Carty/tree/codex/ui-exploration). Fresh and Pantry, their fonts, and their preview assets are excluded from this implementation branch.

## Reference renders

These [City Home](previews/city-home.png) and [City basket](previews/city-basket.png) screenshots document the original selection. They use sample groceries and are not a guarantee of every later feature's exact layout.

Regenerate current City screens with `flutter test tool/render_design_previews.dart`. The capture uses bundled fonts and an in-memory basket, without reading or modifying a shopper’s data.

## Provenance

The original exploration inspected the public [Uber Eats grocery page](https://www.ubereats.com/near-me/grocery), [Deliveroo](https://deliveroo.co.uk/), and [Just Eat](https://www.just-eat.co.uk/). Carty’s layouts and vector grocery artwork are original adaptations. The [REA project](https://github.com/morluto/rea) was researched but was not used for native binary analysis.

Manrope comes from [Google Fonts](https://github.com/google/fonts/tree/main/ofl/manrope). Its SIL Open Font License is bundled and available in the app’s license screen. No third-party logos, proprietary fonts, or catalog photography are bundled.
