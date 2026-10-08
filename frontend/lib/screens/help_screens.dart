// lib/screens/help_screens.dart
//
// Help & Support (drawer):  For Buying · For Selling · FAQ · About Us · Contact Us
//
// Contact Us posts to  POST contact/contact-us/
//   { name*, phone*, email?, subject* (max 50), message* }
//   -> 201 {status: true, message}  |  400 {status: false, errors}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../constants/design_tokens.dart';
import '../services/api_urls.dart';
import '../utils/shared_preferences_helper.dart';

const _blue = Color(0xFF0D6EFD);
const _supportEmail = 'qnxmartb2b@gmail.com';
const _website = 'https://qnxmartb2b.com';

enum HelpTopic { buying, selling, faq, about }

class _Block {
  final String title;
  final String body;
  final IconData icon;
  const _Block(this.icon, this.title, this.body);
}

// =====================================================================
// INFO PAGES
// =====================================================================
class HelpInfoScreen extends StatelessWidget {
  final HelpTopic topic;
  /// Lets the page open other app screens (e.g. Contact Us, Add Company).
  final void Function(String route)? onNavigate;

  const HelpInfoScreen({super.key, required this.topic, this.onNavigate});

  String get _title => switch (topic) {
    HelpTopic.buying => 'For Buying',
    HelpTopic.selling => 'For Selling',
    HelpTopic.faq => 'FAQ',
    HelpTopic.about => 'About Us',
  };

  String get _intro => switch (topic) {
    HelpTopic.buying =>
    'How to find products, contact sellers and place orders on QNXMart B2B.',
    HelpTopic.selling =>
    'How to register your company and list products for B2B buyers.',
    HelpTopic.faq => 'Answers to the questions we hear most often.',
    HelpTopic.about => 'Who we are and what QNXMart B2B offers.',
  };

  List<_Block> get _blocks => switch (topic) {
    HelpTopic.buying => const [
      _Block(Icons.search_rounded, '1. Find what you need',
          'Search from the home screen, pick a category, or open All Products. Use Filters to sort by price or show only products with stock or franchise options.'),
      _Block(Icons.mail_outline_rounded, '2. Send an enquiry',
          'Tap Enquiry on any product to ask the seller about bulk pricing, delivery or specifications. The seller receives your details and contacts you.'),
      _Block(Icons.shopping_cart_outlined, '3. Add to cart and order',
          'Tap Cart to add a product, then open your cart to review quantities and place the order. You need to be logged in to use the cart.'),
      _Block(Icons.receipt_long_outlined, '4. Track your orders',
          'Open Orders from the bottom bar to see the status of everything you have ordered.'),
      _Block(Icons.storefront_rounded, 'Franchise opportunities',
          'Products marked Franchise can be taken up as a franchise. Tap the Franchise badge to see the plans and apply.'),
      _Block(Icons.account_balance_outlined, 'Business loans',
          'Need funds for your purchase? Use Get Your Loan on the home screen to send a loan enquiry to our banking partners.'),
    ],
    HelpTopic.selling => const [
      _Block(Icons.domain_add_rounded, '1. Register your company',
          'Open Add Company and fill in your business details, address and logo. A one-time registration fee is paid securely through Razorpay to activate the company.'),
      _Block(Icons.category_outlined, '2. Set up your catalog',
          'Add branches if you sell from more than one location, then create categories, subcategories, brands and units. You can also add them directly from the product form.'),
      _Block(Icons.inventory_2_outlined, '3. Add products',
          'Use Add Product to enter the name, price, discount, GST, stock, packed weight and size, photos and variants. Weight and size are used to calculate shipping.'),
      _Block(Icons.verified_outlined, '4. Admin approval',
          'Every new product is reviewed by our team before buyers can see it. Changes to a live product are also sent for approval, and the current listing stays visible until then.'),
      _Block(Icons.insights_outlined, '5. Manage stock and enquiries',
          'Open My Products to see approved, in-review and low-stock items, restock, or hide a product. Buyer enquiries reach you through the contact details you provided.'),
    ],
    HelpTopic.faq => const [
      _Block(Icons.help_outline_rounded, 'Do I need an account to browse?',
          'No. Anyone can browse products and properties. You need to log in to use the cart, place orders, send some enquiries or sell.'),
      _Block(Icons.help_outline_rounded, 'Why is my product not visible to buyers?',
          'New products stay "In review" until the admin approves them. You can check the status in My Products.'),
      _Block(Icons.help_outline_rounded, 'I paid the registration fee but my company shows Pending.',
          'Open My Companies and tap Pay now on that company. If the payment was already captured, the app confirms it without charging you again. If it still shows Pending, contact us with your payment reference.'),
      _Block(Icons.help_outline_rounded, 'Can I change a product after it is approved?',
          'Yes. Tap Edit details in My Products. Your changes are sent for approval and go live once approved. Only one change request can be pending per product.'),
      _Block(Icons.help_outline_rounded, 'What is QNX ReMart?',
          'QNX ReMart is our marketplace for used and resale items. Browse listings in the app and send an enquiry to the seller.'),
      _Block(Icons.help_outline_rounded, 'How do I contact support?',
          'Use Contact Us in the menu or email $_supportEmail.'),
    ],
    HelpTopic.about => const [
      _Block(Icons.business_rounded, 'QNXMart B2B',
          'QNXMart B2B is a marketplace for small and growing businesses, operated by Quivonex Solutions Pvt. Ltd. Our tagline says it best: Market chalega nahi, daudega.'),
      _Block(Icons.shopping_bag_outlined, 'QNXMart — Shopping & Products',
          'Verified companies list their products for business buyers, with enquiries, cart ordering, shipping and franchise options.'),
      _Block(Icons.apartment_rounded, 'Real Estate — Buy, Sell & Rent',
          'Verified properties from trusted channel partners, with enquiries and site-visit scheduling.'),
      _Block(Icons.recycling_rounded, 'QNXRemart — Used & Resale',
          'A marketplace for buying and selling used and resale goods.'),
      _Block(Icons.account_balance_outlined, 'Finance',
          'Business loan enquiries with our banking and finance partners.'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(_title, style: DT.text(size: 18, weight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: DT.onyx900,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(_intro, style: DT.text(size: 14, color: DT.onyx600, height: 1.5)),
          const SizedBox(height: 14),
          for (final b in _blocks) ...[
            topic == HelpTopic.faq ? _faqTile(b) : _card(b),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          _contactCard(context),
        ],
      ),
    );
  }

  Widget _card(_Block b) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(b.icon, color: _blue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.title, style: DT.text(size: 15, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(b.body, style: DT.text(size: 13.5, color: DT.onyx600, height: 1.5)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _faqTile(_Block b) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        iconColor: _blue,
        collapsedIconColor: DT.slate500,
        title: Text(b.title, style: DT.text(size: 14.5, weight: FontWeight.w700)),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(b.body, style: DT.text(size: 13.5, color: DT.onyx600, height: 1.5)),
          ),
        ],
      ),
    ),
  );

