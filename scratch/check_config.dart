
import 'package:pakiip/services/api_service.dart';

void main() async {
  try {
    final config = await ApiService.get('/config/public');
    print('CONFIG: $config');
  } catch (e) {
    print('ERROR: $e');
  }
}
