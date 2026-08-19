import 'package:flutter/material.dart';
import '../../models/timetable_models.dart';
import '../../services/timetable_storage.dart';

class FreeRoomFinderScreen extends StatefulWidget {
  const FreeRoomFinderScreen({super.key});

  @override
  State<FreeRoomFinderScreen> createState() => _FreeRoomFinderScreenState();
}

class _FreeRoomFinderScreenState extends State<FreeRoomFinderScreen> {
  bool _isLoading = true;
  bool _timetableNotConfigured = false;

  List<TimetableDayEvent> _allEvents = [];
  List<String> _allRooms = [];

  late String _selectedDay;
  String _selectedSlot = '08:30-10:00';
  String _searchQuery = '';
  bool _onlyFree = true;

  final TextEditingController _searchController = TextEditingController();

  static const List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _standardSlots = [
    '08:30-10:00',
    '10:00-11:30',
    '11:30-01:00',
    '01:00-02:30',
    '02:30-04:00',
    '04:00-05:30',
  ];

  static const Color _accent = Color(0xFF2563EB); // Royal Blue
  static const Color _ink = Color(0xFF0F172A); // Dark Slate
  static const Color _muted = Color(0xFF6B7280); // Cool Gray
  static const Color _freeGreen = Color(0xFF10B981);
  static const Color _busyRed = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _initDayAndSlot();
    _loadTimetableData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initDayAndSlot() {
    final now = DateTime.now();
    final dayIndex = now.weekday - 1;
    _selectedDay = (dayIndex >= 0 && dayIndex < _days.length) ? _days[dayIndex] : 'Monday';

    // Auto-detect current active time slot
    final currentHour = now.hour;
    final currentMin = now.minute;
    final currentTimeInMins = currentHour * 60 + currentMin;

    if (currentTimeInMins >= 8 * 60 + 30 && currentTimeInMins < 10 * 60) {
      _selectedSlot = '08:30-10:00';
    } else if (currentTimeInMins >= 10 * 60 && currentTimeInMins < 11 * 60 + 30) {
      _selectedSlot = '10:00-11:30';
    } else if (currentTimeInMins >= 11 * 60 + 30 && currentTimeInMins < 13 * 60) {
      _selectedSlot = '11:30-01:00';
    } else if (currentTimeInMins >= 13 * 60 && currentTimeInMins < 14 * 60 + 30) {
      _selectedSlot = '01:00-02:30';
    } else if (currentTimeInMins >= 14 * 60 + 30 && currentTimeInMins < 16 * 60) {
      _selectedSlot = '02:30-04:00';
    } else if (currentTimeInMins >= 16 * 60 && currentTimeInMins < 17 * 60 + 30) {
      _selectedSlot = '04:00-05:30';
    } else {
      _selectedSlot = '08:30-10:00';
    }
  }

