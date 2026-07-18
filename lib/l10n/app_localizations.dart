import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_si.dart';
import 'app_localizations_ta.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('si'),
    Locale('ta'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'SYU Sri Lanka'**
  String get appTitle;

  /// No description provided for @riseTogether.
  ///
  /// In en, this message translates to:
  /// **'Rise together.'**
  String get riseTogether;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @completeRegistration.
  ///
  /// In en, this message translates to:
  /// **'Complete registration'**
  String get completeRegistration;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @signInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue with SYU Sri Lanka.'**
  String get signInPrompt;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @newToSyu.
  ///
  /// In en, this message translates to:
  /// **'New to SYU?'**
  String get newToSyu;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @news.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get news;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get changeLanguage;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @updateDetails.
  ///
  /// In en, this message translates to:
  /// **'Update your details'**
  String get updateDetails;

  /// No description provided for @latestAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'Latest announcements'**
  String get latestAnnouncements;

  /// No description provided for @upcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'Upcoming events'**
  String get upcomingEvents;

  /// No description provided for @messagesFromSyu.
  ///
  /// In en, this message translates to:
  /// **'Messages from SYU'**
  String get messagesFromSyu;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin dashboard'**
  String get adminDashboard;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @clubs.
  ///
  /// In en, this message translates to:
  /// **'Clubs'**
  String get clubs;

  /// No description provided for @broadcast.
  ///
  /// In en, this message translates to:
  /// **'Broadcast'**
  String get broadcast;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @audit.
  ///
  /// In en, this message translates to:
  /// **'Audit'**
  String get audit;

  /// No description provided for @personal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get personal;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @qualifications.
  ///
  /// In en, this message translates to:
  /// **'Qualifications'**
  String get qualifications;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get next;

  /// No description provided for @submitRegistration.
  ///
  /// In en, this message translates to:
  /// **'Submit registration'**
  String get submitRegistration;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phone;

  /// No description provided for @nic.
  ///
  /// In en, this message translates to:
  /// **'NIC'**
  String get nic;

  /// No description provided for @dob.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dob;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// No description provided for @dsDivision.
  ///
  /// In en, this message translates to:
  /// **'DS Division'**
  String get dsDivision;

  /// No description provided for @gnDivision.
  ///
  /// In en, this message translates to:
  /// **'GN Division'**
  String get gnDivision;

  /// No description provided for @club.
  ///
  /// In en, this message translates to:
  /// **'Youth Club'**
  String get club;

  /// No description provided for @languageSkills.
  ///
  /// In en, this message translates to:
  /// **'Language Skills'**
  String get languageSkills;

  /// No description provided for @hubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your hub for membership, announcements, events, and club messaging.'**
  String get hubSubtitle;

  /// No description provided for @completeRegistrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Finish your member profile to activate membership.'**
  String get completeRegistrationSubtitle;

  /// No description provided for @completeRegistrationBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish your registration'**
  String get completeRegistrationBannerTitle;

  /// No description provided for @completeRegistrationBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Your profile is incomplete. Complete registration to unlock full membership features.'**
  String get completeRegistrationBannerBody;

  /// No description provided for @completeRegistrationBannerAction.
  ///
  /// In en, this message translates to:
  /// **'Complete now'**
  String get completeRegistrationBannerAction;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @updateDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your profile, contacts, and club info current.'**
  String get updateDetailsSubtitle;

  /// No description provided for @newsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open the News tab for updates.'**
  String get newsSubtitle;

  /// No description provided for @eventsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse and RSVP in the Events tab.'**
  String get eventsSubtitle;

  /// No description provided for @adminDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage members, publish news and events, and reach youth across districts.'**
  String get adminDashboardSubtitle;

  /// No description provided for @quickAccess.
  ///
  /// In en, this message translates to:
  /// **'Quick access'**
  String get quickAccess;

  /// No description provided for @publish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publish;

  /// No description provided for @otherTools.
  ///
  /// In en, this message translates to:
  /// **'Other tools'**
  String get otherTools;

  /// No description provided for @confirmEmail.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get confirmEmail;

  /// No description provided for @sentLinkTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to'**
  String get sentLinkTo;

  /// No description provided for @openLinkPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from that email to activate your account. Check your spam or junk folder if you do not see it. You cannot log in until your email is confirmed.'**
  String get openLinkPrompt;

  /// No description provided for @goToSignIn.
  ///
  /// In en, this message translates to:
  /// **'I confirmed — go to sign in'**
  String get goToSignIn;

  /// No description provided for @resendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendEmail;

  /// No description provided for @useDifferentEmail.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get useDifferentEmail;

  /// No description provided for @enterVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get enterVerificationCode;

  /// No description provided for @verifyAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify & continue'**
  String get verifyAndContinue;

  /// No description provided for @invalidVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your email.'**
  String get invalidVerificationCode;

  /// No description provided for @codeResent.
  ///
  /// In en, this message translates to:
  /// **'A new code was sent. Check your inbox.'**
  String get codeResent;

  /// No description provided for @codeResendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not resend right now. Wait a moment and try again.'**
  String get codeResendFailed;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @preferredName.
  ///
  /// In en, this message translates to:
  /// **'Preferred name'**
  String get preferredName;

  /// No description provided for @occupation.
  ///
  /// In en, this message translates to:
  /// **'Occupation / job'**
  String get occupation;

  /// No description provided for @occupationHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — e.g. student, teacher, technician'**
  String get occupationHint;

  /// No description provided for @occupationTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use 120 characters or fewer'**
  String get occupationTooLong;

  /// No description provided for @youthClub.
  ///
  /// In en, this message translates to:
  /// **'Youth club'**
  String get youthClub;

  /// No description provided for @alreadyYouthClubMember.
  ///
  /// In en, this message translates to:
  /// **'Are you already a member of a youth club?'**
  String get alreadyYouthClubMember;

  /// No description provided for @youthClubMemberNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get youthClubMemberNo;

  /// No description provided for @youthClubMemberYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get youthClubMemberYes;

  /// No description provided for @youthClubName.
  ///
  /// In en, this message translates to:
  /// **'Club name'**
  String get youthClubName;

  /// No description provided for @youthClubNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your youth club name'**
  String get youthClubNameHint;

  /// No description provided for @youthClubNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your club name'**
  String get youthClubNameRequired;

  /// No description provided for @youthClubRegistrationNo.
  ///
  /// In en, this message translates to:
  /// **'Membership / registration number'**
  String get youthClubRegistrationNo;

  /// No description provided for @youthClubRegistrationNoHint.
  ///
  /// In en, this message translates to:
  /// **'Letters and numbers (e.g. YC-2024-01)'**
  String get youthClubRegistrationNoHint;

  /// No description provided for @youthClubRegistrationNoRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your registration number'**
  String get youthClubRegistrationNoRequired;

  /// No description provided for @youthClubRegistrationNoInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use letters and numbers only (max 40)'**
  String get youthClubRegistrationNoInvalid;

  /// No description provided for @selectClubFromList.
  ///
  /// In en, this message translates to:
  /// **'Optional — select a club from the list'**
  String get selectClubFromList;

  /// No description provided for @chooseAClub.
  ///
  /// In en, this message translates to:
  /// **'Choose a club'**
  String get chooseAClub;

  /// No description provided for @locationBasedTitle.
  ///
  /// In en, this message translates to:
  /// **'Where are you based?'**
  String get locationBasedTitle;

  /// No description provided for @locationBasedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used for youth club suggestions and regional updates.'**
  String get locationBasedSubtitle;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'Phone (+94…)'**
  String get phoneHint;

  /// No description provided for @completenessPercent.
  ///
  /// In en, this message translates to:
  /// **'Completeness {percent}%'**
  String completenessPercent(int percent);

  /// No description provided for @missingPrefix.
  ///
  /// In en, this message translates to:
  /// **'Missing: {items}'**
  String missingPrefix(String items);

  /// No description provided for @selectAllThatApply.
  ///
  /// In en, this message translates to:
  /// **'Select all that apply.'**
  String get selectAllThatApply;

  /// No description provided for @otherQualification.
  ///
  /// In en, this message translates to:
  /// **'Other qualification'**
  String get otherQualification;

  /// No description provided for @otherQualificationHint.
  ///
  /// In en, this message translates to:
  /// **'NVQ / vocational qualification'**
  String get otherQualificationHint;

  /// No description provided for @otherQualificationTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use 250 characters or fewer'**
  String get otherQualificationTooLong;

  /// No description provided for @selectLanguagesYouSpeak.
  ///
  /// In en, this message translates to:
  /// **'Select languages you can speak.'**
  String get selectLanguagesYouSpeak;

  /// No description provided for @langSinhala.
  ///
  /// In en, this message translates to:
  /// **'Sinhala'**
  String get langSinhala;

  /// No description provided for @langTamil.
  ///
  /// In en, this message translates to:
  /// **'Tamil'**
  String get langTamil;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @validEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get validEmail;

  /// No description provided for @validPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get validPhone;

  /// No description provided for @nicRequired.
  ///
  /// In en, this message translates to:
  /// **'NIC is required'**
  String get nicRequired;

  /// No description provided for @nicInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid NIC (123456789V or 12 digits)'**
  String get nicInvalid;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Use at least {count} characters'**
  String passwordMinLength(int count);

  /// No description provided for @dobRequired.
  ///
  /// In en, this message translates to:
  /// **'Date of birth is required'**
  String get dobRequired;

  /// No description provided for @ageTooYoung.
  ///
  /// In en, this message translates to:
  /// **'You must be at least {age} years old'**
  String ageTooYoung(int age);

  /// No description provided for @ageTooOld.
  ///
  /// In en, this message translates to:
  /// **'Membership age limit is {age}'**
  String ageTooOld(int age);

  /// No description provided for @noAnnouncementsYet.
  ///
  /// In en, this message translates to:
  /// **'No announcements yet.'**
  String get noAnnouncementsYet;

  /// No description provided for @noEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No published events yet.'**
  String get noEventsYet;

  /// No description provided for @chatListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your chats with SYU. You can reply while a chat is open.'**
  String get chatListSubtitle;

  /// No description provided for @noConversationsYet.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet. When an admin messages you, it will appear here.'**
  String get noConversationsYet;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @resetPasswordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email and we will send a reset link.'**
  String get resetPasswordPrompt;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkYourEmail;

  /// No description provided for @resetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for {email}, we sent a password reset link.'**
  String resetLinkSent(String email);

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @createAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Create your account to start membership registration.'**
  String get createAccountPrompt;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccount;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get genderOther;

  /// No description provided for @genderPreferNot.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get genderPreferNot;

  /// No description provided for @fieldProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get fieldProfile;

  /// No description provided for @notificationsAndAccount.
  ///
  /// In en, this message translates to:
  /// **'Notifications & account'**
  String get notificationsAndAccount;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @browseAndMessage.
  ///
  /// In en, this message translates to:
  /// **'Browse & message'**
  String get browseAndMessage;

  /// No description provided for @quickShortlist.
  ///
  /// In en, this message translates to:
  /// **'Quick shortlist'**
  String get quickShortlist;

  /// No description provided for @memberThreads.
  ///
  /// In en, this message translates to:
  /// **'Member threads'**
  String get memberThreads;

  /// No description provided for @newMessages.
  ///
  /// In en, this message translates to:
  /// **'New messages'**
  String get newMessages;

  /// No description provided for @notifyAudiences.
  ///
  /// In en, this message translates to:
  /// **'Notify audiences'**
  String get notifyAudiences;

  /// No description provided for @announcements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcements;

  /// No description provided for @createAndRsvp.
  ///
  /// In en, this message translates to:
  /// **'Create & RSVP'**
  String get createAndRsvp;

  /// No description provided for @youthClubs.
  ///
  /// In en, this message translates to:
  /// **'Youth clubs'**
  String get youthClubs;

  /// No description provided for @summaries.
  ///
  /// In en, this message translates to:
  /// **'Summaries'**
  String get summaries;

  /// No description provided for @adminActions.
  ///
  /// In en, this message translates to:
  /// **'Admin actions'**
  String get adminActions;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @approvals.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get approvals;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @searchMembersHint.
  ///
  /// In en, this message translates to:
  /// **'Search name, email, NIC'**
  String get searchMembersHint;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @filtersWithCount.
  ///
  /// In en, this message translates to:
  /// **'Filters ({count})'**
  String filtersWithCount(int count);

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get statusSuspended;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @pageLabel.
  ///
  /// In en, this message translates to:
  /// **'Page {current}/{total}'**
  String pageLabel(int current, int total);

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @terminate.
  ///
  /// In en, this message translates to:
  /// **'Terminate'**
  String get terminate;

  /// No description provided for @reopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get reopen;

  /// No description provided for @terminateChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminate chat?'**
  String get terminateChatTitle;

  /// No description provided for @terminateChatBody.
  ///
  /// In en, this message translates to:
  /// **'The member will no longer be able to reply. Messages stay visible.'**
  String get terminateChatBody;

  /// No description provided for @clearChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all messages?'**
  String get clearChatTitle;

  /// No description provided for @clearChatBody.
  ///
  /// In en, this message translates to:
  /// **'Deletes every message in this chat and closes it. The member will no longer be able to reply.'**
  String get clearChatBody;

  /// No description provided for @messageMembers.
  ///
  /// In en, this message translates to:
  /// **'Message members'**
  String get messageMembers;

  /// No description provided for @messageAction.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageAction;

  /// No description provided for @terminated.
  ///
  /// In en, this message translates to:
  /// **'Terminated'**
  String get terminated;

  /// No description provided for @chatClosedHint.
  ///
  /// In en, this message translates to:
  /// **'This chat is closed. The member cannot reply. Tap Reopen to continue.'**
  String get chatClosedHint;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get messageHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @hideFilters.
  ///
  /// In en, this message translates to:
  /// **'Hide filters'**
  String get hideFilters;

  /// No description provided for @savedWithCount.
  ///
  /// In en, this message translates to:
  /// **'Saved {count}'**
  String savedWithCount(int count);

  /// No description provided for @rangeOf.
  ///
  /// In en, this message translates to:
  /// **'{from}–{to} of {total}'**
  String rangeOf(int from, int to, int total);

  /// No description provided for @chatTerminated.
  ///
  /// In en, this message translates to:
  /// **'Chat terminated'**
  String get chatTerminated;

  /// No description provided for @chatCleared.
  ///
  /// In en, this message translates to:
  /// **'Chat cleared'**
  String get chatCleared;

  /// No description provided for @chatReopened.
  ///
  /// In en, this message translates to:
  /// **'Chat reopened'**
  String get chatReopened;

  /// No description provided for @chatStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open — can reply'**
  String get chatStatusOpen;

  /// No description provided for @chatStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed — member cannot reply'**
  String get chatStatusClosed;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet — write below'**
  String get noMessagesYet;

  /// No description provided for @noMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages'**
  String get noMessages;

  /// No description provided for @selectMember.
  ///
  /// In en, this message translates to:
  /// **'Select member'**
  String get selectMember;

  /// No description provided for @searchNameOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Search name or email'**
  String get searchNameOrEmail;

  /// No description provided for @divisionAdmins.
  ///
  /// In en, this message translates to:
  /// **'Division admins'**
  String get divisionAdmins;

  /// No description provided for @divisionAdminsHint.
  ///
  /// In en, this message translates to:
  /// **'Contacts for this district'**
  String get divisionAdminsHint;

  /// No description provided for @noDivisionAdmins.
  ///
  /// In en, this message translates to:
  /// **'No division admins for this district yet'**
  String get noDivisionAdmins;

  /// No description provided for @divisionAdminContactRequired.
  ///
  /// In en, this message translates to:
  /// **'Add your name and phone number'**
  String get divisionAdminContactRequired;

  /// No description provided for @divisionAdminContactBody.
  ///
  /// In en, this message translates to:
  /// **'Division admins must share a name and phone so district admins can reach you.'**
  String get divisionAdminContactBody;

  /// No description provided for @addContactDetails.
  ///
  /// In en, this message translates to:
  /// **'Add contact details'**
  String get addContactDetails;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @phoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phoneRequired;

  /// No description provided for @userTypes.
  ///
  /// In en, this message translates to:
  /// **'User Types'**
  String get userTypes;

  /// No description provided for @userTypeMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get userTypeMembers;

  /// No description provided for @userTypeDistrictAdmins.
  ///
  /// In en, this message translates to:
  /// **'District admins'**
  String get userTypeDistrictAdmins;

  /// No description provided for @userTypeDivisionAdmins.
  ///
  /// In en, this message translates to:
  /// **'Division admins'**
  String get userTypeDivisionAdmins;
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
      <String>['en', 'si', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'si':
      return AppLocalizationsSi();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
