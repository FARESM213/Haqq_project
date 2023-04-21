import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String apiKey = 'your_api_key';
const String apiBaseUrl = 'https://api.quran.com/api/v4';

class QuranSurahDetailsScreen extends StatefulWidget {
  final dynamic surah;

  const QuranSurahDetailsScreen(this.surah, {Key? key}) : super(key: key);
  @override
  _QuranSurahDetailsScreenState createState() =>
      _QuranSurahDetailsScreenState();
}

class _QuranSurahDetailsScreenState extends State<QuranSurahDetailsScreen> {
  bool isplaying = false;
  late Future<List<List<dynamic>>> pages;
  final audioPlayer = AudioPlayer();
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  bool audioLoaded = false;

  late String currentAudioUrl;
  late String nextAudioUrl;

  bool isDisposed = false;
  Duration lastPosition = Duration.zero;
  bool waspaused = false; // Ajouter cette ligne et initialiser à false
  late List<double> audioDurations;
  var recitationAudio="";

  @override
  void initState() {
    super.initState();
    pages = fetchPages();
    audioPlayer.onPlayerStateChanged.listen((state) {
      if (isDisposed) return;
      setState(() {
        isplaying = state == PlayerState.PLAYING;
      });
    });

    audioPlayer.onDurationChanged.listen((newDuration) {
      if (isDisposed) return;
      setState(() {
        duration = newDuration;
      });
    });

    audioPlayer.onAudioPositionChanged.listen((newPosition) {
      if (isDisposed) return;
      setState(() {
        position = newPosition;
      });
    });

  }
  Future<void> preloadAudio(String audioUrl) async {
    await audioPlayer.setUrl(audioUrl);
  }

  Future<double> fetchAudioDuration(String audioUrl) async {
    Completer<Duration> completer = Completer();
    AudioPlayer audioPlayer = AudioPlayer();
    await audioPlayer.setUrl("https://verses.quran.com/$audioUrl");

    audioPlayer.onDurationChanged.listen((Duration duration) {
      if (!completer.isCompleted) {
        completer.complete(duration);
      }
    });

    Duration audioDuration = await completer.future;
    double durationInSeconds = audioDuration.inMilliseconds / 1000;
    return durationInSeconds;
  }

  Future<List<double>> fetchAllAudioDurations(List<String> audioUrls) async {
    List<Future<double>> durationFutures = audioUrls.map((url) => fetchAudioDuration(url)).toList();
    List<double> durees = await Future.wait(durationFutures);
    return durees;
  }

  @override
  void dispose() {
    isDisposed = true;
    audioPlayer.stop();
    audioPlayer.dispose();
    audioPlayer.onPlayerStateChanged.drain();
    audioPlayer.onDurationChanged.drain();
    audioPlayer.onAudioPositionChanged.drain();
    audioPlayer.onPlayerCompletion.drain();
    super.dispose();
  }

