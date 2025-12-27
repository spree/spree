module Spree
  module Webhooks
    def self.table_name_prefix
      'spree_webhooks_'
    end

    class Base < Spree.base_class
      self.abstract_class = true
    end
  end
end
