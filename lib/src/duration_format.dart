library postgresql.duration_format;

class DurationFormat {

  DurationFormat()
    : _approx = false, _threshold = 0;
  
  DurationFormat.approximate([int threshold = 5])
    : _approx = true, _threshold = threshold;
  
  final bool _approx;
  final int _threshold;
    
  Duration parse(String s, {onError(String s)}) {
    if (s == null) throw new ArgumentError.notNull('string');
    
    ex() => new FormatException('Cannot parse string as duration: "$s".');
    fail(s) => onError == null ? throw ex() : onError(s);
    
    parsePrefix(s, [int suffixLen = 1])
      => int.parse(s.substring(0, s.length-suffixLen), onError: fail); 
    
    if (s.endsWith('d')) return new Duration(days: parsePrefix(s));
    if (s.endsWith('h')) return new Duration(hours: parsePrefix(s));
    if (s.endsWith('m')) return new Duration(minutes: parsePrefix(s));
    if (s.endsWith('s')) return new Duration(seconds: parsePrefix(s));
    if (s.endsWith('ms')) return new Duration(milliseconds: parsePrefix(s, 2));
    if (s.endsWith('us')) return new Duration(microseconds: parsePrefix(s, 2));
    
    throw ex();
  }

  String format(Duration d) {
    
    if (d == null) throw new ArgumentError.notNull('duration');
    
    if (_approx) d = _approximate(d);
    
    if (d.inMicroseconds == 0)
      return '0s';
    
    if (d.inMicroseconds % Duration.MICROSECONDS_PER_MILLISECOND != 0)
      return '${d.inMicroseconds}us';

    if (d.inMilliseconds % Duration.MILLISECONDS_PER_SECOND != 0)
      return '${d.inMilliseconds}ms';

    if (d.inSeconds % Duration.SECONDS_PER_MINUTE != 0)
      return '${d.inSeconds}s';

    if (d.inMinutes % Duration.MINUTES_PER_HOUR != 0)
      return '${d.inMinutes}m';

    if (d.inHours % Duration.HOURS_PER_DAY != 0)
      return '${d.inHours}h';

    return '${d.inDays}d';
  }
  
  // Round up to the nearest unit.
  Duration _approximate(Duration d) {
    if (d.inMicroseconds == 0) return d;
    
    if (d > new Duration(days: _threshold))
      return new Duration(days: d.inDays);
    
    if (d > new Duration(hours: _threshold))
      return new Duration(hours: d.inHours);
    
    if (d > new Duration(minutes: _threshold))
      return new Duration(minutes: d.inMinutes);
    
    if (d > new Duration(seconds: _threshold))
      return new Duration(seconds: d.inSeconds);
    
    if (d > new Duration(milliseconds: _threshold))
      return new Duration(milliseconds: d.inMilliseconds);
    
    return new Duration(microseconds: d.inMicroseconds);
  }

}
