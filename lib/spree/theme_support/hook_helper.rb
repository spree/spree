module Spree::ThemeSupport::HookHelper
  
  # Allow hooks to be used in views like this:
  # 
  #   <%= hook :some_hook %>
  #
  #   <% hook :some_hook do %>
  #     <p>Some HTML</p>
  #   <% end %>
  # 
  def hook(hook_name, &block)
    content = block_given? ? capture(&block) : ''
    result = Spree::ThemeSupport::Hook.render_hook(hook_name, content, self)
    block_given? ? concat(result) : result
  end

end