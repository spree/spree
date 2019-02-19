import * as React from 'react'

import Layout from 'components/Layout'
import Section from 'components/Section'
import ExternalLink from 'components/ExternalLink'

const IndexPage = () => (
  <Layout
    pathname="/"
    title="Spree API"
    activeRootSection="api"
    description="Spree Commerce REST API v2, REST API v1 & GrapQL documentation"
  >
    <div className="center mw9 ph4 mt5">
      <p className="lh-copy f3 tc mw7 center mb5">Choose API version</p>

      <div className="mw8 center">
        <div className="flex flex-row flex-column-m mv4">
          <Section path="/api/v2" title="REST API v2" className="mr3">
            Modern lightweight REST API based on&nbsp;
            <ExternalLink url="https://jsonapi.org">JSON API schema</ExternalLink>
            &nbsp;built on top of Netflix
            <ExternalLink url="https://github.com/Netflix/fast_jsonapi">
              fast_json_api
            </ExternalLink>
            &nbsp;gem and oAuth authentication. Postman collection available.
          </Section>

          <Section title="Graph QL" className="ml3">
            GraphQL support is coming soon!
          </Section>
        </div>

        <div className="flex flex-row flex-column-m mb5">
          <Section path="/api/" title="Legacy REST API v1" className="mr3">
            Older REST API that requires API key authentication for access.
          </Section>
        </div>
      </div>
    </div>
  </Layout>
)

export default IndexPage
