import codecs

path = 'lib/screens/profile_screen.dart'
with codecs.open(path, 'r', 'utf-8') as f:
    code = f.read()

# 1. Imports
code = code.replace("import 'package:cloud_firestore/cloud_firestore.dart';", "import 'package:supabase_flutter/supabase_flutter.dart';")
code = code.replace("import 'package:firebase_auth/firebase_auth.dart';", "")

# 2. Instances
code = code.replace("final db = FirebaseFirestore.instance;", "final db = Supabase.instance.client;")

# 3. _reauthWithPassword
code = code.replace(
"""  Future<bool> _reauthWithPassword(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;""",
"""  Future<bool> _reauthWithPassword(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;"""
)
code = code.replace(
"""    try {
      final email = user.email!;
      final cred = EmailAuthProvider.credential(email: email, password: pass);
      await user.reauthenticateWithCredential(cred);
      return true;
    } catch (e) {""",
"""    try {
      final email = user.email!;
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: pass);
      return true;
    } catch (e) {"""
)

# 4. _loadProfile
code = code.replace("final uid = auth.currentUser?.uid;", "final uid = auth.currentUser?.id;")
code = code.replace(
"""    final snap = await db.collection("users").doc(uid).get();
    final data = snap.data() ?? {};""",
"""    final data = await db.from("users").select().eq("id", uid).maybeSingle() ?? {};"""
)

# 5. _saveProfile
code = code.replace(
r"""      final update = <String, dynamic>{
        "name": name,
        "phone": phone,
        "city": city,
        "updatedAt": FieldValue.serverTimestamp(),
      };""",
r"""      final update = <String, dynamic>{
        "name": name,
        "phone": phone,
        "city": city,
        "updatedAt": DateTime.now().toUtc().toIso8601String(),
      };"""
)
code = code.replace(
"""      await db.collection("users").doc(uid).update(update);""",
"""      if (!context.mounted) return;
      await db.from("users").update(update).eq("id", uid);"""
)

# 6. _changePassword and _changeEmail replaces
code = code.replace("await FirebaseAuth.instance.currentUser!.updatePassword(p1);", "await db.auth.updateUser(UserAttributes(password: p1));")
code = code.replace("await FirebaseAuth.instance.currentUser!\n          .verifyBeforeUpdateEmail(newEmail);", "await db.auth.updateUser(UserAttributes(email: newEmail));")
code = code.replace("await FirebaseAuth.instance.currentUser!.verifyBeforeUpdateEmail(newEmail);", "await db.auth.updateUser(UserAttributes(email: newEmail));")

code = code.replace("""    try {
      if (!context.mounted) return;
      final okReauth = await _reauthWithPassword(context);
      if (!okReauth) return;

      await FirebaseAuth.instance.currentUser!.updatePassword(p1);""",
"""    try {
      final okReauth = await _reauthWithPassword(context);
      if (!okReauth) return;

      if (!context.mounted) return;
      await db.auth.updateUser(UserAttributes(password: p1));""")

code = code.replace("""    try {
      if (!context.mounted) return;
      final okReauth = await _reauthWithPassword(context);
      if (!okReauth) return;

      await FirebaseAuth.instance.currentUser!
          .verifyBeforeUpdateEmail(newEmail);""",
"""    try {
      final okReauth = await _reauthWithPassword(context);
      if (!okReauth) return;

      if (!context.mounted) return;
      await db.auth.updateUser(UserAttributes(email: newEmail));""")

# 7. Rating card
code = code.replace("""                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance
                            .collection("users")
                            .doc(AuthService().currentUser?.uid)
                            .get(),
                        builder: (context, snap) {
                          final d = snap.data?.data() ?? {};""",
"""                      FutureBuilder<Map<String, dynamic>?>(
                        future: db
                            .from("users")
                            .select()
                            .eq("id", AuthService().currentUser?.id ?? "")
                            .maybeSingle(),
                        builder: (context, snap) {
                          final d = snap.data ?? {};""")

# 8. Past Jobs StreamBuilder
code = code.replace("""              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection("loads")
                    .where(
                        appState.role == "driver"
                            ? "acceptedDriverId"
                            : "shipperId",
                        isEqualTo: AuthService().currentUser?.uid)
                    .where("status", isEqualTo: "done")
                    .orderBy("doneAt", descending: true)
                    .snapshots(),
                builder: (context, snap) {""",
"""              StreamBuilder<List<Map<String, dynamic>>>(
                stream: db
                    .from("loads")
                    .stream(primaryKey: ['id'])
                    .eq(appState.role == "driver" ? "acceptedDriverId" : "shipperId", AuthService().currentUser?.id ?? "")
                    .eq("status", "done")
                    .order("createdAt", ascending: false),
                builder: (context, snap) {""")

code = code.replace("""                  final jobs =
                      snap.data!.docs.map((d) => Load.fromDoc(d)).toList();""",
"""                  final jobs =
                      snap.data!.map((d) => Load.fromMap(d)).toList();""")

code = code.replace("appState.notifyListeners();", "// ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member\n      appState.notifyListeners();")

# Remove unused variables if any
code = code.replace("""    final isDriver = appState.role == "driver";
    final cs = Theme.of(context).colorScheme;

    return Scaffold(""", """    // final isDriver = appState.role == "driver";
    // final cs = Theme.of(context).colorScheme;

    return Scaffold(""")

with codecs.open(path, 'w', 'utf-8') as f:
    f.write(code)

print("Restored Supabase and fixed Context checks.")
