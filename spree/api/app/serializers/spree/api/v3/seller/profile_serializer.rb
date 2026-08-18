module Spree
  module Api
    module V3
      module Seller
        # A seller's own record, as they see it.
        #
        # Sits between the two existing views: more than the shopper's public
        # profile (the seller needs their contact details and where they stand
        # in the marketplace), less than the operator's (they read their
        # settlement terms but never the operator's private notes).
        #
        # `status` and `sellable` are readable but not writable — a seller
        # should know they are suspended; moving between states is the
        # operator's decision, made through workflows.
        class ProfileSerializer < V3::SellerSerializer
          typelize status: :string,
                   contact_email: [:string, nullable: true],
                   billing_email: [:string, nullable: true],
                   tax_remittance: :string,
                   payouts_schedule_interval: [:string, nullable: true],
                   minimum_payout_amount: [:string, nullable: true],
                   holiday_mode_until: [:string, nullable: true],
                   terms_accepted_at: [:string, nullable: true],
                   on_holiday: :boolean, sellable: :boolean,
                   products_count: :number

          attributes :status, :contact_email, :billing_email,
                     :tax_remittance, :payouts_schedule_interval,
                     holiday_mode_until: :iso8601,
                     terms_accepted_at: :iso8601,
                     created_at: :iso8601

          attribute :minimum_payout_amount do |seller|
            seller.minimum_payout_amount&.to_s
          end

          attribute :on_holiday do |seller|
            seller.on_holiday?
          end

          attribute :sellable do |seller|
            seller.sellable?
          end

          attribute :products_count do |seller|
            seller.products.count
          end

          one :billing_address,
              resource: proc { Spree.api.address_serializer },
              if: proc { |seller| seller.billing_address.present? }

          one :returns_address,
              resource: proc { Spree.api.address_serializer },
              if: proc { |seller| seller.returns_address.present? }
        end
      end
    end
  end
end
