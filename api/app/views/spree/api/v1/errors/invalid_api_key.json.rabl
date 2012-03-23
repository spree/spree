object false
node(:error) { I18n.t(:invalid_api_key, :key => params[:key], :scope => "spree.api") }
