$(document).ready(function() {
  function performTaxonPickerSearch() {
    var QUERY = $('.js-taxon-picker-search input').val();
    $('.js-taxon-picker-index').html('Loading..');

    $.ajax({
      type: 'GET',
      url: '/admin/taxons',
      data: {
        q: {
          translations_name_cont: QUERY
        },
      },
    }).done(function(data) {
      $('.js-taxon-picker-index').html(data);
    }).error(function(msg) {
      console.log(msg);
    });
  }

  $('.js-taxon-picker-search-form').submit(function() {
    performTaxonPickerSearch();
    return false;
  });

  $('.js-taxon-picker-search .btn').click(function() {
    performTaxonPickerSearch();
  });
});

function taxonPickerValuesAsArray(values) {
  /* make sure we return a valid array and dont return [","] */

  values = values.split(',');

  if (values.length == 1 && values[0] == '') {
    values = [];
  }

  return values;
}

function taxonPickerCollectionRow(id, name, pretty_name) {
  return '<tr class="success">' +
           '<td>2110</td>' +
           '<td>' + name + '</td>' +
           '<td>' + pretty_name + '</td>' +
           '<td>' +
             '<a class="btn btn-danger btn-sm js-delete-from-taxon-picker-target icon-link with-tip action-delete no-text" data-id="' + id + '" title="" href="javascript:;" data-original-title="Delete"><span class="icon icon-delete"></span></a>' +
           '</td>' +
         '</tr>';
}

$(document).on('click', '.js-taxon-picker-index tbody td a', function(e) {
  e.preventDefault();

  var TAXON_ID = $(this).data('id');
  var TAXON_NAME = $(this).data('name');
  var TAXON_PRETTY_NAME = $(this).data('pretty-name');
  var CURRENT_TAXON_IDS = taxonPickerValuesAsArray($('.js-taxon-picker-target').val());
  var ALLREADY_EXIST = CURRENT_TAXON_IDS.indexOf(('' + TAXON_ID)); /* Taxon ID as a string */

  if (ALLREADY_EXIST == -1) {
    /* only add when it's not yet in the array */
    CURRENT_TAXON_IDS.push(TAXON_ID);
    $('.js-taxon-picker-target').val(CURRENT_TAXON_IDS);

    /* add the new taxon as a readable label, and be able to remove it again */
    $('.js-taxon-picker-collection tbody').prepend(taxonPickerCollectionRow(TAXON_ID, TAXON_NAME, TAXON_PRETTY_NAME));

    $('#taxonPicker').modal('hide');
  } else {
    /* no award winner error but better then nothing */
    alert('This taxon is allready selected');
  }
});

$(document).on('click', '.js-delete-from-taxon-picker-target', function(e) {
  e.preventDefault();

  var TAXON_ID = $(this).data('id');
  var TAXON_NAME = $(this).data('name');
  var CURRENT_TAXON_IDS = taxonPickerValuesAsArray($('.js-taxon-picker-target').val());

  CURRENT_TAXON_IDS = jQuery.grep(CURRENT_TAXON_IDS, function(value) {
    return value != TAXON_ID;
  });

  $('.js-taxon-picker-target').val(CURRENT_TAXON_IDS);

  $(this).parents('tr').remove();
});
