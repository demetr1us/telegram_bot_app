module AdminProcs
  def users!
    return false unless admin?
    users = User.all
    puts "users = #{users.count}"
  end
end