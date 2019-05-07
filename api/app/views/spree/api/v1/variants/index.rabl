object false
node(:count) { @variants.count }
node(:total_count) { @variants.total_count }
node(:current_page) { params[:page] ? params[:page].to_i : 1 }
node(:pages) { @variants.total_pages }

child(@variants => :variants) do
  extends 'spree/api/v1/variants/big'
end
