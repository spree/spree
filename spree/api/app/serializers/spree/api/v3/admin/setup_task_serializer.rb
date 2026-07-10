module Spree
  module Api
    module V3
      module Admin
        # Serializes {Spree::SetupTask} — an evaluated onboarding checklist
        # entry. A value object, so no id.
        class SetupTaskSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize name: :string, done: :boolean

          attributes :name, :done
        end
      end
    end
  end
end
