require 'rubygems'
require 'sinatra'
require 'slim'
require 'sequel'
require 'holiday_jp'
set :slim, pretty: false, sort_attrs: false
set :logging, false

# uncomment for debug
# require 'sinatra/reloader'
# require 'pry'
# require 'pp'
# set :logging, true

before do
  DB ||= Sequel.connect('sqlite://schedule.db')
end

# ------------------- helpers ------------------------------------

helpers do
  APP ||= ''
  DAY_LETTERS ||= %w(日 月 火 水 木 金 土)
  TIME_LETTERS ||= %w(朝 昼 夜)
  AVAILABILITY_LETTERS ||= %w(○ △ × -)

  # --- helpers for controller

  # scheduleを取得してhash化
  def get_schedule_hash(days)
    schedule = DB[:schedule].where(date: days)

    entries = {}
    schedule.each do |s|
      entries[{
        date:      s[:date],
        timeslot:  s[:timeslot],
        member_id: s[:member_id]
      }] = s[:availability]
    end
    entries
  end

  # yyyymmのバリデーション
  def validate_yyyymm?(yyyymm)
    return true  if yyyymm.nil?  # nilならnilでOK
    return false unless /^\d{6}$/ === yyyymm

    # 日付としてparse可能か
    begin
      Date.parse(yyyymm + '01')
      true
    rescue ArgumentError
      false
    end
  end

  # 'yyyymm'から各種日付の生成
  def gen_dates(yyyymm)
    if yyyymm
      target = Date.parse(yyyymm + '01')
    else
      # nilの場合は今月
      target = Date.new(Date.today.year, Date.today.month, 1)
    end

    # targetからの1ヶ月間のうちで土日・祝日のみ選択
    days = (target..target.next_month-1).to_a.select { |d|
      d.saturday? || d.sunday? || HolidayJp.holiday?(d)
    }

    # 前ページ・当ページ・次ページのナビゲーション用日付文字列
    navs = {}
    navs[:prev] = target.prev_month.strftime('%Y%m')
    navs[:here] = (yyyymm || '')
    navs[:next] = target.next_month.strftime('%Y%m')

    [target, days, navs]
  end

  # --- helpers for view

  # '祝'マーク生成
  def holiday_mark(date)
    HolidayJp.holiday?(date) ? '祝' : ''
  end

  # ラジオボタンのname属性生成
  def rbtn_name(member, date, timeslot)
    "entry_#{member[:id]}_#{date.strftime('%Y%m%d')}_#{timeslot}"
  end
end

# ------------------- schedule ------------------------------------

# index
get %r{^/(\d{6})?$} do |yyyymm|
  halt 404, 'invalid parameter' unless validate_yyyymm?(yyyymm)

  @members = DB[:members].where(:active).order(:order)
  _, @days, @navs = gen_dates(yyyymm)
  @entries = get_schedule_hash(@days)
  slim :index
end

# edit
get %r{^/members/(\d+)/schedule/edit/(\d{6})?$} do |member_id, yyyymm|
  halt 404, 'invalid parameter' unless validate_yyyymm?(yyyymm)

  @member = DB[:members].where(id: member_id).first
  _, @days, @navs = gen_dates(yyyymm)
  @entries = get_schedule_hash(@days)
  slim :edit
end

# update
post %r{^/(\d{6})?$} do |yyyymm|
  # paramsからスケジュールエントリを拾う
  entries = []
  params.each do |key, value|
    if /^entry_/ =~ key
      _, m, d, t = key.split('_')
      a = value
      entries << {
        date: Date.parse(d),
        timeslot: t.to_i,
        member_id: m.to_i,
        availability: a.to_i
      }
    end
  end

  # insert or update
  entries.each do |e|
    # updateしてみて，更新行数が0の場合はinsert
    if DB[:schedule].where(
        date: e[:date],
        timeslot: e[:timeslot],
        member_id: e[:member_id]
       ).update(availability: e[:availability]) == 0
      DB[:schedule].insert e
    end
  end

  if params[:button] == 'save_and_next'
    # 次月へ
    redirect "#{APP}/members/#{params[:member_id]}/schedule/edit/#{params[:next_month]}"
  else
    # indexへ
    redirect "#{APP}/#{yyyymm}"
  end
end

# ------------------- member ------------------------------------

# index
get '/members' do
  @members = DB[:members].order(:order)
  slim :'members/index'
end

# edit
get %r{^/members/(\d+)/edit$} do |member_id|
  @member = DB[:members].where(id: member_id).first
  slim :'members/edit'
end

# update
post %r{^/members/(\d+)$} do |member_id|
  DB[:members].where(id: member_id).update(
    name: params[:member_name],
    order: params[:member_order],
    active: (params[:member_active] == 'on')
  )
  redirect "#{APP}/members"
end

# delete
delete %r{^/members/(\d+)$} do |member_id|
  DB[:members].where(id: member_id).delete
  redirect "#{APP}/members"
end

# new
get '/members/new' do
  # 新規メンバの「表示順」のデフォルトは，現在の最大値に10を加えて1の位を切り捨てた数
  # e.g. 現在の最大値が13の場合は20がデフォルト
  # memberが0人の場合はmax()でnilが返るので.to_iが必要
  @default_order = (DB[:members].max(:order).to_i + 10) / 10 * 10
  slim :'members/new'
end

# insert
post '/members' do
  DB[:members].insert(
    name: params[:member_name],
    order: params[:member_order],
    active: (params[:member_active] == 'on')
  )
  redirect "#{APP}/members"
end

# ------------------- debug ------------------------------------

get '/db_dump' do
  content_type 'text/plain'
  DB.tables.map { |t| [t.to_s, *DB[t].all] }.join("\n")
end

def db_create_table
  DB.create_table :members do
    primary_key :id
    String      :name
    Integer     :order
    TrueClass   :active
  end
  DB.create_table :schedule do
    primary_key :id
    Date        :date
    Integer     :timeslot
    foreign_key :member_id, :members, on_delete: :cascade
    Integer     :availability
  end
end

get '/db_initialize' do
  content_type 'text/plain'
  DB.tables.each do |t|
    DB.drop_table t
  end
  db_create_table
  'DB has been initialized!'
end

__END__

get '/db_seed' do
  content_type 'text/plain'
  db_seed
  'Data has been seeded!'
end

def db_seed
  [
    {name: '佐藤',    order: 30, active: true},
    {name: '佐々木',  order: 10, active: true},
    {name: '田中',    order: 20, active: true},
  ].each do |i|
    DB[:members].insert i
  end
  [
    {date: Date.new(2015,5,2), timeslot: 0, member_id: 1, availability: 0},
    {date: Date.new(2015,5,2), timeslot: 1, member_id: 1, availability: 2},
    {date: Date.new(2015,5,2), timeslot: 2, member_id: 1, availability: 2},
    {date: Date.new(2015,5,2), timeslot: 0, member_id: 2, availability: 1},
    {date: Date.new(2015,5,7), timeslot: 1, member_id: 2, availability: 0},
    {date: Date.new(2015,5,7), timeslot: 2, member_id: 2, availability: 0},
    {date: Date.new(2015,5,3), timeslot: 0, member_id: 2, availability: 1},
    {date: Date.new(2015,5,3), timeslot: 1, member_id: 2, availability: 0},
    {date: Date.new(2015,5,3), timeslot: 2, member_id: 2, availability: 0},
  ].each do |i|
    DB[:schedule].insert i
  end
end
