module ClientStuffConcern
  extend ActiveSupport::Concern

  def new_order_client
    session['client'] = {}
    session['client']['order'] = {}
    save_context :new_order_client2
    respond_with :message, text: "Назва виробу:"
  end

  def new_order_client2(*args)
    save_context :new_order_client3
    session['client']['order']['name'] = args.join(" ")
    respond_with :message, text: "Опишіть що саме треба зробити:"
  end

  def new_order_client3(*args)
    save_context :new_order_client4
    user = getUser(chat['id'])
    user.create_order(session['client']['order']['name'], args.join(" "))
    respond_with :message, text: "Замовлення додано успішно!"
    list!
  end

  def client_orders!(*)
    client = getUser(chat['id'])
    client_orders(client.phone)
  end

  def client_orders(phone_number)
    orders = Order.clientOrders(phone_number)
    users = User.getUsers
    orders.each do |order|
      saldo = eval(order.price) - order.deposit.to_i unless order.price.nil?
      msg = "====#{order.name}====\n"
      msg += "#{order.description}\n"
      msg += "Відповідальна особа: #{users[order.user_id]}\n"
      msg += "Статус: #{order.clientStatus} \n"
      msg += "До оплати: #{saldo} грн\n" if order.price.to_i >0
      msg += "Остання дія: #{order.updated_at.strftime("%d.%m.%Y %H:%M")}"
      respond_with :message, text: msg
    end
  end

end