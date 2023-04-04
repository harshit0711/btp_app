import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class NetworkHandler {
  String baseurl = "https://btp-backend-flask-inpm4aannq-el.a.run.app/api/v1";
  var log = Logger();
  FlutterSecureStorage storage = FlutterSecureStorage();

  Future get(String url) async {
    final access_token = await storage.read(key: "access_token");
    var response = await Dio().get(
      baseurl + url,
      options: Options(headers: {'Authorization': 'Bearer $access_token'}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      log.i(response.data);
      return response;
    } else if (response.statusCode == 401 || response.statusCode == 422) {
      log.i(response.data);
      log.i(response.statusCode);
      if (await refresh()) get(url);
    }
  }

  Future predict(FormData formData) async {
    final access_token = await storage.read(key: "access_token");
    var response = await Dio().post(
      baseurl + "/predict/predict",
      options: Options(headers: {'Authorization': 'Bearer $access_token'}),
      data: formData
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      log.i(response.data);
      return response;
    } else if (response.statusCode == 401 || response.statusCode == 422) {
      log.i(response.data);
      log.i(response.statusCode);
      if (await refresh()) predict(formData);
    }
  }

  Future post(String url, var body) async {
    final access_token = await storage.read(key: "access_token");
    log.d(body);
    var response = await Dio().post(
      baseurl + url,
      options: Options(headers: {'Authorization': 'Bearer $access_token'}),
      data: json.encode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      log.i(response.data);
      return json.decode(response.data);
    } else if (response.statusCode == 401 || response.statusCode == 422) {
      log.i(response.data);
      log.i(response.statusCode);
      if (await refresh()) post(url, body);
    }
    return response;
  }

  Future login(Map<String, String> body) async {
    var response =
        await Dio().post(baseurl + "/user/login", data: json.encode(body));
    if (response.statusCode == 200 && response.data["success"] == true) {
      log.i(response.data);
      storage.write(
          key: 'access_token', value: response.data["user"]["access_token"]);
      storage.write(
          key: "refresh_token", value: response.data["user"]["refresh_token"]);
    } else {
      log.i(response.data);
      log.i(response.statusCode);
    }
    return response;
  }

  Future refresh() async {
    final refresh_token = await storage.read(key: "refresh_token");
    var response = await Dio().post(
      baseurl + "/user/refresh",
      options: Options(headers: {'Authorization': 'Bearer $refresh_token'}),
    );
    if (response.statusCode == 200 && response.data["success"] == true) {
      log.i(response.data);
      storage.write(
          key: 'access_token', value: response.data["user"]["access_token"]);
      return true;
    } else {
      log.i(response.data);
      log.i(response.statusCode);
      storage.deleteAll();
      return false;
    }
  }
}
