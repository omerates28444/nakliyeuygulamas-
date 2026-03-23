import codecs
import re

path = 'lib/screens/profile_screen.dart'
with codecs.open(path, 'r', 'utf-8') as f:
    code = f.read()

# Normalize
code = code.replace('\r\n', '\n')

code = code.replace("final user = FirebaseAuth.instance.currentUser;", "final user = db.auth.currentUser;")

code = code.replace("final cred = EmailAuthProvider.credential(email: email, password: pass);\n      await user.reauthenticateWithCredential(cred);", "await db.auth.signInWithPassword(email: email, password: pass);")

code = code.replace("final snap = await db.collection(\"users\").doc(uid).get();\n    final data = snap.data() ?? {};", 'final data = await db.from("users").select().eq("id", uid).maybeSingle() ?? {};')

code = code.replace("\"updatedAt\": FieldValue.serverTimestamp(),", "\"updatedAt\": DateTime.now().toUtc().toIso8601String(),")

code = code.replace("await FirebaseAuth.instance.currentUser!\n          .verifyBeforeUpdateEmail(newEmail);", "await db.auth.updateUser(UserAttributes(email: newEmail));")
code = code.replace("await FirebaseAuth.instance.currentUser!.verifyBeforeUpdateEmail(newEmail);", "await db.auth.updateUser(UserAttributes(email: newEmail));")

code = code.replace("FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>", "FutureBuilder<Map<String, dynamic>?>")

code = code.replace("""FirebaseFirestore.instance
                            .collection("users")
                            .doc(AuthService().currentUser?.uid)
                            .get()""", 'db.from("users").select().eq("id", AuthService().currentUser?.id ?? "").maybeSingle()')


code = code.replace("StreamBuilder<QuerySnapshot<Map<String, dynamic>>>", "StreamBuilder<List<Map<String, dynamic>>>")

# Using re.sub for the complex multi-line chunk to ignore spaces perfectly
pattern = r'stream:\s*FirebaseFirestore\.instance\s*\.collection\("loads"\)\s*\.where\(\s*appState\.role == "driver"\s*\?\s*"acceptedDriverId"\s*:\s*"shipperId",\s*isEqualTo:\s*AuthService\(\)\.currentUser\?\.uid\)\s*\.where\("status", isEqualTo:\s*"done"\)\s*\.orderBy\("doneAt", descending:\s*true\)\s*\.snapshots\(\),'

replacement = """stream: db
                    .from("loads")
                    .stream(primaryKey: ['id'])
                    .eq(appState.role == "driver" ? "acceptedDriverId" : "shipperId", AuthService().currentUser?.id ?? "")
                    .eq("status", "done")
                    .order("doneAt", ascending: false),"""

code = re.sub(pattern, replacement, code, flags=re.MULTILINE)

code = code.replace("snap.data!.docs.map((d) => Load.fromDoc(d)).toList();", "snap.data!.map((d) => Load.fromMap(d)).toList();")

with codecs.open(path, 'w', 'utf-8') as f:
    f.write(code)

print("Applied fix_profile3.py")
