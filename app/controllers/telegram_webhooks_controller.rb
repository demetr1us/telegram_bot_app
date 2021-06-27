class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext

  def getUser(chat_id)
    User.where({'telegram_id': chat['id']}).first
  end

  def admin?
    User.where({'telegram_id': chat['id']}).first.is_admin
  end

  def start!(*)
    user = getUser(chat['id'])
    if user.nil?
      save_context :register1
      session['register'] = {}
      respond_with :message, text: "Вкажіть Ваше ім'я(ПІП):"
    else
      respond_with :message, text: "Добрий день, #{user.name}"
      main
    end
  end

  def view!(*args)
    user = getUser(chat['id'])
    order = Order.getUserOrder(args.join(" "), chat['id'])
    users = User.getUsers
    response = "========================================================\n"
    response += "працівник: #{users[order.user_id]}\n" if user.is_admin
    response += "Заказ: #{order.name} (#{order.created_at.to_date.strftime("%d.%m.%Y")}) \n"
    response += "клієнт: #{order.clientname} (#{order.clientphone})\n"
    response += "#{order.description}\n"
    response += "ціна/аванс: #{order.price}/#{order.deposit}\n"
    response += "Закінчення: #{order.finish_date.strftime("%d.%m.%Y")}\n"
    response += "========================================================\n"

    if order.finished?
      button = {text: 'Відновити', callback_data: "finish_#{order.id}"}
    else
      button = {text: 'Закінчити', callback_data: "finish_#{order.id}"}
    end

    respond_with :message, text: response, reply_markup: {
      inline_keyboard: [
        [
          button
        ]
      ],
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true,
    }

  end

  def register1(*args)
    session['register']['name'] =  args.join(" ")
    save_context :register2
    respond_with :message, text: "Вкажіть Ваш номер телефону:"
  end

  def register2(*args)
    puts args.inspect
    session['register']['phone'] =  args.join(" ")
    save_context :register3
    respond_with :message, text: "Ваше ім'я: #{session['register']['name']}\nВаш телефон: #{session['register']['phone']}", reply_markup: {
      keyboard: [
        ['text':'Підтверджую', 'callback_data': 'ok'],
        ['Скасувати']],
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true,
    }
  end

  def register3(val)
    puts val.inspect
    if (val == 'Підтверджую')
      begin
      user = User.new
      user.id = chat['id']
      user.name = session['register']['name']
      user.phone = session['register']['phone']
      user.role = 0
      user.telegram_id = chat['id']
      user.save!
      rescue
        respond_with :message, text: "Щось пішло не так, зв'яжіться з адміністратором"
      end
        respond_with :message, text: "Чудово! тепер ми знайомі, можна приступати до роботи :) !"
        main
      end

    end

  def main(*)
    user = getUser(chat['id'])
    if user.is_admin
      admin_menu
    else
      user_menu
    end
  end

  def admin_menu(value = nil, *)
    save_context :admin_menu2
    respond_with :message, text: "Menu", reply_markup: {
      inline_keyboard: [
        [
          {text: 'Новий заказ', callback_data: 'new'},
          {text: 'Список заказів', callback_data: 'list'},
        ]
      ],
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true,
    }

  end


  def admin_menu2(value = nil, *)
    if value == 'Новий'
      save_context :new_order
      session['client'] = {}
      respond_with :message, text: "Ім'я клієнта: "
    elsif value == 'Список'
      admin_orders
    end
  end

  def admin_orders
    users = User.getUsers
    response = []
    Order.adminOrders.each do |order|
      response.push("#{users[order.user_id]} ||| #{order.clientname}: ||| #{order.name} ||| закінчити: #{order.finish_date} ||| '/view_#{order.id}'" )
    end
    respond_with :message, text: response.join("\n")
  end

  def user_menu(value = nil, *)
    save_context :user_menu2
    respond_with :message, text: "Menu", reply_markup: {
      inline_keyboard: [
              [
               {text: 'Новий заказ', callback_data: 'new'},
               {text: 'Список заказів', callback_data: 'list'},
               ]
        ],
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true,
    }
  end

  def user_menu2(value = nil, *)
    #respond_with :message, text: value.join(' ')
    puts value
    if value == 'Новий'
      save_context :new_order
      session['client'] = {}
      respond_with :message, text: "Ім'я клієнта: "
    elsif value == 'Список'
      order_list
    end
  end

  def order_list
    orders = Order.userOrders(chat['id'])
    return false if orders.empty?
    response = []
    orders.each do |order|
      response.push("#{order.clientname}: ||| #{order.name} ||| закінчити: #{order.finish_date} ||| '/view_#{order.id}'" )
    end
    respond_with :message, text: response.join("\n")
  end

  def new!(*)
    save_context :new_order
    session['client'] = {}
    respond_with :message, text: "Ім'я клієнта: "
  end

  def new_order(*args)
    save_context :new_order2
    session['client']['name'] =  args.join(" ")
    respond_with :message, text: "Номер телефону клієнта:"
  end

  def normaize_phone(phone)
    phone = phone.delete('^0-9')

    phone ="38#{phone}" if phone.length  == 10
    phone
  end

  def new_order2(*args)
    save_context :new_order3
    session['client']['phone'] =  normaize_phone(args.join(" "))
    respond_with :message, text: "Назва заказу(виріб):"
  end

  def new_order3(*args)
    save_context :new_order4
    session['order'] = {}
    session['order']['name'] =  args.join(" ")
    respond_with :message, text: "Опис заказу(що треба зробити):"
  end

  def new_order4(*args)
    save_context :new_order5
    session['order']['description'] =  args.join(" ")
    respond_with :message, text: "Ціна заказу:"
  end

  def new_order5(*args)
    save_context :new_order6
    session['order']['price'] =  args.join(" ")
    respond_with :message, text: "Внесенний завдаток:"
  end

  def new_order6(*args)
    save_context :new_order7
    session['order']['money'] =  args.join(" ")
    respond_with :message, text: "Дата закінчення (орієнтовно):"
  end

  def new_order7(*args)
    save_context :new_order5
    session['order']['finish_date'] =  args.join(" ").to_datetime
    puts "client = "+session['client'].inspect
    puts "order = "+session['order'].inspect

    begin
      order = Order.new
      order.user_id = chat['id']
      order.clientname = session['client']['name']
      order.clientphone =  session['client']['phone']
      order.name = session['order']['name']
      order.description = session['order']['description']
      order.price = session['order']['price']
      order.deposit = session['order']['money']
      order.finish_date = session['order']['finish_date']
      order.save!
    rescue
      respond_with :message, text: "Щось пішло не так, зв'яжіться з адміністратором"
      return false
    end
    respond_with :message, text: "Додано!"
    user_menu
  end

  def help!(*)
    respond_with :message, text: t('.content')

  end

  def memo!(*args)
    if args.any?
      session[:memo] = args.join(' ')
      respond_with :message, text: t('.notice')
    else
      respond_with :message, text: t('.prompt')
      save_context :memo!
    end
  end

  def remind_me!(*)
    to_remind = session.delete(:memo)
    reply = to_remind || t('.nothing')
    respond_with :message, text: reply
  end

  def keyboard!(value = nil, *)
    if value
      respond_with :message, text: t('.selected', value: value)
    else
      save_context :keyboard!
      respond_with :message, text: t('.prompt'), reply_markup: {
        keyboard: [t('.buttons')],
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true,
      }
    end
  end

  def inline_keyboard!(*)
    respond_with :message, text: t('.prompt'), reply_markup: {
      inline_keyboard: [
        [
          {text: t('.alert'), callback_data: 'alert'},
          {text: t('.no_alert'), callback_data: 'no_alert'},
        ],
        [{text: t('.repo'), url: 'https://github.com/telegram-bot-rb/telegram-bot'}],
      ],
    }
  end

  def callback_query(data)
    parts = data.split('_')
    if parts[0] == 'new'
      new!
    elsif parts[0] == 'list'
      admin_orders if admin?
      order_list if !admin?
    elsif parts[0] == 'finish'
      finish(parts[1])
    else
      answer_callback_query t('.no_alert')
    end
  end

  def inline_query(query, _offset)
    query = query.first(10) # it's just an example, don't use large queries.
    t_description = t('.description')
    t_content = t('.content')
    results = Array.new(5) do |i|
      {
        type: :article,
        title: "#{query}-#{i}",
        id: "#{query}-#{i}",
        description: "#{t_description} #{i}",
        input_message_content: {
          message_text: "#{t_content} #{i}",
        },
      }
    end
    answer_inline_query results
  end

  # As there is no chat id in such requests, we can not respond instantly.
  # So we just save the result_id, and it's available then with `/last_chosen_inline_result`.
  def chosen_inline_result(result_id, _query)
    session[:last_chosen_inline_result] = result_id
  end

  def last_chosen_inline_result!(*)
    result_id = session[:last_chosen_inline_result]
    if result_id
      respond_with :message, text: t('.selected', result_id: result_id)
    else
      respond_with :message, text: t('.prompt')
    end
  end

  def message(message)
    puts message.to_json
    return  user_menu2(message['text'].split(' ').first) if !admin?
    return admin_menu2(message['text'].split(' ').first) if admin?
    #respond_with :message, text: t('.content', text: message['text'])
  end

  def finish(order_id)
    if admin?
      order = Order.find(order_id)
    else
      order = Order.getUserOrder(order_id, chat['id'])
    end

    return false if order.nil?
    if order.status != 1
      order.status = 1
    else
      order.status = 0
    end
    puts "status = #{order.status}"
    order.save
    view!(order.id)
  end

  def action_missing(action, *_args)
    if action_type == :command
      parts = action.split('_')
      return view!(parts[1].tr('!', '')) if parts[0]=='view'
      return finish(parts[1]) if parts[0] == 'finish'
      return finish(parts[1]) if parts[0] == 'restore'
    end
  end

end
