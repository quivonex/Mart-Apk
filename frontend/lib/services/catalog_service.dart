// lib/services/catalog_service.dart
//
// One service for the product form and its masters. All endpoints are POST.
//
// BRANCH       branch/company_branches/        {company_id}
//              branch/branch/create/           {company, name, phone_number, email, address}
//              branch/branch/update/           {id, ...}
//              branch/branch/soft-delete/      {id}     branch/branch/restore/ {id}
// CATEGORY     product/category/by-company/    {company_id}           (active only)
//              product/category/list/          {}                     (mine, incl. inactive)
//              product/category/create/        {name, description, company, branch?}
//              product/category/update/        {id, ...}
//              product/category/soft-delete/   {id}     product/category/restore/ {id}
// SUBCATEGORY  product/subcategory/by-category/ {category}            (active only)
//              product/subcategory/by-user/list/ {}                   (mine, incl. inactive)
//              product/subcategory/create/     {category, name, description}
//              product/subcategory/update/     {id, category, name, description}
//              product/subcategory/soft-delete/ {id}  product/subcategory/restore/ {id}
// UNIT         product/unit/list/ {} (mine)    product/unit/all/ {} (incl. global)
//              product/unit/create/            {name, short_name}
//              product/unit/update/            {id, ...}
//              product/unit/soft-delete/       {id}     product/unit/restore/ {id}
// BRAND        product/brand/by-subcategory/   {subcategory_id}
// PRODUCT      product/api/products/create/    multipart
// MY PRODUCTS  product/company/products-list/  {company_id?, include_all: true}
//              product/product-active-inactive/ {product_id, is_active}
//              product/company/product/update-request/  multipart (admin approval)

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../models/catalog_models.dart';
import '../models/my_product_model.dart';
import '../utils/shared_preferences_helper.dart';
import 'api_urls.dart';

class CatalogService {
  static const _timeout = Duration(seconds: 30);
  static const _uploadTimeout = Duration(seconds: 180);

  static String _u(String path) => '${ApiUrls.baseUrl}$path';

  // ───────────────────────────── HTTP helpers ─────────────────────────────
  static Future<String?> _token() => SharedPreferencesHelper.getAccessToken();

  static Future<(int, Map<String, dynamic>)> _post(
      String path,
      Map<String, dynamic> body,
      ) async {
    final token = await _token();
    final res = await http
        .post(
      Uri.parse(_u(path)),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    )
        .timeout(_timeout);
    return (res.statusCode, _decode(res.body, res.statusCode));
  }

  static Map<String, dynamic> _decode(String body, int code) {
    try {
      final d = jsonDecode(body);
      if (d is Map<String, dynamic>) return d;
      if (d is List) return {'status': true, 'data': d};
    } catch (_) {}
    if (code == 401) return {'status': false, 'message': 'Session expired. Please log in again.'};
    return {'status': false, 'message': 'Server error ($code). Please try again.'};
  }

  static String _netError(Object e) {
    if (e is SocketException) return 'No internet connection.';
    if (e is TimeoutException) return 'The server took too long to respond.';
    if (e is http.ClientException) return 'Could not reach the server.';
    return 'Something went wrong: $e';
  }

  /// Backend success flags vary: true, "success", or only an HTTP 2xx (branch create).
  static bool _isOk(int code, Map<String, dynamic> json) {
    final s = json['status'];
    if (s == true || s?.toString().toLowerCase() == 'success') return true;
    if (s == false || s?.toString().toLowerCase() == 'error') return false;
    return code >= 200 && code < 300 && json['errors'] == null;
  }

  static List<Map<String, dynamic>> _list(Map<String, dynamic> json) {
    final d = json['data'];
    if (d is List) return d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return const [];
  }

  static Future<CatalogListResult<T>> _fetchList<T>(
      String path,
      Map<String, dynamic> body,
      T Function(Map<String, dynamic>) parse,
      ) async {
    try {
      final (code, json) = await _post(path, body);
      if (!_isOk(code, json)) {
        return CatalogListResult(ok: false, message: catalogErrorText(json));
      }
      return CatalogListResult(ok: true, items: _list(json).map(parse).toList());
    } catch (e) {
      return CatalogListResult(ok: false, message: _netError(e));
    }
  }

