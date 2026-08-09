module SpreeStripe
  class RegisterDomainJob < BaseJob
    def perform(model_id, klass_type = 'store')
      model = model_class(klass_type)&.find_by(id: model_id)
      return if model.blank?

      RegisterDomain.new.call(model: model)
    end

    private

    def model_class(klass_type)
      case klass_type
      when 'store' then Spree::Store
      when 'custom_domain' then Spree::CustomDomain if defined?(Spree::CustomDomain)
      end
    end
  end
end
