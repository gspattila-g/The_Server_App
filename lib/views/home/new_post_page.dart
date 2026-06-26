import 'package:flutter/material.dart';

class NewPostPage extends StatefulWidget {
  @override
  _NewPostPageState createState() => _NewPostPageState();
}

class _NewPostPageState extends State<NewPostPage> {
  final TextEditingController _postController = TextEditingController();

  void _savePost() {
    final text = _postController.text.trim();
    if (text.isNotEmpty) {
      Navigator.pop(context, text); // Visszaküldi az új poszt szöveget
    } else {
      // Ha üres a szöveg, jelezhetsz hibát vagy egyszerűen nem csinálsz semmit
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kérlek, írj be valamit a poszthoz!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Új poszt létrehozása'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _postController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Írd be az új posztot',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _savePost,
              child: Text('Mentés'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size.fromHeight(50),
              ),
            )
          ],
        ),
      ),
    );
  }
}
