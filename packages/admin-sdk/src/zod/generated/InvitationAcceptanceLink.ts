// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const InvitationAcceptanceLinkSchema = z.object({
  id: z.string(),
  acceptance_url: z.string(),
});

export type InvitationAcceptanceLink = z.infer<typeof InvitationAcceptanceLinkSchema>;
