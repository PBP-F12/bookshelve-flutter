import 'package:bookshelve_flutter/constant/urls.dart';
import 'package:bookshelve_flutter/feature/details/models/book_details.dart';
import 'package:bookshelve_flutter/feature/forum/models/forum.dart';
import 'package:bookshelve_flutter/feature/profile/models/profile.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class Cookie {
  String name;
  String value;
  int? expireTimestamp;

  Cookie(this.name, this.value, this.expireTimestamp);

  Cookie.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        value = json['value'],
        expireTimestamp = json['expireTimestamp'];

  Map toJson() => {
        "name": name,
        "value": value,
        "expireTimestamp": expireTimestamp,
      };
}

class CookieRequest {
  Map<String, String> headers = {};
  Map<String, Cookie> cookies = {};
  Map<String, dynamic> jsonData = {};
  final http.Client _client = http.Client();

  String? role;
  String? username;
  int? userId;
  final String backendUrl = '${Urls.backendUrl}';

  late SharedPreferences local;

  bool loggedIn = false;
  bool initialized = false;

  Future init() async {
    if (!initialized) {
      local = await SharedPreferences.getInstance();
      cookies = _loadSharedPrefs();
      if (cookies['sessionid'] != null) {
        loggedIn = true;
        headers['cookie'] = _generateCookieHeader();
      }
    }
    initialized = true;
  }

  Map<String, Cookie> _loadSharedPrefs() {
    String? savedCookies = local.getString("cookies");
    if (savedCookies == null) {
      return {};
    }

    Map<String, Cookie> convCookies = {};

    try {
      var localCookies =
          Map<String, Map<String, dynamic>>.from(json.decode(savedCookies));
      for (String keyName in localCookies.keys) {
        convCookies[keyName] = Cookie.fromJson(localCookies[keyName]!);
      }
    } catch (_) {
      // We do not care if the cookie is invalid, just ignore it
    }

    return convCookies;
  }

  Future persist(String cookies) async {
    local.setString("cookies", cookies);
  }

  Map<String, dynamic> getJsonData() {
    return jsonData;
  }

  Future<dynamic> get(String url) async {
    await init();
    if (kIsWeb) {
      dynamic c = _client;
      c.withCredentials = true;
    }

    http.Response response =
        await _client.get(Uri.parse(url), headers: headers);
    await _updateCookie(response);

    return json.decode(response.body);
  }

  Future<dynamic> post(String url, {dynamic data}) async {
    await init();
    if (kIsWeb) {
      dynamic c = _client;
      c.withCredentials = true;
    }

    http.Response response =
        await _client.post(Uri.parse(url), body: data, headers: headers);
    await _updateCookie(response);

    return json.decode(response.body);
  }

  Future<dynamic> postJson(String url, dynamic data) async {
    await init();
    if (kIsWeb) {
      dynamic c = _client;
      c.withCredentials = true;
    }

    // Add additional header
    headers['Content-Type'] = 'application/json; charset=UTF-8';
    http.Response response =
        await _client.post(Uri.parse(url), body: data, headers: headers);

    // Remove used additional header
    headers.remove('Content-Type');
    await _updateCookie(response);

    return json.decode(response.body);
  }

  Future<dynamic> delete(String url, [dynamic data]) async {
    await init();
    if (kIsWeb) {
      dynamic c = _client;
      c.withCredentials = true;
    }

    if (data != null) {
      http.Response response =
          await _client.delete(Uri.parse(url), body: data, headers: headers);
      await _updateCookie(response);
      return json.decode(response.body);
    } else {
      http.Response response =
          await _client.delete(Uri.parse(url), headers: headers);
      await _updateCookie(response);
      return json.decode(response.body);
    }
  }

  Future _updateCookie(http.Response response) async {
    await init();

    String? allSetCookie = response.headers['set-cookie'];

    if (allSetCookie != null) {
      // Hacky way to simply ignore expires
      allSetCookie = allSetCookie.replaceAll(
        RegExp(r'expires=.+?;', caseSensitive: false),
        "",
      );
      var setCookies = allSetCookie.split(',');

      for (var cookie in setCookies) {
        _setCookie(cookie);
      }

      headers['cookie'] = _generateCookieHeader();
      String cookieObject = (const JsonEncoder()).convert(cookies);
      persist(cookieObject);
    }
  }

