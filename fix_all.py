import re
import codecs

# ----------------- admin_dashboard_screen.dart -----------------
path = 'lib/screens/admin_dashboard_screen.dart'
with codecs.open(path, 'r', 'utf-8') as f:
    code = f.read()

code = re.sub(
    r"import 'package:cloud_firestore/cloud_firestore\.dart';",
    r"import 'package:supabase_flutter/supabase_flutter.dart';",
    code
)

code = re.sub(
    r"final db = FirebaseFirestore\.instance;",
    r"final db = Supabase.instance.client;",
    code
)

code = re.sub(
    r"StreamBuilder<QuerySnapshot>\(\s*stream: db\.collection\(\"loads\"\)\.snapshots\(\),",
    r"StreamBuilder<List<Map<String,dynamic>>>(\n            stream: db.from(\"loads\").stream(primaryKey: ['id']),",
    code
)

code = re.sub(
    r"StreamBuilder<QuerySnapshot>\(\s*stream: db\.collection\(\"users\"\)\.snapshots\(\),",
    r"StreamBuilder<List<Map<String,dynamic>>>(\n                stream: db.from(\"users\").stream(primaryKey: ['id']),",
    code
)

code = re.sub(
    r"final totalUsers = userSnap\.data\?\.docs\.length \?\? 0;",
    r"final totalUsers = userSnap.data?.length ?? 0;",
    code
)

code = re.sub(
    r"final allLoads = loadSnap\.data\?\.docs \?\? \[\];",
    r"final allLoads = loadSnap.data ?? [];",
    code
)

code = re.sub(
    r"for \(var doc in allLoads\) \{\s*final data = doc\.data\(\) as Map<String, dynamic>;",
    r"for (var data in allLoads) {",
    code
)

code = re.sub(
    r"StreamBuilder<QuerySnapshot>\(\s*// En son eklenen 5(.*?\n)\s*stream: db\.collection\(\"loads\"\)\.orderBy\(\"createdAt\", descending: true\)\.limit\(5\)\.snapshots\(\),",
    r"StreamBuilder<List<Map<String,dynamic>>>(\n              // En son eklenen 5\1              stream: db.from(\"loads\").stream(primaryKey: ['id']).order(\"createdAt\", ascending: false).limit(5),",
    code
)

code = re.sub(
    r"final docs = snap\.data!\.docs;",
    r"final docs = snap.data!;",
    code
)

code = re.sub(
    r"children: docs\.map\(\(doc\) \{\s*final data = doc\.data\(\) as Map<String, dynamic>;",
    r"children: docs.map((data) {",
    code
)

with codecs.open(path, 'w', 'utf-8') as f:
    f.write(code)


# ----------------- user_management_screen.dart -----------------
path = 'lib/screens/user_management_screen.dart'
with codecs.open(path, 'r', 'utf-8') as f:
    code = f.read()

code = re.sub(
    r"import 'package:cloud_firestore/cloud_firestore\.dart';",
    r"import 'package:supabase_flutter/supabase_flutter.dart';",
    code
)

code = re.sub(
    r"final db = FirebaseFirestore\.instance;",
    r"final db = Supabase.instance.client;",
    code
)

code = re.sub(
    r"StreamBuilder<QuerySnapshot>\(\s*stream: db\.collection\(\"users\"\)\.orderBy\(\"createdAt\", descending: true\)\.snapshots\(\),",
    r"StreamBuilder<List<Map<String,dynamic>>>(\n        stream: db.from(\"users\").stream(primaryKey: ['id']).order(\"createdAt\", ascending: false),",
    code
)

code = re.sub(
    r"final docs = snap\.data!\.docs;",
    r"final docs = snap.data!;",
    code
)

code = re.sub(
    r"final data = docs\[index\]\.data\(\) as Map<String, dynamic>;\s*final uid = docs\[index\]\.id;",
    r"final data = docs[index];\n              final uid = data['id'].toString();",
    code
)

code = re.sub(
    r"await FirebaseFirestore\.instance\.collection\(\"users\"\)\.doc\(uid\)\.update\(\{\s*\"isVerified\": true,\s*\"verifiedAt\": FieldValue\.serverTimestamp\(\),\s*\}\);",
    r'await Supabase.instance.client.from("users").update({"isVerified": true, "verifiedAt": DateTime.now().toUtc().toIso8601String(),}).eq("id", uid);',
    code
)


with codecs.open(path, 'w', 'utf-8') as f:
    f.write(code)

