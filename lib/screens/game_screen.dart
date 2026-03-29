import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/game_service.dart';
import '../utils/marker_utils.dart';

class GameScreen extends StatefulWidget {
  final String gameCode;
  final String playerName;

  const GameScreen({
    super.key,
    required this.gameCode,
    required this.playerName,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameService _gameService = GameService();
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  String _myStatus = 'in_game';
  LatLng _myPosition = const LatLng(43.7458, 7.1947);
  MapType _mapType = MapType.normal;
  double _myHeading = 0.0;
  bool _showPlayers = false;
  List<QueryDocumentSnapshot> _players = [];

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  void _startLocationTracking() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      final newPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _myPosition = newPos;
        _myHeading = position.heading;
      });
      _gameService.updatePosition(
        widget.gameCode,
        position.latitude,
        position.longitude,
      );
      _mapController?.animateCamera(CameraUpdate.newLatLng(newPos));
    });
  }

  void _toggleStatus() {
    final newStatus = _myStatus == 'in_game' ? 'out' : 'in_game';
    setState(() => _myStatus = newStatus);
    _gameService.updateStatus(widget.gameCode, newStatus);
  }

  void _addPing(LatLng position) {
    _gameService.addPing(
      widget.gameCode,
      position.latitude,
      position.longitude,
      widget.playerName,
    );
  }

  bool _isOffline(dynamic updatedAt) {
    if (updatedAt == null) return true;
    final timestamp = updatedAt as Timestamp;
    final lastSeen = timestamp.toDate();
    return DateTime.now().difference(lastSeen).inSeconds > 30;
  }

  Future<Set<Marker>> _buildPlayerMarkers(
    List<QueryDocumentSnapshot> players,
  ) async {
    final markers = <Marker>{};
    for (final player in players) {
      final data = player.data() as Map<String, dynamic>;
      final lat = data['lat'] as double;
      final lng = data['lng'] as double;
      final name = data['name'] as String;
      final status = data['status'] as String;
      final isMe = player.id == _gameService.myUid;
      final offline = _isOffline(data['updatedAt']);

      if (lat == 0.0 && lng == 0.0) continue;

      Color color;
      if (offline) {
        color = Colors.grey;
      } else if (status == 'in_game') {
        color = isMe ? Colors.green : Colors.blue;
      } else {
        color = Colors.red;
      }

      final icon = await createLabeledMarker(name, color);

      markers.add(
        Marker(
          markerId: MarkerId(player.id),
          position: LatLng(lat, lng),
          rotation: isMe ? _myHeading : 0,
          icon: icon,
          anchor: const Offset(0.5, 0.75),
        ),
      );
    }
    return markers;
  }

  Set<Marker> _buildPingMarkers(List<QueryDocumentSnapshot> pings) {
    final markers = <Marker>{};
    for (final ping in pings) {
      final data = ping.data() as Map<String, dynamic>;
      final lat = data['lat'] as double;
      final lng = data['lng'] as double;
      final playerName = data['playerName'] as String;

      markers.add(
        Marker(
          markerId: MarkerId('ping_${ping.id}'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
          infoWindow: InfoWindow(title: '📍 $playerName'),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _gameService.playersStream(widget.gameCode),
        builder: (context, playersSnapshot) {
          if (playersSnapshot.hasData) {
            _players = playersSnapshot.data!.docs;
            _buildPlayerMarkers(_players).then((newMarkers) {
              if (mounted) {
                setState(() {
                  _markers.removeWhere(
                    (m) => !m.markerId.value.startsWith('ping_'),
                  );
                  _markers.addAll(newMarkers);
                });
              }
            });
          }
          return StreamBuilder<QuerySnapshot>(
            stream: _gameService.pingsStream(widget.gameCode),
            builder: (context, pingsSnapshot) {
              if (pingsSnapshot.hasData) {
                _markers.removeWhere(
                  (m) => m.markerId.value.startsWith('ping_'),
                );
                _markers.addAll(_buildPingMarkers(pingsSnapshot.data!.docs));
              }
              return Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _myPosition,
                      zoom: 16,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    markers: _markers,
                    mapType: _mapType,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    onLongPress: _addPing,
                  ),
                  if (_showPlayers)
                    Positioned(
                      top: 0,
                      left: 0,
                      bottom: 0,
                      child: SafeArea(
                        child: Container(
                          width: 180,
                          color: const Color(0xEE1A1A2E),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    const Text(
                                      'ÉQUIPE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'CODE: ${widget.gameCode}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(color: Colors.white24),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _players.length,
                                  itemBuilder: (context, index) {
                                    final data =
                                        _players[index].data()
                                            as Map<String, dynamic>;
                                    final name = data['name'] as String;
                                    final status = data['status'] as String;
                                    final isMe =
                                        _players[index].id ==
                                        _gameService.myUid;
                                    final offline = _isOffline(
                                      data['updatedAt'],
                                    );
                                    return ListTile(
                                      leading: Icon(
                                        Icons.circle,
                                        color:
                                            offline
                                                ? Colors.grey
                                                : status == 'in_game'
                                                ? Colors.green
                                                : Colors.red,
                                        size: 12,
                                      ),
                                      title: Text(
                                        name + (isMe ? ' (moi)' : ''),
                                        style: TextStyle(
                                          color:
                                              offline
                                                  ? Colors.grey
                                                  : Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        offline
                                            ? 'Hors ligne'
                                            : status == 'in_game'
                                            ? 'En jeu'
                                            : 'Out',
                                        style: TextStyle(
                                          color:
                                              offline
                                                  ? Colors.grey
                                                  : status == 'in_game'
                                                  ? Colors.green
                                                  : Colors.red,
                                          fontSize: 11,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: _showPlayers ? 180 : 0,
                    child: SafeArea(
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0x991A1A2E),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 60,
                    right: 12,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'satellite',
                          backgroundColor: const Color(0xCC1A1A2E),
                          onPressed: () {
                            setState(() {
                              _mapType =
                                  _mapType == MapType.normal
                                      ? MapType.satellite
                                      : MapType.normal;
                            });
                          },
                          child: Icon(
                            _mapType == MapType.normal
                                ? Icons.satellite
                                : Icons.map,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'players',
                          backgroundColor: const Color(0xCC1A1A2E),
                          onPressed:
                              () =>
                                  setState(() => _showPlayers = !_showPlayers),
                          child: Icon(
                            Icons.people,
                            color: _showPlayers ? Colors.green : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ElevatedButton(
                        onPressed: _toggleStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _myStatus == 'in_game'
                                  ? Colors.green
                                  : Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          _myStatus == 'in_game' ? 'EN JEU' : 'OUT',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
