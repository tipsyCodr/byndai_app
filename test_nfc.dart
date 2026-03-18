import 'package:nfc_manager/nfc_manager.dart';

void main() async {
  print(await NfcManager.instance.isAvailable());
}
