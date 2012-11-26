object false
node(:error) { I18n.t(:could_not_transition, :scope => "spree.api.order") }
node(:errors) { @order.errors }
