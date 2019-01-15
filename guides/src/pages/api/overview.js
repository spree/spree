import * as React from 'react'

import Layout from '../../components/Layout'
import Button from '../../components/base/Button'

const IndexPage = () => (
  <Layout activeSection="api/overview">
    <div className="center ph4 mt6 tc">
      <h1 className="mt0">Choose version of API you're using:</h1>
      <div className="mt3">
        <Button to="/api/">Older v1</Button>
        <span className="dib mh3">or</span>
        <Button to="/api/v2/">Latest v2 (OpenAPI)</Button>
      </div>
    </div>
  </Layout>
)

export default IndexPage
