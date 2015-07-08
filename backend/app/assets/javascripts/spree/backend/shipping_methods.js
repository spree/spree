var original_shipping_method_zones;

$(document).ready(function () {
  initZonesSelect();

  $('select.js-zones-by-country').on('change', function () {
    var country_id = $(this).val();

    $.ajax({
      type: 'GET',
      url: '/admin/countries/' + country_id + '/zones.json'
    }).done(function (data) {
      showZones(data);
    }).error(function (msg) {
      console.log(msg);
    });
  });
});

function showZones(zones){
  removeAllZonesFromSelect();

  if(zones.length > 0){
    var options_by_country = [];
    // restore the original options
    $('select.js-zones-select').append(original_shipping_method_zones);

    $.each(zones, function( index, value ) {
      // collect the options to keep
      options_by_country.push($("select.js-zones-select option[value='" + value['id'] + "']")[0].outerHTML);
    });

    removeAllZonesFromSelect();
    $('select.js-zones-select').append(options_by_country.join(''));

  } else {
    $('select.js-zones-select').append('<option>No zones configured</option>');
  }

  // reinit the select2
  $('select.js-zones-select').select2();
}

function removeAllZonesFromSelect(){
  $('select.js-zones-select').find('option').remove();
}

function initZonesSelect(){
  original_shipping_method_zones = $("select.js-zones-select").html();

  if(!$('select.js-zones-select').val()){
    removeAllZonesFromSelect();
    $('select.js-zones-select').append('<option value="">Please pick a country to select a zone</option>');
  }

  $('select.js-zones-select').select2();
}
