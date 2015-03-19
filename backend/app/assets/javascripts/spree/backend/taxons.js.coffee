# replaced when loading more
next_page = undefined
# simple lock to prevent loading when loading
is_loading = 0

class Helper
  getProducts: (page, cb) ->
    try
      taxon_id = Number(window.location.search.match(/(\?|&)taxon_id\=([^&]*)/)[2])
    catch
      taxon_id = Number($('#taxon_id').val())

    try
      per_page = Number(window.location.search.match(/(\?|&)per_page\=([^&]*)/)[2])
    catch error
      per_page = 15

    $.ajax
      url: Spree.routes.taxon_products_api,
      data:
        id: taxon_id
        page: page
        per_page: per_page
      success: (data) ->
        cb? data

  renderProducts: (data) ->
    el = $('#taxon_products')
    el.empty() if data.current_page == 1

    for product in data.products
      if product.master.images[0] != undefined && product.master.images[0].small_url != undefined
        product.image = product.master.images[0].small_url
      el.append(productTemplate({ product: product }))

  loadFollowing: =>
    if next_page != ''
      is_loading = 1
      # note: this will break when the server doesn't respond

      @getProducts next_page, (data) =>
        if data.current_page == 1 && data.count == 0
          $('#taxon_products').html("<div class='alert alert-info'>" + Spree.translations.no_results + "</div>")
        else
          next_page = data.current_page + 1
          @renderProducts(data)
          $('#load-more').show()

          unless next_page <= data.pages
            $('#load-more').hide()
            next_page = ''

        is_loading = 0

$(document).ready ->
  if $("#taxon_id").length == 1
    # Template
    window.productTemplate = Handlebars.compile($('#product_template').text())

    # Helper
    helper = new Helper

    $('#taxon_id').on "change", (e) ->
      # reset next_page
      next_page = 1
      # reset load more button
      $('#load-more').hide()
      # load Products
      helper.loadFollowing()

    $('#load-more').on "click", (e) ->
      # Load more products
      helper.loadFollowing()

    $('#taxon_products').sortable({handle: ".js-sort-handle" });

    $('#taxon_products').on "sortstop", (event, ui) ->
      $.ajax
        url: Spree.routes.classifications_api,
        method: 'PUT',
        dataType:'json',
        data:
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

    $('#taxon_products').on "click", ".js-delete-product", (e) ->
      current_taxon_id = $("#taxon_id").val();
      product = $(this).parents(".product")
      product_id = product.data("product-id");
      product_taxons = String(product.data("taxons")).split(',').map(Number);
      product_index = product_taxons.indexOf(parseFloat(current_taxon_id));
      product_taxons.splice(product_index, 1);
      $.ajax
        url: Spree.routes.products_api + "/" + product_id + "?product[taxon_ids]=" + product_taxons,
        type: "PUT",
        success: (data) ->
          product.fadeOut 400, (e) ->
            product.remove()

    $('#taxon_products').on "click", ".js-edit-product", (e) ->
      product = $(this).parents(".product")
      product_id = product.data("product-id")
      window.location = Spree.routes.edit_product(product_id)

    $(".variant_autocomplete").variantAutocomplete();
