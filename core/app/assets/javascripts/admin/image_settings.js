$(document).ready(function() {

  if ($('input#preferences_use_s3[type="checkbox"]:checked').length > 0)
    $('#s3_settings').show();

  // Toggle display of S3 settings based on value of use_s3 checkbox
  $('input#preferences_use_s3[type="checkbox"]').click(function() {
    $('#s3_settings').toggle();
  });

  $('.destroy_style').live("click", function() {
   $(this).parent().remove();
  });

  $('.destroy_header').live("click", function() {
    $(this).parent().remove();
  });

  // Handle adding new styles
  var styles_hash_index = 1;
  $('.add_style').click(function() {
    $('#styles_list').append(generate_html_for_hash("new_attachment_styles", styles_hash_index));
  });

  // Handle adding new headers
  var headers_hash_index = 1;
  $('.add_header').click(function() {
    $('#headers_list').append(generate_html_for_hash("new_s3_headers", headers_hash_index));
  });

  // Generates html for new paperclip styles form fields
  generate_html_for_hash = function(hash_name, index) {
    var html = '<li>';
    html += '<label for="' + hash_name + '_' + index + '_name">';
    html += 'Name</label>';
    html += '<input id="' + hash_name + '_' + index + '_name" name="' + hash_name + '[' + index + '][name]" type="text">';
    html += '<label for="' + hash_name + '_' + index + '_value">';
    html += 'Value</label>';
    html += '<input id="' + hash_name + '_' + index + '_value" name="' + hash_name + '[' + index + '][value]" type="text">';
    html += '<a href="#" alt="Destroy" class="destroy_style">&nbsp;x</a>';
    html += '</li>';

    index += 1;
    return html;
  };



});
