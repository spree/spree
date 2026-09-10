module Spree
  module Api
    module V3
      module Admin
        # One home-screen counter, as evaluated for the caller. A value
        # object, so it carries no id: `key` is the registered counter name.
        class DashboardCounterSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize key: :string, label: :string, description: [:string, nullable: true], value: :number,
                   link: ['{ resource: string; filters: Array<{ field: string; operator: string; value: string }> } | null',
                          comment: 'The list filter that shows exactly the rows counted, or null when no list can.']

          attributes :key, :label, :description, :value, :link
        end
      end
    end
  end
end
