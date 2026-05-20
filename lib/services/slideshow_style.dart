enum SlideshowStyle {
  fade,
  kenBurns,
  grid,
  random,
}

extension SlideshowStyleX on SlideshowStyle {
  String get apiValue => name;
}
