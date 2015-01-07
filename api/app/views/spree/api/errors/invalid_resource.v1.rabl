object false
node(:error) { I18n.t(:invalid_resource, :scope => "spree.api") }
node(:errors) { @resource.errors.to_hash }
node(:error_codes) do
  @resource.errors.set_reporter(:hash, :machine)
  @resource.errors.to_hash
end
