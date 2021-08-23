class User < ApplicationRecord

  def is_client
    role == 0
  end
  def is_employee
    role == 1
  end
  def is_admin
    role == 2
  end

  def type
    if role == 2
      "Керівник"
    elsif role == 1
      "Майстриня"
    else
      "Клієнт"
    end
  end

  def self.addClient(phone, name, telegram_id)
    user = User.where({:phone=>phone}).first
    user = User.new if user.nil?
    user.id = telegram_id if user.id.to_i == 0
    user.name = name
    user.phone = phone
    user.role = 0
    user.telegram_id = telegram_id if user.telegram_id.to_i == 0
    user.save!
  end

  def create_order(name, description)
    order = Order.new
    order.name = name
    order.description = description
    order.clientphone = self.phone
    order.clientname = self.name
    order.user_id = self.id
    order.actor = self.id
    order.status = 0
    order.save!
    order
  end

  def self.getUsers
    Hash[User.all.collect{|user| [user.telegram_id, user.name]}]
  end

end
