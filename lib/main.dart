import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:go_router/go_router.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            final encodedState = state.uri.queryParameters['state'] ?? '';
            return HillChartScreen(initialState: encodedState);
          },
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Hill Chart To-Do',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      routerConfig: router,
    );
  }
}

class TodoItem {
  final String id;
  final String title;
  double position; // 0.0 to 1.0
  final Color color;
  DateTime lastUpdated;

  TodoItem({
    required this.id,
    required this.title,
    this.position = 0.0,
    required this.color,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'position': position,
      'color': color.value,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'],
      title: json['title'],
      position: json['position'].toDouble(),
      color: Color(json['color']),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  // Check if item is stale (not moved in 2 weekdays)
  bool isStale() {
    final now = DateTime.now();
    final daysSinceUpdate = _calculateWeekdaysBetween(lastUpdated, now);
    return daysSinceUpdate >= 2;
  }

  // Calculate weekdays between two dates (excluding weekends)
  int _calculateWeekdaysBetween(DateTime start, DateTime end) {
    int weekdays = 0;
    DateTime current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    
    while (current.isBefore(endDate)) {
      // Monday = 1, Sunday = 7
      if (current.weekday >= 1 && current.weekday <= 5) {
        weekdays++;
      }
      current = current.add(const Duration(days: 1));
    }
    
    return weekdays;
  }
}

class HillChartState extends ChangeNotifier {
  final List<TodoItem> _items = [];
  final List<Color> _colors = [
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];
  int _colorIndex = 0;
  Function(String)? onStateChange;

  List<TodoItem> get items => _items;

  void addItem(String title) {
    final color = _colors[_colorIndex];
    _colorIndex = (_colorIndex + 1) % _colors.length;
    _items.add(TodoItem(
      id: DateTime.now().toString(),
      title: title,
      position: 0.0,
      color: color,
    ));
    notifyListeners();
    _updateUrl();
  }

  void updateItemPosition(String id, double position) {
    final item = _items.firstWhere((item) => item.id == id);
    item.position = position;
    item.lastUpdated = DateTime.now(); // Update the last moved timestamp
    notifyListeners();
    _updateUrl();
  }

  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
    _updateUrl();
  }

  // URL state management
  String encodeState() {
    if (_items.isEmpty) return '';
    final data = _items.map((item) => item.toJson()).toList();
    final jsonString = jsonEncode(data);
    return base64Url.encode(utf8.encode(jsonString));
  }

  void loadFromEncodedState(String encodedState) {
    if (encodedState.isEmpty) return;

    try {
      final decodedString = utf8.decode(base64Url.decode(encodedState));
      final List<dynamic> data = jsonDecode(decodedString);

      _items.clear();
      _items.addAll(data.map((json) => TodoItem.fromJson(json)));

      // Update color index to avoid color collisions
      if (_items.isNotEmpty) {
        final usedColors = _items.map((item) => item.color.value).toSet();
        _colorIndex = 0;
        while (_colorIndex < _colors.length &&
               usedColors.contains(_colors[_colorIndex].value)) {
          _colorIndex++;
        }
        _colorIndex = _colorIndex % _colors.length;
      }

      notifyListeners();
    } catch (e) {
      // If decoding fails, just start with empty state
      print('Error loading state from URL: $e');
    }
  }

  void _updateUrl() {
    final encodedState = encodeState();
    onStateChange?.call(encodedState);
  }
}

class HillChartScreen extends StatefulWidget {
  final String initialState;

  const HillChartScreen({super.key, this.initialState = ''});

  @override
  _HillChartScreenState createState() => _HillChartScreenState();
}

class _HillChartScreenState extends State<HillChartScreen> {
  final HillChartState _hillChartState = HillChartState();
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Set up URL state change callback
    _hillChartState.onStateChange = (encodedState) {
      if (mounted) {
        final newUri = Uri.parse(GoRouterState.of(context).uri.toString())
            .replace(queryParameters: encodedState.isEmpty ? null : {'state': encodedState});
        context.go(newUri.toString());
      }
    };

    // Load initial state from URL
    _hillChartState.loadFromEncodedState(widget.initialState);

