module Spree
  module Admin
    module TestingSupport
      module TomSelect
        def tom_select(value, from:, create: false)
          fill_in(from, with: value, visible: false)

          if create
            first('.ts-dropdown .ts-dropdown-content .create.active').click
          else
            find('.ts-dropdown .ts-dropdown-content .option', text: /#{Regexp.quote(value)}/i, match: :first).click
          end
        end
      end
    end
  end
end
