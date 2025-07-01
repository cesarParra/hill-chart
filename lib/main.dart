import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hill Chart To-Do',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HillChartScreen(),
    );
  }
}

class TodoItem {
  final String id;
  final String title;
  double position; // 0.0 to 1.0
  final Color color;

  TodoItem({
    required this.id,
    required this.title,
    this.position = 0.0,
    required this.color,
  });
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
  }

  void updateItemPosition(String id, double position) {
    final item = _items.firstWhere((item) => item.id == id);
    item.position = position;
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }
}

class HillChartScreen extends StatefulWidget {
  const HillChartScreen({super.key});

  @override
  _HillChartScreenState createState() => _HillChartScreenState();
}

class _HillChartScreenState extends State<HillChartScreen> {
  final HillChartState _hillChartState = HillChartState();
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
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

class _HillChartViewState extends State<HillChartView> {
  String? _draggedItemId;

  double _getHillY(double position, double chartHeight) {
    final hillAmplitude = chartHeight / 2.5;
    return chartHeight - (sin(position * pi) * hillAmplitude) - (chartHeight / 2);
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
                    message: item.title,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
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
}

class HillChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    path.moveTo(0, size.height / 2);

    for (double i = 1; i <= size.width; i++) {
      final x = i;
      final y = size.height - (sin((i / size.width) * pi) * (size.height / 2.5)) - (size.height / 2);
      path.lineTo(x, y);
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
