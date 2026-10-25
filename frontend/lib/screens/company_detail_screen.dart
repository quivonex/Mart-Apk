// lib/screens/company_detail_screen.dart
//
// Opened when a company card is tapped in CompanyListScreen.
// Loads fresh data from /company/company/single-retrieve/ and links to:
//   edit, pay, products, suppliers, stock, photos, deactivate/restore.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/design_tokens.dart';
import '../models/company_model.dart';
import '../services/company_service.dart';
import '../utils/company_payment_helper.dart';
import '../widgets/company_ui.dart';
import 'company_create_edit_screen.dart';
import 'company_photos_screen.dart';
import 'company_products_list_screen.dart';
import 'company_stock_screen.dart';
import 'supplier_list_screen.dart';
import 'package:qnx_mart/l10n/app_language.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
const _kBrand = Color(0xFF093C71);
const _kBrandDark = Color(0xFF062A50);
const _kTint = Color(0xFFEAF1F9);
const _kLine = Color(0xFFC9DBEE);
const _kRed = Color(0xFFC62828);
const _kRedBg = Color(0xFFFEF2F2);
const _kRedLine = Color(0xFFFECACA);
const _kOrangeDark = Color(0xFFC2410C);
const _kOrangeBg = Color(0xFFFFF7ED);

class CompanyDetailScreen extends StatefulWidget {
  final Company company;

