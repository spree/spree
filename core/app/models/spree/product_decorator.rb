module Spree
  module ProductDecorator
    def self.prepended(base)
      base.class_eval do
        # Add tag search to the searchable scopes
        def self.ransackable_scopes(auth_object = nil)
          super + [:tagged_with]
        end

        # Add tag search to ransackable scopes
        def self.ransackable_scopes_skip_sanitize_arguments
          [:tagged_with]
        end
      end
    end
  end
end

Spree::Product.prepend(Spree::ProductDecorator) if Spree::Product.included_modules.exclude?(Spree::ProductDecorator)
