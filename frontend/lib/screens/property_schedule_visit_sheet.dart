// lib/screens/property_schedule_visit_sheet.dart
//
// QNX Mart › Real Estate › "Schedule a site visit" form (bottom sheet).
//
//   final booked = await showScheduleVisitSheet(context,
//       propertyId: p.id, propertyTitle: p.displayTitle, location: '${p.area}, ${p.city}');
//
// Backend: the customer request is sent through the existing
//   POST real_estate/create/enquiry/
// with the preferred date / time / visitors written in `message`.
// (real_estate/property-enquiry/schedule-meeting/ is only for approved marketing
//  partners — they confirm the visit from their enquiry list.)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/design_tokens.dart';
import '../models/property_enquiry_model.dart';
import '../services/property_enquiry_service.dart';
import '../utils/login_gate.dart';
import '../utils/shared_preferences_helper.dart';
import 'customer_subscription_screen.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
const _kBrand = Color(0xFF093C71);
const _kBrandDark = Color(0xFF062A50);
const _kBrandLight = Color(0xFF1E5A9C);
const _kRed = Color(0xFFC62828);
const _kRedBg = Color(0xFFFEF2F2);
const _kRedLine = Color(0xFFFECACA);
const _kHeader = LinearGradient(
  colors: [_kBrandDark, _kBrand, _kBrandLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class _SV {
  static const brand = Color(0xFF093C71);
  static const brandDark = Color(0xFF062A50);
  static const violet = Color(0xFF1E5A9C);
  static const orange = Color(0xFFF7931E);
  static const green = Color(0xFF10B981);
  static const bg = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E8F0);
  static const tint = Color(0xFFEAF1F9);
  static const ink = Color(0xFF0F172A);
  static const body = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
  static const rose = Color(0xFFC62828);
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _slots = <(int, String)>[
  (10, '10:00 AM'),
  (11, '11:00 AM'),
  (12, '12:00 PM'),
  (14, '02:00 PM'),
  (15, '03:00 PM'),
  (16, '04:00 PM'),
  (17, '05:00 PM'),
  (18, '06:00 PM'),
];

/// Opens the schedule-visit form. Returns `true` when the request was sent.
Future<bool> showScheduleVisitSheet(
    BuildContext context, {
      required int propertyId,
      required String propertyTitle,
      String? location,
    }) async {
  // The enquiry API needs a logged-in user.
  if (!await ensureLoggedIn(context, reason: 'schedule a site visit')) return false;
  if (!context.mounted) return false;
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ScheduleVisitSheet(
      propertyId: propertyId,
      propertyTitle: propertyTitle,
      location: location,
    ),
  );
  return r == true;
}

class _ScheduleVisitSheet extends StatefulWidget {
  final int propertyId;
  final String propertyTitle;
  final String? location;

  const _ScheduleVisitSheet({
    required this.propertyId,
    required this.propertyTitle,
    this.location,
  });

  @override
  State<_ScheduleVisitSheet> createState() => _ScheduleVisitSheetState();
}

class _ScheduleVisitSheetState extends State<_ScheduleVisitSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _note = TextEditingController();

  late final List<DateTime> _days;
  DateTime? _date;
  int? _hour;
  int _visitors = 1;
  bool _showErrors = false;
  bool _sending = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    // Today is offered only while there is still a slot left today.
    final firstOffset = now.hour >= 17 ? 1 : 0;
    _days = [
      for (var i = firstOffset; i < firstOffset + 14; i++)
        start.add(Duration(days: i)),
    ];
    _prefill();
  }

  Future<void> _prefill() async {
    final name = await SharedPreferencesHelper.getUsername();
    final email = await SharedPreferencesHelper.getUserEmail();
    if (!mounted) return;
    if ((name ?? '').trim().isNotEmpty && _name.text.isEmpty) {
      _name.text = name!.trim();
    }
    if ((email ?? '').trim().isNotEmpty && _email.text.isEmpty) {
      _email.text = email!.trim();
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _mobile, _email, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  bool _slotPassed(int hour) {
    if (_date == null || !_isToday(_date!)) return false;
    return DateTime.now().hour >= hour - 1; // need at least ~1 hour notice
  }

  String _longDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

  String _slotLabel(int h) => _slots.firstWhere((s) => s.$1 == h).$2;

  Future<void> _pickOtherDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? _days.first,
      firstDate: _days.first,
      lastDate: DateTime(now.year, now.month + 3, now.day),
      helpText: 'Choose visit date',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: _SV.brand,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      if (_hour != null && _slotPassed(_hour!)) _hour = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _showErrors = true;
      _error = null;
    });
    final formOk = _formKey.currentState!.validate();
    if (_date == null || _hour == null || !formOk) {
      setState(() => _error = _date == null
          ? 'Choose a visit date'
          : _hour == null
          ? 'Choose a time slot'
          : 'Please fix the highlighted fields');
      return;
    }

    final lines = <String>[
      'Site visit request',
      'Preferred date: ${_longDate(_date!)}',
      'Preferred time: ${_slotLabel(_hour!)}',
      'Visitors: $_visitors',
      if (_note.text.trim().isNotEmpty) 'Note: ${_note.text.trim()}',
    ];

    setState(() => _sending = true);
    final r = await PropertyEnquiryService.submitEnquiry(
      PropertyEnquiryRequest(
        property: widget.propertyId,
        customerName: _name.text.trim(),
        customerEmail: _email.text.trim(),
        customerMobile: _mobile.text.trim(),
        message: lines.join('\n'),
      ),
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (r.isSuccess) {
        _done = true;
      } else {
        _error = r.displayMessage;
      }
    });
    if (r.needsSubscription) {
      final bought = await openCustomerSubscription(context, reason: r.displayMessage);
      if (bought && mounted) await _submit();
    }
  }

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        child: Container(
          decoration: const BoxDecoration(
            color: _SV.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: _done ? _successView() : _formView(),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 8, 16),
      decoration: const BoxDecoration(gradient: _kHeader),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0x66FFFFFF),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0x26FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_available_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Schedule a site visit',
                        style: DT.text(
                            size: 16.5,
                            weight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        widget.propertyTitle,
                        if ((widget.location ?? '').trim().isNotEmpty)
                          widget.location!.trim(),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 12, color: const Color(0xD9FFFFFF)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(),
        Flexible(
          child: Form(
            key: _formKey,
            autovalidateMode: _showErrors
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: ListView(
              shrinkWrap: true,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              children: [
                _block(
                  icon: Icons.calendar_month_rounded,
                  title: 'Pick a date',
                  trailing: TextButton.icon(
                    onPressed: _pickOtherDate,
                    style: TextButton.styleFrom(
                      foregroundColor: _SV.brand,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.edit_calendar_rounded, size: 15),
                    label: Text('Other date',
                        style: DT.text(
                            size: 12, weight: FontWeight.w700, color: _SV.brand)),
                  ),
                  child: _dateStrip(),
                ),
                const SizedBox(height: 12),
                _block(
                  icon: Icons.schedule_rounded,
                  title: 'Pick a time',
                  child: _timeGrid(),
                ),
                const SizedBox(height: 12),
                _block(
                  icon: Icons.person_outline_rounded,
                  title: 'Your details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Full name', required: true),
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        style: _inputStyle,
                        decoration: _input('Your name', Icons.badge_outlined),
                        validator: (v) => (v ?? '').trim().length < 2
                            ? 'Enter your name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _label('Mobile number', required: true),
                      TextFormField(
                        controller: _mobile,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: _inputStyle,
                        decoration:
                        _input('10-digit mobile', Icons.phone_iphone_rounded),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.length != 10) return 'Enter a 10-digit mobile number';
                          if (!RegExp(r'^[6-9]').hasMatch(t)) {
                            return 'Enter a valid Indian mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _label('Email', required: true),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: _inputStyle,
                        decoration:
                        _input('you@example.com', Icons.alternate_email_rounded),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'Enter your email';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _visitorsRow(),
                      const SizedBox(height: 12),
                      _label('Note for the agent'),
                      TextFormField(
                        controller: _note,
                        maxLines: 3,
                        maxLength: 300,
                        textCapitalization: TextCapitalization.sentences,
                        style: _inputStyle,
                        decoration: _input(
                            'e.g. Interested in 2 BHK, east facing', null),
                      ),
                    ],
                  ),
                ),
                if (_date != null && _hour != null) ...[
                  const SizedBox(height: 12),
                  _summary(),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _errorBox(_error!),
                ],
              ],
            ),
          ),
        ),
        _bottomBar(),
      ],
    );
  }

  Widget _dateStrip() {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = _days[i];
          final sel = _date != null &&
              _date!.year == d.year &&
              _date!.month == d.month &&
              _date!.day == d.day;
          return GestureDetector(
            onTap: () => setState(() {
              _date = d;
              if (_hour != null && _slotPassed(_hour!)) _hour = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 58,
              decoration: BoxDecoration(
                gradient: sel
                    ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_SV.brand, _SV.violet],
                )
                    : null,
                color: sel ? null : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sel ? Colors.transparent : _SV.line),
                boxShadow: sel
                    ? const [
                  BoxShadow(
                      color: Color(0x40093C71),
                      blurRadius: 10,
                      offset: Offset(0, 4)),
                ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_isToday(d) ? 'Today' : _weekdays[d.weekday - 1],
                      style: DT.text(
                          size: 10.5,
                          weight: FontWeight.w600,
                          color: sel ? const Color(0xE6FFFFFF) : _SV.muted)),
                  const SizedBox(height: 2),
                  Text('${d.day}',
                      style: DT.text(
                          size: 19,
                          weight: FontWeight.w800,
                          color: sel ? Colors.white : _SV.ink)),
                  Text(_months[d.month - 1],
                      style: DT.text(
                          size: 10,
                          weight: FontWeight.w600,
                          color: sel ? const Color(0xE6FFFFFF) : _SV.hint)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _timeGrid() {
    return LayoutBuilder(builder: (context, c) {
      const gap = 8.0;
      final cols = c.maxWidth >= 360 ? 4 : 3;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final s in _slots)
            _slotChip(s.$1, s.$2, w),
        ],
      );
    });
  }

  Widget _slotChip(int hour, String label, double width) {
    final passed = _slotPassed(hour);
    final sel = _hour == hour;
    return GestureDetector(
      onTap: passed ? null : () => setState(() => _hour = hour),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: passed
              ? const Color(0xFFF1F5F9)
              : sel
              ? _SV.tint
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? _SV.brand : _SV.line,
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: DT.text(
              size: 12,
              weight: FontWeight.w700,
              color: passed
                  ? _SV.hint
                  : sel
                  ? _SV.brandDark
                  : _SV.body,
              decoration: passed ? TextDecoration.lineThrough : null,
            )),
      ),
    );
  }

  Widget _visitorsRow() {
    Widget btn(IconData icon, VoidCallback? onTap) => Material(
      color: onTap == null ? const Color(0xFFF1F5F9) : _SV.tint,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon,
              size: 18, color: onTap == null ? _SV.hint : _SV.brand),
        ),
      ),
    );
    return Row(
      children: [
        const Icon(Icons.groups_outlined, size: 18, color: _SV.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Number of visitors',
              style: DT.text(
                  size: 12.5, weight: FontWeight.w600, color: _SV.body)),
        ),
        btn(Icons.remove_rounded,
            _visitors > 1 ? () => setState(() => _visitors--) : null),
        SizedBox(
          width: 40,
          child: Text('$_visitors',
              textAlign: TextAlign.center,
              style: DT.text(
                  size: 15, weight: FontWeight.w800, color: _SV.ink)),
        ),
        btn(Icons.add_rounded,
            _visitors < 10 ? () => setState(() => _visitors++) : null),
      ],
    );
  }

  Widget _summary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_note_rounded, color: _SV.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: DT.text(size: 12.5, color: const Color(0xFF7C2D12)),
                children: [
                  const TextSpan(text: 'Visit on '),
                  TextSpan(
                      text: _longDate(_date!),
                      style: DT.text(
                          size: 12.5,
                          weight: FontWeight.w800,
                          color: const Color(0xFF7C2D12))),
                  const TextSpan(text: ' at '),
                  TextSpan(
                      text: _slotLabel(_hour!),
                      style: DT.text(
                          size: 12.5,
                          weight: FontWeight.w800,
                          color: const Color(0xFF7C2D12))),
                  TextSpan(
                      text:
                      ' · $_visitors visitor${_visitors == 1 ? '' : 's'}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _SV.line)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _kBrand, // buttons: only #093C71
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x33093C71),
                    blurRadius: 12,
                    offset: Offset(0, 5)),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _sending
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                  size: 18, color: Colors.white),
              label: Text(_sending ? 'Sending…' : 'Request site visit',
                  style: DT.text(
                      size: 14.5,
                      weight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _successView() {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _SV.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFECFDF5),
                border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
              ),
              child: const Icon(Icons.check_rounded,
                  color: _SV.green, size: 42),
            ),
            const SizedBox(height: 16),
            Text('Visit request sent!',
                style: DT.text(
                    size: 19, weight: FontWeight.w800, color: _SV.ink)),
            const SizedBox(height: 6),
            Text(
              'We will call you on ${_mobile.text.trim()} to confirm your visit on '
                  '${_longDate(_date!)} at ${_slotLabel(_hour!)}.',
              textAlign: TextAlign.center,
              style: DT.text(size: 13, color: _SV.muted, height: 1.45),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBrand, // buttons: only #093C71
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Done',
                    style: DT.text(
                        size: 14.5,
                        weight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- helpers
  Widget _block({
    required IconData icon,
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _SV.line),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _SV.tint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: _SV.brand),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: DT.text(
                        size: 13.5, weight: FontWeight.w800, color: _SV.ink)),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _label(String text, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        text: text,
        style: DT.text(size: 12, weight: FontWeight.w600, color: _SV.body),
        children: [
          if (required)
            TextSpan(
                text: ' *',
                style: DT.text(
                    size: 12, weight: FontWeight.w700, color: _SV.rose)),
        ],
      ),
    ),
  );

  Widget _errorBox(String text) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kRedBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kRedLine),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, size: 18, color: _kRed),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: DT.text(
                  size: 12.5, weight: FontWeight.w600, color: _kRed)),
        ),
      ],
    ),
  );

  TextStyle get _inputStyle =>
      DT.text(size: 13.5, weight: FontWeight.w600, color: _SV.ink);

  InputDecoration _input(String hint, IconData? icon) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: DT.text(size: 12.5, color: _SV.hint),
      prefixIcon: icon == null ? null : Icon(icon, size: 18, color: _SV.hint),
      isDense: true,
      filled: true,
      fillColor: _SV.bg,
      counterStyle: DT.text(size: 10.5, color: _SV.hint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      enabledBorder: b(_SV.line),
      focusedBorder: b(_SV.brand, 1.6),
      errorBorder: b(_kRed),
      focusedErrorBorder: b(_kRed, 1.6),
      errorStyle: DT.text(size: 11, color: _kRed),
    );
  }
}
