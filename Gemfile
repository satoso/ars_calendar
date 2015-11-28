#source "https://rubygems.org"
source "http://rubygems.org"

gem "sinatra"
gem "sequel"
gem "sqlite3"
gem "holiday_jp"

group :development, :test do
  gem "thin"
  gem "pry"
  gem "sinatra-contrib"
end

# to `bundle install` on sakura internet server:
# - source "http://rubygems.org"  (drop 's' in 'https:')
# - build sqlite3 as follows:
#   $ cd $HOME/local/src
#   $ wget http://www.sqlite.org/2015/sqlite-autoconf-3081001.tar.gz
#   $ tar vxzf sqlite-autoconf-3081001.tar.gz
#   $ cd sqlite-autoconf-3081001
#   $ ./configure --prefix=$HOME/local
#   $ make && make install
# - install sqlite3 as follows:
#   $ gem install sqlite3 -- --with-opt-dir=$HOME/local
#
# see: http://d.hatena.ne.jp/lettas0726/20090820/1250779080
# see: http://d.hatena.ne.jp/aTaGo/20100708/1278608962
