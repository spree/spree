// Formats date and time as "2000.01.20 17:00"
Date.prototype.toFormattedString = function(include_time)
{
   str = this.getFullYear() + "." + Date.padded2(this.getMonth()+1) + "." + Date.padded2(this.getDate());
   if (include_time) { str += " " + this.getHours() + ":" + this.getPaddedMinutes() }
   return str;
}