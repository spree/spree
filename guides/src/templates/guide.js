// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import { graphql } from 'gatsby'
import RehypeReact from 'rehype-react'

// --- Components
import Layout from '../components/Layout'
import Hr from '../components/base/Hr'
import H1 from '../components/base/H1'
import H2 from '../components/base/H2'
import H3 from '../components/base/H3'
import H4 from '../components/base/H4'
import P from '../components/base/P'
import Json from '../components/helpers/Json'
import Status from '../components/helpers/Status'
import Alert from '../components/helpers/Alert'
import Params from '../components/helpers/Params'
import Table from '../components/base/Table'
import Td from '../components/base/Td'
import Th from '../components/base/Th'
import Toc from '../components/Toc'
import MarkdownPageFooter from '../components/MarkdownPageFooter'

/**
 * Helpers
 */

const renderAst = new RehypeReact({
  createElement: React.createElement,
  components: {
    h1: H1,
    h2: H2,
    h3: H3,
    h4: H4,
    p: P,
    hr: Hr,
    json: Json,
    status: Status,
    alert: Alert,
    params: Params,
    table: Table,
    td: Td,
    th: Th
  }
}).Compiler

/**
 * Component
 */

export default function Template({ data }) {
  const { guide } = data

  let pageTitle = guide.frontmatter.title
  if (guide.fields.rootSection) {
    pageTitle += ` | ${guide.fields.rootSection.replace(/_/, ' ')}`
  }

  let pageDescription = guide.frontmatter.description
  if (!pageDescription) {
    const removalRegexp = /Overview|Introduction|Major\/New Features/
    pageDescription = guide.excerpt.replace(removalRegexp, '').trim()
  }

  return (
    <Layout
      title={pageTitle}
      description={pageDescription}
      nav={data.sidebarNav ? data.sidebarNav.group : []}
      activeSection={guide.fields.section}
      activeRootSection={guide.fields.rootSection}
    >
      {guide.headings.length > 0 && <Toc headings={guide.headings} />}
      <article className="mt2 nested-links">
        <H1>{guide.frontmatter.title}</H1>
        {renderAst(guide.htmlAst)}
        <MarkdownPageFooter
          section={guide.fields.section}
          title={guide.frontmatter.title}
          group={data.sidebarNav.group}
          isIndex={guide.fields.isIndex}
        />
      </article>
    </Layout>
  )
}

Template.propTypes = {
  data: PropTypes.object.isRequired
}

/**
 * Page Query
 */

export const pageQuery = graphql`
  query GuideById($id: String, $rootSection: String) {
    sidebarNav: allMarkdownRemark(
      filter: {
        fields: { rootSection: { eq: $rootSection }, section: { ne: null } }
        frontmatter: { hidden: { ne: true } }
      }
      sort: { fields: [frontmatter___order, frontmatter___title], order: ASC }
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
            excerpt
          }
        }
      }
    }
    guide: markdownRemark(id: { eq: $id }) {
      headings {
        depth
        value
      }
      fields {
        section
        rootSection
        isIndex
      }
      htmlAst
      frontmatter {
        title
        description
      }
      excerpt(pruneLength: 160)
    }
  }
`
