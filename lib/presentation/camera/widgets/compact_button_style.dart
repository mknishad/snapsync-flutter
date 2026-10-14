import 'package:flutter/material.dart';

/// The app theme makes every FilledButton full width (its minimum width is
/// infinite). That is wrong inside a Row, where it is an invalid layout, so
/// buttons placed in rows use this style.
final ButtonStyle compactFilledStyle = FilledButton.styleFrom(
  minimumSize: const Size(64, 44),
);
