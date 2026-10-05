/// Heat level of one calendar day, from the minutes actually studied.
/// 0 = nothing studied, 4 = a lot. Used for the dot colours.
int heatLevel(int minutes) {
  if (minutes <= 0) return 0;
  if (minutes < 30) return 1;
  if (minutes < 90) return 2;
  if (minutes < 180) return 3;
  return 4;
}
