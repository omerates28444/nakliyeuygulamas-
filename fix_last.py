import codecs

def replace_in_file(path, old, new):
    with codecs.open(path, 'r', 'utf-8') as f:
        content = f.read()
    if old in content:
        content = content.replace(old, new)
        with codecs.open(path, 'w', 'utf-8') as f:
            f.write(content)
    else:
        print(f"Warning: Chunk not found in {path}")

# Fix app_shell.dart
replace_in_file('lib/screens/app_shell.dart', 'onPopInvoked: (didPop) async {', 'onPopInvokedWithResult: (didPop, result) async {')

# Fix login_screen.dart
replace_in_file('lib/screens/login_screen.dart', 'onPopInvoked: (didPop) async {', 'onPopInvokedWithResult: (didPop, result) async {')

# Fix admin_dashboard_screen.dart unused local variable
replace_in_file('lib/screens/admin_dashboard_screen.dart', 'final cs = Theme.of(context).colorScheme;', '// final cs = Theme.of(context).colorScheme;')

# Fix offers_inbox_screen.dart use_build_context_synchronously
replace_in_file('lib/screens/offers_inbox_screen.dart', '                          await _rateUserDialog(', '                          if (!context.mounted) return;\n                          await _rateUserDialog(')

# Fix profile_screen.dart issues
replace_in_file('lib/screens/profile_screen.dart', '      await db.auth.updateUser(UserAttributes(password: p1));', '      if (!context.mounted) return;\n      await db.auth.updateUser(UserAttributes(password: p1));')
replace_in_file('lib/screens/profile_screen.dart', '      await db.auth.updateUser(UserAttributes(email: newEmail));', '      if (!context.mounted) return;\n      await db.auth.updateUser(UserAttributes(email: newEmail));')
replace_in_file('lib/screens/profile_screen.dart', 'final isDriver = appState.role == "driver";', '// final isDriver = appState.role == "driver";')
replace_in_file('lib/screens/profile_screen.dart', 'final cs = Theme.of(context).colorScheme;', '// final cs = Theme.of(context).colorScheme;')

print("Done fixing last warnings.")