# ----------------- load_create_screen.dart -----------------
path = 'lib/screens/load_create_screen.dart'
with codecs.open(path, 'r', 'utf-8') as f:
    code = f.read()

code = re.sub(
    r"import 'package:cloud_firestore/cloud_firestore\.dart';\s*import 'package:firebase_auth/firebase_auth\.dart';",
    r"import 'package:supabase_flutter/supabase_flutter.dart';\nimport '../services/auth_service.dart';",
    code
)

code = re.sub(
    r"final uid = FirebaseAuth\.instance\.currentUser\?\.uid;",
    r"final uid = AuthService().currentUser?.id;",
    code
)

code = re.sub(
    r"await FirebaseFirestore\.instance\.collection\(\"loads\"\)\.add\(\{([\s\S]*?)\"pickupDate\": Timestamp\.fromDate\(pickupDate\),([\s\S]*?)\"createdAt\": FieldValue\.serverTimestamp\(\),([\s\S]*?)\}\);",
    r'await Supabase.instance.client.from("loads").insert({\1"pickupDate": pickupDate.toUtc().toIso8601String(),\2\3});',
    code
)


with codecs.open(path, 'w', 'utf-8') as f:
    f.write(code)


# ----------------- osm_map_home_screen.dart -----------------
path = 'lib/screens/osm_map_home_screen.dart'
with codecs.open(path, 'r', 'utf-8') as f:
    code = f.read()

# Replace any remaining FirebaseFirestore with regex
# 1. Imports
code = re.sub(
    r"import 'package:cloud_firestore/cloud_firestore\.dart';[\s\S]*?import 'package:firebase_auth/firebase_auth\.dart';",
    r"import 'package:supabase_flutter/supabase_flutter.dart';\nimport '../services/auth_service.dart';",
    code
)

# 2. focusJobById
code = re.sub(
    r"final doc =[\s]*await FirebaseFirestore\.instance\.collection\(\"loads\"\)\.doc\(jobId\)\.get\(\);[\s]*if \(!doc\.exists\) return;[\s]*final l = Load\.fromDoc\(doc\);",
    r"final data = await Supabase.instance.client.from('loads').select().eq('id', jobId).maybeSingle();\n      if (data == null) return;\n      final l = Load.fromMap(data);",
    code
)

# 3. _driverAcceptCounter
code = re.sub(
    r"final db = FirebaseFirestore\.instance;[\s]*await db\.runTransaction\(\(tx\) async \{([\s\S]*?)await batch\.commit\(\);",
    r"""final db = Supabase.instance.client;

    final data = await db.from("loads").select().eq("id", load.id).maybeSingle() ?? {};
    final status = (data["status"] ?? "open").toString();
    final acceptedOfferId = data["acceptedOfferId"];

    if (status != "open" && status != "matched") {
      throw Exception("Bu ilan artık uygun değil.");
    }
    if (acceptedOfferId != null && acceptedOfferId.toString().isNotEmpty) {
      throw Exception("Bu ilan başka bir şoförle eşleşmiş.");
    }

    await db.from("offers").update({"status": "accepted"}).eq("id", myOffer.id);

    await db.from("loads").update({
      "status": "matched",
      "acceptedOfferId": myOffer.id,
      "acceptedDriverId": myOffer.driverId,
    }).eq("id", load.id);

    final others = await db.from("offers").select().eq("loadId", load.id).neq("id", myOffer.id);
    for (final d in others) {
      await db.from("offers").update({"status": "rejected"}).eq("id", d["id"]);
    }""",
    code
)

# 4. _driverRejectCounter
code = re.sub(
    r"await FirebaseFirestore\.instance[\s]*\.collection\(\"offers\"\)[\s]*\.doc\(myOffer\.id\)[\s]*\.update\(\{[\s]*\"status\": \"driver_rejected_counter\",[\s]*\"driverRejectedAt\": FieldValue\.serverTimestamp\(\),[\s]*\}\);",
    r"""await Supabase.instance.client.from("offers").update({
      "status": "driver_rejected_counter",
      "driverRejectedAt": DateTime.now().toUtc().toIso8601String(),
    }).eq("id", myOffer.id);""",
    code
)

