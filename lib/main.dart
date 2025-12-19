import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart'; 
import 'package:http/http.dart' as http; // Added for background email
import 'dart:convert'; // Added for JSON encoding
import 'firebase_options.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ShoppingApp());
}

class ShoppingApp extends StatelessWidget {
  const ShoppingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartShop Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.cyanAccent,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) return const ShoppingHome();
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.cyanAccent.withValues(alpha: 0.1),
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2), width: 2),
              ),
              child: const Icon(Icons.shopping_cart_checkout, size: 80, color: Colors.cyanAccent),
            ),
            const SizedBox(height: 20),
            const Text(
              "SMARTSHOP",
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white),
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: 280,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () async {
                  GoogleAuthProvider authProvider = GoogleAuthProvider();
                  kIsWeb 
                    ? await FirebaseAuth.instance.signInWithPopup(authProvider) 
                    : await FirebaseAuth.instance.signInWithProvider(authProvider);
                },
                icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.blue),
                label: const Text("SIGN IN WITH GOOGLE", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShoppingHome extends StatefulWidget {
  const ShoppingHome({super.key});

  @override
  State<ShoppingHome> createState() => _ShoppingHomeState();
}

class _ShoppingHomeState extends State<ShoppingHome> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: "1");
  String searchQuery = "";
  String selectedCategory = "General";
  final List<String> categories = ["General", "Groceries", "Home", "Electronics", "Pharmacy"];

  void addItem() {
    final user = FirebaseAuth.instance.currentUser;
    String name = nameController.text.trim();
    if (name.isEmpty || user == null) return;

    FirebaseFirestore.instance.collection('items').add({
      'name': name,
      'qty': int.tryParse(qtyController.text) ?? 1,
      'category': selectedCategory,
      'isCompleted': false,
      'uid': user.uid,
      'created': FieldValue.serverTimestamp(),
    });

    nameController.clear();
    qtyController.text = "1";
    FocusScope.of(context).unfocus();
  }

  // --- NEW: COPY TO CLIPBOARD LOGIC ---
  void copyToClipboard(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return;
    String reportContent = "SmartShop List: $selectedCategory\n";
    reportContent += "------------------------------------------\n";
    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      String status = (data['isCompleted'] ?? false) ? "[Done]" : "[Pending]";
      reportContent += "$status ${data['name']} (Qty: ${data['qty']})\n";
    }



    // 1. Capture the service BEFORE the async call
    final messenger = ScaffoldMessenger.of(context);

    Clipboard.setData(ClipboardData(text: reportContent)).then((_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("List copied to clipboard!"),
          backgroundColor: Color.fromARGB(255, 147, 182, 199),
        ),
      );
    });
  }

  // --- AUTOMATIC BACKGROUND EMAIL SENDING ---
  Future<void> sendEmailReport(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    // 1. Build the report text
    String reportContent = "SmartShop Report: $selectedCategory\n";
    reportContent += "------------------------------------------\n";
    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      String status = (data['isCompleted'] ?? false) ? "[Done]" : "[Pending]";
      reportContent += "$status ${data['name']} (Qty: ${data['qty']})\n";
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sending report automatically...")),
    );

    // 2. EmailJS Configuration - REPLACE THESE WITH YOUR KEYS
    const serviceId = 'service_u1fyi4p';
    const templateId = 'template_tzzxdt6';
    const publicKey = 'wK8MG7nAoupNoSAyN';


    // 1. Capture the messenger BEFORE the status check logic
    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'template_params': {
            'to_email': user.email,
            'category': selectedCategory,
            'report_data': reportContent,
          },
        }),
      );

      if (response.statusCode == 200) {
        messenger.showSnackBar(
          SnackBar(content: Text("Report sent to ${user.email}"), backgroundColor: Colors.green),
        );
      } else {
        throw "Error";
      }
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Automatic send failed. Please check EmailJS setup.")),
      );
    }
  }

  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Adding...";
    DateTime date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  void showEditDialog(String docId, String currentName, int currentQty) {
    TextEditingController editName = TextEditingController(text: currentName);
    TextEditingController editQty = TextEditingController(text: currentQty.toString()); 
  showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Item"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: editName, decoration: const InputDecoration(labelText: "Product Name")),
            const SizedBox(height: 15),
            TextField(controller: editQty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Quantity")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('items').doc(docId).update({
                'name': editName.text.trim(),
                'qty': int.tryParse(editQty.text) ?? 1,
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Basket", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
              decoration: const InputDecoration(
                hintText: "Search in this category...",
                prefixIcon: Icon(Icons.search, color: Colors.cyanAccent),
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(categories[index]),
                    selected: selectedCategory == categories[index],
                    onSelected: (selected) {
                      setState(() => selectedCategory = categories[index]);
                    },
                    selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(flex: 3, child: TextField(controller: nameController, decoration: const InputDecoration(hintText: "Product name"))),
                const SizedBox(width: 10),
                Expanded(flex: 1, child: TextField(controller: qtyController, textAlign: TextAlign.center, keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.cyanAccent),
                  onPressed: addItem,
                  icon: const Icon(Icons.add, color: Colors.black),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('items')
                  .where('uid', isEqualTo: user?.uid)
                  .where('category', isEqualTo: selectedCategory)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs.where((d) => d['name'].toString().toLowerCase().contains(searchQuery)).toList();
                
                docs.sort((a, b) {
                  Timestamp? t1 = a['created'] as Timestamp?;
                  Timestamp? t2 = b['created'] as Timestamp?;
                  if (t1 == null) return -1;
                  if (t2 == null) return 1;
                  return t2.compareTo(t1);
                });

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var doc = docs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          bool isDone = data['isCompleted'] ?? false;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: ListTile(
                              leading: Checkbox(
                                value: isDone,
                                onChanged: (v) => doc.reference.update({'isCompleted': v}),
                              ),
                              title: Text(data['name'], style: TextStyle(decoration: isDone ? TextDecoration.lineThrough : null)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Qty: ${data['qty']}", style: const TextStyle(color: Colors.cyanAccent, fontSize: 13)),
                                  Text(formatDate(data['created'] as Timestamp?), style: const TextStyle(fontSize: 10, color: Colors.white38)),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_note, color: Colors.blueAccent),
                                    onPressed: () => showEditDialog(doc.id, data['name'], data['qty']),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => doc.reference.delete(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () => copyToClipboard(docs),
                                icon: const Icon(Icons.copy_rounded),
                                label: const Text("Copy List"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white10,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () => sendEmailReport(docs),
                                icon: const Icon(Icons.auto_awesome),
                                label: Text("Auto-Email $selectedCategory"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyanAccent.withValues(alpha: 0.1),
                                  foregroundColor: Colors.cyanAccent,
                                  side: const BorderSide(color: Colors.cyanAccent),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}