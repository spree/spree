class Admin::TaxCategoriesController < Admin::ResourceController

  def index
    if Spree::Config[:show_price_inc_vat] and (TaxCategory.where(:is_default => true).count != 1)
      flash.notice = "You should configure exactly one default category with your countries default tax rate"
    end
  end
end
