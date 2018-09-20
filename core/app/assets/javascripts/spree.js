//= require jsuri
function Spree() {}

Spree.ready = function (callback) {
  jQuery(callback);
  return jQuery(document).on('page:load turbolinks:load', function () {
    return callback(jQuery);
  });
};

Spree.mountedAt = function () {
  return window.SpreePaths.mounted_at;
};

Spree.adminPath = function () {
  return window.SpreePaths.admin;
};

Spree.pathFor = function (path) {
  var locationOrigin = (window.location.protocol + '//' + window.location.hostname) + (window.location.port ? ':' + window.location.port : '');
  return this.url('' + locationOrigin + (this.mountedAt()) + path, this.url_params).toString();
};

Spree.adminPathFor = function (path) {
  return this.pathFor('' + (this.adminPath()) + path);
};

Spree.url = function (uri, query) {
  if (uri.path === void 0) {
    uri = new Uri(uri);
  }
  if (query) {
    $.each(query, function (key, value) {
      return uri.addQueryParam(key, value);
    });
  }
  return uri;
};

Spree.ajax = function (url_or_settings, settings) {
  var url;
  if (typeof url_or_settings === 'string') {
    return $.ajax(Spree.url(url_or_settings).toString(), settings);
  } else {
    url = url_or_settings['url'];
    delete url_or_settings['url'];
    return $.ajax(Spree.url(url).toString(), url_or_settings);
  }
};

Spree.routes = {
  states_search: Spree.pathFor('api/v1/states'),
  apply_coupon_code: function (order_id) {
    return Spree.pathFor('api/v1/orders/' + order_id + '/apply_coupon_code');
  }
};

Spree.url_params = {};
