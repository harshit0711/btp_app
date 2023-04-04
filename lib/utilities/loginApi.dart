import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:page_transition/page_transition.dart';
import 'package:newapp/main.dart';

class LoginApi {
  final Dio api = Dio();
  String? accessToken;

  final _storage = const FlutterSecureStorage();

  LoginApi() {
    api.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      // if (!options.path.contains('https')) {
      //   options.path =
      //       'https://btp-backend-flask-inpm4aannq-el.a.run.app/api/v1${options.path}';
      // }
      print(options);
      if (options.headers.containsKey("requiresToken")) {
        options.headers.remove("requiresToken");
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
      print(options);
      return handler.next(options);
    }, onResponse: (response, handler) async {
      if (response.data["user"]["access_token"] != null) {
        accessToken = response.data["user"]["access_token"];
        _storage.write(
            key: 'access_token', value: response.data["user"]["access_token"]);
      }
      if (response.data["user"]["refresh_token"] != null) {
        _storage.write(
            key: 'refresh_token',
            value: response.data["user"]["refresh_token"]);
      }
      return handler.next(response);
    }, onError: (DioError error, handler) async {
      if ((error.response?.statusCode == 401 &&
              error.response?.data["msg"] == "Token has expired") ||
          (error.response?.statusCode == 422 &&
              error.response?.data["msg"] == "Signature verification failed")) {
        if (await _storage.containsKey(key: 'refresh_token')) {
          if (await refreshToken()) {
            return handler.resolve(await _retry(error.requestOptions));
          }
        }
      }
      return handler.next(error);
    }));
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );
    return api.request<dynamic>(requestOptions.path,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        options: options);
  }

  Future<bool> refreshToken() async {
    final refresh_token = await _storage.read(key: 'refresh_token');
    final response = await api.post('/user/refresh',
        options: Options(headers: {'Authorization': 'Bearer $refresh_token'}));

    if (response.statusCode == 200 && response.data["success"] == true) {
      accessToken = response.data["user"]["access_token"];
      _storage.write(
          key: 'access_token', value: response.data["user"]["access_token"]);
      return true;
    } else {
      // refresh token is wrong
      accessToken = null;
      _storage.deleteAll();
      // Navigator.pushAndRemoveUntil(
      //     context,
      //     PageTransition(
      //         type: PageTransitionType.rightToLeftWithFade, child: Home()),
      //     (route) => false);
      return false;
    }
  }
}
