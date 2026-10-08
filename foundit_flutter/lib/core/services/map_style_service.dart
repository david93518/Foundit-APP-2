import 'package:flutter_map/flutter_map.dart';

/// 底圖：內政部國土測繪中心「臺灣通用電子地圖」(EMAP) WMTS 圖磚。
///
/// - 政府資料開放授權，免 API 金鑰，標註為繁體中文，涵蓋臺澎金馬。
/// - 點陣圖磚由 flutter_map 內建 TileLayer 繪製，iOS / Android / Web 行為一致；
///   先前的向量圖磚套件（beta）在實測中完全沒有請求圖磚，地圖一片空白。
const baseMapAttribution = '© 內政部國土測繪中心';
const baseMapAttributionUrl = 'https://maps.nlsc.gov.tw/';

TileLayer founditBaseMap({TileProvider? tileProvider}) => TileLayer(
  urlTemplate: 'https://wmts.nlsc.gov.tw/wmts/EMAP/default/GoogleMapsCompatible/{z}/{y}/{x}',
  userAgentPackageName: 'com.david93518.foundit',
  maxNativeZoom: 18,
  maxZoom: 19,
  // 測試注入假圖磚；臺灣範圍外沒有圖磚時保留地圖底色即可。
  tileProvider: tileProvider,
);
