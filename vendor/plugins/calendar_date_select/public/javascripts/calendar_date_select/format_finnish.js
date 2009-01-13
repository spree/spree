Date.padded2 = function(hour) { padded2 = hour.toString(); if ((parseInt(hour) < 10) || (parseInt(hour) == null)) padded2="0" + padded2; return padded2; }
Date.prototype.getAMPMHour = function() { hour=Date.padded2(this.getHours()); return (hour == null) ? 00 : (hour > 24 ? hour - 24 : hour ) }
Date.prototype.getAMPM = function() { return (this.getHours() < 12) ? "" : ""; }

Date.prototype.toFormattedString = function(include_time){
  str = this.getDate() + "." + (this.getMonth() + 1) + "." + this.getFullYear();
  if (include_time) { hour=this.getHours(); str += " " + this.getAMPMHour() + ":" + this.getPaddedMinutes() }
  return str;
}
Date.parseFormattedString = function (string) {
  var regexp = '([0-9]{1,2})\.(([0-9]{1,2})\.(([0-9]{2,4})( ([0-9]{1,2}):([0-9]{2})? *)?)?)?';
  var d = string.match(new RegExp(regexp, "i"));
  if (d==null) return Date.parse(string); // at least give javascript a crack at it.
  var offset = 0;
  if (d[5] && d[5].length == 2) {
    // we got only two digits for the year...
    d[5] = Number(d[5]);
    if (d[5] > 30)
      d[5] += 1900;
    else
      d[5] += 2000;
  }
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
