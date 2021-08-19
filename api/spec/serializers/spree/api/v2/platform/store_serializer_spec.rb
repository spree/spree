require 'spec_helper'

describe Spree::Api::V2::Platform::StoreSerializer do
  subject { described_class.new(store) }

  let!(:store) { Spree::Store.default }
  let!(:menus) { [create(:menu, store: store), create(:menu, location: 'Footer', store: store)] }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: store.id.to_s,
          type: :store,
          attributes: {
            name: store.name,
            url: store.url,
            meta_description: store.meta_description,
            meta_keywords: store.meta_keywords,
            seo_title: store.seo_title,
            mail_from_address: store.mail_from_address,
            default_currency: store.default_currency,
            code: store.code,
            default: store.default,
            created_at: store.created_at,
            updated_at: store.updated_at,
            supported_currencies: store.supported_currencies,
            facebook: store.facebook,
            twitter: store.twitter,
            instagram: store.instagram,
            default_locale: store.default_locale,
            customer_support_email: store.customer_support_email,
            description: store.description,
            address: store.address,
            contact_phone: store.contact_phone,
            new_order_notifications_email: store.new_order_notifications_email,
            seo_robots: store.seo_robots,
            supported_locales: store.supported_locales
          },
          relationships: {
            default_country: {
              data: {
                id: store.default_country.id.to_s,
                type: :country
              }
            },
            menus: {
              data: [
                {
                  id: store.menus.first.id.to_s,
                  type: :menu
                },
                {
                  id: store.menus.second.id.to_s,
                  type: :menu
                }
              ]
            }
          },
        }
      }
    )
  end
end