# 5. _deleteLoadWithOffersById
code = re.sub(
    r"final db = FirebaseFirestore\.instance;[\s]*final offersSnap =[\s]*await db\.collection\(\"offers\"\)\.where\(\"loadId\", isEqualTo: loadId\)\.get\(\);[\s]*final batch = db\.batch\(\);[\s]*for \(final d in offersSnap\.docs\) \{[\s]*batch\.delete\(d\.reference\);[\s]*\}[\s]*batch\.delete\(db\.collection\(\"loads\"\)\.doc\(loadId\)\);[\s]*await batch\.commit\(\);",
    r"""final db = Supabase.instance.client;
    await db.from("offers").delete().eq("loadId", loadId);
    await db.from("loads").delete().eq("id", loadId);""",
    code
)

# 6. _cleanupExpiredLoads uid
code = re.sub(
    r"final uid = FirebaseAuth\.instance\.currentUser\?\.uid;",
    r"final uid = AuthService().currentUser?.id;",
    code
)


# 7. bottom sheet user
code = re.sub(
    r"final Stream<QuerySnapshot<Map<String, dynamic>>>[\s]*myOfferStream = \(uid == null\)[\s]*\? const Stream\.empty\(\)[\s]*: FirebaseFirestore\.instance[\s]*\.collection\(\"offers\"\)[\s]*\.where\(\"loadId\", isEqualTo: l\.id\)[\s]*\.where\(\"driverId\", isEqualTo: uid\)[\s]*\.snapshots\(\);",
    r"""final Stream<List<Map<String, dynamic>>> myOfferStream = (uid == null)
                                ? const Stream.empty()
                                : Supabase.instance.client
                                    .from("offers")
                                    .stream(primaryKey: ['id'])
                                    .eq("loadId", l.id)
                                    .order("createdAt", ascending: false);""",
    code
)

code = re.sub(
    r"return StreamBuilder<[\s]*QuerySnapshot<Map<String, dynamic>>>\(",
    r"return StreamBuilder<List<Map<String, dynamic>>>(",
    code
)

code = re.sub(
    r"final docs = snap\.data!\.docs\.toList\(\);[\s]*// ✅ createdAt'e göre \(client-side\) sırala: en yeni en üstte[\s]*docs\.sort\(\(a, b\) \{[\s]*final ta = \(a\.data\(\)\[\"createdAt\"\] as Timestamp\?\)[\s]*\?\.millisecondsSinceEpoch \?\?[\s]*0;[\s]*final tb = \(b\.data\(\)\[\"createdAt\"\] as Timestamp\?\)[\s]*\?\.millisecondsSinceEpoch \?\?[\s]*0;[\s]*return tb\.compareTo\(ta\);[\s]*\}\);[\s]*// ✅ Tüm teklif geçmişin \(en yeni -> en eski\)[\s]*final myOffers =[\s]*docs\.map\(\(d\) => Offer\.fromDoc\(d\)\)\.toList\(\);",
    r"""final docs = snap.data!.where((d) => d['driverId'] == uid).toList();
                            final myOffers = docs.map((d) => Offer.fromMap(d)).toList();""",
    code
)

# 8. Fixed accept 
code = re.sub(
    r"final db = FirebaseFirestore[\s]*\.instance;[\s]*// ✅ Sabit ilanı kabul et: teklif oluştur \+ load'u matched yap \(transaction\)[\s]*final newOfferRef = db[\s]*\.collection\(\"offers\"\)[\s]*\.doc\(\);[\s]*await db\.runTransaction\([\s\S]*?await batch\.commit\(\);",
    r"""final db = Supabase.instance.client;

final data = await db.from("loads").select().eq("id", l.id).maybeSingle() ?? {};
final status = (data["status"] ?? "open").toString();
final acceptedOfferId = data["acceptedOfferId"];

if (status != "open") {
  throw Exception("Bu ilan artık uygun değil.");
}
if (acceptedOfferId != null && acceptedOfferId.toString().isNotEmpty) {
  throw Exception("Bu ilan başka bir şoförle eşleşmiş.");
}

final offerData = await db.from("offers").insert({
  "loadId": l.id,
  "driverId": uid,
  "driverName": appState.displayName,
  "price": fixedPrice,
  "note": "",
  "status": "accepted",
}).select().maybeSingle();

if (offerData == null) throw Exception("Teklif oluşturulamadı");
final newOfferId = offerData['id'].toString();

await db.from("loads").update({
  "status": "matched",
  "acceptedOfferId": newOfferId,
  "acceptedDriverId": uid,
}).eq("id", l.id);

final others = await db.from("offers").select().eq("loadId", l.id).neq("id", newOfferId);
for (final d in others) {
  await db.from("offers").update({"status": "rejected"}).eq("id", d["id"]);
}""",
    code
)

