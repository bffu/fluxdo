import 'package:dio/dio.dart';

import '../exceptions/api_exception.dart';

/// 错误拦截器
/// 处理 429/502/503/504 错误，转换为自定义异常
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;

    // 重试耗尽后抛出自定义异常供 UI 层处理
    if (statusCode == 429) {
      final retryAfter =
          int.tryParse(err.response?.headers.value('retry-after') ?? '');
      throw RateLimitException(retryAfter);
    }
    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      throw ServerException(statusCode!);
    }

    handler.next(err);
  }
}
