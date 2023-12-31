import 'package:bookshelve_flutter/constant/urls.dart';
import 'package:bookshelve_flutter/utils/cookie.dart';
import 'package:bookshelve_flutter/feature/details/models/review.dart';

class ReviewService {
  Future<List<Review>> fetchReviews(
      String bookPk, CookieRequest request) async {
    var response =
        await request.get('${Urls.backendUrl}/details/review/$bookPk');

    var data = response;
    // melakukan konversi data json menjadi object Item
    List<Review> list_Item = [];
    for (var d in data) {
      if (d != null) {
        list_Item.add(Review.fromJson(d));
      }
    }

    return list_Item;
  }
}
