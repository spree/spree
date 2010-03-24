jQuery(document).ready(function(){  
	function number_with_delimiter(number, delimiter, separator) {
	  try {
	    var delimiter = delimiter || ",";
	    var separator = separator || ".";

	    var parts = number.toString().split('.');
	    parts[0] = parts[0].replace(/(\d)(?=(\d\d\d)+(?!\d))/g, "$1" + delimiter);
	    formatted_number = parts.join(separator);
	
			if(formatted_number.length>=6 && formatted_number.length<=9){
				var arr = formatted_number.split(",");
				return arr[0] + " k";
			}else if(formatted_number.length==10){
				var arr = formatted_number.split(",");
				return arr[0] + " m";
			}else{
				return formatted_number
			}
	  } catch(e) {
	    return number
	  }
	}
	
  function handle_orders_by_day(r){
		var new_points = eval(r);

		if(new_points[0].length>0){
			orders_by_day_settings.axes.xaxis.min = new_points[0][0][0].replace(/-/g, "/");
			orders_by_day_settings.axes.xaxis.max = new_points[0][new_points[0].length -1][0].replace(/-/g, "/");
		}
	
		orders_by_day_settings.axes.yaxis.label = jQuery("#orders_by_day_value :selected").val();

		jQuery("#order_by_day_title").text(orders + " " + jQuery("#orders_by_day_value :selected").val() + " " + by_day + " (" + jQuery("#orders_by_day_reports :selected").text() + ")");

		$('#orders_by_day').empty();
		$.jqplot('orders_by_day', new_points, orders_by_day_settings);

	}
	
	function handle_orders_total(r){
		var values = eval(r);
		
		jQuery('#orders_total').text(number_with_delimiter(values[0].orders_total));
		jQuery('#orders_line_total').text(number_with_delimiter(values[0].orders_line_total));
		jQuery('#orders_adjustment_total').text(number_with_delimiter(values[0].orders_adjustment_total));
		jQuery('#orders_adjustment_total').text(number_with_delimiter(values[0].orders_adjustment_total));
	}

	var orders_by_day_settings = {
		title: {
			textColor: '#476D9B',
			fontSize: '12pt',
		}, 
		grid: {background:'#fff', gridLineColor:'#fff',borderColor: '#476D9B'},
	  axes:{
			yaxis:{
				label:'Order (Count)',
				labelRenderer: $.jqplot.CanvasAxisLabelRenderer,						
				autoscale:true, 
				tickOptions:{
					formatString:'%d',
					fontSize: '10pt',
					textColor: '#476D9B'
				},
				min: 0
			},	
			xaxis:{	 
				renderer:$.jqplot.DateAxisRenderer,
				rendererOptions:{tickRenderer:$.jqplot.CanvasAxisTickRenderer},
				tickOptions:{
					formatString:'%b %#d, %y',
					angle: -30,
					fontSize: '10pt',
					textColor: '#476D9B'
				},
				min: orders_by_day_points[0][0][0].replace(/-/g, "/"), 
				max: orders_by_day_points[0][orders_by_day_points[0].length -1][0].replace(/-/g, "/")//,
				//tickInterval: '1 day'
			}
		},
		series:[{lineWidth:3, color: '#0095DA', fillAndStroke: true, fill: true, fillColor: '#E6F7FF'}],
		highlighter: {
			formatString: "Date: %s <br/>Value: %s ",
			sizeAdjust: 7.5
		}
	};

	jQuery.jqplot('orders_by_day', orders_by_day_points, orders_by_day_settings);

	jQuery("div#orders_by_day_options select").change(function(){
		var report = jQuery("#orders_by_day_reports :selected").val();
		var value = jQuery("#orders_by_day_value :selected").val();
	
		jQuery.ajax({
	       type: 'GET',
	       url: 'admin/overview/get_report_data',
	       data: ({report: 'orders_by_day', name: report, value: value, authenticity_token: AUTH_TOKEN}),
	       success: handle_orders_by_day
		});
		
		jQuery.ajax({
	       type: 'GET',
	       url: 'admin/overview/get_report_data',
	       data: ({report: 'orders_totals', name: report, authenticity_token: AUTH_TOKEN}),
	       success: handle_orders_total
		});

	});

	best_selling_variants = $.jqplot('best_selling_products', [best_selling_variants_points], {
		grid: {background:'#fff',borderWidth: 0, borderColor: '#fff', shadow: false},
		seriesDefaults:{
		  renderer:$.jqplot.PieRenderer, 
		  rendererOptions:{padding:6,sliceMargin:0}
		},
		seriesColors: pie_colors
	});


	top_grossing_variants = $.jqplot('top_grossing_products', [top_grossing_variants_points], {
		grid: {background:'#fff',borderWidth: 0, borderColor: '#fff', shadow: false},
		seriesDefaults:{
		  renderer:$.jqplot.PieRenderer, 
		  rendererOptions:{padding:6,sliceMargin:0}
		},

		seriesColors: pie_colors
	});

	tbest_selling_taxons = $.jqplot('best_selling_taxons', [best_selling_taxons_points], {
		grid: {background:'#fff',borderWidth: 0, borderColor: '#fff', shadow: false},
		seriesDefaults:{
		  renderer:$.jqplot.PieRenderer, 
		  rendererOptions:{padding:6,sliceMargin:0}
		},

		seriesColors: pie_colors
	});


});
