class Admin::TaxRatesController < Admin::ResourceController
  before_filter :load_data

  update.after :update_after
  create.after :create_after

  private
  
  def load_data
    @available_zones = Zone.order(:name)
    @available_categories = TaxCategory.order(:name)
    @calculators = TaxRate.calculators
  end

  def update_after
    Rails.cache.delete('vat_rates')
  end

  def create_after
    Rails.cache.delete('vat_rates')
  end
end
