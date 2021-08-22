class Payment < ApplicationRecord
  belongs_to :order

  TYPE_DEPOSIT=0
  TYPE_PAY = 1


  def self.pay(order, type)
    payment = Payment.find_or_initialize_by(:order_id => order.id, :paytype => TYPE_DEPOSIT)
    if type == TYPE_DEPOSIT
      payment.amount = order.deposit
    else
      payed = payment.amount.to_i
      payment = Payment.find_or_initialize_by(:order_id => order.id, :paytype => TYPE_PAY)
      payment.amount = (eval(order.price) - payed)
    end
    payment.user_id = order.user_id
    payment.save

  end

  def self.day_report
    payments = Payment.where(created_at: Time.current.all_day)
    sum = { }
    payments.each do |pay|
      next if pay.order.nil?
      if sum[pay.order.user.name]
        sum[pay.order.user.name] += pay.amount.to_i
      else
        sum[pay.order.user.name] = pay.amount.to_i
      end
    end
    sum
  end

end
