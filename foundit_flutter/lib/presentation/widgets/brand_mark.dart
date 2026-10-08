import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Original FOUND !T identity. Vector letterforms never depend on system fonts.
/// A narrow parent automatically receives the standalone discovery symbol.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final symbolOnly = compact || constraints.maxWidth < 134;
        final source = symbolOnly
            ? (dark ? _symbolDark : _symbolLight)
            : (dark ? _lockupDark : _lockupLight);
        return Semantics(
          label: 'FOUND IT',
          image: true,
          child: ExcludeSemantics(
            child: SizedBox(
              width: symbolOnly ? 31 : 134,
              height: 31,
              child: SvgPicture.string(
                source,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
        );
      },
    );
  }
}

const _symbolLight =
    '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" role="img" aria-label="FOUND IT"><title>FOUND !T</title><path d="M12 4H4V12M20 28H28V20" fill="none" stroke="#282B30" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M13.5 5.5H18.5L17.8 19H14.2Z" fill="#C64B30"/><circle cx="16" cy="24" r="2.5" fill="#C64B30"/></svg>''';

const _symbolDark =
    '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" role="img" aria-label="FOUND IT"><title>FOUND !T</title><path d="M12 4H4V12M20 28H28V20" fill="none" stroke="#FCFAF7" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M13.5 5.5H18.5L17.8 19H14.2Z" fill="#EF7958"/><circle cx="16" cy="24" r="2.5" fill="#EF7958"/></svg>''';

const _lockupLight =
    '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 142 32" role="img" aria-label="FOUND IT"><title>FOUND !T</title><path d="M12 4H4V12M20 28H28V20" fill="none" stroke="#282B30" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M13.5 5.5H18.5L17.8 19H14.2Z" fill="#C64B30"/><circle cx="16" cy="24" r="2.5" fill="#C64B30"/><path d="M37 8L48 8L48 11L40.3 11L40.3 15L47 15L47 18L40.3 18L40.3 24L37 24Z" fill="#282B30" fill-rule="evenodd"/><path d="M54 8L61 8L64 11L64 21L61 24L54 24L51 21L51 11ZM55.3 11L59.7 11L60.7 12L60.7 20L59.7 21L55.3 21L54.3 20L54.3 12Z" fill="#282B30" fill-rule="evenodd"/><path d="M67 8L70.3 8L70.3 19.8L71.6 21L75.4 21L76.7 19.8L76.7 8L80 8L80 21.1L77.2 24L69.8 24L67 21.1Z" fill="#282B30" fill-rule="evenodd"/><path d="M83 24L83 8L86.1 8L93 18.7L93 8L96.2 8L96.2 24L93.1 24L86.2 13.3L86.2 24Z" fill="#282B30" fill-rule="evenodd"/><path d="M99 8L107.7 8L112 12.3L112 19.7L107.7 24L99 24ZM102.3 11.1L106.3 11.1L108.7 13.5L108.7 18.5L106.3 20.9L102.3 20.9Z" fill="#282B30" fill-rule="evenodd"/><path d="M125 8L138 8L138 11.2L133.2 11.2L133.2 24L129.8 24L129.8 11.2L125 11.2Z" fill="#282B30" fill-rule="evenodd"/><path d="M117 8H121L120.5 19H117.5Z" fill="#C64B30"/><circle cx="119" cy="22.4" r="1.9" fill="#C64B30"/></svg>''';

const _lockupDark =
    '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 142 32" role="img" aria-label="FOUND IT"><title>FOUND !T</title><path d="M12 4H4V12M20 28H28V20" fill="none" stroke="#FCFAF7" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M13.5 5.5H18.5L17.8 19H14.2Z" fill="#EF7958"/><circle cx="16" cy="24" r="2.5" fill="#EF7958"/><path d="M37 8L48 8L48 11L40.3 11L40.3 15L47 15L47 18L40.3 18L40.3 24L37 24Z" fill="#FCFAF7" fill-rule="evenodd"/><path d="M54 8L61 8L64 11L64 21L61 24L54 24L51 21L51 11ZM55.3 11L59.7 11L60.7 12L60.7 20L59.7 21L55.3 21L54.3 20L54.3 12Z" fill="#FCFAF7" fill-rule="evenodd"/><path d="M67 8L70.3 8L70.3 19.8L71.6 21L75.4 21L76.7 19.8L76.7 8L80 8L80 21.1L77.2 24L69.8 24L67 21.1Z" fill="#FCFAF7" fill-rule="evenodd"/><path d="M83 24L83 8L86.1 8L93 18.7L93 8L96.2 8L96.2 24L93.1 24L86.2 13.3L86.2 24Z" fill="#FCFAF7" fill-rule="evenodd"/><path d="M99 8L107.7 8L112 12.3L112 19.7L107.7 24L99 24ZM102.3 11.1L106.3 11.1L108.7 13.5L108.7 18.5L106.3 20.9L102.3 20.9Z" fill="#FCFAF7" fill-rule="evenodd"/><path d="M125 8L138 8L138 11.2L133.2 11.2L133.2 24L129.8 24L129.8 11.2L125 11.2Z" fill="#FCFAF7" fill-rule="evenodd"/><path d="M117 8H121L120.5 19H117.5Z" fill="#EF7958"/><circle cx="119" cy="22.4" r="1.9" fill="#EF7958"/></svg>''';
