module Spree
  module Seeds
    # Seeds the option types core knows the meaning of.
    #
    # Only one so far: condition. It is an option type rather than a column
    # because that is exactly what it is — an axis that splits a product into
    # variants — and modelling it as one hands it the whole option machinery
    # for free: presentation kinds, positions, storefront pickers and facets,
    # and a separate buy box per condition rather than one winner spanning new
    # and used (docs/plans/6.0-multi-seller-marketplace.md, Decision 11).
    #
    # Seeded rather than left to the merchant so that a marketplace's sellers
    # all describe condition the same way. Nothing is enforced: the type and
    # its values are editable like any other option type's, and a store that
    # sells only new goods simply never attaches it to a product.
    #
    # Edits survive a re-run, deletions do not: the three canonical values are
    # restored by the next seed. Seeds run at install and in test setup rather
    # than on a schedule, so a merchant who prunes a value keeps it pruned in
    # practice — but a store that genuinely wants two conditions should edit
    # the third rather than delete it.
    class OptionTypes
      prepend Spree::ServiceModule::Base

      def call
        # Block form, so the defaults apply on create only — re-running the
        # seed must never overwrite a merchant's edits.
        option_type = Spree::OptionType.find_or_create_by!(name: Spree::OptionType::CONDITION_NAME) do |type|
          type.presentation = I18n.t('spree.seed.option_types.condition.label')
          type.kind = 'buttons'
          type.filterable = true
        end

        Spree::OptionType::CONDITION_VALUES.each_with_index do |value, index|
          next if option_type.option_values.exists?(name: value)

          option_type.option_values.create!(
            name: value,
            presentation: I18n.t("spree.seed.option_types.condition.values.#{value}"),
            position: index + 1
          )
        end

        option_type
      end
    end
  end
end
