import {
  ResourceImageField as BaseResourceImageField,
  type ImageFieldsFor,
  type ResourceImageFieldProps,
} from '@spree/dashboard-core'
import { useMediaLibrarySource } from '../../hooks/use-media-library'

export type { ImageFieldsFor, ImageFieldsShape } from '@spree/dashboard-core'

/** The shared image field, with the operator's media library behind it. */
export function ResourceImageField<Name extends string, T extends ImageFieldsFor<Name>>(
  props: Omit<ResourceImageFieldProps<Name, T>, 'mediaLibrary'>,
) {
  return <BaseResourceImageField {...props} mediaLibrary={useMediaLibrarySource()} />
}
