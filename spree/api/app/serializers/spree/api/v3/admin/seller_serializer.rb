module Spree
  module Api
    module V3
      module Admin
        # A seller as the marketplace operator sees it: the public profile the
        # shopper also gets, plus the operational state and the settlement and
        # tax configuration only the operator sets.
        class SellerSerializer < V3::SellerSerializer
          typelize status: [:string, enum: Spree::Seller.statuses, enum_type_name: 'SellerStatus'],
                   legal_name: [:string, nullable: true],
                   registration_number: [:string, nullable: true],
                   contact_email: [:string, nullable: true], billing_email: [:string, nullable: true],
                   tax_remittance: :string,
                   payouts_schedule_interval: [:string, nullable: true],
                   minimum_payout_amount: [:string, nullable: true],
                   holiday_mode_until: [:string, nullable: true],
                   terms_accepted_at: [:string, nullable: true],
                   deleted_at: [:string, nullable: true],
                   on_holiday: :boolean, sellable: :boolean,
                   products_count: :number, users_count: :number,
                   onboarding_progress: '{ done: number; total: number }',
                   onboarding_complete: :boolean,
                   metadata: 'Record<string, unknown> | null'

          attributes :status, :contact_email, :billing_email,
                     :tax_remittance, :payouts_schedule_interval, :metadata,
                     holiday_mode_until: :iso8601,
                     terms_accepted_at: :iso8601,
                     created_at: :iso8601,
                     updated_at: :iso8601,
                     deleted_at: :iso8601

          # A seller's policies are the seller's own, managed on the seller
          # branch — the operator neither edits nor lists them in 6.0. The
          # inherited declaration is dropped rather than shadowed, since
          # keeping it would render a store serializer inside an admin
          # response.
          _attributes.delete(:policies)

          # Stored without a currency, so it is shown as stored rather than
          # rounded to the store's: a rounded figure would be saved back.
          attribute :minimum_payout_amount do |seller|
            Spree::Money::Rounding.format(seller.minimum_payout_amount, (current_store || Spree::Current.store)&.default_currency, unit_price: true)
          end

          # Approved but away still cannot sell, and the list has to say so
          # without the dashboard re-deriving the rule.
          attribute :on_holiday, &:on_holiday?

          attribute :sellable, &:sellable?

          # Saves the dashboard a request per row for the two counts its list
          # and header show. Read off the seller, which memoizes the SQL count
          # so the minimum-products requirement asks the same question free.
          attributes :products_count

          attribute :users_count do |seller|
            seller.users.size
          end

          # How far through the marketplace's checklist this seller is — what
          # the list's progress column and the profile's badge render. The
          # requirements themselves, with their submissions, stay on the
          # heavier `onboarding` action; a list of sellers needs the number,
          # not the rows behind it.
          attributes :onboarding_progress

          attribute :onboarding_complete, &:onboarding_complete?

          attribute :legal_name, &:legal_name
          attribute :registration_number, &:registration_number

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
