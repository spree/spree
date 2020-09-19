/* global productTemplate, Sortable */
$(function () {
  window.productTemplate = Handlebars.compile($('#product_template').text())
  var taxonProducts = $('#taxon_products')
  var taxonId = $('#taxon_id')

  var el = document.getElementById('taxon_products')
  if (el) {
    Sortable.create(el, {
      handle: '.sort-handle',
      ghostClass: 'moving-this',
      animation: 550,
      easing: 'cubic-bezier(1, 0, 0, 1)',
      swapThreshold: 0.9,
      forceFallback: true,
      onEnd: function (evt) {
        var itemEl = evt.item.getAttribute('data-product-id')
        var newin = evt.newIndex
        return $.ajax({
          url: Spree.routes.classifications_api,
          method: 'PUT',
          dataType: 'json',
          data: {
            token: Spree.api_key,
            product_id: itemEl,
            taxon_id: $('#taxon_id').val(),
            position: newin
          }
        })
      }
    })
  }

  if (taxonId.length > 0) {
    taxonId.select2({
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
          }
        },
        results: function (data, page) {
          var more = page < data.pages
          return {
            results: data['taxons'],
            more: more
          }
        }
      },
      formatResult: formatTaxon,
      formatSelection: formatTaxon
    })
  }

  taxonId.on('change', function (e) {
    var el = $('#taxon_products')
    $.ajax({
      url: Spree.routes.taxon_products_api,
      data: {
        id: e.val,
        token: Spree.api_key
      }
    }).done(function (data) {
      var i, j, len, len1, product, ref, ref1, results, variant
      el.empty()
      if (data.products.length === 0) {
        return $('#taxon_products').html('<div class="alert alert-info">' + Spree.translations.no_results + '</div>')
      } else {
        ref = data.products
        results = []
        for (i = 0, len = ref.length; i < len; i++) {
          product = ref[i]
          if (product.master.images[0] !== void 0 && product.master.images[0].small_url !== void 0) {
            product.image = product.master.images[0].small_url
          } else {
            ref1 = product.variants
            for (j = 0, len1 = ref1.length; j < len1; j++) {
              variant = ref1[j]
              if (variant.images[0] !== void 0 && variant.images[0].small_url !== void 0) {
                product.image = variant.images[0].small_url
                break
              }
            }
          }
          results.push(el.append(productTemplate({
            product: product
          })))
        }
        return results
      }
    })
  })
  taxonProducts.on('click', '.js-delete-product', function (e) {
    var currentTaxonId = $('#taxon_id').val()
    var product = $(this).parents('.product')
    var productId = product.data('product-id')
    var productTaxons = String(product.data('taxons')).split(',').map(Number)
    var productIndex = productTaxons.indexOf(parseFloat(currentTaxonId))
    productTaxons.splice(productIndex, 1)
    var taxonIds = productTaxons.length > 0 ? productTaxons : ['']
    $.ajax({
      url: Spree.routes.products_api + '/' + productId,
      data: {
        product: {
          taxon_ids: taxonIds
        },
        token: Spree.api_key
      },
      type: 'PUT'
    }).done(function () {
      product.fadeOut(400, function (e) {
        product.remove()
      })
    })
  })
  $('.variant_autocomplete').variantAutocomplete()

  function formatTaxon (taxon) {
    return Select2.util.escapeMarkup(taxon.pretty_name)
  }
})
