object false
node(:error) { I18n.t(:invalid_resource, scope: 'spree.api') }
node(:errors) { @resource.errors.to_hash }
