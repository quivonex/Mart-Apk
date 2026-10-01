// lib/screens/terms_conditions_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms & Conditions',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'Please read these terms carefully before registering',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('1. Introduction',
                      'QNX Mart is a B2B and B2C marketplace platform that enables businesses to showcase, promote, and sell their products through a growing network of marketing partners and customers. These Terms establish the rights, responsibilities, and obligations of companies using the QNX Mart platform.'),
                  _buildSection('2. Eligibility',
                      'To register as a Company or Seller, you must be a legally registered business entity, possess all licences, registrations, and approvals required under applicable laws, provide accurate business information, provide valid GST details (where applicable), provide PAN and other verification documents whenever required, and have authority to enter into this agreement on behalf of the business. QNX Mart reserves the right to verify submitted information before approving any company registration.'),
                  _buildSection('3. Company Registration',
                      'Registration of a company on QNX Mart does not automatically guarantee approval. QNX Mart may request Business Registration Certificate, GST Certificate, PAN Details, Address Proof, Identity Proof of Authorized Representative, Product Certifications, Brand Authorization Documents, and any additional documents required for verification. Approval remains subject to successful verification.'),
                  _buildSection('4. Product Listing',
                      'Companies are responsible for ensuring that every product listed on QNX Mart contains accurate and complete information. Product listings should include Product Name, Description, Features, Specifications, Images, Pricing, Stock Availability, Warranty Information (if applicable), and Applicable Taxes. All information must remain updated throughout the listing period.'),
                  _buildSection('5. Prohibited Products',
                      'The following products may not be listed on QNX Mart: counterfeit goods, illegal products, expired products, hazardous materials prohibited by law, restricted products, fake branded products, stolen goods, products violating intellectual property rights, and products prohibited under Indian law. QNX Mart reserves the right to remove any listing without prior notice.'),
                  _buildSection('6. Product Registration Fees',
                      'Where applicable, companies shall pay the prescribed product registration fee before product approval. Registration fees apply per approved product, may be revised by QNX Mart from time to time, and are generally non-refundable after successful listing unless otherwise stated. Additional agreement, verification, or payment gateway charges may apply where applicable.'),
                  _buildSection('7. Pricing',
                      'Companies are solely responsible for determining product pricing. Prices must be fair, transparent, include applicable taxes wherever required, and comply with Indian consumer protection laws. Artificial price manipulation or misleading discounts are strictly prohibited.'),
                  _buildSection('8. Inventory Management',
                      'Companies agree to maintain accurate stock information, update inventory regularly, avoid accepting orders for unavailable products, and inform QNX Mart immediately of discontinued products. Repeated stock shortages may affect account status.'),
                  _buildSection('9. Order Fulfillment',
                      'Companies shall process orders promptly, package products securely, dispatch products within agreed timelines, provide shipment tracking details where applicable, and deliver products according to promised schedules. Repeated delays may result in account review or suspension.'),
                  _buildSection('10. Product Quality',
                      'Companies warrant that all listed products match their descriptions, meet advertised specifications, are genuine, are free from manufacturing defects, comply with applicable safety standards, and are legally permitted for sale. The Company remains fully responsible for product quality.'),
                  _buildSection('11. Payments',
                      'Payments for completed sales shall be processed according to the applicable settlement schedule. Payments may be subject to successful order completion, delivery confirmation, applicable marketplace fees, tax deductions required by law, and refund or return adjustments. Settlement schedules may vary depending on business policies.'),
                  _buildSection('12. Marketplace Fees',
                      'Companies agree to pay applicable platform charges, which may include product registration fees, marketplace commissions, subscription charges (if applicable), payment gateway charges, verification charges, and other approved service fees. QNX Mart may revise fee structures after providing appropriate notice.'),
                  _buildSection('13. Returns and Refunds',
                      'Companies agree to accept returns where applicable, including cases such as wrong product supplied, damaged product, manufacturing defect, product differs from description, or incorrect quantity delivered. Refunds shall be processed according to the platform\'s Return & Refund Policy.'),
                  _buildSection('14. Tax Compliance',
                      'Companies are solely responsible for GST compliance, filing statutory returns, payment of applicable taxes, issuing valid tax invoices, and maintaining financial records. Any tax liabilities arising from non-compliance shall remain the sole responsibility of the Company.'),
                  _buildSection('15. Marketing Rights',
                      'By listing products on QNX Mart, the Company grants QNX Mart a non-exclusive right to use product images, product descriptions, brand logos, product videos, and marketing content. These materials may be used for marketplace listings, promotional campaigns, digital marketing, social media promotions, and advertising. Ownership of intellectual property remains with the Company.'),
                  _buildSection('16. Confidentiality',
                      'Companies shall maintain confidentiality regarding customer information, marketing partner information, pricing agreements, business strategies, technical information, financial information, and trade secrets. Confidential information must not be disclosed to unauthorized parties during or after participation in the platform.'),
                  _buildSection('17. Intellectual Property',
                      'Companies confirm that they own or are legally authorized to use all trademarks, logos, images, videos, and content uploaded to QNX Mart, and that their listings do not infringe any third-party intellectual property rights. QNX Mart shall not be liable for disputes arising from unauthorized use of intellectual property by the Company.'),
                  _buildSection('18. Company Responsibilities',
                      'Companies agree to maintain accurate business information, respond to customer inquiries promptly, resolve complaints professionally, maintain ethical business practices, cooperate with verification requests, and follow all QNX Mart policies.'),
                  _buildSection('19. Prohibited Activities',
                      'Companies shall not upload fake products, manipulate prices, provide false information, sell prohibited products, engage in fraudulent transactions, misuse the QNX Mart platform, circumvent platform policies, or interfere with platform operations. Violations may result in immediate suspension. Products will be delisted from the platform if three or more accepted enquiries remain without a status update for more than seven consecutive days.'),
                  _buildSection('20. Account Suspension',
                      'QNX Mart reserves the right to suspend or permanently terminate any Company account in cases including fraudulent activities, fake documentation, intellectual property violations, illegal product listings, repeated customer complaints, non-compliance with applicable laws, or violation of these Terms & Conditions.'),
                  _buildSection('21. Limitation of Liability',
                      'QNX Mart operates as a marketplace platform connecting businesses and customers. QNX Mart shall not be liable for manufacturing defects, product warranties, business losses, lost profits, indirect damages, delayed shipments caused by third parties, or customer misuse of products. The Company remains solely responsible for the products it sells.'),
                  _buildSection('22. Dispute Resolution',
                      'In the event of any dispute, the parties shall first attempt to resolve the matter through mutual discussions. If unresolved, the dispute may be referred to arbitration or other legal remedies as permitted under applicable law. These Terms & Conditions shall be governed by the laws of India.'),
                  _buildSection('23. Policy Updates',
                      'QNX Mart reserves the right to modify marketplace policies, listing requirements, fee structures, product guidelines, platform features, and business processes. Updated Terms become effective upon publication on the QNX Mart platform.'),
                  _buildSection('24. Acceptance',
                      'By registering your Company or listing products on QNX Mart, you confirm that you have read and understood these Terms & Conditions, all information submitted is accurate, you agree to comply with applicable laws and platform policies, you accept future amendments published by QNX Mart, and you acknowledge that failure to comply may result in suspension or termination of your account.'),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'I Accept',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}