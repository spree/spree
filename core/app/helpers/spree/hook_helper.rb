module Spree
  module HookHelper
    # This method is deprecated, left in place
    # to prevent views from breaking
    def hook(hook_name, locals = {}, &block)
      warn "[DEPRECATION] `hook` is deprecated"
      content = block_given? ? capture(&block) : ''
      content
    end
  end
end
