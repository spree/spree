const path = require('path')
const { createFilePath } = require(`gatsby-source-filesystem`)

exports.createPages = ({ actions, graphql }) => {
  const { createPage } = actions

  const guideTemplate = path.resolve(`src/templates/guide.js`)

  return graphql(`
    {
      allFile(filter: { ext: { eq: ".md" } }) {
        edges {
          node {
            relativeDirectory
            relativePath
            ext
            childMarkdownRemark {
              id
            }
          }
        }
      }
    }
  `).then(result => {
    if (result.errors) {
      return Promise.reject(result.errors)
    }

    result.data.allFile.edges.forEach(({ node }) => {
      const section = node.relativeDirectory
      const hasSubsections = section.split('/').length > 1
      const sectionWithSubsectionsGlob = `${section.split('/')[0]}/*`

      createPage({
        path: node.relativePath.replace('.md', '.html'),
        component: guideTemplate,
        context: {
          id: node.childMarkdownRemark.id,
          section: hasSubsections ? sectionWithSubsectionsGlob : section
        }
      })
    })
  })
}

/**
 * Generate table of contest field for article based on headers
 */
exports.onCreateNode = ({ node, getNode, actions }) => {
  const { createNodeField } = actions
  if (node.internal.type === `MarkdownRemark`) {
    const slug = createFilePath({ node, getNode, basePath: `content` })
    createNodeField({
      node,
      name: 'slug',
      value: slug.replace(/(\/$)/, '.html')
    })

    const pathArray = slug.split('/').filter(item => item !== '')
    pathArray.pop()

    createNodeField({
      node,
      name: 'path',
      value: pathArray
    })

    createNodeField({
      node,
      name: 'depth',
      value: pathArray.length
    })

    createNodeField({
      node,
      name: 'rootSection',
      value: pathArray[0]
    })
  }
}
