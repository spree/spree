// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { EmailParcelItemSchema } from './EmailParcelItem';

export const EmailFulfillmentGroupSchema = z.object({
  name: z.string().nullable(),
  display_cost: z.string(),
  seller_names: z.array(z.string()),
  items: z.array(EmailParcelItemSchema),
});

export type EmailFulfillmentGroup = z.infer<typeof EmailFulfillmentGroupSchema>;
