const path = require('path')
const { createFilePath } = require(`gatsby-source-filesystem`)
const R = require('ramda')
// const SwaggerParser = require('swagger-parser')

exports.createPages = ({ actions, graphql }) => {
  const { createPage } = actions

  const guideTemplate = path.resolve(`src/templates/guide.js`)
  // const openApiTemplate = path.resolve(`src/templates/openApi.js`)

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
                isIndex
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

    // const ApiParser = new SwaggerParser()

    // ApiParser.parse('../api/docs/v2/storefront/index.yaml').then(api => {
    //   const parsedApi = { tags: [] }

    //   Object.keys(api.paths).map(path => {
    //     Object.keys(api.paths[path]).map(method => {
    //       api.paths[path][method]['tags'].map(tag => {
    //         const tagObject = {
    //           name: tag,
    //           paths: [
    //             {
    //               name: path,
    //               methods: {
    //                 name: method,
    //                 data: api.paths[path][method]
    //               }
    //             }
    //           ]
    //         }

    //         const tagIndex = R.findIndex(R.propEq('name', tag))(parsedApi.tags)

    //         if (tagIndex > 0) {
    //           parsedApi.tags[tagIndex]['paths'].push(tagObject.paths)
    //         } else {
    //           parsedApi.tags.push(tagObject)
    //         }
    //       })
    //     })
    //   })

    //   const normalizedData = []

    //   parsedApi.tags.forEach(tag => {
    //     const tagName = tag.name
    //     const tagIndex = R.findIndex(R.propEq('name', tagName))(normalizedData)

    //     if (R.isNil(tagIndex) || tagIndex === -1) {
    //       normalizedData.push(tag)
    //     } else {
    //       normalizedData[tagIndex]['paths'].push(tag.paths)
    //     }
    //   })

    //   normalizedData.forEach(tag =>
    //     createPage({
    //       path: `/api/v2/storefront/${R.toLower(tag.name)}`,
    //       component: openApiTemplate,
    //       context: {
    //         paths: tag.paths
    //       }
    //     })
    //   )
    // })

    result.data.guides.edges.forEach(({ node }) => {
      createPage({
        path: node.content.fields.slug,
        component: guideTemplate,
        context: {
          id: node.content.id,
          section: node.content.fields.section,
          rootSection: node.content.fields.rootSection,
          slug: node.content.fields.slug,
          depth: node.content.fields.depth,
          isIndex: node.content.fields.isIndex
        }
      })
    })
  })
}

exports.onCreateNode = ({ node, getNode, actions }) => {
  const { createNodeField } = actions

  if (node.internal.type === `MarkdownRemark`) {
    const slug = createFilePath({ node, getNode, basePath: `content` })
    const pathArray = R.without([''], R.split('/', slug))
    const rootSectionValue = pathArray[0]
    const isIndex = R.contains('index.md', R.split('/', node.fileAbsolutePath))
    const depthFieldValue = isIndex
      ? R.length(pathArray)
      : R.length(R.dropLast(1, pathArray))
    const sectionFieldValue = isIndex
      ? R.last(pathArray)
      : R.last(R.dropLast(1, pathArray))
    const slugWithExt = `${R.join(
      '/',
      R.without([''], R.split('/', slug))
    )}.html`

    createNodeField({
      node,
      name: 'slug',
      value: isIndex ? slug : slugWithExt
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

    createNodeField({
      node,
      name: 'isIndex',
      value: isIndex
    })
  }
}
