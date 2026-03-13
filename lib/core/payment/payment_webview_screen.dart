import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart'; // 🔥 تم استيراد ملف الترجمة

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  const PaymentWebViewScreen({super.key, required this.paymentUrl});

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController controller;
  bool isLoading = true;
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() { isLoading = true; errorMessage = ""; });
          },
          onPageFinished: (String url) {
            setState(() { isLoading = false; });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              isLoading = false;
              // بنخزن وصف الخطأ بس، والترجمة هتحصل تحت في الـ Build
              errorMessage = error.description;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.contains('success=true')) {
              Navigator.pop(context, true);
              return NavigationDecision.prevent;
            } else if (request.url.contains('success=false')) {
              Navigator.pop(context, false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          AppLang.tr(context, 'secure_payment_gateway') ?? "بوابة الدفع الآمنة",
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Column(
        children: [
          // 🔥 الشريط التحذيري للأرقام الإنجليزية 🔥
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: Colors.orange.shade100,
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLang.tr(context, 'english_numbers_warning') ?? "تنبيه: يرجى كتابة الأرقام (OTP / السرية) باللغة الإنجليزية فقط (123...) لتجنب فشل العملية.",
                    style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: controller),

                if (isLoading)
                  Container(
                    color: Colors.white,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                          const SizedBox(height: 16),
                          Text(
                            AppLang.tr(context, 'connecting_to_bank') ?? "جاري الاتصال بالبنك، يرجى الانتظار...",
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (errorMessage.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off_rounded, color: Colors.red, size: 60),
                          const SizedBox(height: 16),
                          Text(
                            "${AppLang.tr(context, 'page_load_failed') ?? 'فشل في تحميل الصفحة:'} $errorMessage",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              setState(() { isLoading = true; errorMessage = ""; });
                              controller.reload();
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            child: Text(
                              AppLang.tr(context, 'retry_btn') ?? "إعادة المحاولة",
                              style: const TextStyle(color: Colors.white),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}