require 'bcrypt'
require 'rom'
require 'rom-repository'
require 'rom/sql'
require 'sqlite3'

# puts "ROM Version #{ROM::Core::VERSION}"
# puts "ROM Version #{ROM::SQL::VERSION}"
# puts "Sequel Version #{Sequel::VERSION}"
# puts "SQLite3 Gem Version #{SQLite3::VERSION}"

opts = {
  adapter: :sqlite,
  database: "#{Dir.pwd}/db.sqlite"
}

rom = ROM.container(:sql, opts) do |config|
  include BCrypt

  config.gateways[:default].create_table :user do
    primary_key :id
    column :username, String, null: false
    property :password, BCryptHash
    column :email, String, null: false
  end

  config.relation(:users) do
    schema(infer: true)
  end

  class User < ROM::Relation[:sql] # rubocop:disable Lint/ConstantDefinitionInBlock
    schema(infer: true)

    def authenticate(attempted_password)
      # `password` is an instance of `BCrypt`, which defines `==` for comparing a
      # plain text string to an encrypted string.
      # See https://github.com/codahale/bcrypt-ruby/blob/master/lib/bcrypt/password.rb#L64-L67
      password == attempted_password
    end
  end

  config.register_relation(User)
end

users = rom.relations[:user]
puts users.to_a.inspect

create_user = users.command(:create)
create_user.call(name: 'Rob', age: 30, is_admin: true)

ROM.finalize.env

class UserRepo < ROM::Repository[:user]
  commands :create
end

ROM.env.repositories[:default].run_migrations

# Create a test User
if User.count.zero?
  @user = User.create(username: 'admin')
  @user.password = 'admin'
  @user.save
end
