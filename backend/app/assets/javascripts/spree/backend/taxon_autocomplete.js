'use strict'
// eslint-disable-next-line camelcase
function set_taxon_select (selector) {
  function formatTaxonList(values) {
    var formatted_data = $.map(values, function (obj) {
      return {
        id: obj.id,
        text: obj.pretty_name
      }
    });

    return formatted_data
  }

  if ($(selector).length > 0) {
    $(selector).select2({
      multiple: true,
      placeholder: Spree.translations.taxon_placeholder,
      minimumInputLength: 2,
      allowClear: true,
      ajax: {
        url: Spree.routes.taxons_api,
        dataType: 'json',
        data: function (params) {
          var query = {
            q: {
              name_cont: params.term,
            },
            token: Spree.api_key
          }

          return query;
        },
        processResults: function(data) {
          var results = formatTaxonList(data.taxons)

          return {
            results: results
          }
        }
      }
    })
  }
}

$(document).ready(function () {
  set_taxon_select('#product_taxon_ids')
})
