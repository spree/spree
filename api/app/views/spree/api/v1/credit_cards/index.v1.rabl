object false
child(@credit_cards => :credit_cards) do
  extends "spree/api/v1/credit_cards/show"
end
node(:count) { @credit_cards.count }
node(:current_page) { params[:page] || 1 }
node(:pages) { @credit_cards.total_pages }
