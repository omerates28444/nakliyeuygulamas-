import codecs

def replace_in_file(path, replacements):
    with codecs.open(path, 'r', 'utf-8') as f:
        content = f.read()

    for old, new in replacements:
        if old in content:
            content = content.replace(old, new)
        else:
            print(f"Warning: Chunk not found in {path}\n{old}")

    with codecs.open(path, 'w', 'utf-8') as f:
        f.write(content)

replacements_map = [
    (
        'if (appState.role != "shipper") return;',
        'final isDriverView = appState.isAdmin ? appState.adminViewRole == "driver" : appState.role == "driver";\n    if (isDriverView) return;'
    ),
    (
        'final isDriver = appState.role == "driver";',
        'final isDriver = appState.isAdmin ? appState.adminViewRole == "driver" : appState.role == "driver";'
    )
]

replacements_inbox = [
    (
        'if (appState.role != "shipper") {',
        'final isShipperView = appState.isAdmin ? appState.adminViewRole == "shipper" : appState.role == "shipper";\n    if (!isShipperView) {'
    )
]

replace_in_file('lib/screens/osm_map_home_screen.dart', replacements_map)
replace_in_file('lib/screens/offers_inbox_screen.dart', replacements_inbox)
print("Done fixing admin view role checks.")
