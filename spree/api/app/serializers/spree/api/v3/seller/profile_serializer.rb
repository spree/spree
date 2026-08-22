module Spree
  module Api
    module V3
      module Seller
        class ProfileSerializer < V3::SellerSerializer
          typelize status: :string,
                   legal_name: [:string, nullable: true],
                   registration_number: [:string, nullable: true],
                   contact_email: [:string, nullable: true],
                   billing_email: [:string, nullable: true],
                   tax_remittance: :string,
                   payouts_schedule_interval: [:string, nullable: true],
                   minimum_payout_amount: [:string, nullable: true],
                   holiday_mode_until: [:string, nullable: true],
                   terms_accepted_at: [:string, nullable: true],
                   on_holiday: :boolean, sellable: :boolean,
                   products_count: :number

          attributes :status, :legal_name, :registration_number,
                     :contact_email, :billing_email,
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

          many :tax_identifiers,
               resource: proc { Spree.api.seller_tax_identifier_serializer }

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
