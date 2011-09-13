$(document).ready(function() {
  // Hide chapters listing on overview page
  if ($('.spot-inner').children().length === 0) {
    $('.spot-inner').hide();
  }
});
