import * as React from 'react'

import Layout from '../../../components/Layout'
import openApiNav from '../../../utils/openApiNav'

const IndexPage = () => (
  <Layout activeSection="API V2" nav={openApiNav}>
    <p>API v2 Index Content</p>
  </Layout>
)

export default IndexPage
