# GitHubのリポジトリにstarつけた人の住所をGoogleマイマップで出すやつ

## Setup
1. https://github.com/settings/tokens でアクセストークンを取得
2. `cp .env.example .env`
3. `.env` にアクセストークンを書く

## Usage
```sh
bundle exec ruby github_stargazers_map.rb <user_name>/<repo_name>
```

`dist/` にKMLファイルが作られるのでGoogleマイマップにインポートする
