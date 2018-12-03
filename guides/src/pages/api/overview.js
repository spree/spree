import * as React from 'react'
import { Link } from 'gatsby'

import Layout from '../../components/Layout'

const IndexPage = () => (
  <Layout activeRootSection="api/overview">
    <div className="center ph4 mt6 tc">
      <h1 className="mt0">Choose version of API you're using:</h1>
      <div className="mt3">
        <Link
          to="/api/"
          className="dib link ttu bg-spree-blue pv3 ph4 white br3 lh-copy"
        >
          Older v1
        </Link>{' '}
        <span className="dib mh3">or</span>
        <Link
          to="/api/v2/"
          className="dib link ttu bg-spree-blue pv3 ph4 white br3 lh-copy"
        >
          Latest v2 (OpenAPI)
        </Link>
      </div>
    </div>
  </Layout>
)

export default IndexPage
