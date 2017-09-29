# Temporary fix for problems with AR belongs_to_required_by_default
ActiveRecord::Associations::Builder::BelongsTo.class_eval do
  def self.define_validations(model, reflection)
    if reflection.options.key?(:required)
      reflection.options[:optional] = !reflection.options.delete(:required)
    end

    required = if reflection.options[:optional].nil?
                 model.belongs_to_required_by_default && !model.name.index(/(Spree|FriendlyId)/)
               else
                 !reflection.options[:optional]
               end

    super

    if required
      model.validates_presence_of reflection.name, message: :required
    end
  end
end
