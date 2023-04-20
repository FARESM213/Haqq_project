import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:haqq/sourateScreen.dart';
import 'package:http/http.dart' as http;

const String apiKey = 'your_api_key';
const String apiBaseUrl = 'https://api.quran.com/api/v4';

class QuranSurahsScreen extends StatefulWidget {
  const QuranSurahsScreen({super.key});

  @override
  _QuranSurahsScreenState createState() => _QuranSurahsScreenState();
}

class _QuranSurahsScreenState extends State<QuranSurahsScreen> {
  List<dynamic> surahs = [];

  @override
  void initState() {
    super.initState();
    fetchSurahs();
  }

  void fetchSurahs() async {
    var url = Uri.parse('$apiBaseUrl/chapters?language=fr');
    var headers = {
      'accept': 'application/json',
      'X-API-Key': apiKey,
    };
    var response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body)['chapters'];
      setState(() {
        surahs = data;
      });
    } else {
      if (kDebugMode) {
        print('Erreur: ${response.statusCode}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran Surahs'),
      ),
      body: ListView.builder(
        itemCount: surahs.length,
        itemBuilder: (BuildContext context, int index) {
          var surah = surahs[index];
          return Card(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuranSurahDetailsScreen(surah),
                  ),
                );
              },
              child: ListTile(
                title: Text(
                  '${surah['name_simple']} - ${surah['name_arabic']}',
                ),
                subtitle: Text('Nombre de versets: ${surah['verses_count']}'),
              ),
            ),
          );
        },
      ),
    );
  }
}