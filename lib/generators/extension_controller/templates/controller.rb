class <%= class_name %>Controller < Spree::BaseController
<% if options[:scaffold] %>
  scaffold :<%= singular_name %>

<% end %>

<% for action in actions %>

  def <%= action %>
  end
<% end %>
end
