module Spree
  module Api
    module V3
      module Admin
        # One home-screen counter, as evaluated for the caller. A value
        # object, so it carries no id: `key` is the registered counter name,
        # and it carries no copy either — the dashboard owns every string it
        # shows and translates the key in its own locale.
        class DashboardCounterSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize key: [:string, comment: 'Registered counter name. The dashboard translates it; built-in: orders_to_fulfill, payments_to_collect, open_returns, open_exchanges, open_claims, low_stock_items, out_of_stock_items.'],
                   value: :number,
                   link: ['{ resource: string; filters: Array<{ field: string; operator: string; value: string }> } | null',
                          comment: 'The list filter that shows exactly the rows counted, or null when no list can.'],
                   nav: [:string, nullable: true, comment: 'Sidebar entry key this count badges, or null.']

          attributes :key, :value, :link, :nav
        end
      end
    end
  end
end
