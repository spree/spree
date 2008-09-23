module Admin::TaxonsHelper
  def taxon_path(taxon)
    taxon.ancestors.reverse.collect { |ancestor| ancestor.name }.join( " >> ")
  end
end