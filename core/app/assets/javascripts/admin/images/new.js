$('#cancel_link').click(function (event) {
  event.preventDefault();
  $('#new_image_link').show();
  $('#images').html('');
});