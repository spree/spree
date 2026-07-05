module Spree
  class ReportLineItem
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_accessor :record, :report

    delegate :store, :currency, to: :report
    delegate :id, to: :record, prefix: true

    def self.headers
      attribute_types.keys.map do |attribute|
        { name: attribute.to_sym, label: Spree.t(attribute.to_sym) }
      end
    end

    def self.csv_headers
      attribute_types.keys
    end

    def to_csv
      self.class.attribute_types.keys.map do |attribute|
        send(attribute)
      end
    end
  end
end
