import * as React from 'react'
import PropTypes from 'prop-types'
// import Helmet from 'react-helmet'
// import RehypeReact from 'rehype-react'

import Layout from '../components/Layout'

// import H1 from '../components/base/H1'
// import H2 from '../components/base/H2'
// import H3 from '../components/base/H3'
// import P from '../components/base/P'
// import Json from '../components/helpers/Json'
// import Status from '../components/helpers/Status'
// import Alert from '../components/helpers/Alert'
// import Params from '../components/helpers/Params'

// const renderAst = new RehypeReact({
//   createElement: React.createElement,
//   components: {
//     h1: H1,
//     h2: H2,
//     h3: H3,
//     p: P,
//     json: Json,
//     status: Status,
//     alert: Alert,
//     params: Params
//   }
// }).Compiler

export default class OpenApiTemplate extends React.Component {
  static propTypes = {
    pageContext: PropTypes.shape({
      apiPath: PropTypes.object.isRequired,
      methods: PropTypes.array
    })
  }

  render() {
    const {
      pageContext: { paths }
    } = this.props

    return (
      <Layout nav={[]}>
        <div className="guide-container">
          {console.log(paths)}
          {paths.map(path => (
            <h1>{path.name}</h1>
          ))}
        </div>
      </Layout>
    )
  }
}
