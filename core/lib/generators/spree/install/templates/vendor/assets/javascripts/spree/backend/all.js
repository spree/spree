// This is a manifest file that'll be compiled into including all the files listed below.
// Add new JavaScript/Coffee code in separate files in this directory and they'll automatically
// be included in the compiled file accessible from http://example.com/assets/application.js
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
//= require spree/backend
<% unless options[:lib_name] == 'spree' || options[:lib_name] == 'spree/backend' %>
  <% filename = "spree/backend/#{ options[:lib_name].gsub("/", "_") }" %>
  <% filepath = File.join(File.dirname(__FILE__), "../../app/assets/javascripts/#{filename}") %>
  <% if javascript_exists?(filepath) %>
    //= require <%= filename %>
  <% end %>
<% end %>
//= require_tree .
