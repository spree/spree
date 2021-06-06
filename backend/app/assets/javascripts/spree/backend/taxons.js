/* global productTemplate */
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
        var classificationId = evt.item.getAttribute('data-classification-id')
        var newIndex = evt.newIndex
        return $.ajax({
          url: Spree.routes.classifications_api_v2 + '/' + classificationId.toString() + '/reposition',
          headers: Spree.apiV2Authentication(),
          method: 'PUT',
          dataType: 'json',
          data: {
            classification: {
              position: newIndex
            }
          }
        })
      }
    })
  }

  if (taxonId.length > 0) {
    taxonId.select2({
      placeholder: Spree.translations.find_a_taxon,
      minimumInputLength: 3,
      multiple: false,
      ajax: {
        url: Spree.routes.taxons_api_v2,
        datatype: 'json',
        headers: Spree.apiV2Authentication(),
        data: function (params, page) {
          return {
            per_page: 50,
            page: page,
            filter: {
              name_cont: params.term
            }
          }
        },
        processResults: function (data, page) {
          var more = page < data.meta.total_pages

          var results = data.data.map(function (obj) {
            return {
              id: obj.id,
              text: obj.attributes.pretty_name
            }
          })

          return {
            results: results,
            pagination: {
              more: more
            }
          }
        }
      }
    }).on('select2:select', function (e) {
      $.ajax({
        url: Spree.routes.classifications_api_v2,
        headers: Spree.apiV2Authentication(),
        data: {
          filter: {
            taxon_id_eq: e.params.data.id
          },
          include: 'product.images',
          per_page: 150,
          sort: 'position'
        }
      }).done(function (json) {
        taxonProducts.empty()

        if (json.meta.total_count === 0) {
          return taxonProducts.html('<p class="text-center w-100 p-4">' + Spree.translations.no_results + '</p>')
        } else {
          var results = []

          json.data.forEach(function (classification) {
            var productId = classification.relationships.product.data.id.toString()

            var product = json.included.find(function(included) {
              if (included.type === 'product' && included.id === productId) {
                return included
              }
            })

            if (product && classification) {
              var imageUrl = null

              if (product.relationships.images.data.length > 0) {
                var imageId = product.relationships.images.data[0].id

                var image = json.included.find(function(included) {
                  if (included.type === 'image' && included.id === imageId) {
                    return included
                  }
                })

                if (image && image.attributes && image.attributes.styles) {
                  imageUrl = image.attributes.styles[2].url
                }
              }

              results.push(taxonProducts.append(productTemplate({
                product: product,
                classification: classification,
                image: imageUrl
              })))
            }
          })

          return results
        }
      })
    })
  }

  taxonProducts.on('click', '.js-delete-product', function (e) {
    var product = $(this).parents('.product')
    var classificationId = product.data('classification-id')
    $.ajax({
      url: Spree.routes.classifications_api_v2 + '/' + classificationId.toString(),
      headers: Spree.apiV2Authentication(),
      type: 'DELETE'
    }).done(function () {
      product.fadeOut(400, function (e) {
        product.remove()
      })
    })
  })

  $('.variant_autocomplete').variantAutocomplete()
})
