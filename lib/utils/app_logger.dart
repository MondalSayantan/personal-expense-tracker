class AppLogger {
  static void log(String message) {
    // In a production app, you might want to use a proper logging package
    // or send logs to a service like Firebase Crashlytics
    print('[ExpenseTracker] $message');
  }
}
