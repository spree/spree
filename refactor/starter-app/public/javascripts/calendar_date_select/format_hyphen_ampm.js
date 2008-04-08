Date.prototype.toFormattedString = function(include_time){
  str = this.getFullYear() + "-" + Date.padded2(this.getMonth() + 1) + "-" +Date.padded2(this.getDate()); 

if (include_time) { hour=this.getHours(); str += " " + this.getAMPMHour() + ":" + this.getPaddedMinutes() + " " + this.getAMPM() }
return str;
}

Date.parseFormattedString = function (string) {
  var regexp = "([0-9]{4})(-([0-9]{2})(-([0-9]{2})" +
      "( ([0-9]{1,2}):([0-9]{2})? *(pm|am)" +
      "?)?)?)?";
  var d = string.match(new RegExp(regexp, "i"));
  if (d==null) return Date.parse(string); // at least give javascript a crack at it.
  var offset = 0;
  var date = new Date(d[1], 0, 1);
  if (d[3]) { date.setMonth(d[3] - 1); }
  if (d[5]) { date.setDate(d[5]); }
  if (d[7]) {
    hours = parseInt(d[7], 10);
    offset=0;
    is_pm = (d[9].toLowerCase()=="pm")
    if (is_pm && hours <= 11) hours+=12;
    if (!is_pm && hours == 12) hours=0;
    date.setHours(hours); 
    
  }
  if (d[8]) { date.setMinutes(d[8]); }
  if (d[10]) { date.setSeconds(d[10]); }
  if (d[12]) { date.setMilliseconds(Number("0." + d[12]) * 1000); }
  if (d[14]) {
      offset = (Number(d[16]) * 60) + Number(d[17]);
      offset *= ((d[15] == '-') ? 1 : -1);
  }

  return date;
}