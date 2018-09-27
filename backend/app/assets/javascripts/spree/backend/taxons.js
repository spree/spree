$(function () {
  window.productTemplate = Handlebars.compile($('#product_template').text());
  var taxon_products = $('#taxon_products');
  var taxon_id = $('#taxon_id');

  taxon_products.sortable({
    handle: '.js-sort-handle'
  });

  taxon_products.on('sortstop', function (event, ui) {
    return $.ajax({
      url: Spree.routes.classifications_api,
      method: 'PUT',
      dataType: 'json',
      data: {
        token: Spree.api_key,
        product_id: ui.item.data('product-id'),
        taxon_id: $('#taxon_id').val(),
        position: ui.item.index()
      }
    });
  });

  if (taxon_id.length > 0) {
    taxon_id.select2({
      dropdownCssClass: 'taxon_select_box',
      placeholder: Spree.translations.find_a_taxon,
      ajax: {
        url: Spree.routes.taxons_api,
        datatype: 'json',
        data: function (term, page) {
          return {
            per_page: 50,
            page: page,
            without_children: true,
            token: Spree.api_key,
            q: {
              name_cont: term
            }
          };
        },
        results: function (data, page) {
          var more = page < data.pages;
          return {
            results: data['taxons'],
            more: more
          };
        }
      },
      formatResult: formatTaxon,
      formatSelection: formatTaxon
    });
  }

  taxon_id.on('change', function (e) {
    var el = $('#taxon_products');
    $.ajax({
      url: Spree.routes.taxon_products_api,
      data: {
        id: e.val,
        token: Spree.api_key
      }
    }).done(function (data) {
      var i, j, len, len1, product, ref, ref1, results, variant;
      el.empty();
      if (data.products.length === 0) {
        return $('#taxon_products').html('<div class="alert alert-info">' + Spree.translations.no_results + '</div>');
      } else {
        ref = data.products;
        results = [];
        for (i = 0, len = ref.length; i < len; i++) {
          product = ref[i];
          if (product.master.images[0] !== void 0 && product.master.images[0].small_url !== void 0) {
            product.image = product.master.images[0].small_url;
          } else {
            ref1 = product.variants;
            for (j = 0, len1 = ref1.length; j < len1; j++) {
              variant = ref1[j];
              if (variant.images[0] !== void 0 && variant.images[0].small_url !== void 0) {
                product.image = variant.images[0].small_url;
                break;
              }
            }
          }
          results.push(el.append(productTemplate({
            product: product
          })));
        }
        return results;
      }
    });
  });
  taxon_products.on('click', '.js-delete-product', function (e) {
    var current_taxon_id = $('#taxon_id').val();
    var product = $(this).parents('.product');
    var product_id = product.data('product-id');
    var product_taxons = String(product.data('taxons')).split(',').map(Number);
    var product_index = product_taxons.indexOf(parseFloat(current_taxon_id));
    product_taxons.splice(product_index, 1);
    var taxon_ids = product_taxons.length > 0 ? product_taxons : [''];
    $.ajax({
      url: Spree.routes.products_api + '/' + product_id,
      data: {
        product: {
          taxon_ids: taxon_ids
        },
        token: Spree.api_key
      },
      type: 'PUT'
    }).done(function () {
      product.fadeOut(400, function (e) {
        product.remove();
      });
    });
  });
  $('.variant_autocomplete').variantAutocomplete();

  function formatTaxon(taxon) {
    return Select2.util.escapeMarkup(taxon.pretty_name);
  }
});
