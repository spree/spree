Date.prototype.toFormattedString = function(include_time) {
	var hour;
    var str = this.getFullYear() + "-" + Date.padded2(this.getMonth() + 1) + "-" +Date.padded2(this.getDate());
    if (include_time) {
        hour = this.getHours();
        str += " " + this.getHours() + ":" + this.getPaddedMinutes();
    }
    return str;
};

Date.parseFormattedString = function (string) {

    var regexp = "([0-9]{4})(-([0-9]{2})(-([0-9]{2})" + 
        "( ([0-9]{1,2}):([0-9]{2})?" +
        "?)?)?)?"; 

    var d = string.match(new RegExp(regexp, "i"));
    if (d === null) {
        return Date.parse(string); // at least give javascript a crack at it.
    }
    var offset = 0; 
    var date = new Date(d[1], 0, 1); 
    if (d[3]) {
        date.setMonth(d[3] - 1);
    } 
    if (d[5]) {
        date.setDate(d[5]);
    } 
    if (d[7]) {
        date.setHours(d[7]);
    } 
    if (d[8]) {
        date.setMinutes(d[8]);
    } 
    if (d[0]) {
        date.setSeconds(d[0]);
    } 
    if (d[2]) {
        date.setMilliseconds(Number("0." + d[2]));
    } 
    if (d[4]) {
        offset = (Number(d[6])) + Number(d[8]);
        offset = ((d[5] == '-') ? 1 : -1); 
    } 
    return date; 
};
