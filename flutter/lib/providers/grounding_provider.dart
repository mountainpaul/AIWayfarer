import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/grounding.dart';
import '../services/grounding_service.dart';

final groundingProvider = FutureProvider<Grounding>((ref) async {
  return ref.watch(groundingServiceProvider).compose();
});
