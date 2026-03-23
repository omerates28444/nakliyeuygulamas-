import codecs

with codecs.open('lib/screens/profile_screen.dart', 'r', 'utf-8') as f:
    code = f.read()

code = code.replace(
    '// final isDriver = appState.role == "driver";',
    'final isDriver = appState.role == "driver";'
)

code = code.replace(
    'final okReauth = await _reauthWithPassword(context);',
    'if (!context.mounted) return;\n      final okReauth = await _reauthWithPassword(context);'
)

with codecs.open('lib/screens/profile_screen.dart', 'w', 'utf-8') as f:
    f.write(code)