  Future<void> _loadTimetableData() async {
    try {
      final snapshot = await TimetableStorage.load();
      if (snapshot == null || snapshot.schedule.isEmpty) {
        setState(() {
          _isLoading = false;
          _timetableNotConfigured = true;
        });
        return;
      }

      final events = snapshot.schedule;

      // Extract unique clean room list
      final roomsSet = <String>{};
      for (final e in events) {
        final r = e.room.trim();
        if (r.isNotEmpty &&
            !r.toLowerCase().contains('virtual') &&
            !r.toLowerCase().contains('online') &&
            r != '-' &&
            r.toLowerCase() != 'n/a') {
          roomsSet.add(r);
        }
      }

      final roomsList = roomsSet.toList()..sort();

      if (mounted) {
        setState(() {
          _allEvents = events;
          _allRooms = roomsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isSlotMatch(String eventTime, String targetSlot) {
    final cleanEvent = eventTime.replaceAll(' ', '').toLowerCase();
    final cleanTarget = targetSlot.replaceAll(' ', '').toLowerCase();
    if (cleanEvent == cleanTarget) return true;

    // Normalizing times
    return cleanEvent.startsWith(cleanTarget.split('-').first);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color inkColor = isDark ? const Color(0xFFF1F5F9) : _ink;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bgColor,
        foregroundColor: inkColor,
        title: const Text(
          'Free Room Finder',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _timetableNotConfigured
              ? _buildNotConfigured(cardBg, borderCol, inkColor)
              : _buildMainContent(isDark, cardBg, borderCol, inkColor),
    );
  }

  Widget _buildNotConfigured(Color cardBg, Color borderCol, Color ink) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.meeting_room_outlined, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'No Timetable Uploaded',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ink),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please upload the campus timetable Excel file in the Timetable Generator tab first to enable empty room detection.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isDark, Color cardBg, Color borderCol, Color ink) {
    // Filter events for selected day
    final dayEvents = _allEvents
        .where((e) => e.day.trim().toLowerCase() == _selectedDay.toLowerCase())
        .toList();

    // Find occupied rooms in this specific slot
    final occupiedRoomsMap = <String, TimetableDayEvent>{};
    for (final e in dayEvents) {
      final r = e.room.trim();
      if (_isSlotMatch(e.time, _selectedSlot)) {
        occupiedRoomsMap[r] = e;
      }
    }

    // Filter room list based on search and "only free" toggle
    final filteredRooms = _allRooms.where((room) {
      final matchesSearch = _searchQuery.isEmpty || room.toLowerCase().contains(_searchQuery);
      final isFree = !occupiedRoomsMap.containsKey(room);
      if (_onlyFree && !isFree) return false;
      return matchesSearch;
    }).toList();

    final totalRooms = _allRooms.length;
    final freeCount = _allRooms.where((r) => !occupiedRoomsMap.containsKey(r)).length;
    final occupiedCount = totalRooms - freeCount;

    return Column(
      children: [
        // Controls Section: Day + Slot Selector
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: borderCol)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day Chips Horizontal Scroll
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final day = _days[i];
                    final isSelected = day == _selectedDay;
                    return ChoiceChip(
                      label: Text(day.substring(0, 3)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedDay = day);
                      },
                      selectedColor: _accent,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : ink,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Time Slot Chips
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _standardSlots.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final slot = _standardSlots[i];
                    final isSelected = slot == _selectedSlot;
                    return ChoiceChip(
                      label: Text(slot),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedSlot = slot);
                      },
                      selectedColor: const Color(0xFF10B981),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : ink,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Search & Filter Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 18, color: _muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(fontSize: 13, color: ink),
                              decoration: const InputDecoration(
                                hintText: 'Search room (e.g. CS-01, B-02)...',
                                hintStyle: TextStyle(fontSize: 12, color: _muted),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () => _searchController.clear(),
                              child: const Icon(Icons.clear, size: 16, color: _muted),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                      _onlyFree ? 'Free Only' : 'All Rooms',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _onlyFree ? _freeGreen : _muted,
                      ),
                    ),
                    selected: _onlyFree,
                    onSelected: (val) => setState(() => _onlyFree = val),
                    backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    selectedColor: _freeGreen.withOpacity(0.15),
                    checkmarkColor: _freeGreen,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Availability Summary Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_selectedDay • $_selectedSlot'.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _muted,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _freeGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$freeCount Free',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _freeGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _busyRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$occupiedCount Busy',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _busyRed,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Room Grid / List
        Expanded(
          child: filteredRooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: _muted),
                      const SizedBox(height: 8),
                      Text(
                        'No matching rooms found',
                        style: TextStyle(color: _muted, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: filteredRooms.length,
                  itemBuilder: (context, index) {
                    final room = filteredRooms[index];
                    final isOccupied = occupiedRoomsMap.containsKey(room);
                    final event = occupiedRoomsMap[room];

                    // Find upcoming class for free room
                    String nextClassInfo = '';
                    if (!isOccupied) {
                      final laterEvents = dayEvents
                          .where((e) => e.room.trim() == room)
                          .toList()
                        ..sort((a, b) => a.time.compareTo(b.time));
                      if (laterEvents.isNotEmpty) {
                        nextClassInfo = 'Next: ${laterEvents.first.course} (${laterEvents.first.time})';
                      } else {
                        nextClassInfo = 'Free for the rest of today';
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isOccupied ? _busyRed.withOpacity(0.3) : borderCol,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isOccupied
                                  ? _busyRed.withOpacity(0.1)
                                  : _freeGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Icon(
                                isOccupied ? Icons.do_not_disturb_on : Icons.check_circle,
                                color: isOccupied ? _busyRed : _freeGreen,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      room,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: ink,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isOccupied
                                            ? _busyRed.withOpacity(0.1)
                                            : _freeGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isOccupied ? 'OCCUPIED' : 'AVAILABLE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isOccupied ? _busyRed : _freeGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (isOccupied && event != null)
                                  Text(
                                    '${event.course} • ${event.teacher} (${event.section})',
                                    style: const TextStyle(fontSize: 12, color: _muted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                else
                                  Text(
                                    nextClassInfo,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
