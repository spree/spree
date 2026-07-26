# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ReportSerializer < BaseSerializer
        typelize type: [:string, nullable: true],
                 user_id: [:string, nullable: true],
                 currency: [:string, nullable: true],
                 date_from: [:string, nullable: true], date_to: [:string, nullable: true]

        attributes :currency

        # Wire shorthand (`"sales_total"`), not the Ruby class name — clients
        # shouldn't have to know or parse `Spree::Reports::SalesTotal`.
        attribute :type do |report|
          Spree::Report.api_type_for(report.type)
        end

        attribute :user_id do |report|
          report.user&.prefixed_id
        end

        attribute :date_from do |report|
          report.date_from&.iso8601
        end

        attribute :date_to do |report|
          report.date_to&.iso8601
        end
      end
    end
  end
end
