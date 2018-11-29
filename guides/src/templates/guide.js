import * as React from 'react'
import PropTypes from 'prop-types'
import Helmet from 'react-helmet'
import { graphql } from 'gatsby'
import RehypeReact from 'rehype-react'

import Layout from '../components/Layout'

import H1 from '../components/base/H1'
import H2 from '../components/base/H2'
import H3 from '../components/base/H3'
import P from '../components/base/P'
import Json from '../components/helpers/Json'
import Status from '../components/helpers/Status'
import Alert from '../components/helpers/Alert'
import Params from '../components/helpers/Params'

const renderAst = new RehypeReact({
  createElement: React.createElement,
  components: {
    h1: H1,
    h2: H2,
    h3: H3,
    p: P,
    json: Json,
    status: Status,
    alert: Alert,
    params: Params
  }
}).Compiler

export default function Template({ data }) {
  const { guide } = data

  return (
    <Layout
      nav={data.sidebarNav ? data.sidebarNav.group : []}
      activeSection={guide.fields.section}
      activeRootSection={guide.fields.rootSection}
    >
      <div className="guide-container">
        <Helmet title={`Spree Guides :: ${guide.frontmatter.title}`} />
        <div className="guide">{renderAst(guide.htmlAst)}</div>
      </div>
    </Layout>
  )
}

Template.propTypes = {
  data: PropTypes.object.isRequired
}

export const pageQuery = graphql`
  query GuideById($id: String, $rootSection: String) {
    sidebarNav: allMarkdownRemark(
      filter: {
        fields: { rootSection: { eq: $rootSection }, section: { ne: "null" } }
      }
      sort: { fields: [frontmatter___title], order: ASC }
    ) {
      group(field: fields___section) {
        section: fieldValue
        edges {
          node {
            fields {
              section
              slug
              rootSection
              isIndex
            }
            frontmatter {
              title
            }
          }
        }
      }
    }
    guide: markdownRemark(id: { eq: $id }) {
      fields {
        section
        rootSection
      }
      htmlAst
      frontmatter {
        title
      }
    }
  }
`
