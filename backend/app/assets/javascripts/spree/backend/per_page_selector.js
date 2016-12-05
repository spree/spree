// per page dropdown
// preserves all selected filters / queries supplied by user
// changes only per_page value

function PerPageSelector(inputs) {
  this.perPageElement = inputs.perPageElement;
}

PerPageSelector.prototype.init = function() {
  this.bindEvents();
};

PerPageSelector.prototype.bindEvents = function() {
  var _this = this;
  this.perPageElement.change(function() {
    _this.updateFormUrl($(this));
  });
};

PerPageSelector.prototype.updateFormUrl = function($perPageElement) {
  var form = $perPageElement.closest(".js-per-page-form"),
    url  = form.attr('action'),
    value = $perPageElement.val().toString();

  if (url.match(/\?/)) {
    url += "&per_page=" + value;
  } else {
    url += "?per_page=" + value;
  }
  window.location = url;
};
