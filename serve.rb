require 'rubygems'
require 'sinatra'
require 'datamapper'
require 'do_postgres'
require 'haml'
require 'open-uri'
require 'rss/maker'
require 'lib/authorization'
before do headers "Content-Type" => "text/html; charset=utf-8" end
$posts = ''
class Post
	include DataMapper::Resource
	property :id, Serial
	property :title, String
	property :description, Text
	property :date, DateTime
end
DataMapper::setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/dev.db")
DataMapper.auto_upgrade!

get '/' do
	refresh
	haml :new
end
get '/posts.xml' do
   content_type 'text/xml', :charset => 'utf-8'
	refresh if $posts == ''
	return "ERROR" if $posts == ''
	return $posts.to_s
end
get '/id/:id' do
	haml :post
end
get '/delete/:id' do
	require_admin
	Post.all(:id => params[:id].to_i).destroy!
	refresh
	redirect 'http://www.samwarmuth.com/fresh'
end
post '/new' do
	require_admin
	return "Malformed Input. Or you just suck." if params[:title].nil?||params[:title]==''
	post = Post.new(:title => params[:title], :description => params[:description], :date => Time.now)
	post.save
	refresh
	redirect "http://www.samwarmuth.com/fresh"
end
def refresh
	posts = Post.all
	return if posts.length == 0
	version = "2.0"
	content = RSS::Maker.make(version) do |m|
		m.channel.title = "SamWarmuth.com QuickPosts"
		m.channel.link = "http://www.samwarmuth.com"
		m.channel.description = "Old news (or new olds)"
		m.items.do_sort = true # sort items by date
		posts.each do |post|
			i = m.items.new_item
			i.title = post.title + " <a href='http://pdb.samwarmuth.com/delete/"+post.id.to_s+"'>x</a>"
			i.description = post.description
			i.link = "http://pdb.samwarmuth.com/id/"+post.id.to_s
			i.date = Time.parse(post.date.to_s)
		end
	end
	$posts=content
end
helpers do
	include Sinatra::Authorization
end
__END__
@@layout
!!!
%head
	%title Post DB
%body
	=yield
	
@@new
%form{:method => "POST", :action => "/new"}
	<input type="text" name="title" size=73 />
	%br
	<textarea rows = 10, cols = 70, name="description"></textarea>
	%br
	<button class="button">Add Item</button>
-posts = Post.all
-posts.each do |post|
	%p
		=post.title
		=post.date
		="http://pdb.samwarmuth.com/id/"+post.id.to_s
		%br
		=post.description
		
@@post
-post = Post.get(params[:id])
%h1
	= post.title
%p
	= post.date
	||
	= post.description
	||
	= "http://pdb.samwarmuth.com/id/"+post.id.to_s