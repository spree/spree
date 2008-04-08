// Formats date and time as "01 January 2000 17:00"
Date.prototype.toFormattedString = function(include_time)
{
   str = Date.padded2(this.getDate()) + " " + Date.months[this.getMonth()] + " " + this.getFullYear();
   if (include_time) { str += " " + this.getHours() + ":" + this.getPaddedMinutes() }
   return str;
}