  static Future<CatalogResult<T>> _action<T>(
      String path,
      Map<String, dynamic> body,
      String successText, {
        T Function(Map<String, dynamic>)? parse,
      }) async {
    try {
      final (code, json) = await _post(path, body);
      if (!_isOk(code, json)) {
        return CatalogResult(ok: false, message: catalogErrorText(json));
      }
      T? data;
      if (parse != null && json['data'] is Map) {
        data = parse(Map<String, dynamic>.from(json['data']));
      }
      return CatalogResult(
        ok: true,
        message: (json['message'] ?? json['msg'] ?? successText).toString(),
        data: data,
      );
    } catch (e) {
      return CatalogResult(ok: false, message: _netError(e));
    }
  }

  static List<T> _sorted<T extends CatalogOption>(List<T> items) =>
      [...items]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  // ─────────────────────────────── BRANCH ────────────────────────────────
  static Future<CatalogListResult<CatalogBranch>> getBranches(
      int companyId, {
        bool activeOnly = true,
      }) async {
    final r = await _fetchList('/branch/company_branches/', {'company_id': companyId},
        CatalogBranch.fromJson);
    if (!r.ok) return r;
    final items = activeOnly ? r.items.where((b) => b.isActive).toList() : r.items;
    return CatalogListResult(ok: true, items: _sorted(items));
  }

  static Future<CatalogResult<CatalogBranch>> createBranch({
    required int companyId,
    required String name,
    String phone = '',
    String email = '',
    String address = '',
  }) =>
      _action(
        '/branch/branch/create/',
        {
          'company': companyId,
          'name': name,
          'phone_number': phone,
          if (email.isNotEmpty) 'email': email,
          'address': address,
        },
        'Branch created',
        parse: CatalogBranch.fromJson,
      );

  static Future<CatalogResult<CatalogBranch>> updateBranch(
      int id, {
        required String name,
        String phone = '',
        String email = '',
        String address = '',
      }) =>
      _action(
        '/branch/branch/update/',
        {
          'id': id,
          'name': name,
          'phone_number': phone,
          'email': email.isEmpty ? null : email,
          'address': address,
        },
        'Branch updated',
        parse: CatalogBranch.fromJson,
      );

  static Future<CatalogResult<void>> setBranchActive(int id, bool active) => _action(
      active ? '/branch/branch/restore/' : '/branch/branch/soft-delete/',
      {'id': id},
      active ? 'Branch restored' : 'Branch deactivated');

  // ────────────────────────────── CATEGORY ───────────────────────────────
  /// Active categories of a company (for the product form).
  static Future<CatalogListResult<CatalogCategory>> getCategories(int companyId) async {
    final r = await _fetchList(
        '/product/category/by-company/', {'company_id': companyId}, CatalogCategory.fromJson);
    return r.ok ? CatalogListResult(ok: true, items: _sorted(r.items)) : r;
  }

  /// All of MY categories for a company, including inactive (for the manage list).
  static Future<CatalogListResult<CatalogCategory>> getCategoriesForManage(
      int companyId) async {
    final r = await _fetchList('/product/category/list/', {}, CatalogCategory.fromJson);
    if (!r.ok) return r;
    return CatalogListResult(
        ok: true, items: _sorted(r.items.where((c) => c.companyId == companyId).toList()));
  }

  static Future<CatalogResult<CatalogCategory>> createCategory({
    required int companyId,
    required String name,
    String description = '',
    int? branchId,
  }) =>
      _action(
        '/product/category/create/',
        {
          'company': companyId,
          'name': name,
          'description': description,
          if (branchId != null) 'branch': branchId,
        },
        'Category created',
        parse: CatalogCategory.fromJson,
      );

  static Future<CatalogResult<CatalogCategory>> updateCategory(
      int id, {
        required String name,
        String description = '',
        int? branchId,
      }) =>
      _action(
        '/product/category/update/',
        {'id': id, 'name': name, 'description': description, 'branch': branchId},
        'Category updated',
        parse: CatalogCategory.fromJson,
      );

  static Future<CatalogResult<void>> setCategoryActive(int id, bool active) => _action(
      active ? '/product/category/restore/' : '/product/category/soft-delete/',
      {'id': id},
      active ? 'Category restored' : 'Category deactivated');

  // ──────────────────────────── SUBCATEGORY ──────────────────────────────
  static Future<CatalogListResult<CatalogSubCategory>> getSubCategories(int categoryId) async {
    final r = await _fetchList('/product/subcategory/by-category/', {'category': categoryId},
        CatalogSubCategory.fromJson);
    return r.ok ? CatalogListResult(ok: true, items: _sorted(r.items)) : r;
  }

