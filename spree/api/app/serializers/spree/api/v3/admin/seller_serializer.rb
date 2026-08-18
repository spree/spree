module Spree
  module Api
    module V3
      module Admin
        # A seller as the marketplace operator sees it: the public profile the
        # shopper also gets, plus the operational state and the settlement and
        # tax configuration only the operator sets.
        class SellerSerializer < V3::SellerSerializer
          typelize status: :string,
                   contact_email: [:string, nullable: true], billing_email: [:string, nullable: true],
                   tax_remittance: :string,
                   payouts_schedule_interval: [:string, nullable: true],
                   minimum_payout_amount: [:string, nullable: true],
                   holiday_mode_until: [:string, nullable: true],
                   terms_accepted_at: [:string, nullable: true],
                   deleted_at: [:string, nullable: true],
                   on_holiday: :boolean, sellable: :boolean,
                   products_count: :number, users_count: :number,
                   metadata: 'Record<string, unknown> | null'

          attributes :status, :contact_email, :billing_email,
                     :tax_remittance, :payouts_schedule_interval, :metadata,
                     holiday_mode_until: :iso8601,
                     terms_accepted_at: :iso8601,
                     created_at: :iso8601,
                     updated_at: :iso8601,
                     deleted_at: :iso8601

          attribute :minimum_payout_amount do |seller|
            seller.minimum_payout_amount&.to_s
          end

          # Approved but away still cannot sell, and the list has to say so
          # without the dashboard re-deriving the rule.
          attribute :on_holiday do |seller|
            seller.on_holiday?
          end

          attribute :sellable do |seller|
            seller.sellable?
          end

          # Saves the dashboard a request per row for the two counts its list
          # and header show. `count`, not `size`: a seller's catalog is the one association here
          # that can run to thousands of rows, and the list only ever renders
          # the number. Costs one COUNT per row, which is cheaper than loading
          # the catalog into memory to measure it.
          attribute :products_count do |seller|
            seller.products.count
          end

          attribute :users_count do |seller|
            seller.users.size
          end

          one :billing_address,
              resource: proc { Spree.api.admin_address_serializer },
              if: proc { |seller| seller.billing_address.present? }

          one :returns_address,
              resource: proc { Spree.api.admin_address_serializer },
              if: proc { |seller| seller.returns_address.present? }
        end
      end
    end
  end
end
