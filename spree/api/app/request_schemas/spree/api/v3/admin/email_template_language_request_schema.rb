module Spree
  module Api
    module V3
      module Admin
        # The language every email template endpoint takes. Read from the raw
        # params (Admin::EmailTemplateLookup), so never permitted. Not
        # published on its own.
        class EmailTemplateLanguageRequestSchema < Spree::Api::V3::RequestSchema
          attribute :language, :string,
            permit: false,
            example: 'any',
            description: 'A language code, or `any` (the default) for the version every language uses.'
        end
      end
    end
  end
end
