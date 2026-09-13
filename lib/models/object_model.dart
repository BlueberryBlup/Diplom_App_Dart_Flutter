import 'package:cloud_firestore/cloud_firestore.dart';

class ObjectModel {
  final String id;
  final String name; //название объекта
  final String address; //адресс
  final String customerId; //id заказчика
  final String generalContractorId; //id генподряда

  ObjectModel({
    required this.id,
    required this.name,
    required this.address,
    required this.customerId,
    required this.generalContractorId,
  });

  factory ObjectModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ObjectModel(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      customerId: data['customerId'] ?? '',
      generalContractorId: data['generalContractorId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'customerId': customerId,
      'generalContractorId': generalContractorId,
    };
  }
}
