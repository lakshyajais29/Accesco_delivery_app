import '../models/product_model.dart';

// Simulates the FastAPI /catalog endpoint response.
// In production, replace _catalog with an HTTP fetch + JSON parse.
class CatalogService {
  CatalogService._();

  static final List<ParentProduct> _catalog = [

    // ── WOMEN ── Power Structured Blazer — ATELIER SUR ──────────────────────
    ParentProduct(
      id: 'PBL-AS', name: 'Power Structured Blazer', brand: 'ATELIER SUR',
      category: 'Blazers', gender: ProductGender.women,
      defaultImageUrl: 'https://images.unsplash.com/photo-1551803091-e20673f15770?w=600&q=85',
      originalPriceFormatted: '₹12,000',
      sizes: ['S','M','L','XL'], colors: const [
        VariantColor('Black','#1A1A1A'), VariantColor('Ivory','#F5F0E8'), VariantColor('Blush','#E8A0A0'),
      ],
      isNew: true, stock: 4, droppedMinsAgo: 83, viewersNow: 8, orderedToday: 31, saleEndsAt: '01:42:18',
      cityRank: 2, friendVotes: 18,
      variantMap: {
        'S__#1A1A1A' : ProductVariant(sku:'PBL-AS-BLK-S-101',  parentId:'PBL-AS',size:'S',  colorName:'Black',colorHex:'#1A1A1A',stock:6, priceInPaise:840000),
        'M__#1A1A1A' : ProductVariant(sku:'PBL-AS-BLK-M-102',  parentId:'PBL-AS',size:'M',  colorName:'Black',colorHex:'#1A1A1A',stock:3, priceInPaise:840000),
        'L__#1A1A1A' : ProductVariant(sku:'PBL-AS-BLK-L-103',  parentId:'PBL-AS',size:'L',  colorName:'Black',colorHex:'#1A1A1A',stock:0, priceInPaise:840000),
        'XL__#1A1A1A': ProductVariant(sku:'PBL-AS-BLK-XL-104', parentId:'PBL-AS',size:'XL', colorName:'Black',colorHex:'#1A1A1A',stock:2, priceInPaise:840000),
        'S__#F5F0E8' : ProductVariant(sku:'PBL-AS-IVR-S-111',  parentId:'PBL-AS',size:'S',  colorName:'Ivory',colorHex:'#F5F0E8',stock:4, priceInPaise:870000),
        'M__#F5F0E8' : ProductVariant(sku:'PBL-AS-IVR-M-112',  parentId:'PBL-AS',size:'M',  colorName:'Ivory',colorHex:'#F5F0E8',stock:7, priceInPaise:870000),
        'L__#F5F0E8' : ProductVariant(sku:'PBL-AS-IVR-L-113',  parentId:'PBL-AS',size:'L',  colorName:'Ivory',colorHex:'#F5F0E8',stock:1, priceInPaise:870000),
        'XL__#F5F0E8': ProductVariant(sku:'PBL-AS-IVR-XL-114', parentId:'PBL-AS',size:'XL', colorName:'Ivory',colorHex:'#F5F0E8',stock:0, priceInPaise:870000),
        'S__#E8A0A0' : ProductVariant(sku:'PBL-AS-BLS-S-121',  parentId:'PBL-AS',size:'S',  colorName:'Blush',colorHex:'#E8A0A0',stock:2, priceInPaise:855000),
        'M__#E8A0A0' : ProductVariant(sku:'PBL-AS-BLS-M-122',  parentId:'PBL-AS',size:'M',  colorName:'Blush',colorHex:'#E8A0A0',stock:0, priceInPaise:855000),
        'L__#E8A0A0' : ProductVariant(sku:'PBL-AS-BLS-L-123',  parentId:'PBL-AS',size:'L',  colorName:'Blush',colorHex:'#E8A0A0',stock:5, priceInPaise:855000),
        'XL__#E8A0A0': ProductVariant(sku:'PBL-AS-BLS-XL-124', parentId:'PBL-AS',size:'XL', colorName:'Blush',colorHex:'#E8A0A0',stock:3, priceInPaise:855000),
      },
    ),

    // ── WOMEN ── Ethnic Silk Kurta Set — INDIRA & CO ──────────────────────────
    ParentProduct(
      id: 'VKT-IC', name: 'Ethnic Silk Kurta Set', brand: 'INDIRA & CO',
      category: 'Ethnic', gender: ProductGender.women,
      defaultImageUrl: 'https://images.unsplash.com/photo-1566206091558-7f218b696731?w=600&q=85',
      sizes: ['XS','S','M','L','XL','XXL'], colors: const [
        VariantColor('Saffron','#FF6F00'), VariantColor('Teal','#006064'), VariantColor('Wine','#880E4F'),
      ],
      isNew: true, stock: 5, droppedMinsAgo: 105, viewersNow: 6, orderedToday: 22,
      cityRank: 1, friendVotes: 11,
      variantMap: {
        'XS__#FF6F00' : ProductVariant(sku:'VKT-IC-SAF-XS-401', parentId:'VKT-IC',size:'XS', colorName:'Saffron',colorHex:'#FF6F00',stock:2, priceInPaise:975000),
        'S__#FF6F00'  : ProductVariant(sku:'VKT-IC-SAF-S-402',  parentId:'VKT-IC',size:'S',  colorName:'Saffron',colorHex:'#FF6F00',stock:5, priceInPaise:975000),
        'M__#FF6F00'  : ProductVariant(sku:'VKT-IC-SAF-M-403',  parentId:'VKT-IC',size:'M',  colorName:'Saffron',colorHex:'#FF6F00',stock:8, priceInPaise:975000),
        'L__#FF6F00'  : ProductVariant(sku:'VKT-IC-SAF-L-404',  parentId:'VKT-IC',size:'L',  colorName:'Saffron',colorHex:'#FF6F00',stock:3, priceInPaise:975000),
        'XL__#FF6F00' : ProductVariant(sku:'VKT-IC-SAF-XL-405', parentId:'VKT-IC',size:'XL', colorName:'Saffron',colorHex:'#FF6F00',stock:0, priceInPaise:975000),
        'XXL__#FF6F00': ProductVariant(sku:'VKT-IC-SAF-XXL-406',parentId:'VKT-IC',size:'XXL',colorName:'Saffron',colorHex:'#FF6F00',stock:1, priceInPaise:975000),
        'XS__#006064' : ProductVariant(sku:'VKT-IC-TEL-XS-411', parentId:'VKT-IC',size:'XS', colorName:'Teal',   colorHex:'#006064',stock:4, priceInPaise:975000),
        'S__#006064'  : ProductVariant(sku:'VKT-IC-TEL-S-412',  parentId:'VKT-IC',size:'S',  colorName:'Teal',   colorHex:'#006064',stock:0, priceInPaise:975000),
        'M__#006064'  : ProductVariant(sku:'VKT-IC-TEL-M-413',  parentId:'VKT-IC',size:'M',  colorName:'Teal',   colorHex:'#006064',stock:6, priceInPaise:975000),
        'L__#006064'  : ProductVariant(sku:'VKT-IC-TEL-L-414',  parentId:'VKT-IC',size:'L',  colorName:'Teal',   colorHex:'#006064',stock:2, priceInPaise:975000),
        'XL__#006064' : ProductVariant(sku:'VKT-IC-TEL-XL-415', parentId:'VKT-IC',size:'XL', colorName:'Teal',   colorHex:'#006064',stock:3, priceInPaise:975000),
        'XXL__#006064': ProductVariant(sku:'VKT-IC-TEL-XXL-416',parentId:'VKT-IC',size:'XXL',colorName:'Teal',   colorHex:'#006064',stock:0, priceInPaise:975000),
        'XS__#880E4F' : ProductVariant(sku:'VKT-IC-WIN-XS-421', parentId:'VKT-IC',size:'XS', colorName:'Wine',   colorHex:'#880E4F',stock:1, priceInPaise:1020000),
        'S__#880E4F'  : ProductVariant(sku:'VKT-IC-WIN-S-422',  parentId:'VKT-IC',size:'S',  colorName:'Wine',   colorHex:'#880E4F',stock:3, priceInPaise:1020000),
        'M__#880E4F'  : ProductVariant(sku:'VKT-IC-WIN-M-423',  parentId:'VKT-IC',size:'M',  colorName:'Wine',   colorHex:'#880E4F',stock:0, priceInPaise:1020000),
        'L__#880E4F'  : ProductVariant(sku:'VKT-IC-WIN-L-424',  parentId:'VKT-IC',size:'L',  colorName:'Wine',   colorHex:'#880E4F',stock:5, priceInPaise:1020000),
        'XL__#880E4F' : ProductVariant(sku:'VKT-IC-WIN-XL-425', parentId:'VKT-IC',size:'XL', colorName:'Wine',   colorHex:'#880E4F',stock:2, priceInPaise:1020000),
        'XXL__#880E4F': ProductVariant(sku:'VKT-IC-WIN-XXL-426',parentId:'VKT-IC',size:'XXL',colorName:'Wine',   colorHex:'#880E4F',stock:4, priceInPaise:1020000),
      },
    ),

    // ── WOMEN ── Printed Coord Two-Piece — CASA MODAS ─────────────────────────
    ParentProduct(
      id: 'COS-CM', name: 'Printed Coord Two-Piece', brand: 'CASA MODAS',
      category: 'Co-ords', gender: ProductGender.women,
      defaultImageUrl: 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&q=85',
      sizes: ['XS','S','M','L','XL'], colors: const [
        VariantColor('Beige Print','#C8B89A'), VariantColor('Coral','#E8735A'), VariantColor('Sage','#8FAF88'),
      ],
      stock: 2, saleEndsAt: '02:14:33', deliveryCutoff: '6:30 PM', deliveryMinsLeft: 8, viewersNow: 9,
      cityRank: 3, orderedToday: 38,
      variantMap: {
        'XS__#C8B89A': ProductVariant(sku:'COS-CM-BEG-XS-501',parentId:'COS-CM',size:'XS',colorName:'Beige Print',colorHex:'#C8B89A',stock:4, priceInPaise:750000),
        'S__#C8B89A' : ProductVariant(sku:'COS-CM-BEG-S-502', parentId:'COS-CM',size:'S', colorName:'Beige Print',colorHex:'#C8B89A',stock:2, priceInPaise:750000),
        'M__#C8B89A' : ProductVariant(sku:'COS-CM-BEG-M-503', parentId:'COS-CM',size:'M', colorName:'Beige Print',colorHex:'#C8B89A',stock:0, priceInPaise:750000),
        'L__#C8B89A' : ProductVariant(sku:'COS-CM-BEG-L-504', parentId:'COS-CM',size:'L', colorName:'Beige Print',colorHex:'#C8B89A',stock:1, priceInPaise:750000),
        'XL__#C8B89A': ProductVariant(sku:'COS-CM-BEG-XL-505',parentId:'COS-CM',size:'XL',colorName:'Beige Print',colorHex:'#C8B89A',stock:3, priceInPaise:750000),
        'XS__#E8735A': ProductVariant(sku:'COS-CM-CRL-XS-511',parentId:'COS-CM',size:'XS',colorName:'Coral',colorHex:'#E8735A',stock:6, priceInPaise:750000),
        'S__#E8735A' : ProductVariant(sku:'COS-CM-CRL-S-512', parentId:'COS-CM',size:'S', colorName:'Coral',colorHex:'#E8735A',stock:0, priceInPaise:750000),
        'M__#E8735A' : ProductVariant(sku:'COS-CM-CRL-M-513', parentId:'COS-CM',size:'M', colorName:'Coral',colorHex:'#E8735A',stock:5, priceInPaise:750000),
        'L__#E8735A' : ProductVariant(sku:'COS-CM-CRL-L-514', parentId:'COS-CM',size:'L', colorName:'Coral',colorHex:'#E8735A',stock:3, priceInPaise:750000),
        'XL__#E8735A': ProductVariant(sku:'COS-CM-CRL-XL-515',parentId:'COS-CM',size:'XL',colorName:'Coral',colorHex:'#E8735A',stock:1, priceInPaise:750000),
        'XS__#8FAF88': ProductVariant(sku:'COS-CM-SAG-XS-521',parentId:'COS-CM',size:'XS',colorName:'Sage',colorHex:'#8FAF88',stock:2, priceInPaise:790000),
        'S__#8FAF88' : ProductVariant(sku:'COS-CM-SAG-S-522', parentId:'COS-CM',size:'S', colorName:'Sage',colorHex:'#8FAF88',stock:4, priceInPaise:790000),
        'M__#8FAF88' : ProductVariant(sku:'COS-CM-SAG-M-523', parentId:'COS-CM',size:'M', colorName:'Sage',colorHex:'#8FAF88',stock:0, priceInPaise:790000),
        'L__#8FAF88' : ProductVariant(sku:'COS-CM-SAG-L-524', parentId:'COS-CM',size:'L', colorName:'Sage',colorHex:'#8FAF88',stock:7, priceInPaise:790000),
        'XL__#8FAF88': ProductVariant(sku:'COS-CM-SAG-XL-525',parentId:'COS-CM',size:'XL',colorName:'Sage',colorHex:'#8FAF88',stock:3, priceInPaise:790000),
      },
    ),

    // ── WOMEN ── Street Oversized Jacket — DECO NOIR ──────────────────────────
    ParentProduct(
      id: 'STJ-DN', name: 'Street Oversized Jacket', brand: 'DECO NOIR',
      category: 'Outerwear', gender: ProductGender.women,
      defaultImageUrl: 'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=600&q=85',
      originalPriceFormatted: '₹14,200',
      sizes: ['S','M','L','XL','XXL'], colors: const [
        VariantColor('Onyx','#1A1A1A'), VariantColor('Forest','#2E4A2E'), VariantColor('Stone','#9E9E9E'),
      ],
      isNew: true, stock: 3, droppedMinsAgo: 112, viewersNow: 14, orderedToday: 19, saleEndsAt: '00:58:44',
      cityRank: 4, friendVotes: 9,
      variantMap: {
        'S__#1A1A1A'  : ProductVariant(sku:'STJ-DN-ONX-S-601',  parentId:'STJ-DN',size:'S',  colorName:'Onyx',  colorHex:'#1A1A1A',stock:3, priceInPaise:999900),
        'M__#1A1A1A'  : ProductVariant(sku:'STJ-DN-ONX-M-602',  parentId:'STJ-DN',size:'M',  colorName:'Onyx',  colorHex:'#1A1A1A',stock:0, priceInPaise:999900),
        'L__#1A1A1A'  : ProductVariant(sku:'STJ-DN-ONX-L-603',  parentId:'STJ-DN',size:'L',  colorName:'Onyx',  colorHex:'#1A1A1A',stock:5, priceInPaise:999900),
        'XL__#1A1A1A' : ProductVariant(sku:'STJ-DN-ONX-XL-604', parentId:'STJ-DN',size:'XL', colorName:'Onyx',  colorHex:'#1A1A1A',stock:2, priceInPaise:999900),
        'XXL__#1A1A1A': ProductVariant(sku:'STJ-DN-ONX-XXL-605',parentId:'STJ-DN',size:'XXL',colorName:'Onyx',  colorHex:'#1A1A1A',stock:1, priceInPaise:999900),
        'S__#2E4A2E'  : ProductVariant(sku:'STJ-DN-FOR-S-611',  parentId:'STJ-DN',size:'S',  colorName:'Forest',colorHex:'#2E4A2E',stock:4, priceInPaise:999900),
        'M__#2E4A2E'  : ProductVariant(sku:'STJ-DN-FOR-M-612',  parentId:'STJ-DN',size:'M',  colorName:'Forest',colorHex:'#2E4A2E',stock:6, priceInPaise:999900),
        'L__#2E4A2E'  : ProductVariant(sku:'STJ-DN-FOR-L-613',  parentId:'STJ-DN',size:'L',  colorName:'Forest',colorHex:'#2E4A2E',stock:0, priceInPaise:999900),
        'XL__#2E4A2E' : ProductVariant(sku:'STJ-DN-FOR-XL-614', parentId:'STJ-DN',size:'XL', colorName:'Forest',colorHex:'#2E4A2E',stock:3, priceInPaise:999900),
        'XXL__#2E4A2E': ProductVariant(sku:'STJ-DN-FOR-XXL-615',parentId:'STJ-DN',size:'XXL',colorName:'Forest',colorHex:'#2E4A2E',stock:2, priceInPaise:999900),
        'S__#9E9E9E'  : ProductVariant(sku:'STJ-DN-STN-S-621',  parentId:'STJ-DN',size:'S',  colorName:'Stone', colorHex:'#9E9E9E',stock:2, priceInPaise:979900),
        'M__#9E9E9E'  : ProductVariant(sku:'STJ-DN-STN-M-622',  parentId:'STJ-DN',size:'M',  colorName:'Stone', colorHex:'#9E9E9E',stock:4, priceInPaise:979900),
        'L__#9E9E9E'  : ProductVariant(sku:'STJ-DN-STN-L-623',  parentId:'STJ-DN',size:'L',  colorName:'Stone', colorHex:'#9E9E9E',stock:1, priceInPaise:979900),
        'XL__#9E9E9E' : ProductVariant(sku:'STJ-DN-STN-XL-624', parentId:'STJ-DN',size:'XL', colorName:'Stone', colorHex:'#9E9E9E',stock:0, priceInPaise:979900),
        'XXL__#9E9E9E': ProductVariant(sku:'STJ-DN-STN-XXL-625',parentId:'STJ-DN',size:'XXL',colorName:'Stone', colorHex:'#9E9E9E',stock:3, priceInPaise:979900),
      },
    ),

    // ── WOMEN ── Distressed Denim Jacket — RAW & REFINED ─────────────────────
    ParentProduct(
      id: 'DJK-RR', name: 'Distressed Denim Jacket', brand: 'RAW & REFINED',
      category: 'Jackets', gender: ProductGender.women,
      defaultImageUrl: 'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?w=600&q=85',
      sizes: ['XS','S','M','L','XL'], colors: const [
        VariantColor('Blue Wash','#4A90D9'), VariantColor('Black','#1A1A1A'), VariantColor('White','#F5F5F5'),
      ],
      stock: 1, saleEndsAt: '00:44:10', deliveryCutoff: '7:00 PM', deliveryMinsLeft: 38, viewersNow: 21,
      orderedToday: 29, cityRank: 4, friendVotes: 7,
      variantMap: {
        'XS__#4A90D9': ProductVariant(sku:'DJK-RR-BLU-XS-301',parentId:'DJK-RR',size:'XS',colorName:'Blue Wash',colorHex:'#4A90D9',stock:3, priceInPaise:599900),
        'S__#4A90D9' : ProductVariant(sku:'DJK-RR-BLU-S-302', parentId:'DJK-RR',size:'S', colorName:'Blue Wash',colorHex:'#4A90D9',stock:1, priceInPaise:599900),
        'M__#4A90D9' : ProductVariant(sku:'DJK-RR-BLU-M-303', parentId:'DJK-RR',size:'M', colorName:'Blue Wash',colorHex:'#4A90D9',stock:0, priceInPaise:599900),
        'L__#4A90D9' : ProductVariant(sku:'DJK-RR-BLU-L-304', parentId:'DJK-RR',size:'L', colorName:'Blue Wash',colorHex:'#4A90D9',stock:4, priceInPaise:599900),
        'XL__#4A90D9': ProductVariant(sku:'DJK-RR-BLU-XL-305',parentId:'DJK-RR',size:'XL',colorName:'Blue Wash',colorHex:'#4A90D9',stock:2, priceInPaise:599900),
        'XS__#1A1A1A': ProductVariant(sku:'DJK-RR-BLK-XS-311',parentId:'DJK-RR',size:'XS',colorName:'Black',colorHex:'#1A1A1A',stock:5, priceInPaise:629900),
        'S__#1A1A1A' : ProductVariant(sku:'DJK-RR-BLK-S-312', parentId:'DJK-RR',size:'S', colorName:'Black',colorHex:'#1A1A1A',stock:2, priceInPaise:629900),
        'M__#1A1A1A' : ProductVariant(sku:'DJK-RR-BLK-M-313', parentId:'DJK-RR',size:'M', colorName:'Black',colorHex:'#1A1A1A',stock:7, priceInPaise:629900),
        'L__#1A1A1A' : ProductVariant(sku:'DJK-RR-BLK-L-314', parentId:'DJK-RR',size:'L', colorName:'Black',colorHex:'#1A1A1A',stock:0, priceInPaise:629900),
        'XL__#1A1A1A': ProductVariant(sku:'DJK-RR-BLK-XL-315',parentId:'DJK-RR',size:'XL',colorName:'Black',colorHex:'#1A1A1A',stock:3, priceInPaise:629900),
        'XS__#F5F5F5': ProductVariant(sku:'DJK-RR-WHT-XS-321',parentId:'DJK-RR',size:'XS',colorName:'White',colorHex:'#F5F5F5',stock:0, priceInPaise:579900),
        'S__#F5F5F5' : ProductVariant(sku:'DJK-RR-WHT-S-322', parentId:'DJK-RR',size:'S', colorName:'White',colorHex:'#F5F5F5',stock:4, priceInPaise:579900),
        'M__#F5F5F5' : ProductVariant(sku:'DJK-RR-WHT-M-323', parentId:'DJK-RR',size:'M', colorName:'White',colorHex:'#F5F5F5',stock:6, priceInPaise:579900),
        'L__#F5F5F5' : ProductVariant(sku:'DJK-RR-WHT-L-324', parentId:'DJK-RR',size:'L', colorName:'White',colorHex:'#F5F5F5',stock:1, priceInPaise:579900),
        'XL__#F5F5F5': ProductVariant(sku:'DJK-RR-WHT-XL-325',parentId:'DJK-RR',size:'XL',colorName:'White',colorHex:'#F5F5F5',stock:2, priceInPaise:579900),
      },
    ),

    // ── WOMEN ── Satin Slip Midi Dress — MAISON KAIRA ─────────────────────────
    ParentProduct(
      id: 'MDS-MK', name: 'Satin Slip Midi Dress', brand: 'MAISON KAIRA',
      category: 'Dresses', gender: ProductGender.women,
      defaultImageUrl: 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=600&q=85',
      sizes: ['XS','S','M','L'], colors: const [
        VariantColor('Champagne','#F0DEB4'), VariantColor('Midnight','#1A1A2E'), VariantColor('Rose','#E8A0A0'),
      ],
      isNew: true, stock: 9, droppedMinsAgo: 47, viewersNow: 12, orderedToday: 47,
      friendVotes: 24,
      variantMap: {
        'XS__#F0DEB4': ProductVariant(sku:'MDS-MK-CHP-XS-701',parentId:'MDS-MK',size:'XS',colorName:'Champagne',colorHex:'#F0DEB4',stock:3, priceInPaise:1850000),
        'S__#F0DEB4' : ProductVariant(sku:'MDS-MK-CHP-S-702', parentId:'MDS-MK',size:'S', colorName:'Champagne',colorHex:'#F0DEB4',stock:2, priceInPaise:1850000),
        'M__#F0DEB4' : ProductVariant(sku:'MDS-MK-CHP-M-703', parentId:'MDS-MK',size:'M', colorName:'Champagne',colorHex:'#F0DEB4',stock:4, priceInPaise:1850000),
        'L__#F0DEB4' : ProductVariant(sku:'MDS-MK-CHP-L-704', parentId:'MDS-MK',size:'L', colorName:'Champagne',colorHex:'#F0DEB4',stock:0, priceInPaise:1850000),
        'XS__#1A1A2E': ProductVariant(sku:'MDS-MK-MNT-XS-711',parentId:'MDS-MK',size:'XS',colorName:'Midnight',colorHex:'#1A1A2E',stock:1, priceInPaise:1900000),
        'S__#1A1A2E' : ProductVariant(sku:'MDS-MK-MNT-S-712', parentId:'MDS-MK',size:'S', colorName:'Midnight',colorHex:'#1A1A2E',stock:5, priceInPaise:1900000),
        'M__#1A1A2E' : ProductVariant(sku:'MDS-MK-MNT-M-713', parentId:'MDS-MK',size:'M', colorName:'Midnight',colorHex:'#1A1A2E',stock:3, priceInPaise:1900000),
        'L__#1A1A2E' : ProductVariant(sku:'MDS-MK-MNT-L-714', parentId:'MDS-MK',size:'L', colorName:'Midnight',colorHex:'#1A1A2E',stock:0, priceInPaise:1900000),
        'XS__#E8A0A0': ProductVariant(sku:'MDS-MK-RSE-XS-721',parentId:'MDS-MK',size:'XS',colorName:'Rose',colorHex:'#E8A0A0',stock:6, priceInPaise:1850000),
        'S__#E8A0A0' : ProductVariant(sku:'MDS-MK-RSE-S-722', parentId:'MDS-MK',size:'S', colorName:'Rose',colorHex:'#E8A0A0',stock:4, priceInPaise:1850000),
        'M__#E8A0A0' : ProductVariant(sku:'MDS-MK-RSE-M-723', parentId:'MDS-MK',size:'M', colorName:'Rose',colorHex:'#E8A0A0',stock:2, priceInPaise:1850000),
        'L__#E8A0A0' : ProductVariant(sku:'MDS-MK-RSE-L-724', parentId:'MDS-MK',size:'L', colorName:'Rose',colorHex:'#E8A0A0',stock:1, priceInPaise:1850000),
      },
    ),

    // ── MEN ── Oversized Premium Hoodie — NORDVIK CO ──────────────────────────
    ParentProduct(
      id: 'OHD-NK', name: 'Oversized Premium Hoodie', brand: 'NORDVIK CO',
      category: 'Hoodies', gender: ProductGender.men,
      defaultImageUrl: 'https://images.unsplash.com/photo-1556821840-3a63f15732ce?w=600&q=85',
      sizes: ['S','M','L','XL','XXL'], colors: const [
        VariantColor('Carbon','#2D2D2D'), VariantColor('Ecru','#EDE0C8'), VariantColor('Slate Blue','#5C7A9A'),
      ],
      isNew: true, stock: 6, droppedMinsAgo: 65, viewersNow: 19, orderedToday: 54,
      cityRank: 1, friendVotes: 31,
      variantMap: {
        'S__#2D2D2D'  : ProductVariant(sku:'OHD-NK-CAR-S-801',  parentId:'OHD-NK',size:'S',  colorName:'Carbon',    colorHex:'#2D2D2D',stock:4, priceInPaise:389900),
        'M__#2D2D2D'  : ProductVariant(sku:'OHD-NK-CAR-M-802',  parentId:'OHD-NK',size:'M',  colorName:'Carbon',    colorHex:'#2D2D2D',stock:7, priceInPaise:389900),
        'L__#2D2D2D'  : ProductVariant(sku:'OHD-NK-CAR-L-803',  parentId:'OHD-NK',size:'L',  colorName:'Carbon',    colorHex:'#2D2D2D',stock:2, priceInPaise:389900),
        'XL__#2D2D2D' : ProductVariant(sku:'OHD-NK-CAR-XL-804', parentId:'OHD-NK',size:'XL', colorName:'Carbon',    colorHex:'#2D2D2D',stock:5, priceInPaise:389900),
        'XXL__#2D2D2D': ProductVariant(sku:'OHD-NK-CAR-XXL-805',parentId:'OHD-NK',size:'XXL',colorName:'Carbon',    colorHex:'#2D2D2D',stock:1, priceInPaise:389900),
        'S__#EDE0C8'  : ProductVariant(sku:'OHD-NK-ECR-S-811',  parentId:'OHD-NK',size:'S',  colorName:'Ecru',      colorHex:'#EDE0C8',stock:3, priceInPaise:389900),
        'M__#EDE0C8'  : ProductVariant(sku:'OHD-NK-ECR-M-812',  parentId:'OHD-NK',size:'M',  colorName:'Ecru',      colorHex:'#EDE0C8',stock:0, priceInPaise:389900),
        'L__#EDE0C8'  : ProductVariant(sku:'OHD-NK-ECR-L-813',  parentId:'OHD-NK',size:'L',  colorName:'Ecru',      colorHex:'#EDE0C8',stock:6, priceInPaise:389900),
        'XL__#EDE0C8' : ProductVariant(sku:'OHD-NK-ECR-XL-814', parentId:'OHD-NK',size:'XL', colorName:'Ecru',      colorHex:'#EDE0C8',stock:4, priceInPaise:389900),
        'XXL__#EDE0C8': ProductVariant(sku:'OHD-NK-ECR-XXL-815',parentId:'OHD-NK',size:'XXL',colorName:'Ecru',      colorHex:'#EDE0C8',stock:2, priceInPaise:389900),
        'S__#5C7A9A'  : ProductVariant(sku:'OHD-NK-SLT-S-821',  parentId:'OHD-NK',size:'S',  colorName:'Slate Blue',colorHex:'#5C7A9A',stock:5, priceInPaise:409900),
        'M__#5C7A9A'  : ProductVariant(sku:'OHD-NK-SLT-M-822',  parentId:'OHD-NK',size:'M',  colorName:'Slate Blue',colorHex:'#5C7A9A',stock:3, priceInPaise:409900),
        'L__#5C7A9A'  : ProductVariant(sku:'OHD-NK-SLT-L-823',  parentId:'OHD-NK',size:'L',  colorName:'Slate Blue',colorHex:'#5C7A9A',stock:0, priceInPaise:409900),
        'XL__#5C7A9A' : ProductVariant(sku:'OHD-NK-SLT-XL-824', parentId:'OHD-NK',size:'XL', colorName:'Slate Blue',colorHex:'#5C7A9A',stock:7, priceInPaise:409900),
        'XXL__#5C7A9A': ProductVariant(sku:'OHD-NK-SLT-XXL-825',parentId:'OHD-NK',size:'XXL',colorName:'Slate Blue',colorHex:'#5C7A9A',stock:2, priceInPaise:409900),
      },
    ),

    // ── MEN ── Satin Bomber Jacket — DECO NOIR ────────────────────────────────
    ParentProduct(
      id: 'BMB-DN', name: 'Satin Bomber Jacket', brand: 'DECO NOIR',
      category: 'Jackets', gender: ProductGender.men,
      defaultImageUrl: 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=600&q=85',
      originalPriceFormatted: '₹16,500',
      sizes: ['S','M','L','XL'], colors: const [
        VariantColor('Jet Black','#0D0D0D'), VariantColor('Olive','#5A6B2E'), VariantColor('Rust','#B5451B'),
      ],
      isNew: true, stock: 3, droppedMinsAgo: 130, viewersNow: 22, orderedToday: 38, saleEndsAt: '02:11:05',
      cityRank: 2, friendVotes: 26,
      variantMap: {
        'S__#0D0D0D' : ProductVariant(sku:'BMB-DN-JBK-S-901', parentId:'BMB-DN',size:'S', colorName:'Jet Black',colorHex:'#0D0D0D',stock:2, priceInPaise:1199900),
        'M__#0D0D0D' : ProductVariant(sku:'BMB-DN-JBK-M-902', parentId:'BMB-DN',size:'M', colorName:'Jet Black',colorHex:'#0D0D0D',stock:5, priceInPaise:1199900),
        'L__#0D0D0D' : ProductVariant(sku:'BMB-DN-JBK-L-903', parentId:'BMB-DN',size:'L', colorName:'Jet Black',colorHex:'#0D0D0D',stock:0, priceInPaise:1199900),
        'XL__#0D0D0D': ProductVariant(sku:'BMB-DN-JBK-XL-904',parentId:'BMB-DN',size:'XL',colorName:'Jet Black',colorHex:'#0D0D0D',stock:3, priceInPaise:1199900),
        'S__#5A6B2E' : ProductVariant(sku:'BMB-DN-OLV-S-911', parentId:'BMB-DN',size:'S', colorName:'Olive',   colorHex:'#5A6B2E',stock:4, priceInPaise:1199900),
        'M__#5A6B2E' : ProductVariant(sku:'BMB-DN-OLV-M-912', parentId:'BMB-DN',size:'M', colorName:'Olive',   colorHex:'#5A6B2E',stock:1, priceInPaise:1199900),
        'L__#5A6B2E' : ProductVariant(sku:'BMB-DN-OLV-L-913', parentId:'BMB-DN',size:'L', colorName:'Olive',   colorHex:'#5A6B2E',stock:6, priceInPaise:1199900),
        'XL__#5A6B2E': ProductVariant(sku:'BMB-DN-OLV-XL-914',parentId:'BMB-DN',size:'XL',colorName:'Olive',   colorHex:'#5A6B2E',stock:2, priceInPaise:1199900),
        'S__#B5451B' : ProductVariant(sku:'BMB-DN-RST-S-921', parentId:'BMB-DN',size:'S', colorName:'Rust',    colorHex:'#B5451B',stock:3, priceInPaise:1149900),
        'M__#B5451B' : ProductVariant(sku:'BMB-DN-RST-M-922', parentId:'BMB-DN',size:'M', colorName:'Rust',    colorHex:'#B5451B',stock:0, priceInPaise:1149900),
        'L__#B5451B' : ProductVariant(sku:'BMB-DN-RST-L-923', parentId:'BMB-DN',size:'L', colorName:'Rust',    colorHex:'#B5451B',stock:5, priceInPaise:1149900),
        'XL__#B5451B': ProductVariant(sku:'BMB-DN-RST-XL-924',parentId:'BMB-DN',size:'XL',colorName:'Rust',    colorHex:'#B5451B',stock:1, priceInPaise:1149900),
      },
    ),

    // ── MEN ── Tapered Cargo Jogger — NORDVIK CO ──────────────────────────────
    ParentProduct(
      id: 'CGJ-NK', name: 'Tapered Cargo Jogger', brand: 'NORDVIK CO',
      category: 'Bottoms', gender: ProductGender.men,
      defaultImageUrl: 'https://images.unsplash.com/photo-1542272604-787c3835535d?w=600&q=85',
      sizes: ['S','M','L','XL','XXL'], colors: const [
        VariantColor('Khaki','#B5A07A'), VariantColor('Charcoal','#3D3D3D'), VariantColor('Olive Drab','#6B6B2E'),
      ],
      stock: 2, saleEndsAt: '01:22:44', deliveryCutoff: '7:30 PM', deliveryMinsLeft: 6, viewersNow: 11,
      orderedToday: 33, cityRank: 3, friendVotes: 14,
      variantMap: {
        'S__#B5A07A'  : ProductVariant(sku:'CGJ-NK-KHK-S-A01',  parentId:'CGJ-NK',size:'S',  colorName:'Khaki',     colorHex:'#B5A07A',stock:3, priceInPaise:449900),
        'M__#B5A07A'  : ProductVariant(sku:'CGJ-NK-KHK-M-A02',  parentId:'CGJ-NK',size:'M',  colorName:'Khaki',     colorHex:'#B5A07A',stock:1, priceInPaise:449900),
        'L__#B5A07A'  : ProductVariant(sku:'CGJ-NK-KHK-L-A03',  parentId:'CGJ-NK',size:'L',  colorName:'Khaki',     colorHex:'#B5A07A',stock:0, priceInPaise:449900),
        'XL__#B5A07A' : ProductVariant(sku:'CGJ-NK-KHK-XL-A04', parentId:'CGJ-NK',size:'XL', colorName:'Khaki',     colorHex:'#B5A07A',stock:4, priceInPaise:449900),
        'XXL__#B5A07A': ProductVariant(sku:'CGJ-NK-KHK-XXL-A05',parentId:'CGJ-NK',size:'XXL',colorName:'Khaki',     colorHex:'#B5A07A',stock:2, priceInPaise:449900),
        'S__#3D3D3D'  : ProductVariant(sku:'CGJ-NK-CHR-S-A11',  parentId:'CGJ-NK',size:'S',  colorName:'Charcoal',  colorHex:'#3D3D3D',stock:5, priceInPaise:449900),
        'M__#3D3D3D'  : ProductVariant(sku:'CGJ-NK-CHR-M-A12',  parentId:'CGJ-NK',size:'M',  colorName:'Charcoal',  colorHex:'#3D3D3D',stock:0, priceInPaise:449900),
        'L__#3D3D3D'  : ProductVariant(sku:'CGJ-NK-CHR-L-A13',  parentId:'CGJ-NK',size:'L',  colorName:'Charcoal',  colorHex:'#3D3D3D',stock:7, priceInPaise:449900),
        'XL__#3D3D3D' : ProductVariant(sku:'CGJ-NK-CHR-XL-A14', parentId:'CGJ-NK',size:'XL', colorName:'Charcoal',  colorHex:'#3D3D3D',stock:3, priceInPaise:449900),
        'XXL__#3D3D3D': ProductVariant(sku:'CGJ-NK-CHR-XXL-A15',parentId:'CGJ-NK',size:'XXL',colorName:'Charcoal',  colorHex:'#3D3D3D',stock:1, priceInPaise:449900),
        'S__#6B6B2E'  : ProductVariant(sku:'CGJ-NK-OLD-S-A21',  parentId:'CGJ-NK',size:'S',  colorName:'Olive Drab',colorHex:'#6B6B2E',stock:2, priceInPaise:469900),
        'M__#6B6B2E'  : ProductVariant(sku:'CGJ-NK-OLD-M-A22',  parentId:'CGJ-NK',size:'M',  colorName:'Olive Drab',colorHex:'#6B6B2E',stock:4, priceInPaise:469900),
        'L__#6B6B2E'  : ProductVariant(sku:'CGJ-NK-OLD-L-A23',  parentId:'CGJ-NK',size:'L',  colorName:'Olive Drab',colorHex:'#6B6B2E',stock:0, priceInPaise:469900),
        'XL__#6B6B2E' : ProductVariant(sku:'CGJ-NK-OLD-XL-A24', parentId:'CGJ-NK',size:'XL', colorName:'Olive Drab',colorHex:'#6B6B2E',stock:3, priceInPaise:469900),
        'XXL__#6B6B2E': ProductVariant(sku:'CGJ-NK-OLD-XXL-A25',parentId:'CGJ-NK',size:'XXL',colorName:'Olive Drab',colorHex:'#6B6B2E',stock:2, priceInPaise:469900),
      },
    ),

    // ── MEN ── Slim Stretch Denim — RAW & REFINED ─────────────────────────────
    ParentProduct(
      id: 'SLJ-RR', name: 'Slim Stretch Denim', brand: 'RAW & REFINED',
      category: 'Denim', gender: ProductGender.men,
      defaultImageUrl: 'https://images.unsplash.com/photo-1542272604-787c3835535d?w=600&q=85',
      sizes: ['28','30','32','34','36'], colors: const [
        VariantColor('Raw Indigo','#2B4F8A'), VariantColor('Black','#1A1A1A'), VariantColor('Grey Wash','#888888'),
      ],
      stock: 3, viewersNow: 7, orderedToday: 21, cityRank: 5, friendVotes: 9,
      variantMap: {
        '28__#2B4F8A': ProductVariant(sku:'SLJ-RR-IND-28-B01',parentId:'SLJ-RR',size:'28',colorName:'Raw Indigo',colorHex:'#2B4F8A',stock:2, priceInPaise:499900),
        '30__#2B4F8A': ProductVariant(sku:'SLJ-RR-IND-30-B02',parentId:'SLJ-RR',size:'30',colorName:'Raw Indigo',colorHex:'#2B4F8A',stock:4, priceInPaise:499900),
        '32__#2B4F8A': ProductVariant(sku:'SLJ-RR-IND-32-B03',parentId:'SLJ-RR',size:'32',colorName:'Raw Indigo',colorHex:'#2B4F8A',stock:3, priceInPaise:499900),
        '34__#2B4F8A': ProductVariant(sku:'SLJ-RR-IND-34-B04',parentId:'SLJ-RR',size:'34',colorName:'Raw Indigo',colorHex:'#2B4F8A',stock:0, priceInPaise:499900),
        '36__#2B4F8A': ProductVariant(sku:'SLJ-RR-IND-36-B05',parentId:'SLJ-RR',size:'36',colorName:'Raw Indigo',colorHex:'#2B4F8A',stock:1, priceInPaise:499900),
        '28__#1A1A1A': ProductVariant(sku:'SLJ-RR-BLK-28-B11',parentId:'SLJ-RR',size:'28',colorName:'Black',    colorHex:'#1A1A1A',stock:5, priceInPaise:529900),
        '30__#1A1A1A': ProductVariant(sku:'SLJ-RR-BLK-30-B12',parentId:'SLJ-RR',size:'30',colorName:'Black',    colorHex:'#1A1A1A',stock:2, priceInPaise:529900),
        '32__#1A1A1A': ProductVariant(sku:'SLJ-RR-BLK-32-B13',parentId:'SLJ-RR',size:'32',colorName:'Black',    colorHex:'#1A1A1A',stock:6, priceInPaise:529900),
        '34__#1A1A1A': ProductVariant(sku:'SLJ-RR-BLK-34-B14',parentId:'SLJ-RR',size:'34',colorName:'Black',    colorHex:'#1A1A1A',stock:1, priceInPaise:529900),
        '36__#1A1A1A': ProductVariant(sku:'SLJ-RR-BLK-36-B15',parentId:'SLJ-RR',size:'36',colorName:'Black',    colorHex:'#1A1A1A',stock:0, priceInPaise:529900),
        '28__#888888': ProductVariant(sku:'SLJ-RR-GRY-28-B21',parentId:'SLJ-RR',size:'28',colorName:'Grey Wash',colorHex:'#888888',stock:3, priceInPaise:479900),
        '30__#888888': ProductVariant(sku:'SLJ-RR-GRY-30-B22',parentId:'SLJ-RR',size:'30',colorName:'Grey Wash',colorHex:'#888888',stock:0, priceInPaise:479900),
        '32__#888888': ProductVariant(sku:'SLJ-RR-GRY-32-B23',parentId:'SLJ-RR',size:'32',colorName:'Grey Wash',colorHex:'#888888',stock:4, priceInPaise:479900),
        '34__#888888': ProductVariant(sku:'SLJ-RR-GRY-34-B24',parentId:'SLJ-RR',size:'34',colorName:'Grey Wash',colorHex:'#888888',stock:2, priceInPaise:479900),
        '36__#888888': ProductVariant(sku:'SLJ-RR-GRY-36-B25',parentId:'SLJ-RR',size:'36',colorName:'Grey Wash',colorHex:'#888888',stock:1, priceInPaise:479900),
      },
    ),

    // ── MEN ── Men's Cotton Kurta — INDIRA & CO ───────────────────────────────
    ParentProduct(
      id: 'KRT-IC', name: 'Premium Cotton Kurta', brand: 'INDIRA & CO',
      category: 'Ethnic', gender: ProductGender.men,
      defaultImageUrl: 'https://images.unsplash.com/photo-1603252109303-2751441dd157?w=600&q=85',
      sizes: ['S','M','L','XL','XXL'], colors: const [
        VariantColor('Ivory','#EDE8DC'), VariantColor('Slate','#4A5568'), VariantColor('Crimson','#9B1C1C'),
      ],
      stock: 7, viewersNow: 15, orderedToday: 44, cityRank: 2, friendVotes: 19,
      variantMap: {
        'S__#EDE8DC'  : ProductVariant(sku:'KRT-IC-IVR-S-C01',  parentId:'KRT-IC',size:'S',  colorName:'Ivory',  colorHex:'#EDE8DC',stock:4, priceInPaise:449900),
        'M__#EDE8DC'  : ProductVariant(sku:'KRT-IC-IVR-M-C02',  parentId:'KRT-IC',size:'M',  colorName:'Ivory',  colorHex:'#EDE8DC',stock:6, priceInPaise:449900),
        'L__#EDE8DC'  : ProductVariant(sku:'KRT-IC-IVR-L-C03',  parentId:'KRT-IC',size:'L',  colorName:'Ivory',  colorHex:'#EDE8DC',stock:2, priceInPaise:449900),
        'XL__#EDE8DC' : ProductVariant(sku:'KRT-IC-IVR-XL-C04', parentId:'KRT-IC',size:'XL', colorName:'Ivory',  colorHex:'#EDE8DC',stock:5, priceInPaise:449900),
        'XXL__#EDE8DC': ProductVariant(sku:'KRT-IC-IVR-XXL-C05',parentId:'KRT-IC',size:'XXL',colorName:'Ivory',  colorHex:'#EDE8DC',stock:0, priceInPaise:449900),
        'S__#4A5568'  : ProductVariant(sku:'KRT-IC-SLT-S-C11',  parentId:'KRT-IC',size:'S',  colorName:'Slate',  colorHex:'#4A5568',stock:3, priceInPaise:469900),
        'M__#4A5568'  : ProductVariant(sku:'KRT-IC-SLT-M-C12',  parentId:'KRT-IC',size:'M',  colorName:'Slate',  colorHex:'#4A5568',stock:0, priceInPaise:469900),
        'L__#4A5568'  : ProductVariant(sku:'KRT-IC-SLT-L-C13',  parentId:'KRT-IC',size:'L',  colorName:'Slate',  colorHex:'#4A5568',stock:7, priceInPaise:469900),
        'XL__#4A5568' : ProductVariant(sku:'KRT-IC-SLT-XL-C14', parentId:'KRT-IC',size:'XL', colorName:'Slate',  colorHex:'#4A5568',stock:4, priceInPaise:469900),
        'XXL__#4A5568': ProductVariant(sku:'KRT-IC-SLT-XXL-C15',parentId:'KRT-IC',size:'XXL',colorName:'Slate',  colorHex:'#4A5568',stock:1, priceInPaise:469900),
        'S__#9B1C1C'  : ProductVariant(sku:'KRT-IC-CRM-S-C21',  parentId:'KRT-IC',size:'S',  colorName:'Crimson',colorHex:'#9B1C1C',stock:2, priceInPaise:489900),
        'M__#9B1C1C'  : ProductVariant(sku:'KRT-IC-CRM-M-C22',  parentId:'KRT-IC',size:'M',  colorName:'Crimson',colorHex:'#9B1C1C',stock:5, priceInPaise:489900),
        'L__#9B1C1C'  : ProductVariant(sku:'KRT-IC-CRM-L-C23',  parentId:'KRT-IC',size:'L',  colorName:'Crimson',colorHex:'#9B1C1C',stock:0, priceInPaise:489900),
        'XL__#9B1C1C' : ProductVariant(sku:'KRT-IC-CRM-XL-C24', parentId:'KRT-IC',size:'XL', colorName:'Crimson',colorHex:'#9B1C1C',stock:3, priceInPaise:489900),
        'XXL__#9B1C1C': ProductVariant(sku:'KRT-IC-CRM-XXL-C25',parentId:'KRT-IC',size:'XXL',colorName:'Crimson',colorHex:'#9B1C1C',stock:6, priceInPaise:489900),
      },
    ),

    // ── UNISEX ── Logo Snapback Cap — NORDVIK CO ──────────────────────────────
    ParentProduct(
      id: 'CAP-NK', name: 'Logo Snapback Cap', brand: 'NORDVIK CO',
      category: 'Accessories', gender: ProductGender.unisex,
      defaultImageUrl: 'https://images.unsplash.com/photo-1588850561407-ed78c282e89b?w=600&q=85',
      sizes: ['Free Size'], colors: const [
        VariantColor('Black','#1A1A1A'), VariantColor('Beige','#D4C5A9'), VariantColor('Navy','#1A2E4A'),
      ],
      isNew: true, stock: 12, droppedMinsAgo: 30, viewersNow: 25, orderedToday: 61,
      cityRank: 1, friendVotes: 38,
      variantMap: {
        'Free Size__#1A1A1A': ProductVariant(sku:'CAP-NK-BLK-F-D01',parentId:'CAP-NK',size:'Free Size',colorName:'Black',colorHex:'#1A1A1A',stock:8, priceInPaise:149900),
        'Free Size__#D4C5A9': ProductVariant(sku:'CAP-NK-BEG-F-D02',parentId:'CAP-NK',size:'Free Size',colorName:'Beige',colorHex:'#D4C5A9',stock:5, priceInPaise:149900),
        'Free Size__#1A2E4A': ProductVariant(sku:'CAP-NK-NVY-F-D03',parentId:'CAP-NK',size:'Free Size',colorName:'Navy', colorHex:'#1A2E4A',stock:12,priceInPaise:149900),
      },
    ),

    // ── UNISEX ── Chunky Trainer Sneaker — STRIDE ELITE ───────────────────────
    ParentProduct(
      id: 'SNK-SE', name: 'Chunky Trainer Sneaker', brand: 'STRIDE ELITE',
      category: 'Footwear', gender: ProductGender.unisex,
      defaultImageUrl: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=600&q=85',
      originalPriceFormatted: '₹11,999',
      sizes: ['UK6','UK7','UK8','UK9','UK10','UK11'], colors: const [
        VariantColor('Triple White','#F5F5F5'), VariantColor('Black Gum','#1A1A1A'), VariantColor('Clay','#B5956E'),
      ],
      isNew: true, stock: 2, droppedMinsAgo: 180, viewersNow: 34, orderedToday: 73, saleEndsAt: '03:30:00',
      cityRank: 1, friendVotes: 42,
      variantMap: {
        'UK6__#F5F5F5' : ProductVariant(sku:'SNK-SE-TWH-UK6-E01', parentId:'SNK-SE',size:'UK6', colorName:'Triple White',colorHex:'#F5F5F5',stock:4, priceInPaise:899900),
        'UK7__#F5F5F5' : ProductVariant(sku:'SNK-SE-TWH-UK7-E02', parentId:'SNK-SE',size:'UK7', colorName:'Triple White',colorHex:'#F5F5F5',stock:2, priceInPaise:899900),
        'UK8__#F5F5F5' : ProductVariant(sku:'SNK-SE-TWH-UK8-E03', parentId:'SNK-SE',size:'UK8', colorName:'Triple White',colorHex:'#F5F5F5',stock:0, priceInPaise:899900),
        'UK9__#F5F5F5' : ProductVariant(sku:'SNK-SE-TWH-UK9-E04', parentId:'SNK-SE',size:'UK9', colorName:'Triple White',colorHex:'#F5F5F5',stock:5, priceInPaise:899900),
        'UK10__#F5F5F5': ProductVariant(sku:'SNK-SE-TWH-UK10-E05',parentId:'SNK-SE',size:'UK10',colorName:'Triple White',colorHex:'#F5F5F5',stock:1, priceInPaise:899900),
        'UK11__#F5F5F5': ProductVariant(sku:'SNK-SE-TWH-UK11-E06',parentId:'SNK-SE',size:'UK11',colorName:'Triple White',colorHex:'#F5F5F5',stock:3, priceInPaise:899900),
        'UK6__#1A1A1A' : ProductVariant(sku:'SNK-SE-BGM-UK6-E11', parentId:'SNK-SE',size:'UK6', colorName:'Black Gum',  colorHex:'#1A1A1A',stock:3, priceInPaise:949900),
        'UK7__#1A1A1A' : ProductVariant(sku:'SNK-SE-BGM-UK7-E12', parentId:'SNK-SE',size:'UK7', colorName:'Black Gum',  colorHex:'#1A1A1A',stock:6, priceInPaise:949900),
        'UK8__#1A1A1A' : ProductVariant(sku:'SNK-SE-BGM-UK8-E13', parentId:'SNK-SE',size:'UK8', colorName:'Black Gum',  colorHex:'#1A1A1A',stock:4, priceInPaise:949900),
        'UK9__#1A1A1A' : ProductVariant(sku:'SNK-SE-BGM-UK9-E14', parentId:'SNK-SE',size:'UK9', colorName:'Black Gum',  colorHex:'#1A1A1A',stock:0, priceInPaise:949900),
        'UK10__#1A1A1A': ProductVariant(sku:'SNK-SE-BGM-UK10-E15',parentId:'SNK-SE',size:'UK10',colorName:'Black Gum',  colorHex:'#1A1A1A',stock:2, priceInPaise:949900),
        'UK11__#1A1A1A': ProductVariant(sku:'SNK-SE-BGM-UK11-E16',parentId:'SNK-SE',size:'UK11',colorName:'Black Gum',  colorHex:'#1A1A1A',stock:1, priceInPaise:949900),
        'UK6__#B5956E' : ProductVariant(sku:'SNK-SE-CLY-UK6-E21', parentId:'SNK-SE',size:'UK6', colorName:'Clay',       colorHex:'#B5956E',stock:5, priceInPaise:879900),
        'UK7__#B5956E' : ProductVariant(sku:'SNK-SE-CLY-UK7-E22', parentId:'SNK-SE',size:'UK7', colorName:'Clay',       colorHex:'#B5956E',stock:2, priceInPaise:879900),
        'UK8__#B5956E' : ProductVariant(sku:'SNK-SE-CLY-UK8-E23', parentId:'SNK-SE',size:'UK8', colorName:'Clay',       colorHex:'#B5956E',stock:7, priceInPaise:879900),
        'UK9__#B5956E' : ProductVariant(sku:'SNK-SE-CLY-UK9-E24', parentId:'SNK-SE',size:'UK9', colorName:'Clay',       colorHex:'#B5956E',stock:0, priceInPaise:879900),
        'UK10__#B5956E': ProductVariant(sku:'SNK-SE-CLY-UK10-E25',parentId:'SNK-SE',size:'UK10',colorName:'Clay',       colorHex:'#B5956E',stock:3, priceInPaise:879900),
        'UK11__#B5956E': ProductVariant(sku:'SNK-SE-CLY-UK11-E26',parentId:'SNK-SE',size:'UK11',colorName:'Clay',       colorHex:'#B5956E',stock:4, priceInPaise:879900),
      },
    ),
  ];

