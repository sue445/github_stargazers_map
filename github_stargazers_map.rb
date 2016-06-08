require "bundler"
require "pp"
require "open-uri"
require "uri"

Bundler.require

Dotenv.load

MAX_RETRY_COUNT = 5

# starを取得するリポジトリ（user/repo）
REPO_NAME = ARGV[0]

raise "require GITHUB_API_TOKEN" unless ENV["GITHUB_API_TOKEN"]
raise "require REPONAME" unless REPO_NAME

class RetryableError < StandardError; end

# リポジトリにstarをつけた人の一覧を取得する
def get_repo_stargazers(repo_name)
  Octokit.auto_paginate = true
  client = Octokit::Client.new(access_token: ENV["GITHUB_API_TOKEN"])

  puts "Fetch stargazers"
  stargazers = client.stargazers(repo_name)

  Parallel.map_with_index(stargazers) do |stargazer, i|
    puts "Fetch user (#{i+1}/#{stargazers.count}): #{stargazer.login}"
    user = client.user(stargazer.login)

    {
      user_name: stargazer.login,
      location: user.location,
      avatar_url: user.avatar_url,
    }
  end
end

# 住所から緯度経度を取得する
def fetch_latlng(address)
  retry_count = 0
  begin
    json = open("http://maps.googleapis.com/maps/api/geocode/json?address=#{URI.encode(address)}&sensor=false").read
    hash = JSON.parse(json)

    case hash["status"]
    when "OK"
      {
        lat: hash["results"][0]["geometry"]["location"]["lat"],
        lng: hash["results"][0]["geometry"]["location"]["lng"],
      }
    when "OVER_QUERY_LIMIT"
      raise RetryableError
    else
      raise "status is #{hash["status"]}: #{address}"
    end
  rescue RetryableError
    retry_count += 1
    raise "Retry over" if retry_count > MAX_RETRY_COUNT

    # NOTE: スリープしないとRateLimit超えてエラーになる
    sleep 1
    retry
  end
end

# locationから全員分の緯度経度を取得する
def fetch_user_locations(users)
  users.each_with_index do |user, i|
    puts "Fetch latlng (#{i+1}/#{users.count}): #{user[:user_name]}"
    next if user[:location].blank?

    latlng = fetch_latlng(user[:location])
    user[:lat] = latlng[:lat]
    user[:lng] = latlng[:lng]
  end
end

# KMLファイルに出力する
def write_kml(title, users, filename)
  kml = KMLFile.new
  folder = KML::Folder.new(name: title)
  users.find_all { |user| user[:lat] && user[:lng] }.each do |user|
    folder.features << KML::Placemark.new(
      name:     user[:user_name],
      description: user[:location],
      style: KML::Style.new(
        id: "style_#{user[:user_name]}",
        icon_style: KML::IconStyle.new(
          icon: KML::Icon.new(href: user[:avatar_url])
        )
      ),
      geometry: KML::Point.new(coordinates: {lat: user[:lat], lng: user[:lng]}),
    )
  end

  # NOTE: 1レイヤー2000行まで
  #   https://support.google.com/mymaps/answer/3024937
  raise "over 2000 features" if folder.features.count > 2000

  kml.objects << folder

  File.open(filename, "wb") do |f|
    f.write(kml.render)
  end
end

users = get_repo_stargazers(REPO_NAME)
fetch_user_locations(users)

filename = "dist/#{REPO_NAME.gsub("/", "-")}.kml"
write_kml("#{REPO_NAME} Stargazers", users, filename)
puts "Write to #{filename}"
