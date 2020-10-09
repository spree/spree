Spree.ready(function ($) {
  $('#sort-by-overlay-show-button').click(function () {
    $('#sort-by-overlay').show();
  });
  $('#sort-by-overlay-hide-button').click(function () {
    $('#sort-by-overlay').hide();
  });

  $('#filter-by-overlay-show-button').click(function () {
    $('#filter-by-overlay').show();
  });
  $('#filter-by-overlay-hide-button').click(function () {
    $('#filter-by-overlay').hide();
  });

  function closeNoProductModal() {
    $('#no-product-available').removeClass('shown');
    $('#overlay').removeClass('shown');
  }

  $('#no-product-available-close-button').click(closeNoProductModal);
  $('#no-product-available-hide-button').click(closeNoProductModal);

  function customEncodeURI(value) {
    return encodeURI(
      value.replace(/\s/g, '+').replace(/'/g, '%27').replace(/\$/g, '%24')
    ).replace(/%25/g, '%');
  }

  function setNewUrl(searchParams) {
    history.replaceState(
      {},
      '',
      location.pathname +
        '?' +
        customEncodeURI(decodeURIComponent(searchParams.toString()))
    );
    Turbolinks.visit(location);
  }

  function updateFilters(event, $this, removeValue) {
    event.preventDefault();
    var data = $this.closest('a[data-params]').data();
    var searchParams = new URLSearchParams(location.search);
    var key = data.filterName;
    var value = data.params[key].toString();

    searchParams.delete('page');
    if (!searchParams.has('menu_open') && data.params['menu_open']) {
      searchParams.set('menu_open', data.params['menu_open']);
    } else if (searchParams.has('menu_open') && !data.params['menu_open']) {
      searchParams.delete('menu_open');
    }

    if (searchParams.get(key) === null || !data.multiselect) {
      searchParams.set(key, value);
    } else {
      var arr = searchParams.get(key).toString().split(',');
      var index = arr.indexOf(data.id.toString());

      if (index > -1 && removeValue) {
        arr.splice(index, 1);
      } else {
        arr.push(data.id.toString());
      }

      searchParams.set(key, arr.join(','));
    }

    setNewUrl(searchParams);
  }

  $('.plp-overlay-card-item').click(function (event) {
    if (window.URLSearchParams) {
      updateFilters(
        event,
        $(this),
        $(this).hasClass('plp-overlay-card-item--selected')
      );
    }
    $(this).toggleClass('plp-overlay-card-item--selected');
  });

  $(
    '#filters-accordion .color-select, #plp-filters-accordion .color-select'
  ).click(function (event) {
    var colorItem = $(this).find('.plp-overlay-color-item');
    if (window.URLSearchParams) {
      updateFilters(
        event,
        $(this),
        colorItem.hasClass('color-select-border--selected')
      );
    }
    colorItem.toggleClass('color-select-border--selected');
  });

  $('.plp-overlay-ul-li').click(function() {
    $('.plp-overlay-ul-li').removeClass('plp-overlay-ul-li--active')
    $(this).addClass('plp-overlay-ul-li--active');
  });

  $('.plp-overlay-buttons .done-btn').click(function (event) {
    if (window.URLSearchParams) {
      event.preventDefault();
      var searchParams = new URLSearchParams(location.search);
      searchParams.delete('menu_open');
      setNewUrl(searchParams);
    }
  });
});
