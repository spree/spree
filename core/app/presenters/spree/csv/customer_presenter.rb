module Spree
  module CSV
    class CustomerPresenter
      HEADERS = [
        'First Name',
        'Last Name',
        'Email',
        'Accepts Email Marketing',
        'Company',
        'Address 1',
        'Address 2',
        'City',
        'Province',
        'Province Code',
        'Country',
        'Country Code',
        'Zip',
        'Phone',
        'Total Spent',
        'Total Orders',
        'Tags'
      ].freeze

      def initialize(customer)
        @customer = customer
      end

      attr_accessor :customer

      def call
        [
          customer.first_name,
          customer.last_name,
          customer.email,
          customer.accepts_email_marketing ? Spree.t(:say_yes) : Spree.t(:say_no),
          customer.address&.company,
          customer.address&.address1,
          customer.address&.address2,
          customer.address&.city,
          customer.address&.state_text,
          customer.address&.state_abbr,
          customer.address&.country&.name,
          customer.address&.country&.iso,
          customer.address&.zipcode,
          customer.phone,
          customer.amount_spent_in(Spree::Store.current.default_currency),
          customer.completed_orders.count,
          customer.tag_list
        ]
      end
    end
  end
end
