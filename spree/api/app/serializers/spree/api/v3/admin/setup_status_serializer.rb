module Spree
  module Api
    module V3
      module Admin
        # Whether the installation still waits for its first admin.
        class SetupStatusSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize setup_required: [:boolean, comment: 'True only while the installation has no admin user']

          attributes :setup_required
        end
      end
    end
  end
end
