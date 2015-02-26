class MovePromotionCodeToPromotionCodeValue < ActiveRecord::Migration
  def up

    # This is done via SQL for performance reasons. For larger stores it makes
    # a difference of minutes vs hours for completion time.

    say_with_time 'generating spree_promotion_codes' do
      Spree::Promotion.connection.execute(<<-SQL.strip_heredoc)
        insert into spree_promotion_codes
          (promotion_id, value, created_at, updated_at)
        select
          spree_promotions.id,
          spree_promotions.code,
          '#{Time.now.to_s(:db)}',
          '#{Time.now.to_s(:db)}'
        from spree_promotions
        left join spree_promotion_codes
          on spree_promotion_codes.promotion_id = spree_promotions.id
        where (spree_promotions.code is not null and spree_promotions.code <> '') -- promotion has a code
          and spree_promotion_codes.id is null -- a promotion_code hasn't already been created
      SQL
    end

    if Spree::PromotionCode.group(:promotion_id).having("count(0) > 1").exists?
      raise "Error: You have promotions with multiple promo codes. The
             migration code will not work correctly".squish
    end

    say_with_time 'linking order promotions' do
      Spree::Promotion.connection.execute(<<-SQL.strip_heredoc)
        update spree_order_promotions
        set promotion_code_id = (
          select spree_promotion_codes.id
          from spree_promotions
          inner join spree_promotion_codes
            on spree_promotion_codes.promotion_id = spree_promotions.id
          where spree_promotions.id = spree_order_promotions.promotion_id
        )
        where spree_order_promotions.promotion_code_id is null
      SQL
    end

    say_with_time 'linking adjustments' do
      Spree::Promotion.connection.execute(<<-SQL.strip_heredoc)
        update spree_adjustments
        set promotion_code_id = (
          select spree_promotion_codes.id
          from spree_promotion_actions
          inner join spree_promotions
            on spree_promotions.id = spree_promotion_actions.promotion_id
          inner join spree_promotion_codes
            on spree_promotion_codes.promotion_id = spree_promotions.id
          where spree_promotion_actions.id = spree_adjustments.source_id
        )
        where spree_adjustments.source_type = 'Spree::PromotionAction'
          and spree_adjustments.promotion_code_id is null
      SQL
    end
  end

  def down
    # We can't do a down migration because we can't tell which data was created
    # by this migration and which data already existed.
  end
end
