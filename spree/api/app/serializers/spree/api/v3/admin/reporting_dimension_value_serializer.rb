module Spree
  module Api
    module V3
      module Admin
        # The display payload of a lookup-backed or enumerated dimension, as
        # Spree::Reporting::Hydration builds it.
        class ReportingDimensionValueSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize id: [:string, nullable: true,
                                 comment: 'Prefixed id of the record (`cust_…`), or the raw value of an enumerated dimension. Null when ' \
                                          'there is no record behind the group, such as guest customers.'],
                   label: :string,
                   meta: 'Record<string, unknown>'

          attributes :id, :label, :meta
        end
      end
    end
  end
end
