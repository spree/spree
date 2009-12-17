module HookHelper
  
  # Allow hooks to be used in views like this:
  # 
  #   <%= hook :some_hook %>
  #
  #   <% hook :some_hook do %>
  #     <p>Some HTML</p>
  #   <% end %>
  # 
  def hook(hook_name, locals = {}, &block)
    content = block_given? ? capture(&block) : ''
    result = Spree::ThemeSupport::Hook.render_hook(hook_name, content, self, locals)
    block_given? ? concat(result.to_s) : result
  end

  def locals_hash(names, binding)
    names.inject({}) {|memo, key| memo[key.to_sym] = eval(key, binding); memo}
  end

end