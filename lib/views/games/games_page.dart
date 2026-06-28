import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth importálása

import '../../models/game.dart';
import '../../services/game_service.dart';
import '../../widgets/notification_bell.dart';

/// A Játék Könyvtár oldal widgetje.
///
/// Itt a felhasználók megtekinthetik és kezelhetik a játékaikat.
/// Lehetővé teszi új játékok hozzáadását és meglévők állapotának frissítését.
class GamesPage extends StatefulWidget {
  const GamesPage({super.key});

  @override
  State<GamesPage> createState() => _GamesPageState();
}

// Előre definiált játék adatstruktúra
class _PreDefinedGame {
  final String name;
  final String genre;
  final String platform;
  const _PreDefinedGame(this.name, this.genre, this.platform);
}

class _GamesPageState extends State<GamesPage> {
  final GameService _gameService = GameService();
  final TextEditingController _gameNameController = TextEditingController();
  final TextEditingController _gameGenreController = TextEditingController();
  final TextEditingController _gamePlatformController = TextEditingController();

  String _selectedStatus = 'wishlist';

  static const List<_PreDefinedGame> _preDefinedGames = [
    _PreDefinedGame('Minecraft', 'Sandbox', 'PC / Console / Mobile'),
    _PreDefinedGame('Fortnite', 'Battle Royale', 'PC / Console / Mobile'),
    _PreDefinedGame('League of Legends', 'MOBA', 'PC'),
    _PreDefinedGame('Counter-Strike 2', 'FPS', 'PC'),
    _PreDefinedGame('Valorant', 'FPS', 'PC'),
    _PreDefinedGame('Dota 2', 'MOBA', 'PC'),
    _PreDefinedGame('Grand Theft Auto V', 'Action-Adventure', 'PC / PlayStation / Xbox'),
    _PreDefinedGame('Red Dead Redemption 2', 'Action-Adventure', 'PC / PlayStation / Xbox'),
    _PreDefinedGame('The Witcher 3', 'RPG', 'PC / PlayStation / Xbox'),
    _PreDefinedGame('Cyberpunk 2077', 'RPG', 'PC / PlayStation / Xbox'),
    _PreDefinedGame('Elden Ring', 'RPG', 'PC / PlayStation / Xbox'),
    _PreDefinedGame('Baldur\'s Gate 3', 'RPG', 'PC / PlayStation'),
    _PreDefinedGame('Diablo IV', 'RPG', 'PC / Console'),
    _PreDefinedGame('Dark Souls III', 'RPG', 'PC / PlayStation / Xbox'),
    _PreDefinedGame('Hades', 'Roguelike', 'PC / Console'),
    _PreDefinedGame('Hollow Knight', 'Metroidvania', 'PC / Console'),
    _PreDefinedGame('God of War', 'Action-Adventure', 'PlayStation / PC'),
    _PreDefinedGame('The Last of Us', 'Action-Adventure', 'PlayStation / PC'),
    _PreDefinedGame('Apex Legends', 'Battle Royale', 'PC / Console'),
    _PreDefinedGame('Call of Duty: Warzone', 'FPS', 'PC / Console'),
    _PreDefinedGame('Overwatch 2', 'FPS', 'PC / Console'),
    _PreDefinedGame('Rocket League', 'Sports', 'PC / Console'),
    _PreDefinedGame('EA Sports FC 24', 'Sports', 'PC / Console'),
    _PreDefinedGame('Stardew Valley', 'Simulation', 'PC / Console / Mobile'),
    _PreDefinedGame('Among Us', 'Social Deduction', 'PC / Mobile'),
  ];

  final List<String> _gameStatuses = [
    'wishlist',
    'playing',
    'completed',
    'dropped',
  ];

  @override
  void dispose() {
    _gameNameController.dispose();
    _gameGenreController.dispose();
    _gamePlatformController.dispose();
    super.dispose();
  }

