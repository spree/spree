module Admin::TaxonsHelper
  def taxon_path(taxon)
    taxon.ancestors.reverse.collect { |ancestor| ancestor.presentation }.join( " >> ")
  end
end