//= require jquery-migrate-1.0.0
//= require jquery-ui
//= require modernizr
//= require jquery.cookie
//= require jquery.delayedobserver
//= require jquery.jstree/jquery.jstree
//= require jquery.alerts/jquery.alerts
//= require jquery.powertip
//= require jquery.vAlign
//= require css_browser_selector_dev
//= require spin
//= require trunk8
//= require jquery.adaptivemenu
//= require equalize
//= require responsive-tables
//= require jquery.horizontalNav
//= require jsuri
//= require_tree .

var Spree = {
  // Helper function to take a URL and add query parameters to it
  // Uses the JSUri library from here: https://code.google.com/p/jsuri/
  // Thanks to Jake Moffat for the suggestion: https://twitter.com/jakeonrails/statuses/321776992221544449
  url: function(uri, query) {
    var uri = new Uri(uri);
    $.each(query, function (key, value) {
      uri.addQueryParam(key, value);
    });
    return uri;
  }
};
