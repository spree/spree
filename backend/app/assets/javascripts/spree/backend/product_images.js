$(document).ready(function () {
  $('.thumbnail').mouseover(function(){
    var source = $(this).attr('src');
    source = source.replace(/w=\d+/, '').replace(/h=\d+/, '')

    $('.main').attr('src', source)
  });
});
