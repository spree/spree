module Spree
  module Admin
    module MultiStore
      module BaseControllerDecorator
        def self.prepended(base)
          base.helper 'spree/admin/multi_store'
        end
      end
    end

    BaseController.prepend(MultiStore::BaseControllerDecorator)
  end
end