  Widget _contactCard(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF212529),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Still need help?', style: DT.text(size: 15, weight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 4),
        Text('Write to us and our team will get back to you.',
            style: DT.text(size: 13, color: Colors.white70)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const ContactUsScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Contact Us',
                    style: DT.text(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => launchUrl(Uri.parse('mailto:$_supportEmail')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Email us',
                    style: DT.text(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// =====================================================================
// CONTACT US
// =====================================================================
class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final name = await SharedPreferencesHelper.getUsername();
    final email = await SharedPreferencesHelper.getUserEmail();
    if (!mounted) return;
    if (_name.text.isEmpty && name != null) _name.text = name;
    if (_email.text.isEmpty && email != null) _email.text = email;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _subject, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    String msg;
    bool ok = false;
    try {
      // No auth header on purpose: an expired token would make the public form fail.
      final res = await http
          .post(
        Uri.parse('${ApiUrls.baseUrl}/contact/contact-us/'),
        headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'name': _name.text.trim(),
          'phone': _phone.text.trim(),
          if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
          'subject': _subject.text.trim(),
          'message': _message.text.trim(),
        }),
      )
          .timeout(const Duration(seconds: 20));
      final j = jsonDecode(res.body);
      ok = res.statusCode == 201 || (j is Map && j['status'] == true);
      if (ok) {
        msg = (j['message'] ?? 'Your message has been sent.').toString();
      } else if (j is Map && j['errors'] is Map && (j['errors'] as Map).isNotEmpty) {
        final e = (j['errors'] as Map).entries.first;
        final v = e.value is List && (e.value as List).isNotEmpty ? (e.value as List).first : e.value;
        msg = '${e.key}: $v';
      } else {
        msg = (j is Map ? j['message'] : null)?.toString() ?? 'Could not send your message.';
      }
    } catch (_) {
      msg = 'Could not reach the server. Please try again.';
    }
    if (!mounted) return;
    setState(() => _sending = false);

    if (ok) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF198754), size: 48),
          title: Text('Message sent', style: DT.text(size: 18, weight: FontWeight.w800)),
          content: Text('$msg\nWe will get back to you soon.',
              textAlign: TextAlign.center, style: DT.text(size: 13.5, color: DT.onyx600, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('OK', style: DT.text(size: 14, weight: FontWeight.w700, color: _blue)),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: DT.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: DT.text(size: 13.5, color: DT.slate500),
    prefixIcon: Icon(icon, size: 20, color: DT.slate400),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _blue, width: 1.6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text('Contact Us', style: DT.text(size: 18, weight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: DT.onyx900,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mail_outline_rounded, color: _blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => launchUrl(Uri.parse('mailto:$_supportEmail')),
                        child: Text.rich(TextSpan(
                          text: 'Email us at ',
                          style: DT.text(size: 13.5, color: DT.onyx700),
                          children: [
                            TextSpan(
                                text: _supportEmail,
                                style: DT.text(size: 13.5, weight: FontWeight.w700, color: _blue)),
                            const TextSpan(text: ' or send a message below.'),
                          ],
                        )),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(150)],
                decoration: _dec('Your name *', Icons.person_outline_rounded),
                validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: _dec('Mobile number *', Icons.phone_outlined),
                validator: (v) =>
                RegExp(r'^[6-9]\d{9}$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid 10-digit number',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('Email', Icons.alternate_email_rounded),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(t) ? null : 'Invalid email';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subject,
                inputFormatters: [LengthLimitingTextInputFormatter(50)], // backend max_length=50
                decoration: _dec('Subject *', Icons.subject_rounded),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a subject' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _message,
                maxLines: 5,
                minLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: _dec('Message *', Icons.chat_bubble_outline_rounded),
                validator: (v) => (v ?? '').trim().length < 10 ? 'Please write a little more' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_sending ? 'Sending…' : 'Send message',
                      style: DT.text(size: 15, weight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    disabledBackgroundColor: _blue.withValues(alpha: 0.6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: () => launchUrl(Uri.parse(_website), mode: LaunchMode.externalApplication),
                  child: Text('Visit qnxmartb2b.com',
                      style: DT.text(size: 13, weight: FontWeight.w600, color: _blue)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}