  const CompanyDetailScreen({super.key, required this.company});

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  late Company _c = widget.company;
  bool _refreshing = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _refreshing = true;
      _error = null;
    });
    final res = await CompanyService.getCompanyDetail(_c.id);
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      if (res.isSuccess) {
        _c = res.data!;
      } else {
        _error = res.message ?? tr('Could not refresh company');
      }
    });
  }

  // =================================================================
  // ACTIONS
  // =================================================================
  Future<void> _open(Widget page, {bool reload = true}) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (reload || result == true) _load();
  }

  Future<void> _pay() async {
    final paid = await CompanyPaymentHelper.pay(context, _c);
    if (paid) _load();
  }

  Future<void> _toggleActive() async {
    final deactivate = _c.isActive;
    final ok = await confirmAction(
      context,
      title: deactivate ? tr('Deactivate {0}?', [_c.name]) : tr('Restore {0}?', [_c.name]),
      message: deactivate
          ? tr('The company and its listings will be hidden from buyers. You can restore it any time from this screen.')
          : tr('The company will be visible to buyers again.'),
      confirmLabel: deactivate ? tr('Deactivate') : tr('Restore'),
      destructive: deactivate,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    final res = deactivate
        ? await CompanyService.softDeleteCompany(_c.id)
        : await CompanyService.restoreCompany(_c.id);
    if (!mounted) return;
    setState(() => _busy = false);
    showCompanySnack(context, res.message, error: !res.isSuccess);
    if (res.isSuccess) _load();
  }

  Future<void> _launch(String raw) async {
    var url = raw.trim();
    if (url.isEmpty) return;
    if (!url.contains(':')) url = 'https://$url';
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showCompanySnack(context, tr('Could not open {0}', [raw]), error: true);
  }

  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  // =================================================================
  // BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.background,
      appBar: CompanyTopBar(
        title: tr(_c.name),
        subtitle: _refreshing ? tr('Refreshing…') : tr('Company details'),
        actions: [
          IconButton(
            tooltip: tr('Edit'),
            onPressed: () => _open(CompanyCreateEditScreen(existing: _c)),
            icon: const Icon(Icons.edit_outlined, color: DT.onyx700),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: _kBrand,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (_error != null) ...[_errorBanner(), const SizedBox(height: 12)],
                _header(),
                if (_c.isPaymentPending) ...[const SizedBox(height: 12), _payBanner()],
                if (!_c.isActive) ...[const SizedBox(height: 12), _inactiveBanner()],
                const SizedBox(height: 16),
                _actions(),
                const SizedBox(height: 16),
                _contactSection(),
                const SizedBox(height: 12),
                _addressSection(),
                const SizedBox(height: 12),
                _businessSection(),
                if (_hasOnline) ...[const SizedBox(height: 12), _onlineSection()],
                if (_c.shortDescription.isNotEmpty || _c.longDescription.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _aboutSection(),
                ],
                const SizedBox(height: 12),
                _photosSection(),
                const SizedBox(height: 24),
                _dangerZone(),
              ],
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66FFFFFF),
                child: Center(child: CircularProgressIndicator(color: _kBrand)),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- Header ----------
  Widget _header() {
    final pill = !_c.isActive
        ? _pill(tr('Inactive'), DT.slate100, DT.onyx600)
        : _c.isPaid
        ? _pill(tr('Paid'), DT.emerald50, DT.emerald700)
        : _pill(tr('Payment pending'), _kOrangeBg, _kOrangeDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kTint,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: _kLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CompanyLogo(url: _c.logo, name: _c.name, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trData(_c.name),
                    style: DT.text(size: 18, weight: FontWeight.w800, letterSpacing: -0.4)),
                if (_c.companySlogan.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(tr(_c.companySlogan),
                      style: DT.text(size: 12.5, color: DT.slate500, height: 1.35)),
                ],
                if (_c.ownerName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(tr('Owned by {0}', [_c.ownerName]),
                      style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx700)),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    pill,
                    if (_c.isoCertified) _pill('ISO', Colors.white, _kBrand),
                    if (_c.isiCertified) _pill('ISI', Colors.white, _kBrand),
                    if (_c.codAvailable) _pill('COD', Colors.white, _kBrand),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Text(tr(text), style: DT.text(size: 11, weight: FontWeight.w700, color: fg)),
  );

  Widget _payBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kTint,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: _kLine),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: _kBrand),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Registration fee not paid'),
                    style: DT.text(size: 13.5, weight: FontWeight.w700, color: _kBrandDark)),
                const SizedBox(height: 2),
                Text(tr('Pay to activate the admin panel and shipping pickup.'),
                    style: DT.text(size: 12, color: DT.onyx600, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _pay,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBrand,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
            ),
            child: Text(tr('Pay now'),
                style: DT.text(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _inactiveBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DT.slate100,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.slate200),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_off_outlined, color: DT.onyx600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(tr('This company is deactivated and hidden from buyers.'),
                style: DT.text(size: 12.5, color: DT.onyx700, height: 1.4)),
          ),
          TextButton(
            onPressed: _toggleActive,
            child: Text(tr('Restore'),
                style: DT.text(size: 13, weight: FontWeight.w700, color: _kBrand)),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kRedBg,
      borderRadius: BorderRadius.circular(DT.rMd),
      border: Border.all(color: _kRedLine),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, size: 18, color: _kRed),
        const SizedBox(width: 8),
        Expanded(
          child: Text(tr('{0}. Showing saved details.', [_error]),
              style: DT.text(size: 12, color: _kRed, weight: FontWeight.w600)),
        ),
        GestureDetector(
          onTap: _load,
          child: Text(tr('Retry'),
              style: DT.text(size: 12, weight: FontWeight.w700, color: _kRed)),
        ),
      ],
    ),
  );

  // ---------- Actions grid ----------
  Widget _actions() {
    final tiles = <_ActionTile>[
      _ActionTile(Icons.inventory_2_outlined, tr('Products'),
              () => _open(CompanyProductsListScreen(companyId: _c.id, companyName: _c.name), reload: false)),
      _ActionTile(Icons.local_shipping_outlined, tr('Suppliers'),
              () => _open(SupplierListScreen(company: _c), reload: false)),
      _ActionTile(Icons.bar_chart_rounded, tr('Stock'),
              () => _open(CompanyStockScreen(company: _c), reload: false)),
      _ActionTile(Icons.photo_library_outlined,
          _c.images.isEmpty ? tr('Photos') : tr('Photos ({0})', [_c.images.length]),
              () => _open(CompanyPhotosScreen(company: _c))),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.95,
      children: [
        for (final t in tiles)
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DT.rMd),
              side: const BorderSide(color: DT.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(DT.rMd),
              onTap: t.onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _kTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(t.icon, color: _kBrand, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(tr(t.label),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 11.5, weight: FontWeight.w700, color: DT.onyx800)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ---------- Sections ----------
  Widget _contactSection() {
    final extraEmails = _c.multipleEmailIds.where((e) => e != _c.email).join(', ');
    final extraPhones = _c.contacts.where((e) => e != _c.phoneNumber).join(', ');
    return SectionCard(
      title: tr('Contact'),
      child: Column(children: [
        InfoLine(
            icon: Icons.phone_outlined,
            label: tr('Phone'),
            value: _c.phoneNumber,
            onTap: () => _launch('tel:${_digits(_c.phoneNumber)}')),
        InfoLine(
            icon: Icons.chat_outlined,
            label: tr('WhatsApp'),
            value: _c.whatsappNo,
            onTap: () {
              final d = _digits(_c.whatsappNo);
              _launch('https://wa.me/${d.length == 10 ? '91$d' : d}');
            }),
        InfoLine(
            icon: Icons.mail_outline_rounded,
            label: tr('Email'),
            value: _c.email,
            onTap: () => _launch('mailto:${_c.email}')),
        InfoLine(icon: Icons.alternate_email_rounded, label: tr('Other emails'), value: extraEmails),
        InfoLine(icon: Icons.contacts_outlined, label: tr('Other phones'), value: extraPhones),
        if ([_c.phoneNumber, _c.whatsappNo, _c.email, extraEmails, extraPhones]
            .every((s) => s.trim().isEmpty))
          _emptyLine(tr('No contact details yet. Tap edit to add them.')),
      ]),
    );
  }

  Widget _addressSection() {
    final area = [_c.village, _c.taluka, _c.district, _c.state]
        .where((s) => s.trim().isNotEmpty)
        .join(', ');
    final hasMap = _c.latitude.isNotEmpty && _c.longitude.isNotEmpty;
    return SectionCard(
      title: tr('Address'),
      trailing: hasMap
          ? TextButton.icon(
        onPressed: () => _launch(
            'https://www.google.com/maps/search/?api=1&query=${_c.latitude},${_c.longitude}'),
        icon: const Icon(Icons.map_outlined, size: 16),
        label: Text(tr('Map'),
            style: DT.text(size: 12, weight: FontWeight.w700, color: _kBrand)),
        style: TextButton.styleFrom(
          foregroundColor: _kBrand,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 32),
        ),
      )
          : null,
      child: Column(children: [
        InfoLine(icon: Icons.home_work_outlined, label: tr('Address'), value: _c.address),
        InfoLine(icon: Icons.location_on_outlined, label: tr('Area'), value: area),
        InfoLine(icon: Icons.markunread_mailbox_outlined, label: tr('Pincode'), value: _c.pincode),
        InfoLine(
            icon: Icons.local_shipping_outlined, label: tr('Pickup'), value: _c.pickupLocation),
        if ([_c.address, area, _c.pincode, _c.pickupLocation].every((s) => s.trim().isEmpty))
          _emptyLine(tr('No address yet.')),
      ]),
    );
  }

  Widget _businessSection() {
    return SectionCard(
      title: tr('Business details'),
      child: Column(children: [
        InfoLine(icon: Icons.receipt_long_outlined, label: tr('GST'), value: _c.gstNumber),
        InfoLine(icon: Icons.badge_outlined, label: tr('PAN'), value: _c.companyPanNo),
        InfoLine(
            icon: Icons.assignment_outlined, label: tr('Registration'), value: _c.registrationNo),
        InfoLine(icon: Icons.numbers_rounded, label: tr('IAN no.'), value: _c.ianNo),
        InfoLine(
            icon: Icons.event_outlined, label: tr('Since'), value: _c.farmRegistrationYear),
        InfoLine(icon: Icons.schedule_outlined, label: tr('Joined'), value: _fmtDate(_c.createdAt)),
      ]),
    );
  }

  bool get _hasOnline => [
    _c.websiteUrl,
    _c.facebookUrl,
    _c.instagramUrl,
    _c.linkedinUrl,
    _c.youtubeUrl,
    _c.privacyPolicyUrl,
    _c.termsConditionsUrl,
  ].any((s) => s.trim().isNotEmpty);

  Widget _onlineSection() {
    InfoLine link(IconData i, String l, String v) =>
        InfoLine(icon: i, label: tr(l), value: _short(v), onTap: () => _launch(v));
    return SectionCard(
      title: tr('Online'),
      child: Column(children: [
        link(Icons.language_rounded, tr('Website'), _c.websiteUrl),
        link(Icons.facebook_rounded, tr('Facebook'), _c.facebookUrl),
        link(Icons.camera_alt_outlined, tr('Instagram'), _c.instagramUrl),
        link(Icons.work_outline_rounded, tr('LinkedIn'), _c.linkedinUrl),
        link(Icons.smart_display_outlined, tr('YouTube'), _c.youtubeUrl),
        link(Icons.privacy_tip_outlined, tr('Privacy'), _c.privacyPolicyUrl),
        link(Icons.gavel_outlined, tr('Terms'), _c.termsConditionsUrl),
      ]),
    );
  }

  Widget _aboutSection() {
    return SectionCard(
      title: tr('About'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_c.shortDescription.isNotEmpty)
            Text(trData(_c.shortDescription),
                style: DT.text(size: 13, weight: FontWeight.w600, height: 1.5)),
          if (_c.shortDescription.isNotEmpty && _c.longDescription.isNotEmpty)
            const SizedBox(height: 8),
          if (_c.longDescription.isNotEmpty)
            Text(tr(_c.longDescription),
                style: DT.text(size: 12.5, color: DT.onyx600, height: 1.55)),
        ],
      ),
    );
  }

  Widget _photosSection() {
    return SectionCard(
      title: tr('Photos'),
      trailing: TextButton(
        onPressed: () => _open(CompanyPhotosScreen(company: _c)),
        child: Text(_c.images.isEmpty ? tr('Add') : tr('Manage'),
            style: DT.text(size: 12.5, weight: FontWeight.w700, color: _kBrand)),
      ),
      child: _c.images.isEmpty
          ? _emptyLine(tr('Add photos of your shop, warehouse or products.'))
          : SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _c.images.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ClipRRect(
            borderRadius: BorderRadius.circular(DT.rMd),
            child: Image.network(
              _c.images[i].displayUrl,
              width: 84,
              height: 84,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 84,
                height: 84,
                color: DT.slate100,
                child: const Icon(Icons.broken_image_outlined, color: DT.slate400),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dangerZone() {
    final deactivate = _c.isActive;
    return OutlinedButton.icon(
      onPressed: _busy ? null : _toggleActive,
      icon: Icon(
          deactivate ? Icons.visibility_off_outlined : Icons.restore_rounded, size: 18),
      label: Text(deactivate ? tr('Deactivate company') : tr('Restore company'),
          style: DT.text(
              size: 13.5,
              weight: FontWeight.w700,
              color: _kBrand)), // buttons: only #093C71
      style: OutlinedButton.styleFrom(
        foregroundColor: _kBrand,
        side: const BorderSide(color: _kBrand),
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
      ),
    );
  }

  Widget _emptyLine(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(tr(text), style: DT.text(size: 12.5, color: DT.slate500, height: 1.4)),
  );

  String _short(String url) =>
      url.replaceFirst(RegExp(r'^https?://(www\.)?'), '').replaceFirst(RegExp(r'/$'), '');

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final l = d.toLocal();
    return '${l.day} ${tr(m[l.month - 1])} ${l.year}';
  }
}

class _ActionTile {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _ActionTile(this.icon, this.label, this.onTap);
}