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
    <div className="center mw9 ph4">
      <h3 className="f3 tc mv5">Choose API version</h3>

      <div className="mw7 center">
        <div className="flex flex-column flex-row-ns">
          <Section path="/api/v2" title="REST API v2" className="mr2-ns">
            Modern lightweight REST API based on&nbsp;
            <ExternalLink url="https://jsonapi.org">
              JSON API schema
            </ExternalLink>{' '}
            built on top of Netflix{' '}
            <ExternalLink url="https://github.com/Netflix/fast_jsonapi">
              fast_json_api
            </ExternalLink>{' '}
            gem and oAuth authentication. Postman collection available.
          </Section>

          <Section title="Graph QL" className="ml2-ns">
            GraphQL support is coming soon!
          </Section>
        </div>

        <Section path="/api/" title="Legacy REST API v1" className="mt2-ns tc">
          Older REST API that requires API key authentication for access.
        </Section>
      </div>
    </div>
  </Layout>
)

export default IndexPage
