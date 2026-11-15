class CatalogVariant {
  const CatalogVariant({
    required this.id,
    required this.available,
    required this.options,
  });

  final int id;
  final bool available;
  final List<String> options;
}

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.vendorLine,
    required this.type,
    required this.price,
    required this.image,
    required this.optionLabel,
    required this.sizes,
    required this.variants,
    required this.url,
  });

  final String id;
  final String name;
  final String vendorLine;
  final String type;
  final double price;
  final String image;
  final String optionLabel;
  final List<String> sizes;
  final List<CatalogVariant> variants;
  final String url;
}

class PinSpec {
  const PinSpec({
    required this.number,
    required this.title,
    required this.leftFrac,
    required this.topFrac,
    this.isNew = false,
  });

  final int number;
  final String title;
  final double leftFrac;
  final double topFrac;
  final bool isNew;
}

class LookSpec {
  const LookSpec({
    required this.index,
    required this.key,
    required this.name,
    required this.description,
    required this.image640,
    required this.image1080,
    required this.productIds,
    required this.pins,
  });

  final int index;
  final String key;
  final String name;
  final String description;
  final String image640;
  final String image1080;
  final List<String> productIds;
  final List<PinSpec> pins;

  String get accessibilityLabel => 'Look ${index + 1}: $name';
}

class RunwayCatalog {
  RunwayCatalog._();

  static const String source = 'https://nike-makknzjs.myshopify.com/pages/runway';
  static const String nikeLogoSvgUrl =
      'https://reel-ref-try-the-look.vercel.app/assets/nike-logo.svg';
  static const double bundleOriginalPrice = 547.00;
  static const double bundleSalePrice = 492.30;

