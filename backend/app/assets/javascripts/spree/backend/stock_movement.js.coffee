jQuery ->
  el = $('#stock_movement_stock_item_id')
  el.select2
    placeholder: "Find a stock item" # translate
    ajax:
      url: Spree.url(Spree.routes.stock_items_api(el.data('stock-location-id')))
      data: (term, page) ->
        q:
          variant_product_name_cont: term
        per_page: 50
        page: page
        token: Spree.api_key
      results: (data, page) ->
        more = (page * 50) < data.count
        return { results: data.stock_items, more: more }
    formatResult: (stock_item) ->
      variantTemplate({ variant: stock_item.variant })
    formatSelection: (stock_item) ->
      "#{stock_item.variant.name} (#{stock_item.variant.options_text})"
