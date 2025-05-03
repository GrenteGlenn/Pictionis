import 'package:flutter/material.dart';

class ColoredLine {
  final List<Offset> offsets; // Liste des points pour dessiner une ligne
  final Color color; // Couleur de la ligne
  final double strokeWidth; // Largeur du trait

  ColoredLine(this.offsets, this.color, this.strokeWidth);
}
