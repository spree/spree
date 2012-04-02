// This is a manifest file that'll be compiled into including all the files listed below.
// Add new JavaScript/Coffee code in separate files in this directory and they'll automatically
// be included in the compiled file accessible from http://example.com/assets/application.js
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
<% if options[:lib_name] == 'spree' %>
//= require store/spree_core
//= require store/spree_auth
//= require store/spree_promo
<% else %>
//= require store/<%= options[:lib_name].gsub("/", "_") %>
<% end %>
//= require_tree .