  // ── Query API (mock FastAPI endpoints) ───────────────────────────────────────

  static List<ParentProduct> getAll() => List.unmodifiable(_catalog);

  static List<ParentProduct> getByGender(ProductGender gender) =>
      _catalog.where((p) => p.gender == gender).toList();

  /// Returns products visible in a gender filter tab (includes unisex)
  static List<ParentProduct> getForTab(ProductGender gender) =>
      _catalog.where((p) => p.gender == gender || p.gender == ProductGender.unisex).toList();

  static List<ParentProduct> getJustDropped({ProductGender? gender}) {
    var src = gender == null ? _catalog : getForTab(gender);
    return src.where((p) => p.isNew && p.droppedMinsAgo > 0).toList()
      ..sort((a, b) => a.droppedMinsAgo.compareTo(b.droppedMinsAgo));
  }

  static List<ParentProduct> getAlmostGone({ProductGender? gender}) {
    var src = gender == null ? _catalog : getForTab(gender);
    return src.where((p) => p.stock < 4).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
  }

  static List<ParentProduct> getTrending({ProductGender? gender}) {
    var src = gender == null ? _catalog : getForTab(gender);
    return src.where((p) => p.cityRank > 0).toList()
      ..sort((a, b) => a.cityRank.compareTo(b.cityRank));
  }

  static List<ParentProduct> getVibeCheck({ProductGender? gender}) {
    var src = gender == null ? _catalog : getForTab(gender);
    return src.where((p) => p.friendVotes > 0).toList()
      ..sort((a, b) => b.friendVotes.compareTo(a.friendVotes));
  }

  static List<ParentProduct> getReorders() => _catalog.take(3).toList();

  static ParentProduct? getById(String id) =>
      _catalog.cast<ParentProduct?>().firstWhere((p) => p?.id == id, orElse: () => null);

  static CartPayload buildCartPayload({
    required ParentProduct parent,
    required ProductVariant variant,
    int quantity = 1,
  }) {
    return CartPayload(
      parentId         : parent.id,
      variantSku       : variant.sku,
      productName      : parent.name,
      brand            : parent.brand,
      size             : variant.size,
      colorName        : variant.colorName,
      colorHex         : variant.colorHex,
      quantity         : quantity,
      unitPriceInPaise : variant.priceInPaise,
      imageUrl         : variant.imageUrl ?? parent.defaultImageUrl,
    );
  }
}