    _hillChartState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _hillChartState.removeListener(_onStateChanged);
    _hillChartState.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    setState(() {});
  }

  void _showDeleteConfirmationDialog(String id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Item?'),
          content: const Text('Do you want to remove this item?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                _hillChartState.removeItem(id);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hill Chart To-Do'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: HillChartView(
                  items: _hillChartState.items,
                  onUpdatePosition: (id, position) {
                    _hillChartState.updateItemPosition(id, position);
                    if (position == 1.0) {
                      _showDeleteConfirmationDialog(id);
                    }
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: 'New To-Do Item',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _hillChartState.addItem(value);
                        _textController.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_textController.text.isNotEmpty) {
                      _hillChartState.addItem(_textController.text);
                      _textController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HillChartView extends StatefulWidget {
  final List<TodoItem> items;
  final Function(String, double) onUpdatePosition;

  const HillChartView({super.key, required this.items, required this.onUpdatePosition});

  @override
  _HillChartViewState createState() => _HillChartViewState();
}

class _HillChartViewState extends State<HillChartView> with TickerProviderStateMixin {
  String? _draggedItemId;
  late AnimationController _flashAnimationController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _flashAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _flashAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flashAnimationController,
      curve: Curves.easeInOut,
    ));
    _flashAnimationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _flashAnimationController.dispose();
    super.dispose();
  }

  double _getHillY(double position, double chartHeight) {
    // Create a parabola that touches the bottom of the container
    // Using formula: y = -4 * amplitude * (x - 0.5)^2 + amplitude
    // Where amplitude is the height of the hill
    final amplitude = chartHeight * 0.6; // 60% of container height
    final normalizedX = position - 0.5; // Center the parabola
    final y = -4 * amplitude * normalizedX * normalizedX + amplitude;
    return chartHeight - y;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth;
        final chartHeight = constraints.maxHeight;

        return GestureDetector(
          onPanStart: (details) {
            if (widget.items.isNotEmpty) {
              final dx = details.localPosition.dx;
              final position = (dx / chartWidth).clamp(0.0, 1.0);

              final closestItem = widget.items.reduce((a, b) {
                return (a.position - position).abs() < (b.position - position).abs() ? a : b;
              });

              final itemY = _getHillY(closestItem.position, chartHeight);
              if ((details.localPosition.dy - itemY).abs() < 30) {
                setState(() {
                  _draggedItemId = closestItem.id;
                });
              }
            }
          },
          onPanUpdate: (details) {
            if (_draggedItemId != null) {
              final position = (details.localPosition.dx / chartWidth).clamp(0.0, 1.0);
              widget.onUpdatePosition(_draggedItemId!, position);
            }
          },
          onPanEnd: (_) {
            setState(() {
              _draggedItemId = null;
            });
          },
          child: CustomPaint(
            painter: HillChartPainter(),
            child: Stack(
              children: widget.items.map((item) {
                return Positioned(
                  left: item.position * chartWidth - 10,
                  top: _getHillY(item.position, chartHeight) - 10,
                  child: Tooltip(
                    message: '${item.title}\nLast updated: ${_formatDate(item.lastUpdated)}',
                    child: AnimatedBuilder(
                      animation: _flashAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: item.isStale() 
                                ? item.color.withOpacity(_flashAnimation.value)
                                : item.color,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class HillChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    
    // Create a parabola that touches the bottom of the container
    // Start from bottom left
    path.moveTo(0, size.height);
    
    for (double i = 0; i <= size.width; i++) {
      final x = i;
      final position = i / size.width;
      final amplitude = size.height * 0.6; // 60% of container height
      final normalizedX = position - 0.5; // Center the parabola
      final y = -4 * amplitude * normalizedX * normalizedX + amplitude;
      final canvasY = size.height - y;
      path.lineTo(x, canvasY);
    }

    canvas.drawPath(path, paint);

    final centerLinePaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height), centerLinePaint);

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final textStyle = TextStyle(color: Colors.grey.shade600, fontSize: 16);

    textPainter.text = TextSpan(text: 'Figuring it out', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width / 4 - textPainter.width / 2, 10));

    textPainter.text = TextSpan(text: 'Making it happen', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width * 3 / 4 - textPainter.width / 2, 10));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
