# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ReportSerializer < BaseSerializer
        typelize type: [:string, nullable: true],
                 user_id: [:string, nullable: true],
                 currency: [:string, nullable: true],
                 date_from: [:string, nullable: true], date_to: [:string, nullable: true]

        attributes :type, :currency,
                   created_at: :iso8601, updated_at: :iso8601

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