  static Future<CatalogListResult<CatalogSubCategory>> getSubCategoriesForManage(
      int categoryId) async {
    final r = await _fetchList(
        '/product/subcategory/by-user/list/', {}, CatalogSubCategory.fromJson);
    if (!r.ok) return r;
    return CatalogListResult(
        ok: true, items: _sorted(r.items.where((s) => s.categoryId == categoryId).toList()));
  }

  static Future<CatalogResult<CatalogSubCategory>> createSubCategory({
    required int categoryId,
    required String name,
    String description = '',
  }) =>
      _action(
        '/product/subcategory/create/',
        {'category': categoryId, 'name': name, 'description': description},
        'Subcategory created',
        parse: CatalogSubCategory.fromJson,
      );

  static Future<CatalogResult<CatalogSubCategory>> updateSubCategory(
      int id, {
        required int categoryId,
        required String name,
        String description = '',
      }) =>
      _action(
        '/product/subcategory/update/',
        {'id': id, 'category': categoryId, 'name': name, 'description': description},
        'Subcategory updated',
        parse: CatalogSubCategory.fromJson,
      );

  static Future<CatalogResult<void>> setSubCategoryActive(int id, bool active) => _action(
      active ? '/product/subcategory/restore/' : '/product/subcategory/soft-delete/',
      {'id': id},
      active ? 'Subcategory restored' : 'Subcategory deactivated');

  // ──────────────────────────────── UNIT ─────────────────────────────────
  /// My units + global (admin) units. activeOnly for the product form.
  static Future<CatalogListResult<CatalogUnit>> getUnits({bool activeOnly = true}) async {
    final results = await Future.wait([
      _fetchList('/product/unit/list/', {}, CatalogUnit.fromJson),
      _fetchList('/product/unit/all/', {}, CatalogUnit.fromJson),
    ]);
    final mine = results[0];
    final all = results[1];
    if (!mine.ok && !all.ok) return mine;

    final byId = <int, CatalogUnit>{};
    for (final u in mine.items) {
      byId[u.id] = u;
    }
    for (final u in all.items.where((u) => u.isGlobal)) {
      byId[u.id] = u;
    }
    var items = byId.values.toList();
    if (activeOnly) items = items.where((u) => u.isActive).toList();
    return CatalogListResult(ok: true, items: _sorted(items));
  }

  static Future<CatalogResult<CatalogUnit>> createUnit({
    required String name,
    required String shortName,
  }) =>
      _action('/product/unit/create/', {'name': name, 'short_name': shortName},
          'Unit created',
          parse: CatalogUnit.fromJson);

  static Future<CatalogResult<CatalogUnit>> updateUnit(
      int id, {
        required String name,
        required String shortName,
      }) =>
      _action('/product/unit/update/', {'id': id, 'name': name, 'short_name': shortName},
          'Unit updated',
          parse: CatalogUnit.fromJson);

  static Future<CatalogResult<void>> setUnitActive(int id, bool active) => _action(
      active ? '/product/unit/restore/' : '/product/unit/soft-delete/',
      {'id': id},
      active ? 'Unit restored' : 'Unit deactivated');

  // ──────────────────────────────── BRAND ────────────────────────────────
  static Future<CatalogListResult<CatalogBrand>> getBrands(int subcategoryId) async {
    final r = await _fetchList('/product/brand/by-subcategory/',
        {'subcategory_id': subcategoryId}, CatalogBrand.fromJson);
    return r.ok ? CatalogListResult(ok: true, items: _sorted(r.items)) : r;
  }

  // ─────────────────────────────── PRODUCT ───────────────────────────────
  /// Multipart create. Files are XFile so it works on web and mobile.
  /// variantImages keys must be 'variant_image_<index>'.
  static Future<CatalogResult<Map<String, dynamic>>> createProduct({
    required Map<String, String> fields,
    required XFile thumbnail,
    List<XFile> images = const [],
    Map<String, XFile> variantImages = const {},
  }) async {
    try {
      final token = await _token();
      final req = http.MultipartRequest('POST', Uri.parse(_u('/product/api/products/create/')))
        ..headers.addAll({
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        })
        ..fields.addAll(fields);

      req.files.add(await imagePart('thumbnail', thumbnail));
      for (final img in images) {
        req.files.add(await imagePart('images', img));
      }
      for (final e in variantImages.entries) {
        req.files.add(await imagePart(e.key, e.value));
      }

      final streamed = await req.send().timeout(_uploadTimeout);
      final res = await http.Response.fromStream(streamed);
      final json = _decode(res.body, res.statusCode);

      if (!_isOk(res.statusCode, json)) {
        return CatalogResult(ok: false, message: catalogErrorText(json));
      }
      return CatalogResult(
        ok: true,
        message: (json['message'] ?? 'Product created').toString(),
        data: json['product'] is Map ? Map<String, dynamic>.from(json['product']) : null,
      );
    } catch (e) {
      return CatalogResult(ok: false, message: _netError(e));
    }
  }

