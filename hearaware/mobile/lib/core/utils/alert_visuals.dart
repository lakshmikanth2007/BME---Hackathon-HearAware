import 'package:flutter/material.dart';

/// Icon + arrow for an event so meaning never depends on colour alone.
IconData iconForEvent(String event) {
  switch (event) {
    case 'vehicle horn':
    case 'car':
      return Icons.directions_car;
    case 'horn':
      return Icons.campaign;
    case 'siren':
    case 'vehicle siren':
      return Icons.emergency;
    case 'alarm':
      return Icons.notifications_active;
    case 'doorbell':
      return Icons.notifications;
    case 'knock':
      return Icons.door_front_door;
    case 'dog bark':
      return Icons.pets;
    case 'speech':
      return Icons.record_voice_over;
    case 'person':
      return Icons.person;
    case 'bus':
      return Icons.directions_bus;
    case 'truck':
      return Icons.local_shipping;
    case 'bicycle':
      return Icons.directions_bike;
    case 'motorcycle':
      return Icons.two_wheeler;
    case 'traffic light':
      return Icons.traffic;
    case 'stop sign':
      return Icons.stop_circle;
  }
  return Icons.hearing;
}

IconData? arrowForDirection(String direction) {
  switch (direction) {
    case 'left':
      return Icons.arrow_back;
    case 'right':
      return Icons.arrow_forward;
    case 'front':
      return Icons.arrow_upward;
    case 'behind':
      return Icons.arrow_downward;
  }
  return null;
}

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 5) return 'just now';
  if (d.inSeconds < 60) return '${d.inSeconds}s ago';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  return '${d.inHours} h ago';
}
