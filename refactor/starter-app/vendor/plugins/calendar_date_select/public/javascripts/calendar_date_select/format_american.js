// American Format: 12/31/2000 5:00 pm
// Thanks, Wes Hays
Date.prototype.toFormattedString = function(include_time){
  str = Date.padded2(this.getMonth() + 1) + '/' +Date.padded2(this.getDate()) + '/' + this.getFullYear();

  if (include_time) { hour=this.getHours(); str += " " + this.getAMPMHour() + ":" + this.getPaddedMinutes() + " " + this.getAMPM() }
  return str;
}

Date.parseFormattedString = function (string) {
  // Test these with and without the time
  // 11/11/1111 12pm
  // 11/11/1111 1pm
  // 1/11/1111 10:10pm
  // 11/1/1111 01pm
  // 1/1/1111 01:11pm
  // 1/1/1111 1:11pm
  var regexp = "(([0-1]?[0-9])\/[0-3]?[0-9]\/[0-9]{4}) *([0-9]{1,2}(:[0-9]{2})? *(am|pm))?";
  var d = string.match(new RegExp(regexp, "i"));
  if (d==null) {
    return Date.parse(string); // Give javascript a chance to parse it.
  }

  mdy = d[1].split('/');
  hrs = 0;
  mts = 0;
  if(d[3] != null) {
    hrs = parseInt(d[3].split('')[0], 10);
    if(d[5].toLowerCase() == 'pm') { hrs += 12; } // Add 12 more to hrs
    mts = d[4].split(':')[1];
  }
  
  return new Date(mdy[2], parseInt(mdy[0], 10)-1, mdy[1], hrs, mts, 0);
}
