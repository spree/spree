$(document).ready(function() {
  function performTaxonPickerSearch() {
    var query = $('.js-taxon-picker-search input').val();
    var taxonomy = $('.js-taxon-picker-search select').val();

    $('.js-taxon-picker-index').html('Loading..');

    $.ajax({
      type: 'GET',
      url: '/admin/taxons',
      data: {
        q: {
          admin_search_terms_cont: query,
          taxonomy_id_eq: taxonomy
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

  var $target = $('.js-taxon-picker-target');
  var taxonId = $(this).data('id');
  var taxonName = $(this).data('name');
  var taxonPrettyName = $(this).data('pretty-name');
  var singleId = ($target.data('taxon-picker-single') == true);
  var keepOpenOnSelect = ($target.data('taxon-picker-keep-open') == true);
  var currentTaxonIds = taxonPickerValuesAsArray($target.val());
  var allreadyExist = currentTaxonIds.indexOf(('' + taxonId)); /* Taxon ID as a string */

  /* only add when it's not yet in the array */
  if (allreadyExist == -1) {
    if (singleId) {
      /* when only 1 id is supported */
      $('.js-taxon-picker-target').val(taxonId);
    } else {
      /* when we can select multiple ids */
      currentTaxonIds.push(taxonId);
      $('.js-taxon-picker-target').val(currentTaxonIds);
    }

    /* add the new taxon as a readable label, and be able to remove it again */
    $('.js-taxon-picker-collection tbody').prepend(taxonPickerCollectionRow(taxonId, taxonName, taxonPrettyName));

    if (!keepOpenOnSelect) {
      $('#taxonPicker').modal('hide');
    }
  } else {
    /* no award winner error but better then nothing */
    alert('This taxon is allready selected');
  }
});

$(document).on('click', '.js-delete-from-taxon-picker-target', function(e) {
  e.preventDefault();

  var taxonId = $(this).data('id');
  var taxonName = $(this).data('name');
  var currentTaxonIds = taxonPickerValuesAsArray($('.js-taxon-picker-target').val());

  currentTaxonIds = jQuery.grep(currentTaxonIds, function(value) {
    return value != taxonId;
  });

  $('.js-taxon-picker-target').val(currentTaxonIds);

  $(this).parents('tr').remove();
});
