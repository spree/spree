(function ($) {
  // VERTICALLY ALIGN FUNCTION
  $.fn.vAlign = function() {
    return this.each(function(i){
    var ah = $(this).height();
    var ph = $(this).parent().height();
    var mh = Math.ceil((ph-ah) / 2);
    $(this).css('margin-top', mh);
    });
  };
})(jQuery);