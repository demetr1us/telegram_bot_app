class OrdersLog < ApplicationRecord

  def self.add_log(actor, order_id, user_id, reason)
    record = OrdersLog.new
    record.actor = actor
    record.order_id = order_id.to_i
    record.user_id = user_id.to_i
    record.reason = reason
    record.save
  end

  def self.order_history(order_id)
    OrdersLog.where(order_id: order_id.to_i).order(created_at: :desc)
  end

end