  /// Új játék hozzáadása dialógus megjelenítése.
  Future<void> _addGame() async {
    _gameNameController.clear();
    _gameGenreController.clear();
    _gamePlatformController.clear();
    _selectedStatus = 'wishlist';
    _PreDefinedGame? selectedPreDefined;
    int? dialogRating;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            final bool isManual = selectedPreDefined == null;

            return AlertDialog(
              title: const Text('Új játék hozzáadása'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Játék kiválasztó dropdown
                    DropdownButtonFormField<_PreDefinedGame?>(
                      value: selectedPreDefined,
                      decoration: const InputDecoration(labelText: 'Játék kiválasztása'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<_PreDefinedGame?>(
                          value: null,
                          child: Text('✏️ Manuális (saját)'),
                        ),
                        ..._preDefinedGames.map((game) => DropdownMenuItem<_PreDefinedGame?>(
                              value: game,
                              child: Text(game.name),
                            )),
                      ],
                      onChanged: (value) {
                        setStateInDialog(() {
                          selectedPreDefined = value;
                          if (value != null) {
                            _gameNameController.text = value.name;
                            _gameGenreController.text = value.genre;
                            _gamePlatformController.text = value.platform;
                          } else {
                            _gameNameController.clear();
                            _gameGenreController.clear();
                            _gamePlatformController.clear();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _gameNameController,
                      enabled: isManual,
                      decoration: InputDecoration(
                        labelText: 'Játék neve',
                        filled: !isManual,
                        fillColor: isManual ? null : Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _gameGenreController,
                      enabled: isManual,
                      decoration: InputDecoration(
                        labelText: 'Műfaj',
                        filled: !isManual,
                        fillColor: isManual ? null : Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _gamePlatformController,
                      decoration: const InputDecoration(labelText: 'Platform'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(labelText: 'Státusz'),
                      items: _gameStatuses.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(_getLocalizedGameStatus(status)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setStateInDialog(() {
                          _selectedStatus = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Értékelés:'),
                        const SizedBox(width: 8),
                        ...List.generate(5, (i) => GestureDetector(
                          onTap: () => setStateInDialog(() {
                            dialogRating = (dialogRating == i + 1) ? null : i + 1;
                          }),
                          child: Icon(
                            dialogRating != null && i < dialogRating!
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Mégse'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Hozzáadás'),
                  onPressed: () async {
                    if (_gameNameController.text.isNotEmpty) {
                      final newGame = Game(
                        id: '',
                        name: _gameNameController.text.trim(),
                        genre: _gameGenreController.text.trim().isEmpty ? 'Ismeretlen' : _gameGenreController.text.trim(),
                        platform: _gamePlatformController.text.trim().isEmpty ? 'Ismeretlen' : _gamePlatformController.text.trim(),
                        status: _selectedStatus,
                        addedAt: Timestamp.now(),
                        rating: dialogRating,
                      );
                      try {
                        await _gameService.addGame(newGame);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Játék sikeresen hozzáadva!')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Hiba a játék hozzáadásakor: $e')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('A játék neve nem lehet üres.')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Játék szerkesztése/törlése dialógus megjelenítése.
  Future<void> _editGame(Game game) async {
    _gameNameController.text = game.name;
    _gameGenreController.text = game.genre;
    _gamePlatformController.text = game.platform;
    _selectedStatus = game.status;
    int? dialogRating = game.rating;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: const Text('Játék szerkesztése'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _gameNameController,
                      decoration: const InputDecoration(labelText: 'Játék neve'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _gameGenreController,
                      decoration: const InputDecoration(labelText: 'Műfaj'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _gamePlatformController,
                      decoration: const InputDecoration(labelText: 'Platform'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(labelText: 'Státusz'),
                      items: _gameStatuses.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(_getLocalizedGameStatus(status)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setStateInDialog(() {
                          _selectedStatus = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Értékelés:'),
                        const SizedBox(width: 8),
                        ...List.generate(5, (i) => GestureDetector(
                          onTap: () => setStateInDialog(() {
                            dialogRating = (dialogRating == i + 1) ? null : i + 1;
                          }),
                          child: Icon(
                            dialogRating != null && i < dialogRating!
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Törlés'),
                  onPressed: () async {
                    // Megerősítő dialógus törlés előtt
                    final bool? confirmDelete = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Játék törlése'),
                          content: Text('Biztosan törölni szeretnéd a(z) "${game.name}" játékot?'),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('Mégse'),
                              onPressed: () {
                                Navigator.of(context).pop(false);
                              },
                            ),
                            ElevatedButton(
                              child: const Text('Törlés', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () {
                                Navigator.of(context).pop(true);
                              },
                            ),
                          ],
                        );
                      },
                    );

                    if (confirmDelete == true) {
                      try {
                        await _gameService.deleteGame(game.id);
                        Navigator.of(context).pop(); // Bezárjuk a szerkesztő dialógust
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Játék sikeresen törölve!')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Hiba a játék törlésekor: $e')),
                        );
                      }
                    }
                  },
                ),
                TextButton(
                  child: const Text('Mégse'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Mentés'),
                  onPressed: () async {
                    if (_gameNameController.text.isNotEmpty) {
                      final updatedGame = Game(
                        id: game.id,
                        name: _gameNameController.text.trim(),
                        genre: _gameGenreController.text.trim().isEmpty ? 'Ismeretlen' : _gameGenreController.text.trim(),
                        platform: _gamePlatformController.text.trim().isEmpty ? 'Ismeretlen' : _gamePlatformController.text.trim(),
                        status: _selectedStatus,
                        addedAt: game.addedAt,
                        rating: dialogRating,
                      );
                      try {
                        await _gameService.updateGame(updatedGame);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Játék sikeresen frissítve!')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Hiba a játék frissítésekor: $e')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('A játék neve nem lehet üres.')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Segédmetódus a státuszszöveg lokalizálásához
  String _getLocalizedGameStatus(String status) {
    switch (status) {
      case 'wishlist':
        return 'Kívánságlista';
      case 'playing':
        return 'Játszom';
      case 'completed':
        return 'Befejeztem';
      case 'dropped':
        return 'Abbahagytam';
      default:
        return 'Ismeretlen';
    }
  }

  /// Segédmetódus a státuszszöveg színének beállításához
  Color _getStatusColor(String status) {
    switch (status) {
      case 'wishlist':
        return Colors.orange;
      case 'playing':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'dropped':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const Center(child: Text('Nincs bejelentkezett felhasználó.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Játék könyvtár'),
        actions: const [NotificationBell()],
      ),
      body: StreamBuilder<List<Game>>(
        stream: _gameService.getGamesStreamForUser(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hiba a játékok betöltésekor: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Még nincsenek játékok a gyűjteményedben.'));
          }

          final games = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 2,
                child: InkWell( // Make the card tappable
                  onTap: () => _editGame(game), // Call edit function on tap
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                game.name,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(game.status).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _getLocalizedGameStatus(game.status),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _getStatusColor(game.status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text('Műfaj: ${game.genre}', style: const TextStyle(fontSize: 14)),
                        Text('Platform: ${game.platform}', style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 5),
                        Row(
                          children: List.generate(5, (i) => Icon(
                            game.rating != null && i < game.rating!
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 18,
                          )),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hozzáadva: ${_formatTimestamp(game.addedAt)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGame,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Időbélyeg formázása olvasható stringgé.
  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return 'néhány másodperce';
    if (difference.inMinutes < 60) return '${difference.inMinutes} perce';
    if (difference.inHours < 24) return '${difference.inHours} órája';
    return '${date.year}.${date.month}.${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
