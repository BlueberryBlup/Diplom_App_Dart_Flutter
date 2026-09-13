import 'package:cloud_firestore/cloud_firestore.dart';

class LocationModel {
  final String id;
  final String objectId; //id объекта
  final int floor; //этаж
  final String number; //номер помещения

  LocationModel({
    required this.id,
    required this.objectId,
    required this.floor,
    required this.number,
  });

  factory LocationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LocationModel(
      id: doc.id,
      objectId: data['objectId'] ?? '',
      floor: data['floor'] ?? '',
      number: data['number'] ?? '',
    
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'objectId': objectId, 'floor': floor, 'number': number};
  }
}
