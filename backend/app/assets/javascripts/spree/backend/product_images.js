$(document).ready(function () {
  $('.thumbnail').mouseover(function(){
    var source = $(this).attr('data-large');
    $('.main').attr('src', source)
  });
});
