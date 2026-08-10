import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

const _testStrings = <String>[
  // Exact upstream multilingual input; retaining it verbatim prevents drift.
  // ignore: lines_longer_than_80_chars
  'Лорем ипсум долор сит амет, ех сеа аццусам диссентиет. Ан еос стет еирмод витуперата. Иус дицерет урбанитас ет. Ан при алтера долорес сплендиде, цу яуо интегре денияуе, игнота волуптариа инструцтиор цу вим.',
  // Exact upstream multilingual input; retaining it verbatim prevents drift.
  // ignore: lines_longer_than_80_chars
  'ლორემ იფსუმ დოლორ სით ამეთ, ფაცერ მუციუს ცონსეთეთურ ყუო იდ, ფერ ვივენდუმ ყუაერენდუმ ეა, ესთ ამეთ მოვეთ სუავითათე ცუ. ვითაე სენსიბუს ან ვიხ. ეხერცი დეთერრუისსეთ უთ ყუი. ვოცენთ დებითის ადიფისცი ეთ ფერ. ნეც ან ფეუგაით ფორენსიბუს ინთერესსეთ. იდ დიცო რიდენს იუს. დისსენთიეთ ცონსეყუუნთურ სედ ნე, ნოვუმ მუნერე ეუმ ათ, ნე ეუმ ნიჰილ ირაცუნდია ურბანითას.',
  // Exact upstream multilingual input; retaining it verbatim prevents drift.
  // ignore: lines_longer_than_80_chars
  'अधिकांश अमितकुमार प्रोत्साहित मुख्य जाने प्रसारन विश्लेषण विश्व दारी अनुवादक अधिकांश नवंबर विषय गटकउसि गोपनीयता विकास जनित परस्पर गटकउसि अन्तरराष्ट्रीयकरन होसके मानव पुर्णता कम्प्युटर यन्त्रालय प्रति साधन',
  // Exact upstream multilingual input; retaining it verbatim prevents drift.
  // ignore: lines_longer_than_80_chars
  '覧六子当聞社計文護行情投身斗来。増落世的況上席備界先関権能万。本物挙歯乳全事携供板栃果以。頭月患端撤競見界記引去法条公泊候。決海備駆取品目芸方用朝示上用報。講申務紙約週堂出応理田流団幸稿。起保帯吉対阜庭支肯豪彰属本躍。量抑熊事府募動極都掲仮読岸。自続工就断庫指北速配鳴約事新住米信中験。婚浜袋著金市生交保他取情距。',
  // Exact upstream multilingual input; retaining it verbatim prevents drift.
  // ignore: lines_longer_than_80_chars
  '八メル務問へふらく博辞説いわょ読全タヨムケ東校どっ知壁テケ禁去フミ人過を装5階がねぜ法逆はじ端40落ミ予竹マヘナセ任1悪た。省ぜりせ製暇ょへそけ風井イ劣手はぼまず郵富法く作断タオイ取座ゅょが出作ホシ月給26島ツチ皇面ユトクイ暮犯リワナヤ断連こうでつ蔭柔薄とレにの。演めけふぱ損田転10得観びトげぎ王物鉄夜がまけ理惜くち牡提づ車惑参ヘカユモ長臓超漫ぼドかわ。',
  // Exact upstream multilingual input; retaining it verbatim prevents drift.
  // ignore: lines_longer_than_80_chars
  '모든 국민은 행위시의 법률에 의하여 범죄를 구성하지 아니하는 행위로 소추되지 아니하며. 전직대통령의 신분과 예우에 관하여는 법률로 정한다, 국회는 헌법 또는 법률에 특별한 규정이 없는 한 재적의원 과반수의 출석과 출석의원 과반수의 찬성으로 의결한다. 군인·군무원·경찰공무원 기타 법률이 정하는 자가 전투·훈련등 직무집행과 관련하여 받은 손해에 대하여는 법률이 정하는 보상외에 국가 또는 공공단체에 공무원의 직무상 불법행위로 인한 배상은 청구할 수 없다.',
  // Exact upstream multilingual input; retaining it verbatim prevents drift.
  // ignore: lines_longer_than_80_chars
  'كان فشكّل الشرقي مع, واحدة للمجهود تزامناً بعض بل. وتم جنوب للصين غينيا لم, ان وبدون وكسبت الأمور ذلك, أسر الخاسر الانجليزية هو. نفس لغزو مواقعها هو. الجو علاقة الصعداء انه أي, كما مع بمباركة للإتحاد الوزراء. ترتيب الأولى أن حدى, الشتوية باستحداث مدن بل, كان قد أوسع عملية. الأوضاع بالمطالبة كل قام, دون إذ شمال الربيع،. هُزم الخاصّة ٣٠ أما, مايو الصينية مع قبل.',
  // Exact upstream multilingual input; retaining it verbatim prevents drift.
  // ignore: lines_longer_than_80_chars
  'או סדר החול מיזמי קרימינולוגיה. קהילה בגרסה לויקיפדים אל היא, של צעד ציור ואלקטרוניקה. מדע מה ברית המזנון ארכיאולוגיה, אל טבלאות מבוקשים כלל. מאמרשיחהצפה העריכהגירסאות שכל אל, כתב עיצוב מושגי של. קבלו קלאסיים ב מתן. נבחרים אווירונאוטיקה אם מלא, לוח למנוע ארכיאולוגיה מה. ארץ לערוך בקרבת מונחונים או, עזרה רקטות לויקיפדים אחר גם.',
  'Лорем ლორემ अधिकांश 覧六子 八メル 모든 בקרבת 💮 😂 äggg 123€ 𝄞.',
];

