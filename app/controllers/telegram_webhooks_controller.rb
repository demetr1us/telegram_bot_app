class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext

  def menu!
    start!
  end

  def users_buttons(order_id)
    result = []
    users = getUsers()
    users.each_slice(3) do |slice|
      slice.map!{|user| {text: user.name, callback_data: "assign_#{order_id}_#{user.id}"} }
      result.push(slice)
    end
    result
  end

  def users!
    return false unless admin?
    users = User.all
    response=[]
    users.each do |user|
      response.push("#{user.name} (#{user.phone})||| приєднався: ||| #{user.created_at.strftime("%d.%m.%Y")} ||| '/user_#{user.id}'" )
    end
    respond_with :message, text: response.join("\n")
  end

  def transfer(order_id)
    puts "1============"
    return false unless admin?
    puts "2============"
    buttons = users_buttons(order_id)
    respond_with :message, text: "Оберіть кому передати замовлення?", reply_markup: {
      inline_keyboard:  buttons,
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true,
    }
  end

  def do_transfer(order_id, user_id)
    return false unless admin?
    order = getOrder(order_id)
    order.transferToUser(user_id)
    order.setOnHold if order.status == 1
    order.actor = chat['id']
    order.save
    view!(order_id)
  end

  def getOrders
    if admin?
      Order.adminOrders
    else
      Order.userOrders(chat['id'])
    end
  end

  def getUsers(type=nil)
    if type.nil?
      User.all
    else
      User.where({:role=>type.to_i})
    end
  end

  def getUser(chat_id)
    User.where({'telegram_id': chat['id']}).first
  end

  def getOrder(order_id)
    if admin?
      Order.find(order_id)
    else
      Order.getUserOrder(order_id, chat['id'])
    end
  end

  def admin?
    User.where({'telegram_id': chat['id']}).first.is_admin
  end

  def start!(*)
    puts users_buttons(5).to_s
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

  def user(user_id)
    return false unless admin?
    puts "user_id=#{user_id}"
    user = User.find(user_id.to_i)
    response = "=====================Працівник=======================\n"
    response +="#{user.type}: #{user.name}\n"
    response += "Телефон: #{user.phone}\n"
    response += "Дата реєстрації: #{user.created_at.strftime("%d.%m.%Y")}"
    respond_with :message, text: response, reply_markup: {
      inline_keyboard: [
        [
          {text: 'Список замовлень', callback_data: "userorder_#{user_id}"}
        ]
      ],
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true,
    }


  end

  def view!(*args)
    user = getUser(chat['id'])
    order = getOrder(args.join(" ").to_i)
    users = User.getUsers
    response = "============Cтатус: #{order.getStatus}================\n"
    response += "номер замовлення: #{order.id}\n"
    response += "працівник: #{users[order.user_id]}\n" if user.is_admin
    response += "Заказ: #{order.name} (#{order.created_at.to_date.strftime("%d.%m.%Y")}) \n"
    response += "клієнт: #{order.clientname} (#{order.clientphone})\n"
    response += "#{order.description}\n"
    response += "ціна/аванс: #{order.price}/#{order.deposit}\n"
    response += "Закінчення: #{order.finish_date.strftime("%d.%m.%Y")}\n"
    response += "========================================================\n"

    all_buttons = []
    all_buttons.push([{text: 'редагувати', callback_data: "edit_#{order.id}"}]) if (order.status == 0 || admin?)
    buttons = []
    unless order.status == 4 || order.status == 5
      buttons.push({text: 'Почати', callback_data: "status_#{order.id}_1"}) unless order.status == 1
      buttons.push({text: 'Зупинити', callback_data: "status_#{order.id}_2"}) unless order.status == 2
      buttons.push({text: 'Готово', callback_data: "status_#{order.id}_3"}) unless order.status == 3
      buttons.push({text: 'Видано', callback_data: "status_#{order.id}_4"})
    end
    buttons.push({text: 'Скасувати', callback_data: "status_#{order.id}_5"}) unless order.status == 5 && order.status == 4
    all_buttons.push(buttons)
    admin_buttons = [{text: 'Призначити майстра', callback_data: "transfer_#{order.id}"}]
    admin_buttons.push({text: 'Відновити', callback_data: "status_#{order.id}_0"}) if order.status == 5
    admin_buttons.push({text: 'Видалити', callback_data: "status_#{order.id}_10"}) if order.status == 5
    all_buttons.push(admin_buttons) if admin?
    all_buttons.push([{text: 'Історія змін', callback_data: "history_#{order.id}"}]) if admin?
    respond_with :message, text: response, reply_markup: {
      inline_keyboard: all_buttons,
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true,
    }

  end

  def history(order_id)
    response = []
    puts "ORDER = #{order_id}"
    records = OrdersLog.order_history(order_id)
    return  respond_with :message, text: "Пусто" if records.empty?
    users = User.getUsers

    records.each do |record|
      response.push("#{record.created_at.strftime('%d.%m.%Y')}: (#{users[record.actor]}) Виконавець: #{users[record.user_id]}  #{record.reason}")
    end
    respond_with :message, text: response.join("\n")
  end

  def register1(*args)
    session['register']['name'] =  args.join(" ")
    save_context :register2
    respond_with :message, text: "Вкажіть Ваш номер телефону:"
  end

  def register2(*args)
    puts args.inspect
    session['register']['phone'] =  normaize_phone(args.join(" "))
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
          {text: 'Працівники', callback_data: 'users' }
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
    elsif value == 'Скасувати'
      menu!
    end
  end

  def list!
    if admin?
      return admin_orders
    else
      return order_list
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
    elsif value == 'Скасувати'
      menu!
    end
  end

  def order_list(user_id=nil)
    orders =  getOrders
    puts orders.to_json
    return false if orders.empty?
    response = []
    orders.each do |order|
      response.push("#{order.clientname}: ||| #{order.name} ||| Статус: #{order.getStatus} ||| '/view_#{order.id}'" )
    end
    respond_with :message, text: response.join("\n")
  end

  def new!(*)
    save_context :new_order
    session['client'] = {}
    respond_with :message, text: "Ім'я клієнта: "
  end

  def edit!(*args)
    save_context :edit1
    order = getOrder(args.join(" ").to_i)
    respond_with :message, text: "Клієнт: #{order.clientname}"
    respond_with :message, text: "Телефон: #{order.clientphone}", reply_markup: {
      inline_keyboard: [
        [{text: 'Змінити', callback_data: "update_#{order.id}_phone"}]
      ],
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true,
    }
    respond_with :message, text: "Назва: #{order.name}", reply_markup: {
      inline_keyboard: [
        [{text: 'Змінити', callback_data: "update_#{order.id}_name"}]
      ],
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true,
    }

    respond_with :message, text: "Опис: #{order.description}", reply_markup: {
      inline_keyboard: [
        [{text: 'Змінити', callback_data: "update_#{order.id}_description"}]
      ],
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true,
    }
    respond_with :message, text: "Ціна: #{order.price}", reply_markup: {
      inline_keyboard: [
        [{text: 'Змінити', callback_data: "update_#{order.id}_price"}]
      ],
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true,
    }
    respond_with :message, text: "Аванс: #{order.deposit}", reply_markup: {
      inline_keyboard: [
        [{text: 'Змінити', callback_data: "update_#{order.id}_deposit"}]
      ],
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true,
    }
    respond_with :message, text: "Закінчення: #{order.finish_date.strftime("%d.%m.%Y")}", reply_markup: {
      inline_keyboard: [
        [{text: 'Змінити', callback_data: "update_#{order.id}_finish"}]
      ],
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true,
    }
  end

  def update!(order_id , type)
    msg = ''
    order = getOrder(order_id.to_i)
    return false if (order.nil? || (order.status != 0 && !admin?))
    save_context :update2
    session['update'] = {'id': order_id, 'type': type}
    if type == 'name'
      msg = "Введіть назву"
    elsif type == 'description'
      msg = "Введіть опис"
    elsif  type == 'price'
      msg = "Введіть ціну"
    elsif  type == 'deposit'
      msg = "Введіть аванс"
    elsif  type == 'finish'
      msg = "Введіть дату закінчення"
    else
      return  respond_with :message, text: 'невідоме поле'
    end
    respond_with :message, text: msg
  end

  def update2(*args)
    value = args.join(" ")
    puts session['update'][:id]
    order = getOrder(session['update'][:id].to_i)
    type = session['update'][:type]
    if type == 'name'
      order.name = value
    elsif type == 'description'
      order.description = value
    elsif  type == 'price'
      order.price = value
    elsif  type == 'deposit'
      order.deposit = value
    elsif  type == 'finish'
      order.finish_date = value.to_datetime
    else
      return  respond_with :message, text: 'невідоме поле'
    end
    order.save
    Payment.pay(order, Payment::TYPE_DEPOSIT)
    order.log('update',type)
    session['update'] = nil
    view!(order.id)
  end

  def new_order(*args)
    save_context :new_order2
    session['client']['name'] =  args.join(" ")
    respond_with :message, text: "Номер телефону клієнта:"
  end

  def normaize_phone(phone)
    phone = phone.delete('^0-9')

    phone ="+38#{phone}" if phone.length  == 10
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
    respond_with :message, text: "Дата закінчення (дд.мм.рррр наприклад 24.08.2021):"
  end

  def new_order7(*args)
    save_context :new_order5
    session['order']['finish_date'] =  args.join(" ").to_datetime

    begin
      order = Order.new
      order.user_id = chat['id']
      order.clientname = session['client']['name']
      order.clientphone =  session['client']['phone']
      order.name = session['order']['name']
      order.description = session['order']['description']
      order.price = session['order']['price'].to_i
      order.deposit = session['order']['money'].to_i
      order.finish_date = session['order']['finish_date']
      order.actor = chat['id']
      order.status = 0
      order.save!
      Payment.pay(order, Payment::TYPE_DEPOSIT)
      order.log('status')
    rescue
      respond_with :message, text: "Щось пішло не так, зв'яжіться з адміністратором"
      return false
    end
    view!(order.id)
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
    elsif parts[0] == 'edit'
      edit!(parts[1])
    elsif parts[0] == 'update'
      update!(parts[1], parts[2])
    elsif parts[0] == 'users'
      users!
    elsif parts[0] == 'list'
      admin_orders if admin?
      order_list if !admin?
    elsif parts[0] == 'status'
      status(parts[1], parts[2])
    elsif parts[0]=='userorder'
      order_list(parts[1]) if admin?
    elsif parts[0] == 'transfer'
      transfer(parts[1])
    elsif parts[0] == 'history'
      history(parts[1])
    elsif parts[0] == 'assign'
      do_transfer(parts[1], parts[2])
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

  def status(order_id,status)
    if status.to_i == 10 && admin?
      Order.deleteOrder(order_id.to_i)
      return order_list
    end
    order = getOrder(order_id)
    return false if order.nil?
    order.status = status
    order.actor = chat['id']
    order.save
    Payment.pay(order, Payment::TYPE_PAY) if order.status == 4
    order.log('status')
    view!(order.id)
  end

  def action_missing(action, *_args)
    if action_type == :command
      parts = action.split('_')
      return view!(parts[1].tr('!', '')) if parts[0]=='view'
      return user(parts[1]) if parts[0]=='user'
      return finish(parts[1]) if parts[0] == 'finish'
      return finish(parts[1]) if parts[0] == 'restore'
    end
  end

end
