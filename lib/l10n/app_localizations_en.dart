// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SYU Sri Lanka';

  @override
  String get riseTogether => 'Rise together.';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get completeRegistration => 'Complete registration';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get signInPrompt => 'Sign in to continue with SYU Sri Lanka.';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get newToSyu => 'New to SYU?';

  @override
  String get createAccount => 'Create account';

  @override
  String get home => 'Home';

  @override
  String get news => 'News';

  @override
  String get events => 'Events';

  @override
  String get chat => 'Chat';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get changeLanguage => 'Change Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get notifications => 'Notifications';

  @override
  String get updateDetails => 'Update your details';

  @override
  String get latestAnnouncements => 'Latest announcements';

  @override
  String get upcomingEvents => 'Upcoming events';

  @override
  String get messagesFromSyu => 'Messages from SYU';

  @override
  String get adminDashboard => 'Admin dashboard';

  @override
  String get members => 'Members';

  @override
  String get clubs => 'Clubs';

  @override
  String get broadcast => 'Broadcast';

  @override
  String get reports => 'Reports';

  @override
  String get audit => 'Audit';

  @override
  String get personal => 'Personal';

  @override
  String get location => 'Location';

  @override
  String get qualifications => 'Qualifications';

  @override
  String get review => 'Review';

  @override
  String get next => 'Continue';

  @override
  String get submitRegistration => 'Submit registration';

  @override
  String get fullName => 'Full Name';

  @override
  String get phone => 'Phone Number';

  @override
  String get nic => 'NIC';

  @override
  String get dob => 'Date of Birth';

  @override
  String get gender => 'Gender';

  @override
  String get district => 'District';

  @override
  String get dsDivision => 'DS Division';

  @override
  String get gnDivision => 'GN Division';

  @override
  String get club => 'Youth Club';

  @override
  String get languageSkills => 'Language Skills';

  @override
  String get hubSubtitle =>
      'Your hub for membership, announcements, events, and club messaging.';

  @override
  String get completeRegistrationSubtitle =>
      'Finish your member profile to activate membership.';

  @override
  String get updateDetailsSubtitle =>
      'Keep your profile, contacts, and club info current.';

  @override
  String get newsSubtitle => 'Open the News tab for updates.';

  @override
  String get eventsSubtitle => 'Browse and RSVP in the Events tab.';

  @override
  String get adminDashboardSubtitle =>
      'Manage members, publish news and events, and reach youth across districts.';

  @override
  String get quickAccess => 'Quick access';

  @override
  String get publish => 'Publish';

  @override
  String get otherTools => 'Other tools';

  @override
  String get confirmEmail => 'Confirm your email';

  @override
  String get sentLinkTo => 'We sent a 6-digit code to';

  @override
  String get openLinkPrompt =>
      'Enter the code from that email to activate your account. Check your spam or junk folder if you do not see it. You cannot log in until your email is confirmed.';

  @override
  String get goToSignIn => 'I confirmed — go to sign in';

  @override
  String get resendEmail => 'Resend code';

  @override
  String get useDifferentEmail => 'Use a different email';

  @override
  String get enterVerificationCode => 'Verification code';

  @override
  String get verifyAndContinue => 'Verify & continue';

  @override
  String get invalidVerificationCode =>
      'Enter the 6-digit code from your email.';

  @override
  String get codeResent => 'A new code was sent. Check your inbox.';

  @override
  String get codeResendFailed =>
      'Could not resend right now. Wait a moment and try again.';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get preferredName => 'Preferred name';

  @override
  String get phoneHint => 'Phone (+94…)';

  @override
  String completenessPercent(int percent) {
    return 'Completeness $percent%';
  }

  @override
  String missingPrefix(String items) {
    return 'Missing: $items';
  }

  @override
  String get selectAllThatApply => 'Select all that apply.';

  @override
  String get selectLanguagesYouSpeak => 'Select languages you can speak.';

  @override
  String get langSinhala => 'Sinhala';

  @override
  String get langTamil => 'Tamil';

  @override
  String get langEnglish => 'English';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get fieldRequired => 'Required';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get validEmail => 'Enter a valid email';

  @override
  String get validPhone => 'Enter a valid phone number';

  @override
  String get nicRequired => 'NIC is required';

  @override
  String get nicInvalid => 'Enter a valid NIC (123456789V or 12 digits)';

  @override
  String passwordMinLength(int count) {
    return 'Use at least $count characters';
  }

  @override
  String get dobRequired => 'Date of birth is required';

  @override
  String ageTooYoung(int age) {
    return 'You must be at least $age years old';
  }

  @override
  String ageTooOld(int age) {
    return 'Membership age limit is $age';
  }

  @override
  String get noAnnouncementsYet => 'No announcements yet.';

  @override
  String get noEventsYet => 'No published events yet.';

  @override
  String get chatListSubtitle =>
      'Your chats with SYU. You can reply while a chat is open.';

  @override
  String get noConversationsYet =>
      'No conversations yet. When an admin messages you, it will appear here.';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get resetPasswordPrompt =>
      'Enter your account email and we will send a reset link.';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get checkYourEmail => 'Check your email';

  @override
  String resetLinkSent(String email) {
    return 'If an account exists for $email, we sent a password reset link.';
  }

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get createAccountPrompt =>
      'Create your account to start membership registration.';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderMale => 'Male';

  @override
  String get genderOther => 'Other';

  @override
  String get genderPreferNot => 'Prefer not to say';

  @override
  String get fieldProfile => 'Profile';

  @override
  String get notificationsAndAccount => 'Notifications & account';

  @override
  String get saved => 'Saved';

  @override
  String get browseAndMessage => 'Browse & message';

  @override
  String get quickShortlist => 'Quick shortlist';

  @override
  String get memberThreads => 'Member threads';

  @override
  String get newMessages => 'New messages';

  @override
  String get notifyAudiences => 'Notify audiences';

  @override
  String get announcements => 'Announcements';

  @override
  String get createAndRsvp => 'Create & RSVP';

  @override
  String get youthClubs => 'Youth clubs';

  @override
  String get summaries => 'Summaries';

  @override
  String get adminActions => 'Admin actions';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get approvals => 'Approvals';

  @override
  String get all => 'All';

  @override
  String get searchMembersHint => 'Search name, email, NIC';

  @override
  String get filters => 'Filters';

  @override
  String filtersWithCount(int count) {
    return 'Filters ($count)';
  }

  @override
  String get statusActive => 'Active';

  @override
  String get statusSuspended => 'Suspended';

  @override
  String get statusPending => 'Pending';

  @override
  String pageLabel(int current, int total) {
    return 'Page $current/$total';
  }

  @override
  String get clear => 'Clear';

  @override
  String get terminate => 'Terminate';

  @override
  String get reopen => 'Reopen';

  @override
  String get terminateChatTitle => 'Terminate chat?';

  @override
  String get terminateChatBody =>
      'The member will no longer be able to reply. Messages stay visible.';

  @override
  String get clearChatTitle => 'Clear all messages?';

  @override
  String get clearChatBody =>
      'Deletes every message in this chat and closes it. The member will no longer be able to reply.';

  @override
  String get messageMembers => 'Message members';

  @override
  String get messageAction => 'Message';

  @override
  String get terminated => 'Terminated';

  @override
  String get chatClosedHint =>
      'This chat is closed. The member cannot reply. Tap Reopen to continue.';

  @override
  String get messageHint => 'Message…';

  @override
  String get cancel => 'Cancel';

  @override
  String get hideFilters => 'Hide filters';

  @override
  String savedWithCount(int count) {
    return 'Saved $count';
  }

  @override
  String rangeOf(int from, int to, int total) {
    return '$from–$to of $total';
  }

  @override
  String get chatTerminated => 'Chat terminated';

  @override
  String get chatCleared => 'Chat cleared';

  @override
  String get chatReopened => 'Chat reopened';

  @override
  String get chatStatusOpen => 'Open — can reply';

  @override
  String get chatStatusClosed => 'Closed — member cannot reply';

  @override
  String get noMessagesYet => 'No messages yet — write below';

  @override
  String get noMessages => 'No messages';

  @override
  String get selectMember => 'Select member';

  @override
  String get searchNameOrEmail => 'Search name or email';
}
