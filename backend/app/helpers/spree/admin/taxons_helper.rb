module Spree
  module Admin
    module TaxonsHelper
      def taxon_path(taxon)
        taxon.ancestors.reverse.collect(&:name).join(' >> ')
      end
    end
  end
end
