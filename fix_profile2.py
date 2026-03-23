import codecs

path = 'lib/screens/profile_screen.dart'
with codecs.open(path, 'r', 'utf-8') as f:
    code = f.read()

# 1. _reauthWithPassword inner
code = code.replace(
"""  Future<bool> _reauthWithPassword(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;""",
"""  Future<bool> _reauthWithPassword(BuildContext context) async {
    final user = db.auth.currentUser;
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
      await db.auth.signInWithPassword(email: email, password: pass);
      return true;
    } catch (e) {"""
)

# 2. _loadProfile
code = code.replace(
"""    final snap = await db.collection("users").doc(uid).get();
    final data = snap.data() ?? {};""",
"""    final data = await db.from("users").select().eq("id", uid).maybeSingle() ?? {};"""
)

# 3. FieldValue
code = code.replace(
"""      final update = <String, dynamic>{
        "name": name,
        "phone": phone,
        "city": city,
        "updatedAt": FieldValue.serverTimestamp(),
      };""",
"""      final update = <String, dynamic>{
        "name": name,
        "phone": phone,
        "city": city,
        "updatedAt": DateTime.now().toUtc().toIso8601String(),
      };"""
)

# 4. Rating card
code = code.replace(
"""                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance
                            .collection("users")
                            .doc(AuthService().currentUser?.uid)
                            .get(),
                        builder: (context, snap) {""",
"""                      FutureBuilder<Map<String, dynamic>?>(
                        future: db
                            .from("users")
                            .select()
                            .eq("id", AuthService().currentUser?.id ?? "")
                            .maybeSingle(),
                        builder: (context, snap) {"""
)

# 5. Past Jobs StreamBuilder
code = code.replace(
"""              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                    .order("doneAt", ascending: false),
                builder: (context, snap) {"""
)

code = code.replace(
"""                  final jobs =
                      snap.data!.docs.map((d) => Load.fromDoc(d)).toList();""",
"""                  final jobs =
                      snap.data!.map((d) => Load.fromMap(d)).toList();"""
)

with codecs.open(path, 'w', 'utf-8') as f:
    f.write(code)

print("Applied fix_profile2.py")
