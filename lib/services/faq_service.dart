import '../l10n/app_strings.dart';
import '../models/faq_item.dart';

/// Bundled FAQs — always match the active app language (incl. Chinese).
class FaqService {
  List<FaqItem> localizedFaqs(AppStrings strings) => strings.helpFaqEntries;
}
