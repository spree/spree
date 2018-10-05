/* global variantTemplate */
$(function () {
  var el = $('#stock_movement_stock_item_id')
  el.select2({
    placeholder: 'Find a stock item', // translate
    ajax: {
      url: Spree.url(Spree.routes.stock_items_api(el.data('stock-location-id'))),
      data: function (term, page) {
        return {
          q: {
            variant_product_name_cont: term
          },
          per_page: 50,
          page: page,
          token: Spree.api_key
        }
      },
      results: function (data, page) {
        var more = (page * 50) < data.count
        return {
          results: data.stock_items,
          more: more
        }
      }
    },
    formatResult: function (stockItem) {
      return variantTemplate({
        variant: stockItem.variant
      })
    },
    formatSelection: function (stockItem) {
      return Select2.util.escapeMarkup(stockItem.variant.name + '(' + stockItem.variant.options_text + ')')
    }
  })
})
