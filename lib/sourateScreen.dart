import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String API_KEY = 'your_api_key';
const String API_BASE_URL = 'https://api.quran.com/api/v4';

class QuranSurahDetailsScreen extends StatefulWidget {
  final dynamic surah;

  const QuranSurahDetailsScreen(this.surah, {Key? key}) : super(key: key);
  @override
  _QuranSurahDetailsScreenState createState() =>
      _QuranSurahDetailsScreenState();
}

class _QuranSurahDetailsScreenState extends State<QuranSurahDetailsScreen> {
  bool isplaying = false;
  late Future<List<List<dynamic>>> surahVerses;
  final audioPlayer = AudioPlayer();
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  int currentIndex = 0;
  List<String> audio = [];
  late String currentAudioUrl;
  late String nextAudioUrl;
  late bool isLoadingNextVerse;
  bool isDisposed = false;
  Duration lastPosition = Duration.zero;
  bool waspaused = false; // Ajouter cette ligne et initialiser à false

  @override
  void initState() {
    super.initState();
    isLoadingNextVerse = false;
    surahVerses = fetchSurahVerses();
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

    audioPlayer.onPlayerCompletion.listen((event) async {
      if (currentIndex < audio.length) {
        await playVerseAudio();
      } else {
        setState(() {
          isplaying = false;
        });
      }
    });
  }
  Future<void> preloadAudio(String audioUrl) async {
    try {
      print('Loading audio: $audioUrl');
      await audioPlayer.setUrl(audioUrl);
      print('Audio loaded successfully: $audioUrl');
    } catch (e) {
      print('Error loading audio: $audioUrl');
      print(e);
    }
  }

  Future<void> playVerseAudio() async {
    if (currentIndex < audio.length) {
      currentAudioUrl = audio[currentIndex];
      try {
        await preloadAudio("https://verses.quran.com/$currentAudioUrl");
        print('Starting to play audio: $currentAudioUrl');
        await audioPlayer.play("https://verses.quran.com/$currentAudioUrl");
        print('Audio playback started: $currentAudioUrl');
        await audioPlayer.setVolume(1.0);
        currentIndex++;
        isLoadingNextVerse = false;
        if (currentIndex < audio.length) {
          nextAudioUrl = audio[currentIndex];
          await preloadAudio("https://verses.quran.com/$nextAudioUrl");
        } else {
          nextAudioUrl = ""; // Si c'est le dernier verset, le prochain est une chaîne vide
        }
        print('Finished playing audio: $currentAudioUrl');
      } catch (e) {
        print('Error playing audio: $currentAudioUrl');
        print(e);
      }
    }
  }

  @override
  void dispose() {
    isDisposed = true;
    audioPlayer.stop();
    audioPlayer.dispose();
    surahVerses = Future.value([]);
    audio.clear();
    audioPlayer.onPlayerStateChanged.drain();
    audioPlayer.onDurationChanged.drain();
    audioPlayer.onAudioPositionChanged.drain();
    audioPlayer.onPlayerCompletion.drain();
    super.dispose();
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
                future: surahVerses,
                builder: (BuildContext context,
                    AsyncSnapshot<List<List<dynamic>>> snapshot) {
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
                        audio.add(verse['audio']['url']);
                      }
                    }
                    return Column(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          child: IconButton(
                            icon: Icon(
                              isplaying ? Icons.pause : Icons.play_arrow,
                            ),
                            onPressed: () async {
                              if (isplaying) {
                                await audioPlayer.pause();
                                setState(() {
                                  waspaused = true; // Définir waspaused à true
                                });
                              } else {
                                if (position >= duration) {
                                  currentIndex = 0;
                                  audioPlayer.stop();
                                }
                                if (waspaused) {
                                  await audioPlayer.resume();
                                } else {
                                  await playVerseAudio();
                                }
                                setState(() {
                                  waspaused = false; // Définir waspaused à false
                                });
                              }
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
                        Container(
                          color: Colors.grey[200], // Couleur de fond
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: RichText(
                                  text: TextSpan(children: words),
                                ),
                              ),
                            ),
                          ),
                        ),
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

  Future<List<List<dynamic>>> fetchSurahVerses() async {
    var pages = <List<dynamic>>[];
    int nombredepage = 1;
    var url = Uri.parse(
        '$API_BASE_URL/verses/by_chapter/${widget.surah['id']}?language=en&words=false');
    var headers = {
      'accept': 'application/json',
      'X-API-Key': API_KEY,
    };
    var response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body)['pagination'];
      nombredepage = data['total_pages'];
      for (var i = 1; i <= nombredepage; i++) {
        var url = Uri.parse(
            '$API_BASE_URL/verses/by_chapter/${widget.surah['id']}?words=true&translations=fr&audio=4&word_fields=code_v1&page=$i&per_page=10');
        var headers = {
          'accept': 'application/json',
          'X-API-Key': API_KEY,
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
}