  Widget buildAudioPlayer() {
    return Column(
      children: [
        CircleAvatar(
          radius: 20,
          child: IconButton(
            icon: Icon(
              isplaying ? Icons.pause : Icons.play_arrow,
            ),
            onPressed: () async {
              if (!audioLoaded) {
                var data = await fetchRecitationAndDurations();
                recitationAudio = data['recitation'];
                audioDurations = data['durations'];
                await preloadAudio(recitationAudio);
                setState(() {
                  audioLoaded = true;
                });
              }
              if (isplaying) {
                await audioPlayer.pause();
              } else {
                await audioPlayer.play(recitationAudio);
              }
              setState(() {
                isplaying = !isplaying;
              });
            },
          ),
        ),
        Slider(
          min: 0,
          max: duration.inSeconds.toDouble(),
          value: position.inSeconds.toDouble(),
          onChanged: (value) async {
            final position = Duration(seconds: value.toInt());
            await audioPlayer.seek(position);
            await audioPlayer.resume();
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(position.toString()),
              Text((duration - position).toString())
            ],
          ),
        ),
      ],
    );
  }

  Widget buildVerseText(List<TextSpan> words) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * (2/ 4),
      child: Container(
        color: Colors.grey[200],
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: RichText(
                text: TextSpan(children: words),
              ),
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    int nombredepage = widget.surah['pages'][widget.surah['pages'].length - 1] - widget.surah['pages'][0] + 1;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.surah['name_arabic']}'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Nombre de versets: ${widget.surah['verses_count']}',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Nombre de pages: ${widget.surah['pages'][0]} - ${widget.surah['pages'][widget.surah['pages'].length - 1]} $nombredepage',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * (3 / 4),
            child: Container(
              padding: const EdgeInsets.all(2.0),
              child: FutureBuilder<List<List<dynamic>>>(
                future: pages,
                builder: (BuildContext context, AsyncSnapshot<List<List<dynamic>>> snapshot) {
                  if (snapshot.hasData) {
                    var words = <TextSpan>[];
                    for (var page in snapshot.data!) {
                      for (var verse in page) {
                        verse['words'].forEach((word) {
                          var fontFamily = '';
                          if (word['page_number'] < 10) {
                            fontFamily = "QCF_P00${word['page_number']}";
                          } else if (word['page_number'] < 100) {
                            fontFamily = "QCF_P0${word['page_number']}";
                          } else {
                            fontFamily = "QCF_P${word['page_number']}";
                          }
                          words.add(
                            TextSpan(
                              text: ' ${word['code_v1']} ',
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 28.0,
                                fontWeight: FontWeight.normal,
                                color: Colors.black,
                              ),
                            ),
                          );
                        });
                      }
                    }
                    return Column(
                      children: [
                        buildAudioPlayer(),
                        buildVerseText(words),
                      ],
                    );
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<List<dynamic>>> fetchPages() async {
    var pages = <List<dynamic>>[];
    int nombredepage = 1;
    var url = Uri.parse('$apiBaseUrl/verses/by_chapter/${widget.surah['id']}?language=en&words=false');
    var headers = {
      'accept': 'application/json',
      'X-API-Key': apiKey,
    };
    var response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body)['pagination'];
      nombredepage = data['total_pages'];
      for (var i = 1; i <= nombredepage; i++) {
        var url = Uri.parse('$apiBaseUrl/verses/by_chapter/${widget.surah['id']}?words=true&translations=fr&audio=4&word_fields=code_v1&page=$i&per_page=10');
        var headers = {
          'accept': 'application/json',
          'X-API-Key': apiKey,
        };
        var response = await http.get(url, headers: headers);
        if (response.statusCode == 200) {
          var data = jsonDecode(response.body)['verses'];
          pages.add(data);
        } else {
          throw Exception('Erreur: ${response.statusCode}');
        }
      }
    } else {
      throw Exception('Erreur: ${response.statusCode}');
    }
    return pages;
  }

  Future<Map<String, dynamic>> fetchRecitationAndDurations() async {
    String recitation = "";
    List<double> audioDuration = [];

    // Fetch recitation
    var recitationUrl = Uri.parse('$apiBaseUrl/chapter_recitations/4/${widget.surah['id']}');
    var headers = {
      'accept': 'application/json',
      'X-API-Key': apiKey,
    };
    var response = await http.get(recitationUrl, headers: headers);
    if (response.statusCode == 200) {
      recitation = jsonDecode(response.body)['audio_file']['audio_url'];
    } else {
      throw Exception('Erreur: ${response.statusCode}');
    }
    var durationUrl = Uri.parse('$apiBaseUrl/verses/by_chapter/${widget.surah['id']}?words=true&translations=fr&audio=4&word_fields=code_v1&page=1&per_page=10');
    response = await http.get(durationUrl, headers: headers);
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body)['verses'];
      List<String> audioUrls = (data as List<dynamic>).map((verse) => (verse['audio']['url'] as String)).toList();
      audioDuration = await fetchAllAudioDurations(audioUrls);
      for (int i = 1; i < audioDuration.length; i++) {
        audioDuration[i] += audioDuration[i - 1];
      }
    } else {
      throw Exception('Erreur: ${response.statusCode}');
    }

    return {
      'recitation': recitation,
      'durations': audioDuration,
    };
  }

}
