module Spree
  module Emails
    class ImportSerializer < BaseSerializer
      attributes :number

      attribute :results_url, &:results_page_url

      attribute :completed_count do |import|
        import.rows_status_counts['completed'].to_i
      end

      attribute :failed_count do |import|
        import.rows_status_counts['failed'].to_i
      end

      one :user, resource: Spree::Emails::UserSerializer
    end
  end
end
