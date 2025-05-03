import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'colored_line.dart';
import 'drawing_painter.dart';

class DrawingBoard extends StatefulWidget {
  final String roomId;
  final bool canDraw;
  final bool isCreator;
  final String currentWord;

  const DrawingBoard({
    super.key,
    required this.roomId,
    required this.canDraw,
    required this.isCreator,
    required this.currentWord,
  });

  @override
  _DrawingBoardState createState() => _DrawingBoardState();
}

class _DrawingBoardState extends State<DrawingBoard> {
  Color selectedColor = Colors.black;
  double selectedStrokeWidth = 5.0;
  final List<ColoredLine> _drawingLines = [];
  Offset? _lastOffset;
  bool isFillingMode = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    print('DrawingBoard initialized for room: ${widget.roomId}');
    print('Can draw: ${widget.canDraw}');
    _subscribeToDrawingUpdates();
  }

  void _subscribeToDrawingUpdates() {
    print('Setting up drawing updates listener');
    _firestore
        .collection('rooms')
        .doc(widget.roomId)
        .collection('drawing')
        .orderBy('timestamp')
        .snapshots()
        .listen(
          (snapshot) {
        if (!mounted) return;

        final List<ColoredLine> newLines = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          try {
            if (data.containsKey('points')) {
              final List<dynamic> pointsData = data['points'];
              final List<Offset> points = pointsData.map((point) {
                return Offset(
                  (point['x'] as num).toDouble(),
                  (point['y'] as num).toDouble(),
                );
              }).toList();

              newLines.add(ColoredLine(
                points,
                Color(data['color'] as int),
                (data['strokeWidth'] as num).toDouble(),
              ));
            }
          } catch (e) {
            print('Error processing drawing data: $e');
          }
        }

        setState(() {
          _drawingLines.clear();
          _drawingLines.addAll(newLines);
        });
      },
      onError: (error) {
        print('Error in drawing stream: $error');
      },
    );
  }

  Future<void> _saveLine(ColoredLine line) async {
    try {
      final points = line.offsets
          .map((offset) => {
        'x': offset.dx,
        'y': offset.dy,
      })
          .toList();

      await _firestore
          .collection('rooms')
          .doc(widget.roomId)
          .collection('drawing')
          .add({
        'points': points,
        'color': line.color.value,
        'strokeWidth': line.strokeWidth,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving line: $e');
    }
  }

  void _addPoint(Offset? offset) {
    if (!widget.canDraw || offset == null) return;

    if (offset.dx >= 0 &&
        offset.dx <= MediaQuery.of(context).size.width &&
        offset.dy >= 0 &&
        offset.dy <= MediaQuery.of(context).size.height) {
      setState(() {
        if (_lastOffset == null) {
          _lastOffset = offset;
          final newLine = ColoredLine([offset], selectedColor, selectedStrokeWidth);
          _drawingLines.add(newLine);
        } else {
          _drawingLines.last.offsets.add(offset);
        }
      });
    }
  }

  void _finishLine() {
    if (!widget.canDraw || _drawingLines.isEmpty) return;
    final completedLine = _drawingLines.last;
    _saveLine(completedLine);
    _lastOffset = null;
  }

  Future<void> _clearDrawing() async {
    try {
      final batch = _firestore.batch();
      final drawingDocs = await _firestore
          .collection('rooms')
          .doc(widget.roomId)
          .collection('drawing')
          .get();

      for (var doc in drawingDocs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      setState(() {
        _drawingLines.clear();
      });
    } catch (e) {
      print('Error clearing drawing: $e');
    }
  }

  void _changeColor(Color newColor) {
    setState(() {
      selectedColor = newColor;
    });
  }

  void _setStrokeWidth(double width) {
    setState(() {
      selectedStrokeWidth = width;
    });
  }

  void _undoLastLine() {
    if (_drawingLines.isEmpty) return;

    setState(() {
      _drawingLines.removeLast();
    });

    _firestore
        .collection('rooms')
        .doc(widget.roomId)
        .collection('drawing')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get()
        .then((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        snapshot.docs.first.reference.delete();
      }
    });
  }

  void _toggleFillingMode() {
    setState(() {
      isFillingMode = !isFillingMode;
    });
  }

  void _fillShape(List<Offset> points) {
    if (points.length > 2) {
      final filledLine = ColoredLine(points, selectedColor, 0);
      _saveLine(filledLine);
    }
  }

  IconButton _buildColorPickerButton() {
    return IconButton(
      icon: Icon(Icons.color_lens),
      onPressed: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Choisir une couleur'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              content: SingleChildScrollView(
                child: BlockPicker(
                  pickerColor: selectedColor,
                  onColorChanged: (Color color) {
                    _changeColor(color);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconButton _buildStrokeWidthButton() {
    return IconButton(
      icon: Icon(Icons.format_size),
      onPressed: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setDialogState) {
                return AlertDialog(
                  title: Text('Choisir la taille du pinceau'),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Slider(
                        value: selectedStrokeWidth,
                        min: 1.0,
                        max: 20.0,
                        onChanged: (double value) {
                          setDialogState(() {
                            selectedStrokeWidth = value;
                          });
                        },
                        divisions: 19,
                        label: selectedStrokeWidth.round().toString(),
                      ),
                      Text(
                          'Taille actuelle: ${selectedStrokeWidth.toStringAsFixed(1)}'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      child: Text('OK'),
                      onPressed: () {
                        _setStrokeWidth(selectedStrokeWidth);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (widget.canDraw)
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.brush, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mot à dessiner: ${widget.currentWord}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.undo),
                      onPressed: _undoLastLine,
                      tooltip: 'Annuler',
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.settings),
                      tooltip: 'Options de dessin',
                      onSelected: (String result) {
                        switch (result) {
                          case 'color':
                            _buildColorPickerButton().onPressed?.call();
                            break;
                          case 'stroke':
                            _buildStrokeWidthButton().onPressed?.call();
                            break;
                          case 'fill':
                            _toggleFillingMode();
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'color',
                          child: ListTile(
                            leading: Icon(Icons.color_lens),
                            title: Text('Couleur'),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'stroke',
                          child: ListTile(
                            leading: Icon(Icons.format_size),
                            title: Text('Taille du pinceau'),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'fill',
                          child: ListTile(
                            leading: Icon(isFillingMode
                                ? Icons.check_box
                                : Icons.check_box_outline_blank),
                            title: Text('Mode remplissage'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onPanUpdate: widget.canDraw
                  ? (details) => _addPoint(details.localPosition)
                  : null,
              onPanEnd: widget.canDraw
                  ? (details) {
                if (isFillingMode) {
                  _fillShape(_drawingLines.last.offsets);
                } else {
                  _finishLine();
                }
              }
                  : null,
              child: Container(
                color: Colors.white,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: DrawingPainter(_drawingLines),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.canDraw
          ? FloatingActionButton(
        onPressed: _clearDrawing,
        child: Icon(Icons.clear),
        tooltip: 'Effacer tout',
      )
          : null,
    );
  }
}