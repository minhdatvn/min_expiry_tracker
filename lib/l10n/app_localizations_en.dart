// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MinExpiryTracker';

  @override
  String get searchHint => 'Search by name, notes, location...';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get ownerStatistics => 'Owner Statistics';

  @override
  String get appLogs => 'App Logs';

  @override
  String get settings => 'Settings';

  @override
  String get all => 'All';

  @override
  String get allOwners => 'All Owners';

  @override
  String get allLocations => 'All Locations';

  @override
  String get unassigned => 'Unassigned';

  @override
  String get noLocation => 'No Location';

  @override
  String get catMedicine => 'Medicine';

  @override
  String get catCosmetics => 'Cosmetics';

  @override
  String get catFood => 'Food';

  @override
  String get catOther => 'Other';

  @override
  String get ownerMe => 'Me';

  @override
  String get ownerFamily => 'Family';

  @override
  String get locFridge => 'Fridge';

  @override
  String get locMedicineBox => 'Medicine Box';

  @override
  String get locBathroom => 'Bathroom';

  @override
  String get noItemsYet =>
      'No items yet.\nTap \"+ Add Item\" to track your first item!';

  @override
  String get noItemsMatchFilters => 'No items match your search or filters.';

  @override
  String get clearAllFilters => 'Clear All Filters';

  @override
  String get addItem => 'Add Item';

  @override
  String totalItems(int count) {
    return 'Total: $count items';
  }

  @override
  String get tapOwnerToFilter => 'Tap any owner to filter your list.';

  @override
  String get noItemsToSummarize => 'No items to summarize yet.';

  @override
  String ownerStatsSubtitle(int expired, int soon) {
    return 'Expired: $expired • Expiring ≤7d: $soon';
  }

  @override
  String qtyLabel(int count) {
    return 'Qty: $count';
  }

  @override
  String expLabel(String date) {
    return 'Exp: $date';
  }

  @override
  String get today => 'Today';

  @override
  String daysLeft(int count) {
    return '${count}d left';
  }

  @override
  String daysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String hoursLeft(int count) {
    return '${count}h left';
  }

  @override
  String hoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String minutesLeft(int count) {
    return '${count}m left';
  }

  @override
  String minutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String get editItem => 'Edit Item';

  @override
  String get addNewItem => 'Add New Item';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get addPhoto => 'Add Photo';

  @override
  String get takePhoto => 'Take a Photo';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get removePhoto => 'Remove Photo';

  @override
  String get itemNameLabel => 'Item Name *';

  @override
  String get itemNameHint => 'e.g., Vitamin C Serum, Fresh Milk';

  @override
  String get itemNameError => 'Please enter an item name';

  @override
  String get categoryLabel => 'Category *';

  @override
  String get quantityLabel => 'Quantity';

  @override
  String get expiryDateLabel => 'Expiry Date *';

  @override
  String get tapToSelectDate => 'Tap to select date';

  @override
  String get selectExpiryDateError => 'Please select an expiry date.';

  @override
  String get paoSectionTitle => 'Period After Opening (Optional)';

  @override
  String get paoValueLabel => 'PAO Value';

  @override
  String get unitLabel => 'Unit';

  @override
  String get unitMonths => 'Months';

  @override
  String get unitDays => 'Days';

  @override
  String get unitHours => 'Hours';

  @override
  String get openedDateBtn => 'Opened Date';

  @override
  String get timeBtn => 'Time';

  @override
  String get clearOpenedDate => 'Clear opened date';

  @override
  String get ownerSectionTitle => 'Owner (Optional)';

  @override
  String get newOwner => 'New Owner';

  @override
  String get addNewOwnerTitle => 'Add New Owner';

  @override
  String get addNewOwnerHint => 'e.g., Mom, Dad, Kids';

  @override
  String get locationSectionTitle => 'Location (Optional)';

  @override
  String get newLocation => 'New Location';

  @override
  String get addNewLocationTitle => 'Add New Location';

  @override
  String get addNewLocationHint => 'e.g., Kitchen Shelf, Bedroom';

  @override
  String get alertsSectionTitle => 'Custom Alerts & Device Calendar';

  @override
  String get alertsSectionHint =>
      'Enter time before expiry and tap + to add. Tick \"Add to Calendar\" to auto-sync.';

  @override
  String get beforeLabel => 'Before';

  @override
  String get addAlertTooltip => 'Add Alert';

  @override
  String get noAlertsSet => 'No alerts set for this item.';

  @override
  String get addToCalendar => 'Add to Calendar';

  @override
  String get removeAlertTooltip => 'Remove alert';

  @override
  String get invalidPositiveNumber => 'Please enter a valid positive number.';

  @override
  String get alertAlreadyExists => 'This alert milestone already exists.';

  @override
  String hoursBeforeLabel(int count) {
    return '$count hours before';
  }

  @override
  String daysBeforeLabel(int count) {
    return '$count days before';
  }

  @override
  String get notesSectionTitle => 'Notes (Optional)';

  @override
  String get notesHint => 'Storage tips, dosage, where you bought it...';

  @override
  String get deleteItemTitle => 'Delete Item?';

  @override
  String deleteItemConfirm(String name) {
    return 'Remove \"$name\" from your list?';
  }

  @override
  String get appActivityLogs => 'App Activity Logs';

  @override
  String get sendTestNotification => 'Send Test Notification';

  @override
  String get testNotificationSent => 'Test notification sent!';

  @override
  String get clearLogs => 'Clear Logs';

  @override
  String get clearLogsTitle => 'Clear All Logs?';

  @override
  String get clearLogsConfirm =>
      'This will remove all activity history records.';

  @override
  String get clear => 'Clear';

  @override
  String get noLogsYet => 'No activity logs yet.';

  @override
  String noActionLogsFound(String action) {
    return 'No \"$action\" logs found.';
  }

  @override
  String get logActionAdd => 'Add';

  @override
  String get logActionUpdate => 'Update';

  @override
  String get logActionDelete => 'Delete';

  @override
  String get logActionNotify => 'Notify';

  @override
  String get logActionCalendar => 'Calendar';

  @override
  String get logActionBackup => 'Backup';

  @override
  String get logActionError => 'Error';

  @override
  String logItemAdded(String name, String category) {
    return 'Added \"$name\" ($category).';
  }

  @override
  String logItemUpdated(String name) {
    return 'Updated \"$name\".';
  }

  @override
  String logItemDeleted(String name) {
    return 'Deleted \"$name\".';
  }

  @override
  String get logTestNotifySent => 'Sent test notification.';

  @override
  String logRemindersScheduled(int count, String name) {
    return 'Scheduled $count reminder(s) for \"$name\".';
  }

  @override
  String get logCalendarDenied => 'Calendar permission denied by user.';

  @override
  String get logCalendarNoAccount =>
      'No calendar account found on this device.';

  @override
  String get logCalendarNoWritable =>
      'No writable calendar found (Device Calendar and Google Calendar are unavailable).';

  @override
  String logCalendarSkippedPast(String alert, String name) {
    return 'Skipped past calendar alert ($alert) for \"$name\".';
  }

  @override
  String logCalendarAdded(String name, String alert) {
    return 'Added calendar event for \"$name\" ($alert).';
  }

  @override
  String logCalendarFailed(String name) {
    return 'Failed to add calendar event for \"$name\".';
  }

  @override
  String logCalendarRemoved(int count, String name) {
    return 'Removed $count calendar event(s) for \"$name\".';
  }

  @override
  String logBackupExported(int count, String fileName) {
    return 'Exported $count item(s) to $fileName.';
  }

  @override
  String get logRestoreInvalid => 'Restore failed: Invalid backup file format.';

  @override
  String logBackupRestored(int count) {
    return 'Restored $count item(s) from backup file.';
  }

  @override
  String get languageSection => 'Language';

  @override
  String get languageTitle => 'App Language';

  @override
  String get languageSystem => 'System Default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get dataAndBackup => 'Data & Backup';

  @override
  String get backupData => 'Backup Data';

  @override
  String get backupSubtitle =>
      'Export all items & photos as a .minexpiry file to Google Drive or device storage';

  @override
  String get restoreData => 'Restore Data';

  @override
  String get restoreSubtitle =>
      'Import a saved .minexpiry (or .json) backup file and reschedule alerts';

  @override
  String backupReady(int count) {
    return 'Backup file ready ($count items).';
  }

  @override
  String backupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String get restoreDialogTitle => 'Restore from Backup?';

  @override
  String get restoreDialogContent =>
      'This will replace all current items on this device with the data from your backup file.';

  @override
  String get chooseFile => 'Choose File';

  @override
  String restoreSuccess(int count) {
    return 'Successfully restored $count items!';
  }

  @override
  String get restoreError =>
      'Could not restore: Please select a valid MinExpiryTracker .minexpiry or .json file.';

  @override
  String get aboutSection => 'About';

  @override
  String versionSubtitle(String version) {
    return 'Version $version • Offline Mode';
  }

  @override
  String get testNotifyTitle => 'MinExpiryTracker is ready!';

  @override
  String get testNotifyBody =>
      'Offline expiry reminders are working properly on your phone.';

  @override
  String expiryAlertTitle(String category) {
    return 'Expiry Alert: $category';
  }

  @override
  String expiresInOneHour(String name) {
    return '$name expires in 1 hour!';
  }

  @override
  String expiresInHours(String name, int count) {
    return '$name expires in $count hours!';
  }

  @override
  String expiresTomorrow(String name) {
    return '$name expires tomorrow!';
  }

  @override
  String expiresInDays(String name, int count) {
    return '$name expires in $count days.';
  }

  @override
  String calItemLine(String name, String category) {
    return 'Item: $name ($category)';
  }

  @override
  String calExpiresLine(String date) {
    return 'Expires: $date';
  }

  @override
  String calReminderLine(String reminder) {
    return 'Reminder: $reminder';
  }

  @override
  String calOwnerLine(String owner) {
    return 'Owner: $owner';
  }

  @override
  String calLocationLine(String location) {
    return 'Location: $location';
  }

  @override
  String calNotesLine(String notes) {
    return 'Notes: $notes';
  }

  @override
  String get appearanceSection => 'Appearance';

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeSystem => 'System Default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get filterCategory => 'Category';

  @override
  String get filterOwner => 'Owner';

  @override
  String get filterLocation => 'Location';

  @override
  String get duplicateItem => 'Duplicate Item';

  @override
  String get duplicateHint =>
      'Copied from existing item. Please select the new expiry date.';

  @override
  String get incomingBackupTitle => 'Restore Backup File?';

  @override
  String incomingBackupContent(String date, int count) {
    return 'Backup date: $date\nTotal items: $count\n\nAll current items on this device will be replaced with this backup.';
  }

  @override
  String get restoreNow => 'Restore Now';

  @override
  String get restoringBackup => 'Restoring data...';

  @override
  String moreThanYearsLeft(int count) {
    return '> ${count}y';
  }

  @override
  String monthsLeft(int count) {
    return '${count}mo left';
  }

  @override
  String moreThanYearsAgo(int count) {
    return '> ${count}y ago';
  }

  @override
  String monthsAgo(int count) {
    return '${count}mo ago';
  }

  @override
  String get scanLabelBtn => 'Scan Label (Name & Expiry)';

  @override
  String get scanningLabel => 'Scanning text from image...';

  @override
  String get suggestedNamesLabel => 'Suggested names:';

  @override
  String get suggestedDatesLabel => 'Detected dates:';

  @override
  String get scanNoResult =>
      'No clear product name or expiry date found in the image.';

  @override
  String get scanNameTooltip => 'Scan product name';

  @override
  String get scanExpiryTooltip => 'Scan expiry date';

  @override
  String get scanNameNoResult => 'No clear product name found in the image.';

  @override
  String get scanExpiryNoResult => 'No valid expiry date found in the image.';
}
