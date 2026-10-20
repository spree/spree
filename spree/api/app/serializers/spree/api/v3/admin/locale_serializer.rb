module Spree
  module Api
    module V3
      module Admin
        # The dashboard names locales with Intl.DisplayNames in the admin's
        # own language, so the Admin API sends the code alone.
        class LocaleSerializer < V3::LocaleSerializer
          _attributes.delete(:name)
        end
      end
    end
  end
end