void main() {
  // Static one-to-one registrations are generated below from the pinned
  // xterm.js test identities. Each invokes the exact corresponding case.
  test(
    'xterm TextDecoder 000',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 0..8192 (0x0..0x2000)',
    ),
  );
  test(
    'xterm TextDecoder 001',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 0xFEFF(BOM)',
    ),
  );
  test(
    'xterm TextDecoder 002',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 1007616..1015808 (0xF6000..0xF8000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 003',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 1015808..1024000 (0xF8000..0xFA000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 004',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 1024000..1032192 (0xFA000..0xFC000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 005',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 1032192..1040384 (0xFC000..0xFE000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 006',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 1040384..1048576 (0xFE000..0x100000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 007',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 1048576..1056768 (0x100000..0x102000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 008',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 1056768..1064960 (0x102000..0x104000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 009',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 106496..114688 (0x1A000..0x1C000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 010',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 1064960..1073152 (0x104000..0x106000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 011',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 1073152..1081344 (0x106000..0x108000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 012',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 1081344..1089536 (0x108000..0x10A000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 013',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 1089536..1097728 (0x10A000..0x10C000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 014',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 1097728..1105920 (0x10C000..0x10E000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 015',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 1105920..1114111 (0x10E000..0x10FFFF) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 016',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 114688..122880 (0x1C000..0x1E000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 017',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 122880..131072 (0x1E000..0x20000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 018',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 131072..139264 (0x20000..0x22000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 019',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 139264..147456 (0x22000..0x24000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 020',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 147456..155648 (0x24000..0x26000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 021',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 155648..163840 (0x26000..0x28000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 022',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 16384..24576 (0x4000..0x6000)',
    ),
  );
  test(
    'xterm TextDecoder 023',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 163840..172032 (0x28000..0x2A000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 024',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 172032..180224 (0x2A000..0x2C000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 025',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 180224..188416 (0x2C000..0x2E000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 026',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 188416..196608 (0x2E000..0x30000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 027',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 196608..204800 (0x30000..0x32000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 028',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 204800..212992 (0x32000..0x34000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 029',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 212992..221184 (0x34000..0x36000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 030',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 221184..229376 (0x36000..0x38000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 031',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 229376..237568 (0x38000..0x3A000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 032',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 237568..245760 (0x3A000..0x3C000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 033',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 24576..32768 (0x6000..0x8000)',
    ),
  );
  test(
    'xterm TextDecoder 034',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 245760..253952 (0x3C000..0x3E000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 035',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 253952..262144 (0x3E000..0x40000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 036',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 262144..270336 (0x40000..0x42000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 037',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 270336..278528 (0x42000..0x44000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 038',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 278528..286720 (0x44000..0x46000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 039',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 286720..294912 (0x46000..0x48000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 040',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 294912..303104 (0x48000..0x4A000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 041',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 303104..311296 (0x4A000..0x4C000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 042',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 311296..319488 (0x4C000..0x4E000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 043',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 319488..327680 (0x4E000..0x50000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 044',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 32768..40960 (0x8000..0xA000)',
    ),
  );
  test(
    'xterm TextDecoder 045',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 327680..335872 (0x50000..0x52000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 046',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 335872..344064 (0x52000..0x54000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 047',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 344064..352256 (0x54000..0x56000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 048',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 352256..360448 (0x56000..0x58000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 049',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 360448..368640 (0x58000..0x5A000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 050',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 368640..376832 (0x5A000..0x5C000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 051',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 376832..385024 (0x5C000..0x5E000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 052',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 385024..393216 (0x5E000..0x60000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 053',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 393216..401408 (0x60000..0x62000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 054',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 401408..409600 (0x62000..0x64000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 055',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 40960..49152 (0xA000..0xC000)',
    ),
  );
  test(
    'xterm TextDecoder 056',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 409600..417792 (0x64000..0x66000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 057',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 417792..425984 (0x66000..0x68000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 058',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 425984..434176 (0x68000..0x6A000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 059',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 434176..442368 (0x6A000..0x6C000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 060',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 442368..450560 (0x6C000..0x6E000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 061',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 450560..458752 (0x6E000..0x70000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 062',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 458752..466944 (0x70000..0x72000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 063',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 466944..475136 (0x72000..0x74000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 064',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 475136..483328 (0x74000..0x76000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 065',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 483328..491520 (0x76000..0x78000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 066',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 49152..57344 (0xC000..0xE000)',
    ),
  );
  test(
    'xterm TextDecoder 067',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 491520..499712 (0x78000..0x7A000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 068',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 499712..507904 (0x7A000..0x7C000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 069',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 507904..516096 (0x7C000..0x7E000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 070',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 516096..524288 (0x7E000..0x80000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 071',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 524288..532480 (0x80000..0x82000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 072',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 532480..540672 (0x82000..0x84000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 073',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 540672..548864 (0x84000..0x86000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 074',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 548864..557056 (0x86000..0x88000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 075',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 557056..565248 (0x88000..0x8A000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 076',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 565248..573440 (0x8A000..0x8C000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 077',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 57344..65536 (0xE000..0x10000)',
    ),
  );
  test(
    'xterm TextDecoder 078',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 573440..581632 (0x8C000..0x8E000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 079',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 581632..589824 (0x8E000..0x90000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 080',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 589824..598016 (0x90000..0x92000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 081',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 598016..606208 (0x92000..0x94000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 082',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 606208..614400 (0x94000..0x96000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 083',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 614400..622592 (0x96000..0x98000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 084',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 622592..630784 (0x98000..0x9A000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 085',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 630784..638976 (0x9A000..0x9C000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 086',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 638976..647168 (0x9C000..0x9E000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 087',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 647168..655360 (0x9E000..0xA0000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 088',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 65536..73728 (0x10000..0x12000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 089',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 655360..663552 (0xA0000..0xA2000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 090',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 663552..671744 (0xA2000..0xA4000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 091',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 671744..679936 (0xA4000..0xA6000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 092',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 679936..688128 (0xA6000..0xA8000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 093',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 688128..696320 (0xA8000..0xAA000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 094',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 696320..704512 (0xAA000..0xAC000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 095',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 704512..712704 (0xAC000..0xAE000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 096',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 712704..720896 (0xAE000..0xB0000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 097',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 720896..729088 (0xB0000..0xB2000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 098',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 729088..737280 (0xB2000..0xB4000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 099',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 73728..81920 (0x12000..0x14000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 100',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 737280..745472 (0xB4000..0xB6000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 101',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 745472..753664 (0xB6000..0xB8000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 102',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 753664..761856 (0xB8000..0xBA000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 103',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 761856..770048 (0xBA000..0xBC000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 104',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 770048..778240 (0xBC000..0xBE000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 105',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 778240..786432 (0xBE000..0xC0000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 106',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 786432..794624 (0xC0000..0xC2000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 107',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 794624..802816 (0xC2000..0xC4000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 108',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 802816..811008 (0xC4000..0xC6000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 109',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 811008..819200 (0xC6000..0xC8000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 110',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 8192..16384 (0x2000..0x4000)',
    ),
  );
  test(
    'xterm TextDecoder 111',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 81920..90112 (0x14000..0x16000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 112',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 819200..827392 (0xC8000..0xCA000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 113',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 827392..835584 (0xCA000..0xCC000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 114',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 835584..843776 (0xCC000..0xCE000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 115',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 843776..851968 (0xCE000..0xD0000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 116',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 851968..860160 (0xD0000..0xD2000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 117',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 860160..868352 (0xD2000..0xD4000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 118',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 868352..876544 (0xD4000..0xD6000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 119',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 876544..884736 (0xD6000..0xD8000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 120',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 884736..892928 (0xD8000..0xDA000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 121',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 892928..901120 (0xDA000..0xDC000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 122',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 90112..98304 (0x16000..0x18000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 123',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 901120..909312 (0xDC000..0xDE000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 124',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 909312..917504 (0xDE000..0xE0000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 125',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 917504..925696 (0xE0000..0xE2000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 126',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 925696..933888 (0xE2000..0xE4000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 127',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 933888..942080 (0xE4000..0xE6000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 128',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 942080..950272 (0xE6000..0xE8000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 129',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 950272..958464 (0xE8000..0xEA000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 130',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 958464..966656 (0xEA000..0xEC000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 131',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 966656..974848 (0xEC000..0xEE000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 132',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 974848..983040 (0xEE000..0xF0000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 133',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 98304..106496 (0x18000..0x1A000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 134',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 983040..991232 (0xF0000..0xF2000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 135',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 991232..999424 (0xF2000..0xF4000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 136',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder full codepoint test 999424..1007616 (0xF4000..0xF6000) (surrogates)',
    ),
  );
  test(
    'xterm TextDecoder 137',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder stream handling surrogates mixed advance by 1',
    ),
  );
  test(
    'xterm TextDecoder 138',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings StringToUtf32 decoder test strings',
    ),
  );
  test(
    'xterm TextDecoder 139',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 0..8192 (0x0..0x2000) (1/2/3 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 140',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 0xFEFF(BOM)',
    ),
  );
  test(
    'xterm TextDecoder 141',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 1002080..1010272 (0xF4A60..0xF6A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 142',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 100960..109152 (0x18A60..0x1AA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 143',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 1010272..1018464 (0xF6A60..0xF8A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 144',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 1018464..1026656 (0xF8A60..0xFAA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 145',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 1026656..1034848 (0xFAA60..0xFCA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 146',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 1034848..1043040 (0xFCA60..0xFEA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 147',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 1043040..1051232 (0xFEA60..0x100A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 148',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 1051232..1059424 (0x100A60..0x102A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 149',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 1059424..1067616 (0x102A60..0x104A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 150',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 1067616..1075808 (0x104A60..0x106A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 151',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 1075808..1084000 (0x106A60..0x108A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 152',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 1084000..1092192 (0x108A60..0x10AA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 153',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 109152..117344 (0x1AA60..0x1CA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 154',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 1092192..1100384 (0x10AA60..0x10CA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 155',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 1100384..1108576 (0x10CA60..0x10EA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 156',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 1108576..1114111 (0x10EA60..0x10FFFF) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 157',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 117344..125536 (0x1CA60..0x1EA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 158',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 125536..133728 (0x1EA60..0x20A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 159',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 133728..141920 (0x20A60..0x22A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 160',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 141920..150112 (0x22A60..0x24A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 161',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 150112..158304 (0x24A60..0x26A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 162',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 158304..166496 (0x26A60..0x28A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 163',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 16384..24576 (0x4000..0x6000) (1/2/3 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 164',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 166496..174688 (0x28A60..0x2AA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 165',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 174688..182880 (0x2AA60..0x2CA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 166',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 182880..191072 (0x2CA60..0x2EA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 167',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 191072..199264 (0x2EA60..0x30A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 168',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 199264..207456 (0x30A60..0x32A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 169',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 207456..215648 (0x32A60..0x34A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 170',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 215648..223840 (0x34A60..0x36A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 171',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 223840..232032 (0x36A60..0x38A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 172',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 232032..240224 (0x38A60..0x3AA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 173',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 240224..248416 (0x3AA60..0x3CA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 174',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 24576..32768 (0x6000..0x8000) (1/2/3 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 175',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 248416..256608 (0x3CA60..0x3EA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 176',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 256608..264800 (0x3EA60..0x40A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 177',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 264800..272992 (0x40A60..0x42A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 178',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 272992..281184 (0x42A60..0x44A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 179',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 281184..289376 (0x44A60..0x46A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 180',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 289376..297568 (0x46A60..0x48A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 181',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 297568..305760 (0x48A60..0x4AA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 182',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 305760..313952 (0x4AA60..0x4CA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 183',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 313952..322144 (0x4CA60..0x4EA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 184',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 322144..330336 (0x4EA60..0x50A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 185',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 32768..40960 (0x8000..0xA000) (1/2/3 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 186',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 330336..338528 (0x50A60..0x52A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 187',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 338528..346720 (0x52A60..0x54A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 188',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 346720..354912 (0x54A60..0x56A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 189',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 354912..363104 (0x56A60..0x58A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 190',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 363104..371296 (0x58A60..0x5AA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 191',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 371296..379488 (0x5AA60..0x5CA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 192',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 379488..387680 (0x5CA60..0x5EA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 193',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 387680..395872 (0x5EA60..0x60A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 194',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 395872..404064 (0x60A60..0x62A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 195',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 404064..412256 (0x62A60..0x64A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 196',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 40960..49152 (0xA000..0xC000) (1/2/3 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 197',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 412256..420448 (0x64A60..0x66A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 198',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 420448..428640 (0x66A60..0x68A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 199',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 428640..436832 (0x68A60..0x6AA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 200',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 436832..445024 (0x6AA60..0x6CA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 201',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 445024..453216 (0x6CA60..0x6EA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 202',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 453216..461408 (0x6EA60..0x70A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 203',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 461408..469600 (0x70A60..0x72A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 204',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 469600..477792 (0x72A60..0x74A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 205',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 477792..485984 (0x74A60..0x76A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 206',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 485984..494176 (0x76A60..0x78A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 207',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 49152..57344 (0xC000..0xE000) (1/2/3 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 208',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 494176..502368 (0x78A60..0x7AA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 209',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 502368..510560 (0x7AA60..0x7CA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 210',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 510560..518752 (0x7CA60..0x7EA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 211',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 518752..526944 (0x7EA60..0x80A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 212',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 526944..535136 (0x80A60..0x82A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 213',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 535136..543328 (0x82A60..0x84A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 214',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 543328..551520 (0x84A60..0x86A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 215',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 551520..559712 (0x86A60..0x88A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 216',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 559712..567904 (0x88A60..0x8AA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 217',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 567904..576096 (0x8AA60..0x8CA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 218',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 57344..65536 (0xE000..0x10000) (1/2/3 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 219',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 576096..584288 (0x8CA60..0x8EA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 220',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 584288..592480 (0x8EA60..0x90A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 221',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 592480..600672 (0x90A60..0x92A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 222',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 600672..608864 (0x92A60..0x94A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 223',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 608864..617056 (0x94A60..0x96A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 224',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 617056..625248 (0x96A60..0x98A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 225',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 625248..633440 (0x98A60..0x9AA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 226',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 633440..641632 (0x9AA60..0x9CA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 227',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 641632..649824 (0x9CA60..0x9EA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 228',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 649824..658016 (0x9EA60..0xA0A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 229',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 65536..68192 (0x10000..0x10A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 230',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 658016..666208 (0xA0A60..0xA2A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 231',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 666208..674400 (0xA2A60..0xA4A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 232',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 674400..682592 (0xA4A60..0xA6A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 233',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 68192..76384 (0x10A60..0x12A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 234',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 682592..690784 (0xA6A60..0xA8A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 235',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 690784..698976 (0xA8A60..0xAAA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 236',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 698976..707168 (0xAAA60..0xACA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 237',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 707168..715360 (0xACA60..0xAEA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 238',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 715360..723552 (0xAEA60..0xB0A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 239',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 723552..731744 (0xB0A60..0xB2A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 240',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 731744..739936 (0xB2A60..0xB4A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 241',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 739936..748128 (0xB4A60..0xB6A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 242',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 748128..756320 (0xB6A60..0xB8A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 243',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 756320..764512 (0xB8A60..0xBAA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 244',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 76384..84576 (0x12A60..0x14A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 245',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 764512..772704 (0xBAA60..0xBCA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 246',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 772704..780896 (0xBCA60..0xBEA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 247',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 780896..789088 (0xBEA60..0xC0A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 248',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 789088..797280 (0xC0A60..0xC2A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 249',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 797280..805472 (0xC2A60..0xC4A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 250',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 805472..813664 (0xC4A60..0xC6A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 251',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 813664..821856 (0xC6A60..0xC8A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 252',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 8192..16384 (0x2000..0x4000) (1/2/3 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 253',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 821856..830048 (0xC8A60..0xCAA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 254',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 830048..838240 (0xCAA60..0xCCA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 255',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 838240..846432 (0xCCA60..0xCEA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 256',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 84576..92768 (0x14A60..0x16A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 257',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 846432..854624 (0xCEA60..0xD0A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 258',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 854624..862816 (0xD0A60..0xD2A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 259',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 862816..871008 (0xD2A60..0xD4A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 260',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 871008..879200 (0xD4A60..0xD6A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 261',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 879200..887392 (0xD6A60..0xD8A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 262',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 887392..895584 (0xD8A60..0xDAA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 263',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 895584..903776 (0xDAA60..0xDCA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 264',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 903776..911968 (0xDCA60..0xDEA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 265',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 911968..920160 (0xDEA60..0xE0A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 266',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 920160..928352 (0xE0A60..0xE2A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 267',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 92768..100960 (0x16A60..0x18A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 268',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 928352..936544 (0xE2A60..0xE4A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 269',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 936544..944736 (0xE4A60..0xE6A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 270',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 944736..952928 (0xE6A60..0xE8A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 271',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 952928..961120 (0xE8A60..0xEAA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 272',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 961120..969312 (0xEAA60..0xECA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 273',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 969312..977504 (0xECA60..0xEEA60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 274',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 977504..985696 (0xEEA60..0xF0A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 275',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 985696..993888 (0xF0A60..0xF2A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 276',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder full codepoint test 993888..1002080 (0xF2A60..0xF4A60) (4 byte sequences)',
    ),
  );
  test(
    'xterm TextDecoder 277',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder stream handling 0x80 not swallowed in continuation A—B',
    ),
  );
  test(
    'xterm TextDecoder 278',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder stream handling 0x80 not swallowed in continuation A𐀀B',
    ),
  );
  test(
    'xterm TextDecoder 279',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder stream handling 2 byte sequences - advance by 1',
    ),
  );
  test(
    'xterm TextDecoder 280',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder stream handling 2/3 byte sequences - advance by 1',
    ),
  );
  test(
    'xterm TextDecoder 281',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder stream handling 2/3/4 byte sequences - advance by 1',
    ),
  );
  test(
    'xterm TextDecoder 282',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder stream handling 2/3/4 byte sequences - advance by 2',
    ),
  );
  test(
    'xterm TextDecoder 283',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder stream handling 2/3/4 byte sequences - advance by 3',
    ),
  );
  test(
    'xterm TextDecoder 284',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder stream handling BOMs (3 byte sequences) - advance by 2',
    ),
  );
  test(
    'xterm TextDecoder 285',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder stream handling test break after 3 bytes - issue #2495',
    ),
  );
  test(
    'xterm TextDecoder 286',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings Utf8ToUtf32 decoder test strings',
    ),
  );
  test(
    'xterm TextDecoder 287',
    () => _runUpstreamCase(
      'unit:src/common/input/TextDecoder.test.ts:text encodings stringFromCodePoint/utf32ToString',
    ),
  );
}

void _runUpstreamCase(String id) {
  final range = RegExp(r'test (\d+)\.\.(\d+)').firstMatch(id);
  if (range != null) {
    final minimum = int.parse(range.group(1)!);
    final maximum = int.parse(range.group(2)!);
    if (id.contains('StringToUtf32 decoder')) {
      _assertStringRange(minimum, maximum);
    } else {
      _assertUtf8Range(minimum, maximum);
    }
    return;
  }
  if (id.endsWith('stringFromCodePoint/utf32ToString')) {
    final data = Uint32List.fromList('abcdefg'.codeUnits);
    for (var index = 0; index < data.length; index++) {
      expect(stringFromCodePoint(data[index]), 'abcdefg'[index]);
    }
    expect(utf32ToString(data), 'abcdefg');
    return;
  }
  if (id.contains('StringToUtf32 decoder full codepoint test 0xFEFF')) {
    final decoder = StringToUtf32();
    expect(decoder.decode('\ufeff', Uint32List(5)), 0);
    decoder.clear();
    return;
  }
  if (id.contains('Utf8ToUtf32 decoder full codepoint test 0xFEFF')) {
    final decoder = Utf8ToUtf32();
    expect(decoder.decode(_stringToUtf8Bytes('\ufeff'), Uint32List(5)), 0);
    decoder.clear();
    return;
  }
  if (id.endsWith('StringToUtf32 decoder test strings')) {
    final decoder = StringToUtf32();
    final target = Uint32List(500);
    for (final value in _testStrings) {
      final length = decoder.decode(value, target);
      expect(utf32ToString(target, end: length), value);
      decoder.clear();
    }
    return;
  }
  if (id.endsWith('Utf8ToUtf32 decoder test strings')) {
    final decoder = Utf8ToUtf32();
    final target = Uint32List(500);
    for (final value in _testStrings) {
      final length = decoder.decode(_stringToUtf8Bytes(value), target);
      expect(utf32ToString(target, end: length), value);
      decoder.clear();
    }
    return;
  }
  if (id.endsWith('surrogates mixed advance by 1')) {
    const input = 'Ä€𝄞Ö𝄞€Ü𝄞€';
    final decoder = StringToUtf32();
    final target = Uint32List(5);
    final output = StringBuffer();
    for (var index = 0; index < input.length; index++) {
      final length = decoder.decode(
        String.fromCharCode(input.codeUnitAt(index)),
        target,
      );
      output.write(utf32ToString(target, end: length));
    }
    expect(output.toString(), input);
    return;
  }
  if (id.endsWith('2 byte sequences - advance by 1')) {
    _assertUtf8Chunks(
      <int>[
        0xc3,
        0x84,
        0xc3,
        0x96,
        0xc3,
        0x9c,
        0xc3,
        0x9f,
        0xc3,
        0xb6,
        0xc3,
        0xa4,
        0xc3,
        0xbc,
      ],
      1,
      'ÄÖÜßöäü',
    );
    return;
  }
  if (id.endsWith('2/3 byte sequences - advance by 1')) {
    _assertUtf8Chunks(
      <int>[
        0xc3,
        0x84,
        0xe2,
        0x82,
        0xac,
        0xc3,
        0x96,
        0xe2,
        0x82,
        0xac,
        0xc3,
        0x9c,
        0xe2,
        0x82,
        0xac,
        0xc3,
        0x9f,
        0xe2,
        0x82,
        0xac,
        0xc3,
        0xb6,
        0xe2,
        0x82,
        0xac,
        0xc3,
        0xa4,
        0xe2,
        0x82,
        0xac,
        0xc3,
        0xbc,
      ],
      1,
      'Ä€Ö€Ü€ß€ö€ä€ü',
    );
    return;
  }
  if (id.contains('2/3/4 byte sequences - advance by')) {
    final chunkSize = int.parse(id.substring(id.length - 1));
    _assertUtf8Chunks(
      <int>[
        0xc3,
        0x84,
        0xe2,
        0x82,
        0xac,
        0xf0,
        0x9d,
        0x84,
        0x9e,
        0xc3,
        0x96,
        0xf0,
        0x9d,
        0x84,
        0x9e,
        0xe2,
        0x82,
        0xac,
        0xc3,
        0x9c,
        0xf0,
        0x9d,
        0x84,
        0x9e,
        0xe2,
        0x82,
        0xac,
      ],
      chunkSize,
      'Ä€𝄞Ö𝄞€Ü𝄞€',
    );
    return;
  }
  if (id.endsWith('BOMs (3 byte sequences) - advance by 2')) {
    _assertUtf8Chunks(<int>[0xef, 0xbb, 0xbf, 0xef, 0xbb, 0xbf], 2, '');
    return;
  }
  if (id.endsWith('test break after 3 bytes - issue #2495')) {
    final decoder = Utf8ToUtf32();
    final target = Uint32List(5);
    expect(
      decoder.decode(Uint8List.fromList(<int>[0xf0, 0xa0, 0x9c]), target),
      0,
    );
    final length = decoder.decode(Uint8List.fromList(<int>[0x8e]), target);
    expect(length, 1);
    expect(utf32ToString(target, end: length), '𠜎');
    return;
  }
  if (id.endsWith('0x80 not swallowed in continuation A—B')) {
    _assertUtf8Chunks(
      _stringToUtf8Bytes('A—BA—BA—BA—BA—B'),
      2,
      'A—BA—BA—BA—BA—B',
    );
    return;
  }
  if (id.endsWith('0x80 not swallowed in continuation A𐀀B')) {
    _assertUtf8Chunks(
      _stringToUtf8Bytes('A𐀀BA𐀀BA𐀀BA𐀀BA𐀀B'),
      2,
      'A𐀀BA𐀀BA𐀀BA𐀀BA𐀀B',
    );
    return;
  }
  fail('Unhandled pinned TextDecoder test: $id');
}

void _assertStringRange(int minimum, int maximum) {
  final input = StringBuffer();
  final expected = <int>[];
  for (var codePoint = minimum; codePoint < maximum; codePoint++) {
    if ((codePoint >= 0xd800 && codePoint <= 0xdfff) || codePoint == 0xfeff) {
      continue;
    }
    input.write(stringFromCodePoint(codePoint));
    expected.add(codePoint);
  }
  final decoder = StringToUtf32();
  final target = Uint32List(expected.length);
  final source = input.toString();
  final length = decoder.decode(source, target);
  expect(length, expected.length);
  expect(target, orderedEquals(expected));
  expect(utf32ToString(target, end: length), source);
}

void _assertUtf8Range(int minimum, int maximum) {
  final input = StringBuffer();
  final expected = <int>[];
  for (var codePoint = minimum; codePoint < maximum; codePoint++) {
    if ((codePoint >= 0xd800 && codePoint <= 0xdfff) || codePoint == 0xfeff) {
      continue;
    }
    input.write(stringFromCodePoint(codePoint));
    expected.add(codePoint);
  }
  final decoder = Utf8ToUtf32();
  final target = Uint32List(expected.length);
  final source = input.toString();
  final length = decoder.decode(_stringToUtf8Bytes(source), target);
  expect(length, expected.length);
  expect(target, orderedEquals(expected));
  expect(utf32ToString(target, end: length), source);
}

void _assertUtf8Chunks(List<int> values, int chunkSize, String expected) {
  final input = Uint8List.fromList(values);
  final decoder = Utf8ToUtf32();
  final target = Uint32List(5);
  final output = StringBuffer();
  for (var index = 0; index < input.length; index += chunkSize) {
    final end = (index + chunkSize).clamp(0, input.length);
    final length = decoder.decode(input.sublist(index, end), target);
    output.write(utf32ToString(target, end: length));
  }
  expect(output.toString(), expected);
}

Uint8List _stringToUtf8Bytes(String value) {
  final bytes = <int>[];
  for (var index = 0; index < value.length; index++) {
    var codePoint = value.codeUnitAt(index);
    if (codePoint >= 0xd800 &&
        codePoint <= 0xdbff &&
        index + 1 < value.length) {
      final next = value.codeUnitAt(index + 1);
      if (next >= 0xdc00 && next <= 0xdfff) {
        codePoint = 0x10000 + ((codePoint - 0xd800) << 10) + next - 0xdc00;
        index++;
      }
    }
    if (codePoint < 0x80) {
      bytes.add(codePoint);
    } else if (codePoint < 0x800) {
      bytes.addAll(<int>[0xc0 | codePoint >> 6, 0x80 | codePoint & 0x3f]);
    } else if (codePoint < 0x10000) {
      bytes.addAll(<int>[
        0xe0 | codePoint >> 12,
        0x80 | codePoint >> 6 & 0x3f,
        0x80 | codePoint & 0x3f,
      ]);
    } else {
      bytes.addAll(<int>[
        0xf0 | codePoint >> 18,
        0x80 | codePoint >> 12 & 0x3f,
        0x80 | codePoint >> 6 & 0x3f,
        0x80 | codePoint & 0x3f,
      ]);
    }
  }
  return Uint8List.fromList(bytes);
}
