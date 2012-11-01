module Spree
  module Admin
    module TaxonsHelper
      def taxon_path(taxon)
        taxon.ancestors.reverse.collect { |ancestor| ancestor.name }.join( " >> ")
      end
    end
  end
end
