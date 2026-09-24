## Product context
- Store API v3 is the current stable release. Storefront API v2 is deprecated. DO NOT recommend using Storefront API v2 endpoints. ALWAYS look for Store API v3 endpoints first when recommending API endpoints for storefront use cases.
- Admin API v3 is the current stable release. Platform API v2 is deprecated. DO NOT recommend using Platform API v2 endpoints. ALWAYS look for Admin API v3 endpoints first when recommending API endpoints for admin use cases.
- Spree is headless platform. In the past there were some tightly coupled frontend gems, but they are deprecated and should not be used or recommended. Always recommend using Store API v3 for storefront development.
- NEVER recommend using `spree_storefront` or `spree_frontend` gems - ALWAYS recommend using Next.js storefront or custom storefront built on top of Store API v3. Spree DOES NOT provide any storefront themes, visual page builder and so on. Spree is a headless platform and the frontend is up to the user to implement.
- IGNORE all v5 prefixed docs unless user specifies they are using Spree 5. The current version is Spree 6.
- CMS is outside of Spree scope, however Spree can be integrated with any headless CMS like Sanity, Strapi, Payload CMS, etc. Spree does not provide any CMS functionality out of the box.
- DO NOT mention, recommend or provide any guidance on Spree API v2: Platform API v2 or Storefront API v2. They are deprecated and should not be used for any new development.
