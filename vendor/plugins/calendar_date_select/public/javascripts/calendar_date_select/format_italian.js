// Italian Format: 31/12/2000 23:00
// Thanks, Bigonazzi!

Date.prototype.toFormattedString = function(include_time){
  str = this.getDate() + "/" + (this.getMonth() + 1) + "/" + this.getFullYear();
  if (include_time) { str += " " + this.getHours() + ":" + this.getPaddedMinutes() }
  return str;
}

Date.parseFormattedString = function (string) {
  var regexp = '([0-9]{1,2})/(([0-9]{1,2})/(([0-9]{4})( ([0-9]{1,2}):([0-9]{2})? *)?)?)?';
  var d = string.match(new RegExp(regexp, "i"));
  if (d==null) return Date.parse(string); // at least give javascript a crack at it.
  var offset = 0;
  var date = new Date(d[5], 0, 1);
  if (d[3]) { date.setMonth(d[3] - 1); }
  if (d[5]) { date.setDate(d[1]); }
  if (d[7]) {
    date.setHours(parseInt(d[7], 10));    
  }
  if (d[8]) { date.setMinutes(d[8]); }
  if (d[10]) { date.setSeconds(d[10]); }
  return date;
}