# 9. Offer Send
code = re.sub(
    r"await FirebaseFirestore\.instance[\s]*\.collection\(\"offers\"\)[\s]*\.add\(\{[\s]*\"loadId\": l\.id,[\s]*\"driverId\": uid2,[\s]*\"driverName\": appState\.displayName,[\s]*\"price\": price,[\s]*\"note\": noteCtrl\.text\.trim\(\),[\s]*\"status\": \"sent\",[\s]*\"createdAt\":[\s]*FieldValue\.serverTimestamp\(\),[\s]*\}\);",
    r"""await Supabase.instance.client
                                            .from("offers")
                                            .insert({
                                          "loadId": l.id,
                                          "driverId": uid2,
                                          "driverName": appState.displayName,
                                          "price": price,
                                          "note": noteCtrl.text.trim(),
                                          "status": "sent",
                                        });""",
    code
)

# 10. Map Global Stream Builder
code = re.sub(
    r"final loadsStream =[\s]*FirebaseFirestore\.instance\.collection\(\"loads\"\)\.snapshots\(\);[\s]*return Scaffold\([\s]*body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>\([\s]*stream: loadsStream,",
    r"""final stream = Supabase.instance.client.from("loads").stream(primaryKey: ['id']).order("createdAt", ascending: false);
    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,""",
    code
)
code = re.sub(
    r"final allLoads = snap\.data!\.docs\.map\(\(d\) => Load\.fromDoc\(d\)\)\.toList\(\);",
    r"final allLoads = snap.data!.map((d) => Load.fromMap(d)).toList();",
    code
)

# 11. Custom Panel stream builder
code = re.sub(
    r"final q = FirebaseFirestore\.instance[\s]*\.collection\(\"loads\"\)[\s]*\.where\(\"acceptedDriverId\", isEqualTo: uid\)[\s]*\.where\(\"status\", whereIn: \[\"matched\", \"delivered_pending\"\]\)\.orderBy\([\s]*\"createdAt\",[\s]*descending: true\);[\s]*return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>\([\s]*stream: q\.snapshots\(\),",
    r"""final stream = Supabase.instance.client
        .from("loads")
        .stream(primaryKey: ['id'])
        .eq("acceptedDriverId", uid)
        .order("createdAt", ascending: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,""",
    code
)

code = re.sub(
    r"final jobs = snap\.data!\.docs\.map\(\(d\) => Load\.fromDoc\(d\)\)\.toList\(\);",
    r"final allJobs = snap.data!.map((d) => Load.fromMap(d)).toList();\n        final jobs = allJobs.where((j) => ['matched', 'delivered_pending'].contains(j.status)).toList();",
    code
)

# 12. driver delivered
code = re.sub(
    r"await FirebaseFirestore\.instance[\s]*\.collection\(\"loads\"\)[\s]*\.doc\(j\.id\)[\s]*\.update\(\{[\s]*\"status\": \"delivered_pending\",[\s]*\"deliveredAt\":[\s]*FieldValue\.serverTimestamp\(\),[\s]*\}\);",
    r"""await Supabase.instance.client
                                          .from("loads")
                                          .update({
                                        "status": "delivered_pending",
                                        "deliveredAt": DateTime.now().toUtc().toIso8601String(),
                                      }).eq("id", j.id);""",
    code
)

# 13. driver match cancel
code = re.sub(
    r"await FirebaseFirestore\.instance[\s]*\.collection\(\"loads\"\)[\s]*\.doc\(j\.id\)[\s]*\.update\(\{[\s]*\"status\": \"open\",[\s]*\"acceptedOfferId\": FieldValue\.delete\(\),[\s]*\"acceptedDriverId\": FieldValue\.delete\(\),[\s]*\}\);[\s]*final offers = await FirebaseFirestore\.instance[\s]*\.collection\(\"offers\"\)[\s]*\.where\(\"loadId\", isEqualTo: j\.id\)[\s]*\.get\(\);[\s]*final batch = FirebaseFirestore\.instance\.batch\(\);[\s]*for \(final d in offers\.docs\) \{[\s]*batch\.delete\(d\.reference\);[\s]*\}[\s]*await batch\.commit\(\);",
    r"""await Supabase.instance.client
                                .from("loads")
                                .update({
                              "status": "open",
                              "acceptedOfferId": null,
                              "acceptedDriverId": null,
                            }).eq("id", j.id);

                            await Supabase.instance.client
                                .from("offers")
                                .delete()
                                .eq("loadId", j.id);""",
    code
)

with codecs.open(path, 'w', 'utf-8') as f:
    f.write(code)

print("done")
