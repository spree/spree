module Spree
  module Reporting
    module Adapters
      # Storage adapter contract. Adapters receive a normalized
      # Spree::Reporting::Query and return a Spree::Reporting::Result with raw
      # numeric values — the query never changes shape across adapters, which
      # is what lets storage move from live OLTP to fact tables (or an
      # external OLAP store) without touching consumers.
      class Base
        def execute(query)
          raise NotImplementedError, "#{self.class.name} must implement #execute"
        end
      end
    end
  end
end
