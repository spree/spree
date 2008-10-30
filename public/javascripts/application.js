// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

var shipping_costs = new Hash();

function calculate_order_total(radio){
	$('order_total_cell').update(number_to_currency(order_total_without_shipping + shipping_costs.get(radio.value)));
}

function number_to_currency(number, options) {
	try {
 		var options   = options || {};
		var precision = options["precision"] || 2;
 		var unit      = options["unit"] || "$";
 		var separator = precision > 0 ? options["separator"] || "." : "";
		var delimiter = options["delimiter"] || ",";
   
 		var parts = parseFloat(number).toFixed(precision).split('.');
		return unit + number_with_delimiter(parts[0], delimiter) + separator + parts[1].toString();
	} catch(e) {
		return number
	}
 }

function number_with_delimiter(number, delimiter, separator) {
	try {
		var delimiter = delimiter || ",";
 		var separator = separator || ".";

		var parts = number.toString().split('.');
		parts[0] = parts[0].replace(/(\d)(?=(\d\d\d)+(?!\d))/g, "$1" + delimiter);
		return parts.join(separator);
	} catch(e) {
		return number
	}
}
