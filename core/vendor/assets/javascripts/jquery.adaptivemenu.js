jQuery.fn.AdaptiveMenu = function(options){

	var options = jQuery.extend({
		text: "More...",
		accuracy:70,
		'class':null,
		'classLinckMore':null
	},options);

	var menu = this;
	var li = $(menu).find("li");

	// li.css({"display":"inline","white-space":"nowrap"});

	var width = 0;
	var widthLi = [];
	$.each( li , function(i, l){
		width += $(l).width();
		widthLi.push( width );
	});

	var buildingMenu = function(windowWidth){
		var windowWidth = windowWidth  - options.accuracy;
		for(var i = 0; i<widthLi.length; i++ ){
			if ( widthLi[i] > windowWidth )
				$( li[i] ).hide();
			else
				$( li[i] ).show();
		}
		$(menu).find('#more').remove();
		var hideLi = $(li).filter(':not(:visible)');
		var lastLi = $(li).filter(':visible').last();
		if ( hideLi.length > 0 ){
			var more = $("<li>")
				.css({"display":"inline-block","white-space":"nowrap"})
				.addClass(options.classLinckMore)
				.attr({"id":"more"})
				.html(options.text)
				.click(function(){$(this).find('li').toggle()});

			var ul =  $("<ul>")
				.css({"position":"absolute"})
				.addClass(options.class)
				.html(hideLi.clone()).prepend(lastLi.clone().hide());

			more.append(ul);

			lastLi.hide().before(more);
		}
	}

	jQuery(window).resize(function() {
		buildingMenu( jQuery(window).width() );
	});

	jQuery(window).ready(function() {
		buildingMenu( jQuery(window).width() );
	});

};