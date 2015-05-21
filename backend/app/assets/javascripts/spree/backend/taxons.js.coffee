$(document).ready ->
  window.productTemplate = Handlebars.compile($('#product_template').text());
  $('#taxon_products').sortable({
      handle: ".js-sort-handle"
    });
  $('#taxon_products').on "sortstop", (event, ui) ->
    $.ajax
      url: Spree.routes.classifications_api,
      method: 'PUT',
      dataType:'json',
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
          without_children: true,
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
          $('#taxon_products').html("<div class='alert alert-info'>" + Spree.translations.no_results + "</div>")
        else
          for product in data.products
            if product.master.images[0] != undefined && product.master.images[0].small_url != undefined
              product.image = product.master.images[0].small_url
            el.append(productTemplate({ product: product }))

  $('#taxon_products').on "click", ".js-delete-product", (e) ->
    current_taxon_id = $("#taxon_id").val()
    product = $(this).parents(".product")
    product_id = product.data("product-id")
    product_taxons = String(product.data("taxons")).split(',').map(Number)
    product_index = product_taxons.indexOf(parseFloat(current_taxon_id))
    product_taxons.splice(product_index, 1)
    taxon_ids = if product_taxons.length > 0 then product_taxons else [""]

    $.ajax
      url: Spree.routes.products_api + "/" + product_id
      data:
        product:
          taxon_ids: taxon_ids
        token: Spree.api_key
      type: "PUT",
      success: (data) ->
        product.fadeOut 400, (e) ->
          product.remove()

  $('#taxon_products').on "click", ".js-edit-product", (e) ->
    product = $(this).parents(".product")
    product_id = product.data("product-id")
    window.location = Spree.routes.edit_product(product_id)

  $(".variant_autocomplete").variantAutocomplete();
