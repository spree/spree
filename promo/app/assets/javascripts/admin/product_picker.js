$.fn.productAutocomplete = function() {
  if (Spree.routes) {
    this.select2({
      minimumInputLength: 1,
      multiple: true,
      initSelection: function(element, callback) {
        $.get(Spree.routes.product_search, { ids: element.val() }, function(data) { 
          callback(data)
        })
      },
      ajax: {
        url: Spree.routes.product_search,
        datatype: 'json',
        data: function(term, page) {
          return { q: term }
        },
        results: function(data, page) {
          return { results: data }
        }
      },
      formatResult: function(product) {
        return product.name;
      },
      formatSelection: function(product) {
        return product.name;
      }
    });
  }
}

$(document).ready(function () {
  $('.product_picker').productAutocomplete();
})
