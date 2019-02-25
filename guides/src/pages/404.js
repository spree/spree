import React from 'react'
import { Link } from 'gatsby'
import Layout from '../components/Layout'
import H1 from '../components/base/H1'
import P from '../components/base/P'

const NotFoundPage = () => (
  <Layout>
    <div className="center mw9 ph4 mt5">
      <div className="mw8 center">
        <H1>
          <strong>404</strong> Page couldn't be found
        </H1>
        <P>Page you requested doesn't exist...</P>
        <P>
          For documentation for developers please go to&nbsp;
          <Link to="/developer">Developer section</Link>
        </P>
        <P>
          For documentation for store owners please go to&nbsp;
          <Link to="/user">User section</Link>
        </P>
        <P>
          For documentation on the API go to&nbsp;
          <Link to="/api/overview">API section</Link>
        </P>
      </div>
    </div>
  </Layout>
)

export default NotFoundPage
