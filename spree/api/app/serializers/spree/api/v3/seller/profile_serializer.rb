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
                   products_count: :number,
                   default_currency: :string,
                   supported_currencies: [:string, multi: true]

          attributes :status, :legal_name, :registration_number,
                     :contact_email, :billing_email,
                     :tax_remittance, :payouts_schedule_interval,
                     holiday_mode_until: :iso8601,
                     terms_accepted_at: :iso8601,
                     created_at: :iso8601

          attribute :minimum_payout_amount do |seller|
            seller.minimum_payout_amount&.to_s
          end

          # Rebound from the inherited store declaration to this branch's own
          # serializer: a seller reading their own profile gets the seller
          # shape of a policy (with `created_at`), which is what the seller
          # SDK's generated type and this branch's OpenAPI schema promise.
          _attributes.delete(:policies)
          many :policies,
               resource: proc { Spree.api.seller_policy_serializer },
               if: proc { expand?('policies') }

          attribute :on_holiday do |seller|
            seller.on_holiday?
          end

          attribute :sellable do |seller|
            seller.sellable?
          end

          # What this seller prices in. Theirs by way of the marketplace: a
          # seller has no currency of their own, so the store's is the answer
          # to "what does this amount mean".
          attribute :default_currency do |seller|
            seller.store&.default_currency
          end

          attribute :supported_currencies do |seller|
            seller.store&.supported_currencies_list&.map(&:iso_code) || []
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
