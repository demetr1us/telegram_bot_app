class Payment < ApplicationRecord

  TYPE_DEPOSIT=0
  TYPE_PAY = 1


  def self.pay(order, type)
    if type == TYPE_DEPOSIT
      amount = order.deposit
    else
      amount = order.price.to_i - order.deposit.to_i
    end
    payment = Payment.find_or_initialize_by(:order_id => order.id, :paytype => type)
    payment.user_id = order.user_id
    payment.amount = amount
    payment.save
  end

end
