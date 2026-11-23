import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MinExpiryTracker'**
  String get appTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, notes, location...'**
  String get searchHint;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @ownerStatistics.
  ///
  /// In en, this message translates to:
  /// **'Owner Statistics'**
  String get ownerStatistics;

  /// No description provided for @appLogs.
  ///
  /// In en, this message translates to:
  /// **'App Logs'**
  String get appLogs;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @allOwners.
  ///
  /// In en, this message translates to:
  /// **'All Owners'**
  String get allOwners;

  /// No description provided for @allLocations.
  ///
  /// In en, this message translates to:
  /// **'All Locations'**
  String get allLocations;

  /// No description provided for @unassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get unassigned;

  /// No description provided for @noLocation.
  ///
  /// In en, this message translates to:
  /// **'No Location'**
  String get noLocation;

  /// No description provided for @catMedicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get catMedicine;

  /// No description provided for @catCosmetics.
  ///
  /// In en, this message translates to:
  /// **'Cosmetics'**
  String get catCosmetics;

  /// No description provided for @catFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get catFood;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @ownerMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get ownerMe;

  /// No description provided for @ownerFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get ownerFamily;

  /// No description provided for @locFridge.
  ///
  /// In en, this message translates to:
  /// **'Fridge'**
  String get locFridge;

  /// No description provided for @locMedicineBox.
  ///
  /// In en, this message translates to:
  /// **'Medicine Box'**
  String get locMedicineBox;

  /// No description provided for @locBathroom.
  ///
  /// In en, this message translates to:
  /// **'Bathroom'**
  String get locBathroom;

  /// No description provided for @noItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No items yet.\nTap \"+ Add Item\" to track your first item!'**
  String get noItemsYet;

  /// No description provided for @noItemsMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No items match your search or filters.'**
  String get noItemsMatchFilters;

  /// No description provided for @clearAllFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear All Filters'**
  String get clearAllFilters;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItem;

  /// No description provided for @totalItems.
  ///
  /// In en, this message translates to:
  /// **'Total: {count} items'**
  String totalItems(int count);

  /// No description provided for @tapOwnerToFilter.
  ///
  /// In en, this message translates to:
  /// **'Tap any owner to filter your list.'**
  String get tapOwnerToFilter;

  /// No description provided for @noItemsToSummarize.
  ///
  /// In en, this message translates to:
  /// **'No items to summarize yet.'**
  String get noItemsToSummarize;

  /// No description provided for @ownerStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Expired: {expired} • Expiring ≤7d: {soon}'**
  String ownerStatsSubtitle(int expired, int soon);

  /// No description provided for @qtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Qty: {count}'**
  String qtyLabel(int count);

  /// No description provided for @expLabel.
  ///
  /// In en, this message translates to:
  /// **'Exp: {date}'**
  String expLabel(String date);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count}d left'**
  String daysLeft(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String daysAgo(int count);

  /// No description provided for @hoursLeft.
  ///
  /// In en, this message translates to:
  /// **'{count}h left'**
  String hoursLeft(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String hoursAgo(int count);

  /// No description provided for @minutesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count}m left'**
  String minutesLeft(int count);

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String minutesAgo(int count);

  /// No description provided for @editItem.
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get editItem;

  /// No description provided for @addNewItem.
  ///
  /// In en, this message translates to:
  /// **'Add New Item'**
  String get addNewItem;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get addPhoto;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a Photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove Photo'**
  String get removePhoto;

  /// No description provided for @itemNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Item Name *'**
  String get itemNameLabel;

  /// No description provided for @itemNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Vitamin C Serum, Fresh Milk'**
  String get itemNameHint;

  /// No description provided for @itemNameError.
  ///
  /// In en, this message translates to:
  /// **'Please enter an item name'**
  String get itemNameError;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category *'**
  String get categoryLabel;

  /// No description provided for @quantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantityLabel;

  /// No description provided for @expiryDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date *'**
  String get expiryDateLabel;

  /// No description provided for @tapToSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Tap to select date'**
  String get tapToSelectDate;

  /// No description provided for @selectExpiryDateError.
  ///
  /// In en, this message translates to:
  /// **'Please select an expiry date.'**
  String get selectExpiryDateError;

  /// No description provided for @paoSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Period After Opening (Optional)'**
  String get paoSectionTitle;

  /// No description provided for @paoValueLabel.
  ///
  /// In en, this message translates to:
  /// **'PAO Value'**
  String get paoValueLabel;

  /// No description provided for @unitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unitLabel;

  /// No description provided for @unitMonths.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get unitMonths;

  /// No description provided for @unitDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get unitDays;

  /// No description provided for @unitHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get unitHours;

  /// No description provided for @openedDateBtn.
  ///
  /// In en, this message translates to:
  /// **'Opened Date'**
  String get openedDateBtn;

  /// No description provided for @timeBtn.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeBtn;

  /// No description provided for @clearOpenedDate.
  ///
  /// In en, this message translates to:
  /// **'Clear opened date'**
  String get clearOpenedDate;

  /// No description provided for @ownerSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Owner (Optional)'**
  String get ownerSectionTitle;

  /// No description provided for @newOwner.
  ///
  /// In en, this message translates to:
  /// **'New Owner'**
  String get newOwner;

  /// No description provided for @addNewOwnerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Owner'**
  String get addNewOwnerTitle;

  /// No description provided for @addNewOwnerHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Mom, Dad, Kids'**
  String get addNewOwnerHint;

  /// No description provided for @locationSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Location (Optional)'**
  String get locationSectionTitle;

  /// No description provided for @newLocation.
  ///
  /// In en, this message translates to:
  /// **'New Location'**
  String get newLocation;

  /// No description provided for @addNewLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Location'**
  String get addNewLocationTitle;

  /// No description provided for @addNewLocationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Kitchen Shelf, Bedroom'**
  String get addNewLocationHint;

  /// No description provided for @alertsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Alerts & Device Calendar'**
  String get alertsSectionTitle;

  /// No description provided for @alertsSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Enter time before expiry and tap + to add. Tick \"Add to Calendar\" to auto-sync.'**
  String get alertsSectionHint;

  /// No description provided for @beforeLabel.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get beforeLabel;

  /// No description provided for @addAlertTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add Alert'**
  String get addAlertTooltip;

  /// No description provided for @noAlertsSet.
  ///
  /// In en, this message translates to:
  /// **'No alerts set for this item.'**
  String get noAlertsSet;

  /// No description provided for @addToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Add to Calendar'**
  String get addToCalendar;

  /// No description provided for @removeAlertTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove alert'**
  String get removeAlertTooltip;

  /// No description provided for @invalidPositiveNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid positive number.'**
  String get invalidPositiveNumber;

  /// No description provided for @alertAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'This alert milestone already exists.'**
  String get alertAlreadyExists;

  /// No description provided for @hoursBeforeLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} hours before'**
  String hoursBeforeLabel(int count);

  /// No description provided for @daysBeforeLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} days before'**
  String daysBeforeLabel(int count);

  /// No description provided for @notesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes (Optional)'**
  String get notesSectionTitle;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'Storage tips, dosage, where you bought it...'**
  String get notesHint;

  /// No description provided for @deleteItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Item?'**
  String get deleteItemTitle;

  /// No description provided for @deleteItemConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from your list?'**
  String deleteItemConfirm(String name);

  /// No description provided for @appActivityLogs.
  ///
  /// In en, this message translates to:
  /// **'App Activity Logs'**
  String get appActivityLogs;

  /// No description provided for @sendTestNotification.
  ///
  /// In en, this message translates to:
  /// **'Send Test Notification'**
  String get sendTestNotification;

  /// No description provided for @testNotificationSent.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent!'**
  String get testNotificationSent;

  /// No description provided for @clearLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get clearLogs;

  /// No description provided for @clearLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All Logs?'**
  String get clearLogsTitle;

  /// No description provided for @clearLogsConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will remove all activity history records.'**
  String get clearLogsConfirm;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @noLogsYet.
  ///
  /// In en, this message translates to:
  /// **'No activity logs yet.'**
  String get noLogsYet;

  /// No description provided for @noActionLogsFound.
  ///
  /// In en, this message translates to:
  /// **'No \"{action}\" logs found.'**
  String noActionLogsFound(String action);

  /// No description provided for @logActionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get logActionAdd;

  /// No description provided for @logActionUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get logActionUpdate;

  /// No description provided for @logActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get logActionDelete;

  /// No description provided for @logActionNotify.
  ///
  /// In en, this message translates to:
  /// **'Notify'**
  String get logActionNotify;

  /// No description provided for @logActionCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get logActionCalendar;

  /// No description provided for @logActionBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get logActionBackup;

  /// No description provided for @logActionError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get logActionError;

  /// No description provided for @logItemAdded.
  ///
  /// In en, this message translates to:
  /// **'Added \"{name}\" ({category}).'**
  String logItemAdded(String name, String category);

  /// No description provided for @logItemUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated \"{name}\".'**
  String logItemUpdated(String name);

  /// No description provided for @logItemDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\".'**
  String logItemDeleted(String name);

  /// No description provided for @logTestNotifySent.
  ///
  /// In en, this message translates to:
  /// **'Sent test notification.'**
  String get logTestNotifySent;

  /// No description provided for @logRemindersScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled {count} reminder(s) for \"{name}\".'**
  String logRemindersScheduled(int count, String name);

  /// No description provided for @logCalendarDenied.
  ///
  /// In en, this message translates to:
  /// **'Calendar permission denied by user.'**
  String get logCalendarDenied;

  /// No description provided for @logCalendarNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No calendar account found on this device.'**
  String get logCalendarNoAccount;

  /// No description provided for @logCalendarNoWritable.
  ///
  /// In en, this message translates to:
  /// **'No writable calendar available (sign in to a Google account on device).'**
  String get logCalendarNoWritable;

  /// No description provided for @logCalendarSkippedPast.
  ///
  /// In en, this message translates to:
  /// **'Skipped past calendar alert ({alert}) for \"{name}\".'**
  String logCalendarSkippedPast(String alert, String name);

  /// No description provided for @logCalendarAdded.
  ///
  /// In en, this message translates to:
  /// **'Added calendar event for \"{name}\" ({alert}).'**
  String logCalendarAdded(String name, String alert);

  /// No description provided for @logCalendarFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add calendar event for \"{name}\".'**
  String logCalendarFailed(String name);

  /// No description provided for @logCalendarRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed {count} calendar event(s) for \"{name}\".'**
  String logCalendarRemoved(int count, String name);

  /// No description provided for @logBackupExported.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} item(s) to {fileName}.'**
  String logBackupExported(int count, String fileName);

  /// No description provided for @logRestoreInvalid.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: Invalid backup file format.'**
  String get logRestoreInvalid;

  /// No description provided for @logBackupRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored {count} item(s) from backup file.'**
  String logBackupRestored(int count);

  /// No description provided for @languageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSection;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get languageTitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageVietnamese.
  ///
  /// In en, this message translates to:
  /// **'Tiếng Việt'**
  String get languageVietnamese;

  /// No description provided for @dataAndBackup.
  ///
  /// In en, this message translates to:
  /// **'Data & Backup'**
  String get dataAndBackup;

  /// No description provided for @backupData.
  ///
  /// In en, this message translates to:
  /// **'Backup Data'**
  String get backupData;

  /// No description provided for @backupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export all items & photos as a .json file to Google Drive or device storage'**
  String get backupSubtitle;

  /// No description provided for @restoreData.
  ///
  /// In en, this message translates to:
  /// **'Restore Data'**
  String get restoreData;

  /// No description provided for @restoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import a previously saved .json backup file and reschedule alerts'**
  String get restoreSubtitle;

  /// No description provided for @backupReady.
  ///
  /// In en, this message translates to:
  /// **'Backup file ready ({count} items).'**
  String backupReady(int count);

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {error}'**
  String backupFailed(String error);

  /// No description provided for @restoreDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from Backup?'**
  String get restoreDialogTitle;

  /// No description provided for @restoreDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This will replace all current items on this device with the data from your backup file.'**
  String get restoreDialogContent;

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose File'**
  String get chooseFile;

  /// No description provided for @restoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully restored {count} items!'**
  String restoreSuccess(int count);

  /// No description provided for @restoreError.
  ///
  /// In en, this message translates to:
  /// **'Could not restore: Please select a valid MinExpiryTracker .json file.'**
  String get restoreError;

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSection;

  /// No description provided for @versionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0 • Offline Mode'**
  String get versionSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
