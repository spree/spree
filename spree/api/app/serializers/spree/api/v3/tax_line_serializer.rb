module Spree
  module Api
    module V3
      class TaxLineSerializer < BaseSerializer
        typelize label: :string, amount: :string, display_amount: :string,
                 included: :boolean, tax_rate_id: :string

        attributes :label, :display_amount, :included

        attribute :amount do |tax_line|
          tax_line.amount.to_s
        end

        attribute :tax_rate_id do |tax_line|
          tax_line.tax_rate&.prefixed_id
        end
      end
    end
  end
end
