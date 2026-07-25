class Review {
  final String id;
  final String businessId;
  final String customerId;
  final String customerName;
  final String orderId;
  final int rating; // 1-5
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    required this.orderId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'customerId': customerId,
      'customerName': customerName,
      'orderId': orderId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Review.fromMap(String id, Map<dynamic, dynamic> map) {
    return Review(
      id: id,
      businessId: map['businessId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      orderId: map['orderId'] ?? '',
      rating: map['rating'] ?? 5,
      comment: map['comment'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }
}