  static const List<CatalogItem> items = [
    CatalogItem(
      id: 'tatum-5-orbit-copy',
      name: 'Air Jordan 12 Retro',
      vendorLine: 'Nikey | Password: 1',
      type: 'From the original lookbook',
      price: 149,
      image: 'https://reel-ref-try-the-look.vercel.app/assets/source-tatum-5-orbit-copy.webp',
      optionLabel: 'Shoe size',
      sizes: ['40', '41', '42', '43', '44', '45', '46'],
      variants: [
        CatalogVariant(id: 57015167025457, available: true, options: ['40']),
        CatalogVariant(id: 57015167058225, available: true, options: ['41']),
        CatalogVariant(id: 57015167090993, available: true, options: ['42']),
        CatalogVariant(id: 57015167123761, available: true, options: ['43']),
        CatalogVariant(id: 57015167156529, available: true, options: ['44']),
        CatalogVariant(id: 57015167189297, available: true, options: ['45']),
        CatalogVariant(id: 57015167222065, available: true, options: ['46']),
      ],
      url: 'https://nike-makknzjs.myshopify.com/products/tatum-5-orbit-copy',
    ),
    CatalogItem(
      id: 'tshirt',
      name: 'Tshirt',
      vendorLine: 'Nike',
      type: 'From the original lookbook',
      price: 199,
      image: 'https://reel-ref-try-the-look.vercel.app/assets/source-tshirt.webp',
      optionLabel: 'Size',
      sizes: ['S', 'L', 'M', 'XL'],
      variants: [
        CatalogVariant(id: 56835911582001, available: true, options: ['S']),
        CatalogVariant(id: 56835911614769, available: true, options: ['L']),
        CatalogVariant(id: 56835911647537, available: true, options: ['M']),
        CatalogVariant(id: 56835911680305, available: true, options: ['XL']),
      ],
      url: 'https://nike-makknzjs.myshopify.com/products/tshirt',
    ),
    CatalogItem(
      id: 'sweatshirt',
      name: 'Sweatshirt',
      vendorLine: 'Nike',
      type: 'From the original lookbook',
      price: 199,
      image: 'https://reel-ref-try-the-look.vercel.app/assets/source-sweatshirt.webp',
      optionLabel: 'Size',
      sizes: ['S', 'L', 'M', 'XL'],
      variants: [
        CatalogVariant(id: 56835806396721, available: true, options: ['S']),
        CatalogVariant(id: 56835806429489, available: true, options: ['L']),
        CatalogVariant(id: 56835806462257, available: true, options: ['M']),
        CatalogVariant(id: 56835806495025, available: true, options: ['XL']),
      ],
      url: 'https://nike-makknzjs.myshopify.com/products/sweatshirt',
    ),
    CatalogItem(
      id: 'tatum-5-orbit',
      name: 'Tatum 5 Orbit',
      vendorLine: 'Nikey | Password: 1',
      type: 'From the original lookbook',
      price: 149,
      image: 'https://reel-ref-try-the-look.vercel.app/assets/source-tatum-5-orbit.webp',
      optionLabel: 'Shoe size',
      sizes: ['40', '41', '42', '43', '44', '45', '46'],
      variants: [
        CatalogVariant(id: 57015166730545, available: true, options: ['40']),
        CatalogVariant(id: 57015166763313, available: true, options: ['41']),
        CatalogVariant(id: 57015166796081, available: true, options: ['42']),
        CatalogVariant(id: 57015166828849, available: true, options: ['43']),
        CatalogVariant(id: 57015166861617, available: true, options: ['44']),
        CatalogVariant(id: 57015166894385, available: true, options: ['45']),
        CatalogVariant(id: 57015166927153, available: true, options: ['46']),
      ],
      url: 'https://nike-makknzjs.myshopify.com/products/tatum-5-orbit',
    ),
    CatalogItem(
      id: 'hoodie-black',
      name: 'Hoodie Black',
      vendorLine: 'Nike',
      type: 'From the original lookbook',
      price: 199,
      image: 'https://reel-ref-try-the-look.vercel.app/assets/source-hoodie-black.webp',
      optionLabel: 'Size',
      sizes: ['S', 'L', 'M', 'XL'],
      variants: [
        CatalogVariant(id: 56836251681073, available: true, options: ['S']),
        CatalogVariant(id: 56836251713841, available: true, options: ['L']),
        CatalogVariant(id: 56836251746609, available: true, options: ['M']),
        CatalogVariant(id: 56836251779377, available: true, options: ['XL']),
      ],
      url: 'https://nike-makknzjs.myshopify.com/products/hoodie-black',
    ),
    CatalogItem(
      id: 'sweatshirt-plus',
      name: 'Sweatshirt Plus',
      vendorLine: 'Nike',
      type: 'From the original lookbook',
      price: 199,
      image: 'https://reel-ref-try-the-look.vercel.app/assets/source-sweatshirt-plus.webp',
      optionLabel: 'Size',
      sizes: ['S', 'L', 'M', 'XL'],
      variants: [
        CatalogVariant(id: 56836143743281, available: true, options: ['S']),
        CatalogVariant(id: 56836143776049, available: true, options: ['L']),
        CatalogVariant(id: 56836143808817, available: true, options: ['M']),
        CatalogVariant(id: 56836143841585, available: true, options: ['XL']),
      ],
      url: 'https://nike-makknzjs.myshopify.com/products/sweatshirt-plus',
    ),
    CatalogItem(
      id: 'hoodie',
      name: 'Hoodie',
      vendorLine: 'Nike',
      type: 'From the original lookbook',
      price: 199,
      image: 'https://reel-ref-try-the-look.vercel.app/assets/source-hoodie.webp',
      optionLabel: 'Size',
      sizes: ['S', 'L', 'M', 'XL'],
      variants: [
        CatalogVariant(id: 56836002185521, available: true, options: ['S']),
        CatalogVariant(id: 56836002218289, available: true, options: ['L']),
        CatalogVariant(id: 56836002251057, available: true, options: ['M']),
        CatalogVariant(id: 56836002283825, available: true, options: ['XL']),
      ],
      url: 'https://nike-makknzjs.myshopify.com/products/hoodie',
    ),
    CatalogItem(
      id: 'air-jordan-12-retro-copy',
      name: 'Luka 5',
      vendorLine: 'Nikey | Password: 1',
      type: 'From the original lookbook',
      price: 149,
      image: 'https://reel-ref-try-the-look.vercel.app/assets/source-air-jordan-12-retro-copy.webp',
      optionLabel: 'Shoe size',
      sizes: ['40', '41', '42', '43', '44', '45', '46'],
      variants: [
        CatalogVariant(id: 57015176364337, available: true, options: ['40']),
        CatalogVariant(id: 57015176397105, available: true, options: ['41']),
        CatalogVariant(id: 57015176429873, available: true, options: ['42']),
        CatalogVariant(id: 57015176462641, available: true, options: ['43']),
        CatalogVariant(id: 57015176495409, available: true, options: ['44']),
        CatalogVariant(id: 57015176528177, available: true, options: ['45']),
        CatalogVariant(id: 57015176560945, available: true, options: ['46']),
      ],
      url: 'https://nike-makknzjs.myshopify.com/products/air-jordan-12-retro-copy',
    ),
  ];

