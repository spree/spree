namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Turns each store's default package preferences into a default
      Spree::PackageType row (Spree 6.0).

      The box a store ships in used to be four loose preferences on the store
      (default_package_weight/length/width/height). It is now a row in the
      store's packaging vocabulary, alongside the cartons, pallets and
      containers wholesale orders leave on, so the same geometry can be named,
      reused and referenced by a product.

      Stores that never configured a box — the preferences still at their
      seeded zeros — get nothing, exactly as before: quoting falls back to
      content weight with no tare and no dimensions.

      Idempotent. A store that already has a default package type is skipped,
      so this never overwrites a box the merchant has since edited.
    DESC
    task package_types: :environment do
      created = 0
      skipped = 0

      Spree::Store.find_each do |store|
        if store.default_package_type.present?
          skipped += 1
          next
        end

        # Read the raw preferences hash: the four keys no longer have
        # declarations on Spree::Store, so there are no readers to call.
        # Indifferent access because how the YAML column keyed them depends on
        # what wrote it, and a symbol-only read would silently answer zero and
        # discard a merchant's configured box.
        preferences = (store.preferences || {}).with_indifferent_access
        weight, length, width, height = %i[
          default_package_weight default_package_length default_package_width default_package_height
        ].map { |key| preferences[key].to_f }

        if [weight, length, width, height].all?(&:zero?)
          skipped += 1
          next
        end

        store.package_types.create!(
          name: Spree.t('package_types.default_name'),
          kind: 'box',
          default: true,
          weight: weight.positive? ? weight : nil,
          length: length.positive? ? length : nil,
          width: width.positive? ? width : nil,
          height: height.positive? ? height : nil,
          dimensions_unit: store.metric_unit_system? ? 'cm' : 'in',
          weight_unit: store.preferred_weight_unit
        )
        created += 1
      end

      puts "  Created #{created} default package type(s); skipped #{skipped} store(s)."
    end
  end
end
