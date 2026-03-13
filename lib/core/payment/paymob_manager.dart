import 'package:dio/dio.dart';

class PaymobManager {
  final Dio _dio = Dio();

  final String _apiKey = "ZXlKaGJHY2lPaUpJVXpVeE1pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SmpiR0Z6Y3lJNklrMWxjbU5vWVc1MElpd2ljSEp2Wm1sc1pWOXdheUk2TVRFek56VXhOU3dpYm1GdFpTSTZJbWx1YVhScFlXd2lmUS41bXNTd1pCTUxfRFF0bFBlMWE4dDlSZmpWa0duVFk4emFmQnZESDIxMmZKZGItZS1ISFcwTXFpXy1sVUJRUVdtY0ZVTl8zblRSa094X0dGcWhrdURSQQ==";
  final String _cardIntegrationId = "5565752";
  final String _walletIntegrationId = "5565757";
  final String _iframeId = "1012100";

  Future<String?> _getAuthToken() async {
    try {
      final response = await _dio.post('https://accept.paymob.com/api/auth/tokens', data: {"api_key": _apiKey});
      return response.data['token'];
    } catch (e) { return null; }
  }

  Future<int?> _getOrderId(String token, String amount) async {
    try {
      final response = await _dio.post(
        'https://accept.paymob.com/api/ecommerce/orders',
        data: {"auth_token": token, "delivery_needed": "false", "amount_cents": amount, "currency": "EGP", "items": []},
      );
      return response.data['id'];
    } catch (e) { return null; }
  }

  Future<String?> _getPaymentKey(String token, int orderId, String amount, String integrationId) async {
    try {
      final response = await _dio.post(
        'https://accept.paymob.com/api/acceptance/payment_keys',
        data: {
          "auth_token": token,
          "amount_cents": amount,
          "expiration": 3600,
          "order_id": orderId.toString(),
          // 🔥 الحل السحري: بيانات نموذجية ثابتة عشان بيموب مستحيل يرفضها 🔥
          "billing_data": {
            "apartment": "803", "email": "support@gearup.com", "floor": "42", "first_name": "Gear",
            "street": "Main", "building": "10", "phone_number": "01000000000", "shipping_method": "PKG",
            "postal_code": "11111", "city": "Cairo", "country": "EG", "last_name": "Up", "state": "Cairo"
          },
          "currency": "EGP",
          "integration_id": int.parse(integrationId)
        },
      );
      return response.data['token'];
    } catch (e) { return null; }
  }

  // 🔥 بترجع Map فيه حالة النجاح والرابط أو سبب الخطأ 🔥
  Future<Map<String, dynamic>> getCardPaymentUrl(int amountInEGP) async {
    try {
      String amountCents = (amountInEGP * 100).toString();

      String? token = await _getAuthToken();
      if (token == null) return {'success': false, 'message': 'خطأ: فشل المصادقة مع بيموب (API Key)'};

      int? orderId = await _getOrderId(token, amountCents);
      if (orderId == null) return {'success': false, 'message': 'خطأ: فشل إنشاء الطلب (Order)'};

      String? paymentKey = await _getPaymentKey(token, orderId, amountCents, _cardIntegrationId);
      if (paymentKey == null) return {'success': false, 'message': 'خطأ: فشل إصدار مفتاح الدفع للفيزا'};

      return {'success': true, 'url': "https://accept.paymob.com/api/acceptance/iframes/$_iframeId?payment_token=$paymentKey"};
    } catch (e) { return {'success': false, 'message': 'خطأ غير متوقع: $e'}; }
  }

  Future<Map<String, dynamic>> getWalletPaymentUrl(int amountInEGP, String walletNumber) async {
    try {
      String amountCents = (amountInEGP * 100).toString();

      String? token = await _getAuthToken();
      if (token == null) return {'success': false, 'message': 'خطأ: فشل المصادقة مع بيموب'};

      int? orderId = await _getOrderId(token, amountCents);
      if (orderId == null) return {'success': false, 'message': 'خطأ: فشل إنشاء الطلب (Order)'};

      String? paymentKey = await _getPaymentKey(token, orderId, amountCents, _walletIntegrationId);
      if (paymentKey == null) return {'success': false, 'message': 'خطأ: فشل إصدار مفتاح الدفع للمحفظة'};

      final response = await _dio.post(
        'https://accept.paymob.com/api/acceptance/payments/pay',
        data: {"source": {"identifier": walletNumber, "subtype": "WALLET"}, "payment_token": paymentKey},
      );

      String? redirectUrl = response.data['redirect_url'] ?? response.data['iframe_url'];

      if (redirectUrl != null && redirectUrl.startsWith('http')) {
        return {'success': true, 'url': redirectUrl};
      }
      return {'success': false, 'message': 'البنك لم يرسل رابط الدفع (الرقم غير صالح للمحفظة)'};
    } catch (e) {
      return {'success': false, 'message': 'رقم المحفظة مرفوض من شبكة فودافون/بيموب'};
    }
  }
}