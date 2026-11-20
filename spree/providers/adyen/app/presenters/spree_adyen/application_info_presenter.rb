module SpreeAdyen
  # Names Spree and this gem on every Checkout request, as Adyen's partner
  # checklist requires (https://docs.adyen.com/development-resources/application-information).
  class ApplicationInfoPresenter
    def to_h
      {
        applicationInfo: {
          externalPlatform: {
            name: 'Spree Commerce',
            version: Spree.version,
            integrator: 'Vendo Sp. z o.o.'
          },
          merchantApplication: {
            name: 'spree_adyen',
            version: Spree.version
          }
        }
      }
    end
  end
end