  static const List<LookSpec> looks = [
    LookSpec(
      index: 0,
      key: 'bndthK',
      name: 'The City Edit',
      description: 'A charcoal knit and easy denim.',
      image640: 'https://reel-ref-try-the-look.vercel.app/assets/model-1-640.webp',
      image1080: 'https://reel-ref-try-the-look.vercel.app/assets/original-look-1.webp',
      productIds: ['tatum-5-orbit-copy', 'tshirt', 'sweatshirt'],
      pins: [
        PinSpec(number: 1, title: 'Air Jordan 12 Retro', leftFrac: 0.47, topFrac: 0.27),
        PinSpec(number: 2, title: 'Tshirt', leftFrac: 0.48, topFrac: 0.58),
        PinSpec(number: 3, title: 'Sweatshirt', leftFrac: 0.45, topFrac: 0.96),
      ],
    ),
    LookSpec(
      index: 1,
      key: 'XckgG6',
      name: 'Gallery Opening',
      description: 'A clean white tee and relaxed denim.',
      image640: 'https://reel-ref-try-the-look.vercel.app/assets/model-5-640.webp',
      image1080: 'https://reel-ref-try-the-look.vercel.app/assets/original-look-5.webp',
      productIds: ['tatum-5-orbit', 'hoodie-black', 'tshirt'],
      pins: [
        PinSpec(number: 1, title: 'Tatum 5 Orbit', leftFrac: 0.50, topFrac: 0.28),
        PinSpec(number: 2, title: 'Hoodie Black', leftFrac: 0.48, topFrac: 0.58, isNew: true),
        PinSpec(number: 3, title: 'Tshirt', leftFrac: 0.45, topFrac: 0.88),
      ],
    ),
    LookSpec(
      index: 2,
      key: 'rLfAhC',
      name: 'Gallery Opening',
      description: 'Olive knitwear. A grounded palette.',
      image640: 'https://reel-ref-try-the-look.vercel.app/assets/model-4-640.webp',
      image1080: 'https://reel-ref-try-the-look.vercel.app/assets/original-look-4.webp',
      productIds: ['sweatshirt-plus', 'tatum-5-orbit', 'tshirt'],
      pins: [
        PinSpec(number: 1, title: 'Sweatshirt Plus', leftFrac: 0.50, topFrac: 0.28),
        PinSpec(number: 2, title: 'Tatum 5 Orbit', leftFrac: 0.48, topFrac: 0.58, isNew: true),
        PinSpec(number: 3, title: 'Tshirt', leftFrac: 0.45, topFrac: 0.88),
      ],
    ),
    LookSpec(
      index: 3,
      key: 'FKg67q',
      name: 'Studio Day',
      description: 'Black, white and laid-back denim.',
      image640: 'https://reel-ref-try-the-look.vercel.app/assets/model-6-640.webp',
      image1080: 'https://reel-ref-try-the-look.vercel.app/assets/original-look-6.webp',
      productIds: ['hoodie-black', 'tatum-5-orbit-copy', 'tshirt'],
      pins: [
        PinSpec(number: 1, title: 'Hoodie Black', leftFrac: 0.50, topFrac: 0.28),
        PinSpec(number: 2, title: 'Air Jordan 12 Retro', leftFrac: 0.48, topFrac: 0.58),
        PinSpec(number: 3, title: 'Tshirt', leftFrac: 0.45, topFrac: 0.88),
      ],
    ),
    LookSpec(
      index: 4,
      key: '8KREEE',
      name: 'Studio Day',
      description: 'Burgundy layers. A tailored perspective.',
      image640: 'https://reel-ref-try-the-look.vercel.app/assets/model-3-640.webp',
      image1080: 'https://reel-ref-try-the-look.vercel.app/assets/original-look-3.webp',
      productIds: ['sweatshirt', 'tatum-5-orbit', 'tshirt'],
      pins: [
        PinSpec(number: 1, title: 'Sweatshirt', leftFrac: 0.50, topFrac: 0.28),
        PinSpec(number: 2, title: 'Tatum 5 Orbit', leftFrac: 0.48, topFrac: 0.58),
        PinSpec(number: 3, title: 'Tshirt', leftFrac: 0.45, topFrac: 0.88),
      ],
    ),
    LookSpec(
      index: 5,
      key: 'N3bfm9',
      name: 'Studio Day',
      description: 'A grey crew and your favourite denim.',
      image640: 'https://reel-ref-try-the-look.vercel.app/assets/model-2-640.webp',
      image1080: 'https://reel-ref-try-the-look.vercel.app/assets/original-look-2.webp',
      productIds: ['hoodie', 'air-jordan-12-retro-copy', 'tshirt'],
      pins: [
        PinSpec(number: 1, title: 'Hoodie', leftFrac: 0.50, topFrac: 0.28),
        PinSpec(number: 2, title: 'Luka 5', leftFrac: 0.48, topFrac: 0.58),
        PinSpec(number: 3, title: 'Tshirt', leftFrac: 0.45, topFrac: 0.88),
      ],
    ),
  ];

  static final Map<String, CatalogItem> itemById = {
    for (final item in items) item.id: item,
  };

  static CatalogItem requireItem(String id) => itemById[id]!;
}
