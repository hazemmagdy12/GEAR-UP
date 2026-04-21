import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_lang.dart';

class PaymobManager {
  final Dio _dio = Dio();

  // 🔥 رابط السيرفر بتاعك على Vercel
  final String _baseUrl = "https://gear-up-backend.vercel.app";

  Future<Map<String, dynamic>> getCardPaymentUrl(BuildContext context, int amountInEGP) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/api/payment/get-url',
        data: {
          "amountInEGP": amountInEGP,
          "type": "card"
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'url': response.data['url']};
      }
      return {'success': false, 'message': AppLang.tr(context, 'paymob_server_error') ?? 'فشل الحصول على رابط الدفع من السيرفر'};
    } catch (e) {
      return {'success': false, 'message': '${AppLang.tr(context, 'paymob_unexpected_error') ?? "خطأ غير متوقع:"} $e'};
    }
  }

  Future<Map<String, dynamic>> getWalletPaymentUrl(BuildContext context, int amountInEGP, String walletNumber) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/api/payment/get-url',
        data: {
          "amountInEGP": amountInEGP,
          "type": "wallet",
          "walletNumber": walletNumber
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'url': response.data['url']};
      }
      return {'success': false, 'message': AppLang.tr(context, 'paymob_wallet_rejected') ?? 'رقم المحفظة مرفوض أو البنك لم يرسل رابط'};
    } catch (e) {
      return {'success': false, 'message': '${AppLang.tr(context, 'paymob_unexpected_error') ?? "خطأ غير متوقع:"} $e'};
    }
  }
}