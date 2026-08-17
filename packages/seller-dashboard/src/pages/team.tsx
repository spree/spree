import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldGroup,
  FieldLabel,
  Input,
  useConfirm,
} from '@spree/dashboard-ui'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { sellerClient } from '../api-client'
import { CenteredMessage } from '../components/centered-message'

/**
 * Who can sign in and manage this seller.
 *
 * Everyone holds the seller's own role, which carries the whole seller
 * vocabulary — there is no narrower role to choose yet, so inviting asks only
 * for an address.
 */
export function TeamPage() {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const confirm = useConfirm()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })

  const { data, isLoading, error } = useQuery({
    queryKey: ['seller', sellerId, 'team'],
    queryFn: () => sellerClient().team.list(),
  })

  const form = useForm<{ email: string }>({ defaultValues: { email: '' } })

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'team'] })

  const invite = useMutation({
    mutationFn: (email: string) => sellerClient().team.invite({ email }),
    onSuccess: () => {
      form.reset({ email: '' })
      toast.success(t('team.invited'))
      void invalidate()
    },
    onError: () => toast.error(t('common.error')),
  })

  const remove = useMutation({
    mutationFn: (id: string) => sellerClient().team.remove(id),
    onSuccess: () => {
      toast.success(t('team.removed'))
      void invalidate()
    },
    // The server refuses to remove the last member, since emptying a team
    // leaves a seller nobody can sign in to.
    onError: () => toast.error(t('team.last_member')),
  })

  if (isLoading) return <CenteredMessage>{t('common.loading')}</CenteredMessage>
  if (error) return <CenteredMessage>{t('common.error')}</CenteredMessage>

  const members = data?.data ?? []

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6">
      <div>
        <h1 className="font-medium text-2xl">{t('team.title')}</h1>
        <p className="text-muted-foreground text-sm">{t('team.subtitle')}</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>{t('team.title')}</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col">
          {members.length === 0 && (
            <p className="text-muted-foreground text-sm">{t('team.empty')}</p>
          )}
          {members.map((member) => (
            <div
              key={member.id}
              className="flex items-center justify-between border-border border-b py-3 last:border-b-0"
            >
              <div className="flex flex-col">
                <span className="font-medium text-sm">{member.full_name || member.email}</span>
                {member.full_name && (
                  <span className="text-muted-foreground text-xs">{member.email}</span>
                )}
              </div>
              <Button
                variant="ghost"
                size="sm"
                disabled={remove.isPending}
                onClick={async () => {
                  const ok = await confirm({
                    title: t('team.remove'),
                    message: t('team.remove_confirm', {
                      name: member.full_name || member.email,
                    }),
                    variant: 'destructive',
                    confirmLabel: t('team.remove'),
                  })
                  if (ok) remove.mutate(member.id)
                }}
              >
                {t('team.remove')}
              </Button>
            </div>
          ))}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>{t('team.invite')}</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={form.handleSubmit((values) => invite.mutate(values.email))}>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="invite-email">{t('team.invite_email')}</FieldLabel>
                <Input
                  id="invite-email"
                  type="email"
                  {...form.register('email', { required: true })}
                />
              </Field>
              <div className="flex justify-end">
                <Button type="submit" disabled={invite.isPending}>
                  {invite.isPending ? t('team.invite_sending') : t('team.invite_submit')}
                </Button>
              </div>
            </FieldGroup>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}
