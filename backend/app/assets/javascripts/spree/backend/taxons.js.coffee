$(document).ready ->
  window.productTemplate = Handlebars.compile($('#product_template').text());
  $('#taxon_products').sortable();
  $('#taxon_products').on "sortstop", (event, ui) ->
    $.ajax
      url: Spree.routes.classifications_api,
      method: 'PUT',
      data:
        token: Spree.api_key,
        product_id: ui.item.data('product-id'),
        taxon_id: $('#taxon_id').val(),
        position: ui.item.index()

  if $('#taxon_id').length > 0
    $('#taxon_id').select2
      dropdownCssClass: "taxon_select_box",
      placeholder: Spree.translations.find_a_taxon,
      ajax:
        url: Spree.routes.taxons_search,
        datatype: 'json',
        data: (term, page) ->
          per_page: 50,
          page: page,
          token: Spree.api_key,
          q:
            name_cont: term
        results: (data, page) ->
          more = page < data.pages;
          results: data['taxons'],
          more: more
      formatResult: (taxon) ->
        taxon.pretty_name;
      formatSelection: (taxon) ->
        taxon.pretty_name;

  $('#taxon_id').on "change", (e) ->
    el = $('#taxon_products')
    $.ajax
      url: Spree.routes.taxon_products_api,
      data:
        id: e.val,
        token: Spree.api_key
      success: (data) ->
        el.empty();
        if data.products.length == 0
          $('#sorting_explanation').hide()
          $('#taxon_products').html("<h4>" + Spree.translations.no_results + "</h4>")
        else
          for product in data.products
            if product.master.images[0] != undefined && product.master.images[0].small_url != undefined
              product.image = product.master.images[0].small_url
            el.append(productTemplate({ product: product }))
          $('#sorting_explanation').show()
