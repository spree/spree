const path = require('path')
const { createFilePath } = require(`gatsby-source-filesystem`)
const {
  split,
  dropLast,
  replace,
  without,
  length,
  last,
  equals
} = require('ramda')

exports.createPages = ({ actions, graphql }) => {
  const { createPage } = actions

  const guideTemplate = path.resolve(`src/templates/guide.js`)

  return graphql(`
    {
      guides: allFile(filter: { sourceInstanceName: { eq: "guides" } }) {
        edges {
          node {
            name
            content: childMarkdownRemark {
              id
              frontmatter {
                title
              }
              fields {
                slug
                depth
                rootSection
                section
              }
            }
          }
        }
      }
    }
  `).then(result => {
    if (result.errors) {
      return Promise.reject(result.errors)
    }

    result.data.guides.edges.forEach(({ node }) => {
      createPage({
        path: node.content.fields.slug,
        component: guideTemplate,
        context: {
          id: node.content.id,
          section: node.content.fields.section,
          rootSection: node.content.fields.rootSection,
          slug: node.content.fields.slug,
          depth: node.content.fields.depth
        }
      })
    })
  })
}

exports.onCreateNode = ({ node, getNode, actions }) => {
  const { createNodeField } = actions
  if (node.internal.type === `MarkdownRemark`) {
    const slug = createFilePath({ node, getNode, basePath: `content` })
    const pathArray = without([''], split('/', slug))
    const slugFieldValue = replace(/(\/$)/, '.html', slug)
    const rootSectionValue = pathArray[0]
    const depthFieldValue = length(dropLast(1, pathArray))
    const sectionFieldValue = last(dropLast(1, pathArray))

    createNodeField({
      node,
      name: 'slug',
      value: slugFieldValue
    })

    createNodeField({
      node,
      name: 'depth',
      value: depthFieldValue
    })

    createNodeField({
      node,
      name: 'rootSection',
      value: rootSectionValue
    })

    createNodeField({
      node,
      name: 'section',
      value: sectionFieldValue || 'null'
    })

    // console.log(`
    //   array: ${pathArray};
    //   slug: ${slugFieldValue};
    //   depth: ${depthFieldValue};
    //   rootSection: ${rootSectionValue};
    //   section: ${sectionFieldValue};
    //   ---------------------------------------------------
    // `)
  }
}