  /// Backend upload_file_to_s3 needs a filename with extension + content type.
  static Future<http.MultipartFile> imagePart(String field, XFile x) async {
    final bytes = await x.readAsBytes();
    var name = x.name.isNotEmpty ? x.name : x.path.split('/').last;
    var mime = x.mimeType ?? '';
    if (!mime.startsWith('image/')) {
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
      mime = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
    }
    if (!name.contains('.')) {
      name = '$name.${switch (mime) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        'image/gif' => 'gif',
        _ => 'jpg',
      }}';
    }
    return http.MultipartFile.fromBytes(field, bytes,
        filename: name, contentType: MediaType.parse(mime));
  }

  // ───────────────────────────── MY PRODUCTS ─────────────────────────────
  /// All of the seller's products incl. pending / rejected / inactive.
  /// Needs the backend `include_all` patch (product/views.py).
  static Future<MyProductsResponse> getMyProducts({int? companyId}) async {
    try {
      final (code, json) = await _post('/product/company/products-list/', {
        if (companyId != null) 'company_id': companyId,
        'include_all': true,
      });
      if (!_isOk(code, json)) {
        return MyProductsResponse(ok: false, message: catalogErrorText(json));
      }
      return MyProductsResponse(
        ok: true,
        items: _list(json).map(MyProduct.fromJson).toList(),
      );
    } catch (e) {
      return MyProductsResponse(ok: false, message: _netError(e));
    }
  }

  /// Show / hide a product for buyers (no admin approval needed).
  static Future<CatalogResult<void>> setProductActive(int productId, bool active) async {
    try {
      final (code, json) = await _post('/product/product-active-inactive/',
          {'product_id': productId, 'is_active': active});
      final ok = json['success'] == true || (code >= 200 && code < 300 && json['success'] != false);
      return CatalogResult(
        ok: ok,
        message: (json['message'] ??
            (ok ? (active ? 'Product activated' : 'Product hidden') : 'Request failed'))
            .toString(),
      );
    } catch (e) {
      return CatalogResult(ok: false, message: _netError(e));
    }
  }

  /// Sends changes for admin approval. Only send fields that changed.
  /// The backend allows ONE pending request per product.
  static Future<CatalogResult<void>> requestProductUpdate({
    required int productId,
    Map<String, String> fields = const {},
    XFile? thumbnail,
    List<XFile> images = const [],
    List<int> deleteImageIds = const [],
  }) async {
    try {
      final token = await _token();
      final req = http.MultipartRequest(
          'POST', Uri.parse(_u('/product/company/product/update-request/')))
        ..headers.addAll({
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        })
        ..fields['product_id'] = productId.toString()
        ..fields.addAll(fields);

      // Django reads request.data.getlist('delete_images'). Map-based `fields`
      // can't repeat a key, so each id goes in as its own filename-less part,
      // which Django parses as a normal form field.
      for (final id in deleteImageIds) {
        req.files.add(http.MultipartFile.fromString('delete_images', id.toString()));
      }
      if (thumbnail != null) req.files.add(await imagePart('thumbnail', thumbnail));
      for (final img in images) {
        req.files.add(await imagePart('images', img));
      }

      final streamed = await req.send().timeout(_uploadTimeout);
      final res = await http.Response.fromStream(streamed);
      final json = _decode(res.body, res.statusCode);
      if (!_isOk(res.statusCode, json)) {
        return CatalogResult(ok: false, message: catalogErrorText(json));
      }
      return CatalogResult(
          ok: true, message: (json['message'] ?? 'Update sent for approval').toString());
    } catch (e) {
      return CatalogResult(ok: false, message: _netError(e));
    }
  }

  /// Restock = an update request with only the new stock quantity.
  static Future<CatalogResult<void>> requestRestock(int productId, int newStock) =>
      requestProductUpdate(productId: productId, fields: {'stock_quantity': '$newStock'});
}