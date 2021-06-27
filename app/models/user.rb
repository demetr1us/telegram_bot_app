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

  def self.getUsers
    Hash[User.all.collect{|user| [user.telegram_id, user.name]}]
  end

end
