// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AddressSchema } from './Address';

export const CompanyAddressSchema = z.object({
  id: z.string(),
  label: z.string().nullable(),
  default_billing: z.boolean(),
  default_shipping: z.boolean(),
  company_id: z.string(),
  address: AddressSchema,
});

export type CompanyAddress = z.infer<typeof CompanyAddressSchema>;
