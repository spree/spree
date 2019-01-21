import * as React from 'react'

import Layout from '../components/Layout'

const IndexPage = () => (
  <Layout>
    <div className="center mw9 ph4 mt5">
      <p className="lh-copy f3 tc mw7 center">
        Spree Commerce is a complete modular, API-driven open source e-commerce
        solution built with Ruby on Rails.
      </p>

      <p className="lh-copy f3 bt pt3 b--light-gray tc mw7 center mt3">
        Guides are hosted and maintained by
        <br />
        <a
          href="https://sparksolutions.co/"
          target="_blank"
          rel="noopener"
          className="link spree-blue fw6"
        >
          Spark Solutions
        </a>
      </p>
    </div>
  </Layout>
)

export default IndexPage
