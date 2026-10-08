import 'package:flutter/foundation.dart';

final financeRevision = ValueNotifier<int>(0);
void notifyFinanceChanged() => financeRevision.value++;