  void _setCookie(String rawCookie) {
    if (rawCookie.isEmpty) {
      return;
    }

    var cookieProps = rawCookie.split(";");

    // First part of cookie will always be the key-value pair
    var keyValue = cookieProps[0].split('=');
    if (keyValue.length != 2) {
      return;
    }

    String cookieName = keyValue[0].trim();
    String cookieValue = keyValue[1];

    int? cookieExpire;
    // Iterate through every props and find max-age
    // Expires works but Django always returns max-age, and according to MDN
    // max-age has higher prio

    for (var props in cookieProps.sublist(1)) {
      var keyval = props.split("=");
      if (keyval.length != 2) {
        continue;
      }

      var key = keyval[0].trim().toLowerCase();
      if (key != 'max-age') {
        continue;
      }

      int? deltaTime = int.tryParse(keyval[1]);
      if (deltaTime != null) {
        cookieExpire = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        cookieExpire += deltaTime;
      }
      break;
    }
    cookies[cookieName] = Cookie(cookieValue, cookieValue, cookieExpire);
  }

  String _generateCookieHeader() {
    int currTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    String cookie = "";

    for (var key in cookies.keys) {
      if (cookie.isNotEmpty) cookie += ";";
      Cookie? curr = cookies[key];

      if (curr == null) continue;
      if (curr.expireTimestamp != null && currTime >= curr.expireTimestamp!) {
        if (curr.name == "sessionid") {
          // Reset all states if sessionId got changed
          loggedIn = false;
          jsonData = {};
          cookies = {};
        }
        continue;
      }

      String newCookie = curr.value;
      cookie += '$key=$newCookie';
    }

    return cookie;
  }

  // FETCH AREA =======================================================

  Future<dynamic> login(String url, dynamic data) async {
    await init();
    if (kIsWeb) {
      dynamic c = _client;
      c.withCredentials = true;
    }

    http.Response response =
        await _client.post(Uri.parse(url), body: data, headers: headers);

    await _updateCookie(response);

    if (response.statusCode == 200) {
      loggedIn = true;
      jsonData = json.decode(response.body);
      role = jsonData['role'];
      username = jsonData['username'];
      userId = jsonData['userId'];
    } else {
      loggedIn = false;
    }

    return json.decode(response.body);
  }

  Future<dynamic> logout() async {
    await init();
    if (kIsWeb) {
      dynamic c = _client;
      c.withCredentials = true;
    }

    http.Response response = await _client.post(
        Uri.parse('${Urls.backendUrl}/auth/api/logout'),
        headers: headers);

    if (response.statusCode == 200) {
      loggedIn = false;
      jsonData = {};
      role = null;
      username = null;
      userId = null;
    } else {
      loggedIn = true;
    }

    cookies = {};

    return json.decode(response.body);
  }

  Future<dynamic> registerAs(
      {required String role,
      required String fullName,
      required String username,
      required String password,
      required String confirmationPassword}) async {
    Map<String, dynamic> body = {
      "full_name": fullName,
      "username": username,
      "password1": password,
      "password2": confirmationPassword
    };

    final uri = role == 'AUTHOR'
        ? Uri.parse("${Urls.backendUrl}/auth/api/register/author")
        : Uri.parse("${Urls.backendUrl}/auth/api/register/reader");
    final response = await http.post(uri, body: body);

    var responseJson = json.decode(response.body);
    responseJson['message'] = response.statusCode;

    return responseJson;
  }

  Future<List<Forum>> getForums() async {
    final responseBody = await get('$backendUrl/forum/api');

    if (responseBody['status'] == 200) {
      List<Forum> forums = [];
      for (var forum in responseBody['forums']) {
        if (forum != null) {
          forums.add(Forum.fromJson(forum));
        }
      }

      return forums;
    } else {
      throw 'Failed';
    }
  }

  Future<BookDetail> getDetailBook(String bookId) async {
    final responseBody = await get('$backendUrl/details/book/$bookId');

    if (responseBody['status'] == 200) {
      BookDetail book = BookDetail.fromJson(responseBody['book']);

      return book;
    } else {
      throw 'Failed';
    }
  }

  Future<Profile> getProfileData() async {
    final responseBody = await get('$backendUrl/auth/api/user');

    if (responseBody['status'] == 200) {
      Profile profile = Profile.fromJson(responseBody['user']);

      return profile;
    } else {
      throw 'Failed to fetch';
    }
  }

  NetworkImage getProfilePicture() {
    return NetworkImage('$backendUrl/auth/api/user/picture?id=$userId');
  }

  NetworkImage getProfilePictureByUserId(int userId) {
    return NetworkImage('$backendUrl/auth/api/user/picture?id=$userId');
  }

  Future<bool> uploadProfilePicture(String imagePath) async {
    var request = http.MultipartRequest('POST',
        Uri.parse('${Urls.backendUrl}/auth/api/user/picture?id=$userId'));

    // Add the image file to the request
    var file = await http.MultipartFile.fromPath('profile_picture', imagePath);
    request.files.add(file);

    // Send the request
    var response = await request.send();

    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  // FETCH AREA =======================================================

  bool isAdmin() {
    return role == 'ADMIN';
  }

  bool isReader() {
    return role == 'READER';
  }

  bool isAuthor() {
    return role == 'AUTHOR';
  }
}
