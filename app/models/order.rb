class Order < ApplicationRecord

  def self.userOrders(user_id)
    orders = Order.where({:user_id=>user_id})
    orders
  end

  def self.adminOrders
    Order.all
  end

  def self.getUserOrder(id, user_id)
    Order.where({:user_id=>user_id, :id=>id}).first
  end

  def finished?
     status == 1
  end

end