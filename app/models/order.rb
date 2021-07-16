class Order < ApplicationRecord


  def self.userOrders(user_id)
    orders = Order.where({:user_id=>user_id, :status => [0,1,2,3,4]})
    orders
  end

  def self.adminOrders
    Order.all
  end

  def self.getUserOrder(id, user_id)
    Order.where({:user_id=>user_id, :id=>id}).first
  end

  def setInProgress
    status = 1
  end

  def setOnHold
    status = 2 if status < 2
  end

  def setReady
    status = 3 if status < 3
  end

  def setDone
    status = 4 if status < 4
  end

  def setCancelled
    status = 5
  end

  def getStatus
    if status == 0
      return "Новий"
    elsif status == 1
      return "Виконується"
    elsif status == 2
      return "Призупинено"
    elsif status == 3
      return "Готово"
    elsif status == 4
      return "Здано"
    elsif status == 5
      return "Скасовано"
    end
  end

  def transferToUser(user_id)
    self.user_id = user_id.to_i
  end


  def self.deleteOrder(order_id)
    puts order_id
    OrdersLog.where({order_id: order_id}).destroy_all
    Order.find(order_id.to_i).destroy
  end

  def log(type, info='')
    users = User.getUsers
    OrdersLog.add_log(actor, id, user_id,  "Статус: "+getStatus) if type=='status'
    OrdersLog.add_log(actor, id, user_id,  "Оновлено: "+info) if type=='update'
    # if user_id != actor
    #   OrdersLog.add_log(actor, id,  user_id , "Передано #{users[user_id]}")
    # else

    #    end
  end


end