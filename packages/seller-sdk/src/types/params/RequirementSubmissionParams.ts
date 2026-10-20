// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type RequirementSubmissionParams = {
  /** Anything the seller wants to say alongside the submission. */
  note?: string
  /** A reference number or external identifier, for requirements that ask for one. */
  reference?: string
  /** A `signed_id` from `POST /files`, for requirements that ask for a document. */
  file_signed_id?: string
}
